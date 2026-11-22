"""Tests for register, login, logout, me, and password recovery."""

import re
import shutil
from pathlib import Path
from unittest.mock import Mock

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.db import get_db
from app.core.security import (
    generate_recovery_code,
    hash_password,
    hash_recovery_code,
    verify_password,
    verify_recovery_code,
)
from app.features.auth.models import User
from app.features.auth.repository import AuthRepository
from app.features.auth.schemas import (
    EMAIL_MAX_LENGTH,
    PASSWORD_MIN_LENGTH,
    EmailChange,
    PasswordChange,
    PasswordReset,
)
from app.features.auth.service import (
    AuthService,
    EmailInvalidError,
    InvalidCredentialsError,
    InvalidRecoveryCodeError,
    PasswordTooShortError,
)

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


def test_register_keeps_the_display_name_case(client: TestClient) -> None:
    body = _register(client)

    assert body["user"]["display_name"] == "Amelie"


def test_register_accepts_a_display_name_with_a_space(client: TestClient) -> None:
    response = client.post(
        "/api/v1/auth/register", json={**REGISTER_PAYLOAD, "display_name": "Camille Dubois"}
    )

    assert response.status_code == 201
    assert response.json()["user"]["display_name"] == "Camille Dubois"


def test_register_collapses_inner_spaces(client: TestClient) -> None:
    response = client.post(
        "/api/v1/auth/register", json={**REGISTER_PAYLOAD, "display_name": "  Camille   Dubois "}
    )

    assert response.status_code == 201
    assert response.json()["user"]["display_name"] == "Camille Dubois"


@pytest.mark.parametrize(
    "name", ["ab", "a" * 33, "amélie", "amelie@home", "  ", "ab  ", "ame\tlie"]
)
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


@pytest.mark.parametrize("taken", ["camille dubois", "CAMILLE  DUBOIS", " Camille Dubois "])
def test_register_name_differing_by_case_or_spaces_returns_409(
    client: TestClient, taken: str
) -> None:
    client.post(
        "/api/v1/auth/register", json={**REGISTER_PAYLOAD, "display_name": "Camille Dubois"}
    )

    response = client.post(
        "/api/v1/auth/register",
        json={**REGISTER_PAYLOAD, "email": "other@example.com", "display_name": taken},
    )

    assert response.status_code == 409
    assert response.json()["error"]["code"] == "DISPLAY_NAME_TAKEN"


@pytest.mark.parametrize("schema", ["schema_template", "migrated_template"])
def test_display_name_is_unique_ignoring_case_in_the_database(
    request: pytest.FixtureRequest, tmp_path: Path, schema: str
) -> None:
    db_path = tmp_path / "users.db"
    shutil.copyfile(request.getfixturevalue(schema), db_path)
    engine = create_engine(f"sqlite:///{db_path}")
    user = {"password_hash": "x", "locale": "fr", "currency": "EUR"}
    try:
        with Session(engine) as db:
            db.add(User(email="a@example.com", display_name="Camille Dubois", **user))
            db.commit()
            db.add(User(email="b@example.com", display_name="camille dubois", **user))
            with pytest.raises(IntegrityError):
                db.commit()
    finally:
        engine.dispose()


@pytest.mark.parametrize("identifier", ["Camille Dubois", "camille dubois", " CAMILLE   DUBOIS "])
def test_login_with_a_spaced_display_name_any_case(client: TestClient, identifier: str) -> None:
    client.post(
        "/api/v1/auth/register", json={**REGISTER_PAYLOAD, "display_name": "Camille Dubois"}
    )

    response = client.post(
        "/api/v1/auth/login",
        json={"identifier": identifier, "password": REGISTER_PAYLOAD["password"]},
    )

    assert response.status_code == 200
    assert response.json()["user"]["display_name"] == "Camille Dubois"


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
    assert response.json()["user"]["display_name"] == "Amelie.R"
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
    assert response.json()["user"]["display_name"] == "AMELIE"


def test_update_profile_to_a_name_with_spaces(client: TestClient) -> None:
    body = _register(client)
    headers = {"Authorization": f"Bearer {body['token']}"}

    response = client.patch(
        "/api/v1/auth/me", json={"display_name": "Camille  Dubois"}, headers=headers
    )

    assert response.status_code == 200
    assert response.json()["user"]["display_name"] == "Camille Dubois"
    login = client.post(
        "/api/v1/auth/login",
        json={"identifier": "camille dubois", "password": REGISTER_PAYLOAD["password"]},
    )
    assert login.status_code == 200


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

    response = client.patch(
        "/api/v1/auth/me", json={"display_name": "Camille Dubois!"}, headers=headers
    )

    assert response.status_code == 422


def test_update_profile_requires_auth(client: TestClient) -> None:
    response = client.patch("/api/v1/auth/me", json={"display_name": "amelie"})

    assert response.status_code == 401


# Password minimum length: enforced where a password is set, never at login.

SHORT_PASSWORD = "a" * (PASSWORD_MIN_LENGTH - 1)
MINIMUM_PASSWORD = "a" * PASSWORD_MIN_LENGTH


def test_password_minimum_is_twelve() -> None:
    assert PASSWORD_MIN_LENGTH == 12


@pytest.mark.parametrize(
    ("schema", "field"),
    [
        ("UserRegister", "password"),
        ("PasswordReset", "new_password"),
        ("PasswordChange", "new_password"),
    ],
)
def test_openapi_publishes_the_password_minimum(app: FastAPI, schema: str, field: str) -> None:
    properties = app.openapi()["components"]["schemas"][schema]["properties"]

    assert properties[field]["minLength"] == 12


def test_register_with_11_characters_returns_password_too_short(client: TestClient) -> None:
    response = client.post(
        "/api/v1/auth/register", json={**REGISTER_PAYLOAD, "password": SHORT_PASSWORD}
    )

    assert response.status_code == 422
    error = response.json()["error"]
    assert error["code"] == "PASSWORD_TOO_SHORT"
    assert error["details"] == {"min_length": PASSWORD_MIN_LENGTH}
    login = client.post(
        "/api/v1/auth/login",
        json={"identifier": REGISTER_PAYLOAD["email"], "password": SHORT_PASSWORD},
    )
    assert login.status_code == 401


def test_register_with_12_characters_succeeds(client: TestClient) -> None:
    response = client.post(
        "/api/v1/auth/register", json={**REGISTER_PAYLOAD, "password": MINIMUM_PASSWORD}
    )

    assert response.status_code == 201


def test_password_reset_with_11_characters_returns_password_too_short(
    client: TestClient,
) -> None:
    body = _register(client)

    response = _reset(client, body["recovery_code"], new_password=SHORT_PASSWORD)

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "PASSWORD_TOO_SHORT"
    # Nothing changed: the old password still works and the recovery code isn't spent.
    old_login = client.post(
        "/api/v1/auth/login",
        json={"identifier": REGISTER_PAYLOAD["email"], "password": REGISTER_PAYLOAD["password"]},
    )
    assert old_login.status_code == 200
    assert _reset(client, body["recovery_code"]).status_code == 200


def test_password_reset_with_12_characters_succeeds(client: TestClient) -> None:
    body = _register(client)

    response = _reset(client, body["recovery_code"], new_password=MINIMUM_PASSWORD)

    assert response.status_code == 200
    login = client.post(
        "/api/v1/auth/login",
        json={"identifier": REGISTER_PAYLOAD["email"], "password": MINIMUM_PASSWORD},
    )
    assert login.status_code == 200


def test_password_reset_too_short_is_checked_before_the_recovery_code() -> None:
    repository = Mock(spec=AuthRepository)
    service = AuthService(repository)

    with pytest.raises(PasswordTooShortError):
        service.reset_password(
            PasswordReset(
                identifier=REGISTER_PAYLOAD["email"],
                recovery_code="0000-0000-0000-0000-0000",
                new_password=SHORT_PASSWORD,
            )
        )
    repository.get_user_by_email.assert_not_called()
    repository.reset_credentials.assert_not_called()


def test_login_with_a_short_legacy_password_still_works(app: FastAPI, client: TestClient) -> None:
    _register(client)
    legacy_password = "old-pw"
    # A password set before the minimum existed: write its hash straight into the database.
    session = next(app.dependency_overrides[get_db]())
    try:
        user = session.scalars(select(User).where(User.email == REGISTER_PAYLOAD["email"])).one()
        user.password_hash = hash_password(legacy_password)
        session.commit()
    finally:
        session.close()

    response = client.post(
        "/api/v1/auth/login",
        json={"identifier": REGISTER_PAYLOAD["email"], "password": legacy_password},
    )

    assert response.status_code == 200


NEW_PASSWORD = "another-long-passphrase"


def _change_password(client: TestClient, token: str, current: str, new: str = NEW_PASSWORD):
    return client.put(
        "/api/v1/auth/me/password",
        json={"current_password": current, "new_password": new},
        headers={"Authorization": f"Bearer {token}"},
    )


def _login(client: TestClient, password: str):
    return client.post(
        "/api/v1/auth/login",
        json={"identifier": REGISTER_PAYLOAD["email"], "password": password},
    )


def test_change_password_replaces_the_password(client: TestClient) -> None:
    body = _register(client)

    response = _change_password(client, body["token"], REGISTER_PAYLOAD["password"])

    assert response.status_code == 204
    assert _login(client, REGISTER_PAYLOAD["password"]).status_code == 401
    assert _login(client, NEW_PASSWORD).status_code == 200


def test_change_password_keeps_this_session_and_signs_out_the_others(client: TestClient) -> None:
    body = _register(client)
    other_token = _login(client, REGISTER_PAYLOAD["password"]).json()["token"]

    _change_password(client, body["token"], REGISTER_PAYLOAD["password"])

    def me(token: str) -> int:
        return client.get(
            "/api/v1/auth/me", headers={"Authorization": f"Bearer {token}"}
        ).status_code

    assert me(body["token"]) == 200
    assert me(other_token) == 401


def test_change_password_keeps_the_recovery_code(client: TestClient) -> None:
    body = _register(client)

    _change_password(client, body["token"], REGISTER_PAYLOAD["password"])

    assert _reset(client, body["recovery_code"]).status_code == 200


def test_change_password_wrong_current_password_returns_401(client: TestClient) -> None:
    body = _register(client)

    response = _change_password(client, body["token"], "not-the-password")

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "INVALID_CREDENTIALS"
    assert _login(client, REGISTER_PAYLOAD["password"]).status_code == 200


def test_change_password_too_short_returns_422(client: TestClient) -> None:
    body = _register(client)

    response = _change_password(client, body["token"], REGISTER_PAYLOAD["password"], SHORT_PASSWORD)

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "PASSWORD_TOO_SHORT"
    assert response.json()["error"]["details"]["min_length"] == PASSWORD_MIN_LENGTH
    assert _login(client, REGISTER_PAYLOAD["password"]).status_code == 200


def test_change_password_with_12_characters_succeeds(client: TestClient) -> None:
    body = _register(client)

    response = _change_password(
        client, body["token"], REGISTER_PAYLOAD["password"], MINIMUM_PASSWORD
    )

    assert response.status_code == 204
    assert _login(client, MINIMUM_PASSWORD).status_code == 200


def test_change_password_requires_auth(client: TestClient) -> None:
    response = client.put(
        "/api/v1/auth/me/password",
        json={"current_password": "whatever", "new_password": NEW_PASSWORD},
    )

    assert response.status_code == 401


def test_change_password_too_short_is_checked_before_the_current_password() -> None:
    user = User(
        email=REGISTER_PAYLOAD["email"],
        password_hash=hash_password(REGISTER_PAYLOAD["password"]),
    )
    repository = Mock(spec=AuthRepository)
    service = AuthService(repository)

    with pytest.raises(PasswordTooShortError):
        service.change_password(
            user,
            "session-token",
            PasswordChange(current_password="not-the-password", new_password=SHORT_PASSWORD),
        )
    repository.change_password.assert_not_called()


def test_change_password_closes_the_connections_of_the_dropped_sessions() -> None:
    user = User(
        email=REGISTER_PAYLOAD["email"],
        password_hash=hash_password(REGISTER_PAYLOAD["password"]),
    )
    repository = Mock(spec=AuthRepository)
    repository.change_password.return_value = ["session-a", "session-b"]
    live_sessions = Mock()
    service = AuthService(repository, live_sessions=live_sessions)

    service.change_password(
        user,
        "session-token",
        PasswordChange(current_password=REGISTER_PAYLOAD["password"], new_password=NEW_PASSWORD),
    )

    _, kwargs = repository.change_password.call_args
    assert kwargs["keep_token"] == "session-token"
    assert verify_password(NEW_PASSWORD, kwargs["password_hash"])
    assert [c.args[0] for c in live_sessions.revoke_session.call_args_list] == [
        "session-a",
        "session-b",
    ]


# Changing the email, a login identifier: re-checks the password, keeps the sessions.

NEW_EMAIL = "amelie.r@example.org"


def _change_email(client: TestClient, token: str, email: str, current: str | None = None):
    return client.put(
        "/api/v1/auth/me/email",
        json={
            "email": email,
            "current_password": REGISTER_PAYLOAD["password"] if current is None else current,
        },
        headers={"Authorization": f"Bearer {token}"},
    )


def _login_as(client: TestClient, identifier: str):
    return client.post(
        "/api/v1/auth/login",
        json={"identifier": identifier, "password": REGISTER_PAYLOAD["password"]},
    )


def test_change_email_replaces_the_login_email(client: TestClient) -> None:
    body = _register(client)

    response = _change_email(client, body["token"], NEW_EMAIL)

    assert response.status_code == 200
    assert response.json()["user"]["email"] == NEW_EMAIL
    assert _login_as(client, NEW_EMAIL).status_code == 200
    assert _login_as(client, REGISTER_PAYLOAD["email"]).status_code == 401


def test_change_email_trims_the_address(client: TestClient) -> None:
    body = _register(client)

    response = _change_email(client, body["token"], f"  {NEW_EMAIL} ")

    assert response.json()["user"]["email"] == NEW_EMAIL


def test_change_email_keeps_the_sessions_open(client: TestClient) -> None:
    body = _register(client)
    other_token = _login_as(client, REGISTER_PAYLOAD["email"]).json()["token"]

    _change_email(client, body["token"], NEW_EMAIL)

    for token in (body["token"], other_token):
        me = client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {token}"})
        assert me.status_code == 200


def test_change_email_to_its_own_address_succeeds(client: TestClient) -> None:
    body = _register(client)

    response = _change_email(client, body["token"], REGISTER_PAYLOAD["email"])

    assert response.status_code == 200


def test_change_email_taken_returns_409(client: TestClient) -> None:
    body = _register(client)
    client.post(
        "/api/v1/auth/register",
        json={**REGISTER_PAYLOAD, "email": "bruno@example.com", "display_name": "bruno"},
    )

    response = _change_email(client, body["token"], "bruno@example.com")

    assert response.status_code == 409
    assert response.json()["error"]["code"] == "EMAIL_TAKEN"
    assert _login_as(client, REGISTER_PAYLOAD["email"]).status_code == 200


@pytest.mark.parametrize(
    "email",
    ["amelie", "amelie@example", "amelie@@example.com", "ame lie@example.com", " "],
)
def test_change_email_malformed_returns_422_envelope(client: TestClient, email: str) -> None:
    body = _register(client)

    response = _change_email(client, body["token"], email)

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "EMAIL_INVALID"


def test_change_email_too_long_returns_422_envelope(client: TestClient) -> None:
    body = _register(client)
    email = "a" * (EMAIL_MAX_LENGTH - len("@example.com") + 1) + "@example.com"

    response = _change_email(client, body["token"], email)

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "EMAIL_INVALID"


def test_change_email_wrong_password_returns_401(client: TestClient) -> None:
    body = _register(client)

    response = _change_email(client, body["token"], NEW_EMAIL, current="not-the-password")

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "INVALID_CREDENTIALS"
    assert _login_as(client, REGISTER_PAYLOAD["email"]).status_code == 200


def test_change_email_requires_auth(client: TestClient) -> None:
    response = client.put(
        "/api/v1/auth/me/email",
        json={"email": NEW_EMAIL, "current_password": REGISTER_PAYLOAD["password"]},
    )

    assert response.status_code == 401


def test_change_email_checks_the_password_before_looking_the_address_up() -> None:
    user = User(
        id="user-a",
        email=REGISTER_PAYLOAD["email"],
        password_hash=hash_password(REGISTER_PAYLOAD["password"]),
    )
    repository = Mock(spec=AuthRepository)
    service = AuthService(repository)

    with pytest.raises(InvalidCredentialsError):
        service.change_email(user, EmailChange(email=NEW_EMAIL, current_password="wrong"))
    repository.get_user_by_email.assert_not_called()
    repository.save_user.assert_not_called()


def test_change_email_checks_the_address_before_the_password() -> None:
    user = User(
        id="user-a",
        email=REGISTER_PAYLOAD["email"],
        password_hash=hash_password(REGISTER_PAYLOAD["password"]),
    )
    repository = Mock(spec=AuthRepository)
    service = AuthService(repository)

    with pytest.raises(EmailInvalidError):
        service.change_email(user, EmailChange(email="amelie", current_password="wrong"))
    repository.save_user.assert_not_called()
