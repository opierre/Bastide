"""Client for a local inference runtime, spoken over the OpenAI-compatible `/v1` surface.

`llama-server` (llama.cpp) and Ollama both expose that surface, so which engine is running
is configuration — `inference_base_url` and `model_tag` on the user's settings row — not
code (`PROJECT.md` §3). Nothing above this module may learn which one answered, which is
why only `/v1/models` and `/v1/chat/completions` are called and why every transport failure
is re-raised as one of the three errors below.
"""

from collections.abc import Sequence
from typing import Any, Protocol

import httpx

from app.features.settings.models import UserSettings

# A chat message as the `/v1/chat/completions` body carries it: {"role": ..., "content": ...}.
type Message = dict[str, str]

# Connect and read are deliberately separate budgets: a local model *generating* is slow,
# while a local model *absent* fails at once. Sharing one budget would either make an
# absent runtime hang the caller or cut a working one off mid-generation.
DEFAULT_CONNECT_TIMEOUT_S = 2.0
DEFAULT_READ_TIMEOUT_S = 120.0


class InferenceError(Exception):
    """Base class for every failure this module raises.

    No `httpx` exception escapes the module: callers branch on these types, so the HTTP
    library stays an implementation detail of the client.
    """


class InferenceUnavailable(InferenceError):
    """Nothing is listening: connection refused, unresolvable host, or connect timeout."""


class InferenceTimeout(InferenceError):
    """The runtime accepted the connection but did not answer within the read budget."""


class InferenceProtocolError(InferenceError):
    """The runtime answered with a non-2xx status or a body we cannot make sense of."""


class InferenceClient(Protocol):
    """The two operations the rest of the app may ask of an inference runtime."""

    async def list_models(self) -> list[str]:
        """Return the model tags the runtime currently offers.

        Raises:
            InferenceUnavailable: nothing is listening at the configured base URL.
            InferenceTimeout: the runtime accepted the connection but did not answer.
            InferenceProtocolError: non-2xx status or an unparseable body.
        """
        ...

    async def complete(
        self,
        messages: Sequence[Message],
        *,
        model: str,
        response_format: dict[str, Any] | None = None,
        timeout: float | None = None,
    ) -> str:
        """Run one non-streaming completion and return the assistant's message content.

        Raises:
            InferenceUnavailable: nothing is listening at the configured base URL.
            InferenceTimeout: generation exceeded the read budget.
            InferenceProtocolError: non-2xx status or an unparseable body.
        """
        ...


class HttpInferenceClient:
    """`InferenceClient` over HTTP against an OpenAI-compatible runtime on loopback."""

    def __init__(
        self,
        base_url: str,
        *,
        connect_timeout: float = DEFAULT_CONNECT_TIMEOUT_S,
        read_timeout: float = DEFAULT_READ_TIMEOUT_S,
        transport: httpx.AsyncBaseTransport | None = None,
    ) -> None:
        """Build a client.

        Args:
            base_url: the runtime's API root; `/v1` is appended when absent.
            connect_timeout: seconds to wait for the connection itself.
            read_timeout: seconds to wait for a completion to come back.
            transport: injected in tests so no request ever leaves the process.
        """
        self._base_url = _normalize_base_url(base_url)
        self._connect_timeout = connect_timeout
        self._read_timeout = read_timeout
        self._transport = transport

    @property
    def base_url(self) -> str:
        """The normalized `/v1` API root this client talks to."""
        return self._base_url

    async def list_models(self) -> list[str]:
        """Return the tags from `GET /v1/models`.

        Listing models is a lookup, not a generation, so it is held to the connect budget
        for reading too: a runtime that has accepted the connection but cannot list its
        models in that time is not one the caller should wait on.
        """
        response = await self._send("GET", "/models", timeout=self._timeout(self._connect_timeout))
        return _extract_models(self._parse(response))

    async def complete(
        self,
        messages: Sequence[Message],
        *,
        model: str,
        response_format: dict[str, Any] | None = None,
        timeout: float | None = None,
    ) -> str:
        """Run one non-streaming `POST /v1/chat/completions` and return the content.

        `response_format` requests structured output where the runtime supports it. Support
        varies between runtimes and builds, so it is treated as an optimisation only: if the
        request comes back with an error status, it is retried once without the parameter.
        The guarantee that the reply is usable comes from parsing it defensively, not from
        having constrained it.
        """
        budget = self._timeout(self._read_timeout if timeout is None else timeout)
        body: dict[str, Any] = {"model": model, "messages": list(messages), "stream": False}

        if response_format is None:
            response = await self._send("POST", "/chat/completions", json=body, timeout=budget)
        else:
            response = await self._send(
                "POST",
                "/chat/completions",
                json={**body, "response_format": response_format},
                timeout=budget,
            )
            if response.status_code >= 400:
                # Runtimes signal an unsupported parameter with no single agreed status,
                # so any error status earns the one plain retry rather than a guess at
                # which codes mean "rejected".
                response = await self._send("POST", "/chat/completions", json=body, timeout=budget)

        return _extract_content(self._parse(response))

    def _timeout(self, read: float) -> httpx.Timeout:
        return httpx.Timeout(read, connect=self._connect_timeout)

    async def _send(
        self,
        method: str,
        path: str,
        *,
        timeout: httpx.Timeout,
        json: dict[str, Any] | None = None,
    ) -> httpx.Response:
        """Perform one request, translating transport failures into typed errors.

        Raises:
            InferenceUnavailable: the connection could not be established.
            InferenceTimeout: the connection was established but the answer did not arrive.
            InferenceProtocolError: the exchange failed in some other protocol-level way.
        """
        url = f"{self._base_url}{path}"
        try:
            async with httpx.AsyncClient(transport=self._transport, timeout=timeout) as http:
                return await http.request(method, url, json=json)
        except (httpx.ConnectTimeout, httpx.ConnectError) as exc:
            # ConnectTimeout is also a TimeoutException; caught first because an
            # unreachable runtime is "unavailable", not "slow".
            raise InferenceUnavailable(
                f"No inference runtime answered at {self._base_url}."
            ) from exc
        except httpx.TimeoutException as exc:
            raise InferenceTimeout(
                f"The inference runtime at {self._base_url} did not answer in time."
            ) from exc
        except httpx.TransportError as exc:
            raise InferenceUnavailable(
                f"Could not reach the inference runtime at {self._base_url}."
            ) from exc
        except httpx.HTTPError as exc:
            raise InferenceProtocolError(
                f"The inference runtime at {self._base_url} spoke an unexpected protocol."
            ) from exc

    def _parse(self, response: httpx.Response) -> Any:
        """Return the decoded JSON body of a successful response.

        Raises:
            InferenceProtocolError: non-2xx status, or a body that is not JSON.
        """
        if response.status_code >= 400:
            raise InferenceProtocolError(
                f"The inference runtime returned HTTP {response.status_code}."
            )
        try:
            return response.json()
        except ValueError as exc:
            raise InferenceProtocolError(
                "The inference runtime returned a body that is not JSON."
            ) from exc


def client_from_settings(settings: UserSettings) -> HttpInferenceClient:
    """Build the HTTP client for the runtime a user has configured."""
    return HttpInferenceClient(settings.inference_base_url)


def _normalize_base_url(base_url: str) -> str:
    """Return `base_url` as an OpenAI `/v1` API root, whether or not it already is one."""
    trimmed = base_url.rstrip("/")
    return trimmed if trimmed.endswith("/v1") else f"{trimmed}/v1"


def _extract_models(payload: Any) -> list[str]:
    """Pull the model tags out of a `/v1/models` body.

    Raises:
        InferenceProtocolError: the body is not shaped like a model list.
    """
    if not isinstance(payload, dict) or not isinstance(payload.get("data"), list):
        raise InferenceProtocolError("The inference runtime returned no model list.")
    tags = [
        entry["id"]
        for entry in payload["data"]
        if isinstance(entry, dict) and isinstance(entry.get("id"), str)
    ]
    return tags


def _extract_content(payload: Any) -> str:
    """Pull the assistant message content out of a chat-completion body.

    Raises:
        InferenceProtocolError: the body carries no usable completion.
    """
    try:
        content = payload["choices"][0]["message"]["content"]
    except (KeyError, IndexError, TypeError) as exc:
        raise InferenceProtocolError("The inference runtime returned no completion.") from exc
    if not isinstance(content, str):
        raise InferenceProtocolError("The inference runtime returned a non-text completion.")
    return content
