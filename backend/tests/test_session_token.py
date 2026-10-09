"""Tests for the per-launch session token every request must carry."""

import logging
from collections.abc import Generator

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.core.config import get_settings
from app.core.session import SESSION_TOKEN_HEADER
from app.main import create_app

TOKEN = "launch-token"


def _app(monkeypatch: pytest.MonkeyPatch, token: str | None) -> FastAPI:
    if token is None:
        monkeypatch.delenv("BASTIDE_SESSION_TOKEN", raising=False)
    else:
        monkeypatch.setenv("BASTIDE_SESSION_TOKEN", token)
    get_settings.cache_clear()
    return create_app()


@pytest.fixture(autouse=True)
def _fresh_settings() -> Generator[None]:
    yield
    get_settings.cache_clear()


@pytest.fixture
def client(monkeypatch: pytest.MonkeyPatch) -> TestClient:
    # Not entered as a context manager: no lifespan, so no database is touched.
    return TestClient(_app(monkeypatch, TOKEN))


def test_a_request_without_the_token_is_rejected(client: TestClient) -> None:
    response = client.get("/api/v1/health")

    assert response.status_code == 401
    assert response.json() == {
        "error": {
            "code": "SESSION_TOKEN_INVALID",
            "message": "Missing or invalid session token.",
        }
    }


def test_a_request_with_a_wrong_token_is_rejected(client: TestClient) -> None:
    response = client.get("/api/v1/health", headers={SESSION_TOKEN_HEADER: "guess"})

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "SESSION_TOKEN_INVALID"


def test_the_login_bearer_token_is_not_accepted_in_its_place(client: TestClient) -> None:
    response = client.get("/api/v1/health", headers={"Authorization": f"Bearer {TOKEN}"})

    assert response.status_code == 401


def test_a_request_with_the_token_is_served(client: TestClient) -> None:
    response = client.get("/api/v1/health", headers={SESSION_TOKEN_HEADER: TOKEN})

    assert response.status_code == 200
    assert response.json()["status"] == "ok"


def test_without_a_configured_token_requests_pass_and_a_warning_is_logged(
    monkeypatch: pytest.MonkeyPatch, caplog: pytest.LogCaptureFixture
) -> None:
    with caplog.at_level(logging.WARNING, logger="app.main"):
        client = TestClient(_app(monkeypatch, None))

    assert client.get("/api/v1/health").status_code == 200
    assert "BASTIDE_SESSION_TOKEN is not set" in caplog.text


def test_an_empty_token_counts_as_not_configured(monkeypatch: pytest.MonkeyPatch) -> None:
    client = TestClient(_app(monkeypatch, ""))

    assert client.get("/api/v1/health").status_code == 200
