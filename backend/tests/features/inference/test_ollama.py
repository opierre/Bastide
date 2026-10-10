"""Tests for `GET /api/v1/settings/inference/ollama`, with the transport mocked throughout."""

from collections.abc import Callable

import httpx
from fastapi.testclient import TestClient

from app.features.inference.client import HttpInferenceClient
from app.features.inference.ollama import OLLAMA_BASE_URL
from app.features.inference.router import get_ollama_client
from tests.api import register as _register


def _use_transport(
    client: TestClient, handler: Callable[[httpx.Request], httpx.Response]
) -> list[httpx.Request]:
    """Point the probe at a mock transport and return the requests it sends."""
    seen: list[httpx.Request] = []

    def record(request: httpx.Request) -> httpx.Response:
        seen.append(request)
        return handler(request)

    client.app.dependency_overrides[get_ollama_client] = lambda: HttpInferenceClient(
        OLLAMA_BASE_URL, transport=httpx.MockTransport(record)
    )
    return seen


def test_a_running_ollama_is_found_with_its_models(client: TestClient) -> None:
    headers = _register(client)
    seen = _use_transport(
        client,
        lambda request: httpx.Response(
            200, json={"object": "list", "data": [{"id": "gemma4:e4b"}]}
        ),
    )

    response = client.get("/api/v1/settings/inference/ollama", headers=headers)

    assert response.status_code == 200
    assert response.json() == {
        "found": True,
        "base_url": "http://127.0.0.1:11434/v1",
        "models": ["gemma4:e4b"],
    }
    # Loopback, and only the OpenAI-compatible listing: nothing Ollama-specific, nothing remote.
    assert [str(request.url) for request in seen] == ["http://127.0.0.1:11434/v1/models"]


def test_no_ollama_is_a_200_saying_not_found(client: TestClient) -> None:
    headers = _register(client)

    def refuse(request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectError("connection refused", request=request)

    _use_transport(client, refuse)

    response = client.get("/api/v1/settings/inference/ollama", headers=headers)

    assert response.status_code == 200
    assert response.json() == {
        "found": False,
        "base_url": "http://127.0.0.1:11434/v1",
        "models": [],
    }


def test_something_else_on_the_port_is_not_ollama(client: TestClient) -> None:
    """A listener that does not speak `/v1/models` is not a runtime the app can use."""
    headers = _register(client)
    _use_transport(client, lambda request: httpx.Response(404, text="not found"))

    response = client.get("/api/v1/settings/inference/ollama", headers=headers)

    assert response.json()["found"] is False


def test_detection_requires_authentication(client: TestClient) -> None:
    assert client.get("/api/v1/settings/inference/ollama").status_code == 401
