"""Tests for the optional bank account id (OFX `ACCTID`) that identifies an account."""

from fastapi.testclient import TestClient

from tests.features.accounts.test_accounts import ACCOUNT_PAYLOAD, _register

ACCTID = "0001234567"


def _create(client: TestClient, headers: dict[str, str], **overrides: object) -> dict:
    response = client.post(
        "/api/v1/accounts", json={**ACCOUNT_PAYLOAD, **overrides}, headers=headers
    )
    assert response.status_code == 201, response.text
    return response.json()


def test_create_accepts_and_returns_the_bank_account_id(client: TestClient) -> None:
    headers = _register(client, "amelie@example.com")

    body = _create(client, headers, ofx_account_id=ACCTID)

    assert body["ofx_account_id"] == ACCTID


def test_the_bank_account_id_is_optional(client: TestClient) -> None:
    headers = _register(client, "amelie@example.com")

    body = _create(client, headers)

    assert body["ofx_account_id"] is None


def test_blank_bank_account_id_is_stored_as_absent(client: TestClient) -> None:
    """An empty string identifies nothing, so it must not claim the id slot."""
    headers = _register(client, "amelie@example.com")

    first = _create(client, headers, ofx_account_id="   ")
    second = _create(client, headers, name="Livret A", ofx_account_id="")

    assert first["ofx_account_id"] is None
    assert second["ofx_account_id"] is None


def test_lookup_by_bank_account_id_finds_the_one_account(client: TestClient) -> None:
    headers = _register(client, "amelie@example.com")
    created = _create(client, headers, ofx_account_id=ACCTID)
    _create(client, headers, name="Livret A", ofx_account_id="0009999999")

    response = client.get(
        "/api/v1/accounts", params={"ofx_account_id": f" {ACCTID} "}, headers=headers
    )

    assert response.status_code == 200
    assert [account["id"] for account in response.json()] == [created["id"]]


def test_lookup_by_unknown_bank_account_id_returns_empty(client: TestClient) -> None:
    headers = _register(client, "amelie@example.com")
    _create(client, headers, ofx_account_id=ACCTID)

    response = client.get(
        "/api/v1/accounts", params={"ofx_account_id": "0000000000"}, headers=headers
    )

    assert response.json() == []


def test_lookup_still_finds_an_archived_account(client: TestClient) -> None:
    """It still owns the id — reporting it as free would only fail on create."""
    headers = _register(client, "amelie@example.com")
    created = _create(client, headers, ofx_account_id=ACCTID)
    client.delete(f"/api/v1/accounts/{created['id']}", headers=headers)

    response = client.get("/api/v1/accounts", params={"ofx_account_id": ACCTID}, headers=headers)

    assert [account["id"] for account in response.json()] == [created["id"]]


def test_lookup_is_scoped_to_the_caller(client: TestClient) -> None:
    headers_a = _register(client, "amelie@example.com")
    _create(client, headers_a, ofx_account_id=ACCTID)

    headers_b = _register(client, "bruno@example.com")
    response = client.get("/api/v1/accounts", params={"ofx_account_id": ACCTID}, headers=headers_b)

    assert response.json() == []


def test_two_users_may_hold_the_same_bank_account_id(client: TestClient) -> None:
    """Uniqueness is per user: two people can bank at the same branch."""
    headers_a = _register(client, "amelie@example.com")
    headers_b = _register(client, "bruno@example.com")

    _create(client, headers_a, ofx_account_id=ACCTID)
    body = _create(client, headers_b, ofx_account_id=ACCTID)

    assert body["ofx_account_id"] == ACCTID


def test_reusing_a_bank_account_id_conflicts(client: TestClient) -> None:
    headers = _register(client, "amelie@example.com")
    first = _create(client, headers, ofx_account_id=ACCTID)

    response = client.post(
        "/api/v1/accounts",
        json={**ACCOUNT_PAYLOAD, "name": "Doublon", "ofx_account_id": ACCTID},
        headers=headers,
    )

    assert response.status_code == 409
    assert response.json()["error"]["code"] == "ACCOUNT_OFX_ID_TAKEN"
    assert response.json()["error"]["details"]["account_id"] == first["id"]


def test_patch_binds_a_bank_account_id_to_an_existing_account(client: TestClient) -> None:
    headers = _register(client, "amelie@example.com")
    created = _create(client, headers)

    response = client.patch(
        f"/api/v1/accounts/{created['id']}",
        json={"ofx_account_id": ACCTID},
        headers=headers,
    )

    assert response.status_code == 200
    assert response.json()["ofx_account_id"] == ACCTID


def test_patch_leaves_the_bank_account_id_alone_when_omitted(client: TestClient) -> None:
    headers = _register(client, "amelie@example.com")
    created = _create(client, headers, ofx_account_id=ACCTID)

    response = client.patch(
        f"/api/v1/accounts/{created['id']}", json={"name": "Compte joint"}, headers=headers
    )

    assert response.json()["ofx_account_id"] == ACCTID


def test_patching_an_id_held_by_another_account_conflicts(client: TestClient) -> None:
    headers = _register(client, "amelie@example.com")
    holder = _create(client, headers, ofx_account_id=ACCTID)
    other = _create(client, headers, name="Livret A")

    response = client.patch(
        f"/api/v1/accounts/{other['id']}", json={"ofx_account_id": ACCTID}, headers=headers
    )

    assert response.status_code == 409
    assert response.json()["error"]["details"]["account_id"] == holder["id"]


def test_repatching_its_own_id_is_not_a_conflict(client: TestClient) -> None:
    headers = _register(client, "amelie@example.com")
    created = _create(client, headers, ofx_account_id=ACCTID)

    response = client.patch(
        f"/api/v1/accounts/{created['id']}", json={"ofx_account_id": ACCTID}, headers=headers
    )

    assert response.status_code == 200
