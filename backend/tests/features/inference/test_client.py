"""Tests for the OpenAI-compatible inference client, with the transport mocked throughout.

No test here opens a socket: every case drives the real client code over an
``httpx.MockTransport``.
"""

import asyncio
import json
from collections.abc import Callable, Coroutine
from typing import Any

import httpx
import pytest

from app.features.inference.client import (
    DEFAULT_CONNECT_TIMEOUT_S,
    DEFAULT_READ_TIMEOUT_S,
    HttpInferenceClient,
    InferenceProtocolError,
    InferenceTimeout,
    InferenceUnavailable,
    client_from_settings,
)
from app.features.settings.models import UserSettings

BASE_URL = "http://127.0.0.1:11434/v1"
MESSAGES = [{"role": "user", "content": "Categorise CARREFOUR MARKET."}]
JSON_SCHEMA = {"type": "json_schema", "json_schema": {"name": "category", "schema": {}}}


def run[T](coro: Coroutine[Any, Any, T]) -> T:
    """Drive one coroutine to completion (avoids depending on an async pytest plugin)."""
    return asyncio.run(coro)


def _client(
    handler: Callable[[httpx.Request], httpx.Response], **kwargs: Any
) -> HttpInferenceClient:
    return HttpInferenceClient(BASE_URL, transport=httpx.MockTransport(handler), **kwargs)


def _completion(content: str) -> httpx.Response:
    return httpx.Response(
        200, json={"choices": [{"message": {"role": "assistant", "content": content}}]}
    )


def _recording_handler(
    responses: list[httpx.Response],
) -> tuple[Callable[[httpx.Request], httpx.Response], list[httpx.Request]]:
    """Return a handler replaying `responses` in order, plus the list it records into."""
    seen: list[httpx.Request] = []

    def handler(request: httpx.Request) -> httpx.Response:
        seen.append(request)
        return responses[min(len(seen) - 1, len(responses) - 1)]

    return handler, seen


def test_complete_parses_the_assistant_content() -> None:
    client = _client(lambda request: _completion("groceries"))

    assert run(client.complete(MESSAGES, model="gemma4:e4b")) == "groceries"


def test_list_models_returns_the_tags() -> None:
    client = _client(
        lambda request: httpx.Response(
            200, json={"object": "list", "data": [{"id": "gemma4:e4b"}, {"id": "qwen3:8b"}]}
        )
    )

    assert run(client.list_models()) == ["gemma4:e4b", "qwen3:8b"]


def test_client_speaks_only_the_openai_v1_paths() -> None:
    handler, seen = _recording_handler(
        [httpx.Response(200, json={"data": []}), _completion("groceries")]
    )
    client = _client(handler)

    run(client.list_models())
    run(client.complete(MESSAGES, model="gemma4:e4b"))

    assert [request.url.path for request in seen] == ["/v1/models", "/v1/chat/completions"]


def test_base_url_without_v1_still_targets_the_v1_paths() -> None:
    handler, seen = _recording_handler([httpx.Response(200, json={"data": []})])
    client = HttpInferenceClient("http://127.0.0.1:8080/", transport=httpx.MockTransport(handler))

    run(client.list_models())

    assert str(seen[0].url) == "http://127.0.0.1:8080/v1/models"


def test_completion_request_is_non_streaming_and_carries_the_model() -> None:
    handler, seen = _recording_handler([_completion("groceries")])
    client = _client(handler)

    run(client.complete(MESSAGES, model="gemma4:e4b"))

    body = json.loads(seen[0].content)
    assert body["stream"] is False
    assert body["model"] == "gemma4:e4b"
    assert body["messages"] == MESSAGES


def test_connection_refused_raises_inference_unavailable() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectError("connection refused", request=request)

    with pytest.raises(InferenceUnavailable):
        run(_client(handler).list_models())


def test_connect_timeout_raises_inference_unavailable() -> None:
    """A connect timeout means nothing is listening — not that generation is slow."""

    def handler(request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectTimeout("timed out connecting", request=request)

    with pytest.raises(InferenceUnavailable):
        run(_client(handler).complete(MESSAGES, model="gemma4:e4b"))


def test_read_timeout_raises_inference_timeout() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        raise httpx.ReadTimeout("timed out reading", request=request)

    with pytest.raises(InferenceTimeout):
        run(_client(handler).complete(MESSAGES, model="gemma4:e4b"))


def test_server_error_raises_inference_protocol_error() -> None:
    client = _client(lambda request: httpx.Response(500, json={"error": "boom"}))

    with pytest.raises(InferenceProtocolError):
        run(client.complete(MESSAGES, model="gemma4:e4b"))


def test_malformed_json_body_raises_inference_protocol_error() -> None:
    client = _client(
        lambda request: httpx.Response(
            200, content=b"<html>not json</html>", headers={"content-type": "application/json"}
        )
    )

    with pytest.raises(InferenceProtocolError):
        run(client.complete(MESSAGES, model="gemma4:e4b"))


def test_completion_without_choices_raises_inference_protocol_error() -> None:
    client = _client(lambda request: httpx.Response(200, json={"choices": []}))

    with pytest.raises(InferenceProtocolError):
        run(client.complete(MESSAGES, model="gemma4:e4b"))


def test_model_list_of_the_wrong_shape_raises_inference_protocol_error() -> None:
    client = _client(lambda request: httpx.Response(200, json={"models": ["gemma4:e4b"]}))

    with pytest.raises(InferenceProtocolError):
        run(client.list_models())


def test_response_format_rejected_is_retried_without_it() -> None:
    handler, seen = _recording_handler(
        [httpx.Response(400, json={"error": "unsupported parameter"}), _completion("groceries")]
    )
    client = _client(handler)

    result = run(client.complete(MESSAGES, model="gemma4:e4b", response_format=JSON_SCHEMA))

    assert result == "groceries"
    assert len(seen) == 2
    assert b"response_format" in seen[0].content
    assert b"response_format" not in seen[1].content


def test_response_format_is_sent_once_when_accepted() -> None:
    handler, seen = _recording_handler([_completion("groceries")])
    client = _client(handler)

    run(client.complete(MESSAGES, model="gemma4:e4b", response_format=JSON_SCHEMA))

    assert len(seen) == 1


def test_response_format_retry_happens_only_once() -> None:
    handler, seen = _recording_handler([httpx.Response(400, json={"error": "nope"})])
    client = _client(handler)

    with pytest.raises(InferenceProtocolError):
        run(client.complete(MESSAGES, model="gemma4:e4b", response_format=JSON_SCHEMA))
    assert len(seen) == 2


def test_completion_uses_the_read_budget_and_the_connect_budget() -> None:
    handler, seen = _recording_handler([_completion("groceries")])
    client = _client(handler)

    run(client.complete(MESSAGES, model="gemma4:e4b"))

    timeout = seen[0].extensions["timeout"]
    assert timeout["connect"] == DEFAULT_CONNECT_TIMEOUT_S
    assert timeout["read"] == DEFAULT_READ_TIMEOUT_S


def test_completion_timeout_argument_overrides_the_read_budget() -> None:
    handler, seen = _recording_handler([_completion("groceries")])
    client = _client(handler)

    run(client.complete(MESSAGES, model="gemma4:e4b", timeout=5.0))

    assert seen[0].extensions["timeout"]["read"] == 5.0


def test_list_models_never_waits_out_the_read_budget() -> None:
    """A probe must fail fast: listing models is a lookup, not a generation."""
    handler, seen = _recording_handler([httpx.Response(200, json={"data": []})])
    client = _client(handler, connect_timeout=2.0, read_timeout=120.0)

    run(client.list_models())

    timeout = seen[0].extensions["timeout"]
    assert timeout["connect"] == 2.0
    assert timeout["read"] == 2.0


def test_timeouts_are_configurable() -> None:
    handler, seen = _recording_handler([_completion("groceries")])
    client = _client(handler, connect_timeout=0.5, read_timeout=30.0)

    run(client.complete(MESSAGES, model="gemma4:e4b"))

    timeout = seen[0].extensions["timeout"]
    assert timeout["connect"] == 0.5
    assert timeout["read"] == 30.0


def test_client_from_settings_uses_the_configured_base_url() -> None:
    settings = UserSettings(user_id="u1", inference_base_url="http://localhost:8080/v1")

    client = client_from_settings(settings)

    assert client.base_url == "http://localhost:8080/v1"
