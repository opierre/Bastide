"""Tests for `GET /api/v1/settings/inference/health`, with the transport mocked throughout."""

import time
from collections.abc import Callable

import httpx
from fastapi.testclient import TestClient

from app.features.inference.client import HttpInferenceClient
from app.features.inference.router import get_inference_client
from tests.api import register as _register

BASE_URL = "http://127.0.0.1:11434/v1"


def _use_transport(client: TestClient, handler: Callable[[httpx.Request], httpx.Response]) -> None:
    """Point the endpoint's client at a mock transport, keeping the real client code."""
    client.app.dependency_overrides[get_inference_client] = lambda: HttpInferenceClient(
        BASE_URL, transport=httpx.MockTransport(handler)
    )


def test_reachable_runtime_lists_its_models(client: TestClient) -> None:
    headers = _register(client)
    _use_transport(
        client,
        lambda request: httpx.Response(
            200, json={"object": "list", "data": [{"id": "gemma4:e4b"}, {"id": "qwen3:8b"}]}
        ),
    )

    response = client.get("/api/v1/settings/inference/health", headers=headers)

    assert response.status_code == 200
    assert response.json() == {
        "reachable": True,
        "models": ["gemma4:e4b", "qwen3:8b"],
        "detail": None,
    }


def test_unreachable_runtime_is_a_200_with_a_detail(client: TestClient) -> None:
    """An absent runtime is the expected default state, not an app error."""
    headers = _register(client)

    def refuse(request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectError("connection refused", request=request)

    _use_transport(client, refuse)

    response = client.get("/api/v1/settings/inference/health", headers=headers)

    assert response.status_code == 200
    body = response.json()
    assert body["reachable"] is False
    assert body["models"] == []
    assert body["detail"]


def test_unreachable_runtime_answers_without_waiting_out_the_read_timeout(
    client: TestClient,
) -> None:
    headers = _register(client)

    def refuse(request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectError("connection refused", request=request)

    _use_transport(client, refuse)

    started = time.monotonic()
    response = client.get("/api/v1/settings/inference/health", headers=headers)
    elapsed = time.monotonic() - started

    assert response.json()["reachable"] is False
    # Comfortably under the 120 s read budget, and under the 2 s connect budget too.
    assert elapsed < 2.0


def test_a_misbehaving_runtime_is_reported_as_unreachable(client: TestClient) -> None:
    """A 500 or an unparseable body is still just "no usable runtime", never a 5xx here."""
    headers = _register(client)
    _use_transport(client, lambda request: httpx.Response(500, json={"error": "boom"}))

    response = client.get("/api/v1/settings/inference/health", headers=headers)

    assert response.status_code == 200
    assert response.json()["reachable"] is False


def test_health_requires_authentication(client: TestClient) -> None:
    assert client.get("/api/v1/settings/inference/health").status_code == 401
