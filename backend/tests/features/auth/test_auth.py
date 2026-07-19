"""Tests for register, login, logout, and me."""

from fastapi.testclient import TestClient

from app.core.security import hash_password, verify_password

REGISTER_PAYLOAD = {
    "email": "amelie@example.com",
    "password": "correct-horse-battery-staple",
    "display_name": "Amelie",
    "locale": "fr",
    "currency": "eur",
}


def test_register_login_me_happy_path(client: TestClient) -> None:
    register_response = client.post("/api/v1/auth/register", json=REGISTER_PAYLOAD)
    assert register_response.status_code == 201
    register_body = register_response.json()
    assert register_body["user"]["email"] == REGISTER_PAYLOAD["email"]
    assert register_body["user"]["locale"] == "fr"
    assert register_body["user"]["currency"] == "EUR"
    assert "password" not in register_body["user"]
    assert "password_hash" not in register_body["user"]

    login_response = client.post(
        "/api/v1/auth/login",
        json={"email": REGISTER_PAYLOAD["email"], "password": REGISTER_PAYLOAD["password"]},
    )
    assert login_response.status_code == 200
    token = login_response.json()["token"]

    me_response = client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {token}"})
    assert me_response.status_code == 200
    assert me_response.json()["user"]["email"] == REGISTER_PAYLOAD["email"]
    assert me_response.json()["user"]["currency"] == "EUR"
    assert me_response.json()["user"]["locale"] == "fr"


def test_register_duplicate_email_returns_409(client: TestClient) -> None:
    client.post("/api/v1/auth/register", json=REGISTER_PAYLOAD)

    response = client.post("/api/v1/auth/register", json=REGISTER_PAYLOAD)

    assert response.status_code == 409
    assert response.json()["error"]["code"] == "EMAIL_TAKEN"


def test_login_wrong_password_returns_401(client: TestClient) -> None:
    client.post("/api/v1/auth/register", json=REGISTER_PAYLOAD)

    response = client.post(
        "/api/v1/auth/login",
        json={"email": REGISTER_PAYLOAD["email"], "password": "not-the-password"},
    )

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "INVALID_CREDENTIALS"


def test_login_unknown_email_returns_401(client: TestClient) -> None:
    response = client.post(
        "/api/v1/auth/login",
        json={"email": "nobody@example.com", "password": "whatever"},
    )

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "INVALID_CREDENTIALS"


def test_me_without_token_returns_401(client: TestClient) -> None:
    response = client.get("/api/v1/auth/me")

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "AUTH_ERROR"


def test_me_with_invalid_token_returns_401(client: TestClient) -> None:
    response = client.get("/api/v1/auth/me", headers={"Authorization": "Bearer not-a-real-token"})

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "AUTH_ERROR"


def test_logout_invalidates_token(client: TestClient) -> None:
    client.post("/api/v1/auth/register", json=REGISTER_PAYLOAD)
    login_response = client.post(
        "/api/v1/auth/login",
        json={"email": REGISTER_PAYLOAD["email"], "password": REGISTER_PAYLOAD["password"]},
    )
    token = login_response.json()["token"]
    headers = {"Authorization": f"Bearer {token}"}

    logout_response = client.post("/api/v1/auth/logout", headers=headers)
    assert logout_response.status_code == 204

    me_response = client.get("/api/v1/auth/me", headers=headers)
    assert me_response.status_code == 401


def test_register_invalid_locale_returns_422(client: TestClient) -> None:
    response = client.post("/api/v1/auth/register", json={**REGISTER_PAYLOAD, "locale": "de"})

    assert response.status_code == 422


def test_register_invalid_currency_returns_422(client: TestClient) -> None:
    response = client.post("/api/v1/auth/register", json={**REGISTER_PAYLOAD, "currency": "NOPE"})

    assert response.status_code == 422


def test_register_response_never_includes_password(client: TestClient) -> None:
    response = client.post("/api/v1/auth/register", json=REGISTER_PAYLOAD)

    assert REGISTER_PAYLOAD["password"] not in response.text


def test_password_hashed_with_argon2id_and_not_reversible() -> None:
    password_hash = hash_password(REGISTER_PAYLOAD["password"])

    assert password_hash != REGISTER_PAYLOAD["password"]
    assert password_hash.startswith("$argon2id$")
    assert verify_password(REGISTER_PAYLOAD["password"], password_hash) is True
    assert verify_password("wrong-password", password_hash) is False
