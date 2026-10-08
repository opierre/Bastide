"""Tests for register, login, logout, me, and password recovery."""

import re
from unittest.mock import Mock

import pytest
from fastapi.testclient import TestClient

from app.core.security import (
    generate_recovery_code,
    hash_password,
    hash_recovery_code,
    verify_password,
    verify_recovery_code,
)
from app.features.auth.models import User
from app.features.auth.repository import AuthRepository
from app.features.auth.schemas import PasswordReset
from app.features.auth.service import AuthService, InvalidRecoveryCodeError

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
        json={"identifier": REGISTER_PAYLOAD["email"], "password": REGISTER_PAYLOAD["password"]},
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


def test_register_stores_display_name_lowercased(client: TestClient) -> None:
    body = _register(client)

    assert body["user"]["display_name"] == "amelie"


@pytest.mark.parametrize("name", ["ab", "a" * 33, "amélie", "ame lie", "amelie@home", "  "])
def test_register_malformed_display_name_returns_422(client: TestClient, name: str) -> None:
    response = client.post("/api/v1/auth/register", json={**REGISTER_PAYLOAD, "display_name": name})

    assert response.status_code == 422


def test_register_email_without_at_returns_422(client: TestClient) -> None:
    response = client.post("/api/v1/auth/register", json={**REGISTER_PAYLOAD, "email": "amelie"})

    assert response.status_code == 422


def test_register_duplicate_display_name_any_case_returns_409(client: TestClient) -> None:
    client.post("/api/v1/auth/register", json=REGISTER_PAYLOAD)

    response = client.post(
        "/api/v1/auth/register",
        json={**REGISTER_PAYLOAD, "email": "other@example.com", "display_name": "AMELIE"},
    )

    assert response.status_code == 409
    assert response.json()["error"]["code"] == "DISPLAY_NAME_TAKEN"


@pytest.mark.parametrize("identifier", ["amelie", "Amelie", " AMELIE "])
def test_login_with_display_name_any_case(client: TestClient, identifier: str) -> None:
    client.post("/api/v1/auth/register", json=REGISTER_PAYLOAD)

    response = client.post(
        "/api/v1/auth/login",
        json={"identifier": identifier, "password": REGISTER_PAYLOAD["password"]},
    )

    assert response.status_code == 200
    assert response.json()["user"]["email"] == REGISTER_PAYLOAD["email"]


def test_login_display_name_wrong_password_returns_401(client: TestClient) -> None:
    client.post("/api/v1/auth/register", json=REGISTER_PAYLOAD)

    response = client.post(
        "/api/v1/auth/login", json={"identifier": "amelie", "password": "not-the-password"}
    )

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "INVALID_CREDENTIALS"


def test_login_wrong_password_returns_401(client: TestClient) -> None:
    client.post("/api/v1/auth/register", json=REGISTER_PAYLOAD)

    response = client.post(
        "/api/v1/auth/login",
        json={"identifier": REGISTER_PAYLOAD["email"], "password": "not-the-password"},
    )

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "INVALID_CREDENTIALS"


def test_login_unknown_email_returns_401(client: TestClient) -> None:
    response = client.post(
        "/api/v1/auth/login",
        json={"identifier": "nobody@example.com", "password": "whatever"},
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
        json={"identifier": REGISTER_PAYLOAD["email"], "password": REGISTER_PAYLOAD["password"]},
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


def _register(client: TestClient) -> dict:
    response = client.post("/api/v1/auth/register", json=REGISTER_PAYLOAD)
    assert response.status_code == 201
    return response.json()


def _reset(client: TestClient, recovery_code: str, new_password: str = "new-password"):
    return client.post(
        "/api/v1/auth/password-reset",
        json={
            "identifier": REGISTER_PAYLOAD["email"],
            "recovery_code": recovery_code,
            "new_password": new_password,
        },
    )


def test_register_returns_a_recovery_code(client: TestClient) -> None:
    body = _register(client)

    assert re.fullmatch(r"([0-9A-HJKMNP-TV-Z]{4}-){4}[0-9A-HJKMNP-TV-Z]{4}", body["recovery_code"])


def test_password_reset_sets_new_password_and_revokes_sessions(client: TestClient) -> None:
    body = _register(client)
    old_headers = {"Authorization": f"Bearer {body['token']}"}

    response = _reset(client, body["recovery_code"])

    assert response.status_code == 200
    reset_body = response.json()
    assert reset_body["user"]["email"] == REGISTER_PAYLOAD["email"]
    assert client.get("/api/v1/auth/me", headers=old_headers).status_code == 401
    new_headers = {"Authorization": f"Bearer {reset_body['token']}"}
    assert client.get("/api/v1/auth/me", headers=new_headers).status_code == 200
    old_login = client.post(
        "/api/v1/auth/login",
        json={"identifier": REGISTER_PAYLOAD["email"], "password": REGISTER_PAYLOAD["password"]},
    )
    assert old_login.status_code == 401
    new_login = client.post(
        "/api/v1/auth/login",
        json={"identifier": REGISTER_PAYLOAD["email"], "password": "new-password"},
    )
    assert new_login.status_code == 200


def test_password_reset_spends_the_code_and_issues_a_new_one(client: TestClient) -> None:
    body = _register(client)

    first = _reset(client, body["recovery_code"])
    reused = _reset(client, body["recovery_code"])
    second = _reset(client, first.json()["recovery_code"])

    assert first.json()["recovery_code"] != body["recovery_code"]
    assert reused.status_code == 401
    assert reused.json()["error"]["code"] == "INVALID_RECOVERY_CODE"
    assert second.status_code == 200


def test_password_reset_accepts_code_as_typed_by_hand(client: TestClient) -> None:
    body = _register(client)
    typed = body["recovery_code"].replace("-", " ").lower()

    assert _reset(client, typed).status_code == 200


def test_password_reset_with_display_name(client: TestClient) -> None:
    body = _register(client)

    response = client.post(
        "/api/v1/auth/password-reset",
        json={
            "identifier": "Amelie",
            "recovery_code": body["recovery_code"],
            "new_password": "new-password",
        },
    )

    assert response.status_code == 200
    assert response.json()["user"]["email"] == REGISTER_PAYLOAD["email"]


def test_password_reset_wrong_code_returns_401(client: TestClient) -> None:
    _register(client)

    response = _reset(client, "0000-0000-0000-0000-0000")

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "INVALID_RECOVERY_CODE"


def test_password_reset_unknown_email_returns_same_error(client: TestClient) -> None:
    response = client.post(
        "/api/v1/auth/password-reset",
        json={
            "identifier": "nobody@example.com",
            "recovery_code": "0000-0000-0000-0000-0000",
            "new_password": "new-password",
        },
    )

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "INVALID_RECOVERY_CODE"


def test_regenerate_recovery_code_replaces_the_old_one(client: TestClient) -> None:
    body = _register(client)
    headers = {"Authorization": f"Bearer {body['token']}"}

    response = client.post(
        "/api/v1/auth/recovery-code",
        json={"password": REGISTER_PAYLOAD["password"]},
        headers=headers,
    )

    assert response.status_code == 200
    new_code = response.json()["recovery_code"]
    assert new_code != body["recovery_code"]
    assert _reset(client, body["recovery_code"]).status_code == 401
    assert _reset(client, new_code).status_code == 200


def test_regenerate_recovery_code_wrong_password_returns_401(client: TestClient) -> None:
    body = _register(client)
    headers = {"Authorization": f"Bearer {body['token']}"}

    response = client.post(
        "/api/v1/auth/recovery-code", json={"password": "not-the-password"}, headers=headers
    )

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "INVALID_CREDENTIALS"
    assert _reset(client, body["recovery_code"]).status_code == 200


def test_regenerate_recovery_code_requires_auth(client: TestClient) -> None:
    response = client.post("/api/v1/auth/recovery-code", json={"password": "whatever"})

    assert response.status_code == 401


def test_password_reset_for_user_without_code_returns_401() -> None:
    user = User(
        email=REGISTER_PAYLOAD["email"],
        password_hash=hash_password(REGISTER_PAYLOAD["password"]),
        recovery_code_hash=None,
    )
    repository = Mock(spec=AuthRepository)
    repository.get_user_by_email.return_value = user
    service = AuthService(repository)

    with pytest.raises(InvalidRecoveryCodeError):
        service.reset_password(
            PasswordReset(
                identifier=REGISTER_PAYLOAD["email"],
                recovery_code="0000-0000-0000-0000-0000",
                new_password="new-password",
            )
        )
    repository.reset_credentials.assert_not_called()


def test_recovery_code_hashed_with_argon2id_and_normalized() -> None:
    code = generate_recovery_code()
    code_hash = hash_recovery_code(code)

    assert code_hash.startswith("$argon2id$")
    assert code not in code_hash
    assert verify_recovery_code(code.lower().replace("-", ""), code_hash) is True
    assert verify_recovery_code(generate_recovery_code(), code_hash) is False


def test_update_profile_changes_the_login_name(client: TestClient) -> None:
    body = _register(client)
    headers = {"Authorization": f"Bearer {body['token']}"}

    response = client.patch("/api/v1/auth/me", json={"display_name": "Amelie.R"}, headers=headers)

    assert response.status_code == 200
    assert response.json()["user"]["display_name"] == "amelie.r"
    password = REGISTER_PAYLOAD["password"]
    new_login = client.post(
        "/api/v1/auth/login", json={"identifier": "amelie.r", "password": password}
    )
    old_login = client.post(
        "/api/v1/auth/login", json={"identifier": "amelie", "password": password}
    )
    assert new_login.status_code == 200
    assert old_login.status_code == 401


def test_update_profile_keeping_own_name_succeeds(client: TestClient) -> None:
    body = _register(client)
    headers = {"Authorization": f"Bearer {body['token']}"}

    response = client.patch("/api/v1/auth/me", json={"display_name": "AMELIE"}, headers=headers)

    assert response.status_code == 200


def test_update_profile_taken_name_returns_409(client: TestClient) -> None:
    body = _register(client)
    client.post(
        "/api/v1/auth/register",
        json={**REGISTER_PAYLOAD, "email": "bruno@example.com", "display_name": "bruno"},
    )
    headers = {"Authorization": f"Bearer {body['token']}"}

    response = client.patch("/api/v1/auth/me", json={"display_name": "Bruno"}, headers=headers)

    assert response.status_code == 409
    assert response.json()["error"]["code"] == "DISPLAY_NAME_TAKEN"


def test_update_profile_malformed_name_returns_422(client: TestClient) -> None:
    body = _register(client)
    headers = {"Authorization": f"Bearer {body['token']}"}

    response = client.patch("/api/v1/auth/me", json={"display_name": "a b"}, headers=headers)

    assert response.status_code == 422


def test_update_profile_requires_auth(client: TestClient) -> None:
    response = client.patch("/api/v1/auth/me", json={"display_name": "amelie"})

    assert response.status_code == 401
