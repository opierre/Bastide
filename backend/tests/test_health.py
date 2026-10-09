"""Tests for the health endpoint and the domain-exception error envelope."""

from fastapi import FastAPI
from fastapi.testclient import TestClient

from app import __version__
from app.core.errors import AuthError, NotFoundError, register_exception_handlers


def test_health_returns_ok_and_the_version(client: TestClient) -> None:
    response = client.get("/api/v1/health")

    assert response.status_code == 200
    assert response.json() == {"status": "ok", "version": __version__}


def test_not_found_error_maps_to_envelope_and_404() -> None:
    app = FastAPI()
    register_exception_handlers(app)

    @app.get("/boom")
    def boom() -> None:
        raise NotFoundError("Account not found", details={"id": "abc"})

    response = TestClient(app).get("/boom")

    assert response.status_code == 404
    assert response.json() == {
        "error": {
            "code": "NOT_FOUND",
            "message": "Account not found",
            "details": {"id": "abc"},
        }
    }


def test_auth_error_maps_to_401() -> None:
    app = FastAPI()
    register_exception_handlers(app)

    @app.get("/private")
    def private() -> None:
        raise AuthError("Not authenticated")

    response = TestClient(app).get("/private")

    assert response.status_code == 401
    assert response.json() == {"error": {"code": "AUTH_ERROR", "message": "Not authenticated"}}
