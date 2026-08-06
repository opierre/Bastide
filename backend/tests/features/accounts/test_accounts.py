"""Tests for account CRUD, archive-on-delete, and user-scoping."""

from fastapi.testclient import TestClient

ACCOUNT_PAYLOAD = {
    "name": "Compte courant",
    "type": "checking",
    "institution": "BNP Paribas",
    "opening_balance_minor": 150_000,
}


def _register(client: TestClient, email: str, currency: str = "eur") -> dict[str, str]:
    response = client.post(
        "/api/v1/auth/register",
        json={
            "email": email,
            "password": "correct-horse-battery-staple",
            "display_name": "Amelie",
            "locale": "fr",
            "currency": currency,
        },
    )
    token = response.json()["token"]
    return {"Authorization": f"Bearer {token}"}


def test_create_account_defaults_currency_to_users_currency(client: TestClient) -> None:
    headers = _register(client, "amelie@example.com", currency="eur")

    response = client.post("/api/v1/accounts", json=ACCOUNT_PAYLOAD, headers=headers)

    assert response.status_code == 201
    body = response.json()
    assert body["currency"] == "EUR"
    assert body["name"] == ACCOUNT_PAYLOAD["name"]
    assert body["type"] == ACCOUNT_PAYLOAD["type"]
    assert body["institution"] == ACCOUNT_PAYLOAD["institution"]
    assert body["opening_balance_minor"] == ACCOUNT_PAYLOAD["opening_balance_minor"]
    assert body["balance_minor"] == ACCOUNT_PAYLOAD["opening_balance_minor"]
    assert body["archived"] is False


def test_list_accounts_returns_created_account(client: TestClient) -> None:
    headers = _register(client, "amelie@example.com")
    client.post("/api/v1/accounts", json=ACCOUNT_PAYLOAD, headers=headers)

    response = client.get("/api/v1/accounts", headers=headers)

    assert response.status_code == 200
    assert len(response.json()) == 1


def test_get_account_includes_derived_balance(client: TestClient) -> None:
    headers = _register(client, "amelie@example.com")
    create_response = client.post("/api/v1/accounts", json=ACCOUNT_PAYLOAD, headers=headers)
    account_id = create_response.json()["id"]

    response = client.get(f"/api/v1/accounts/{account_id}", headers=headers)

    assert response.status_code == 200
    assert response.json()["balance_minor"] == ACCOUNT_PAYLOAD["opening_balance_minor"]


def test_update_account_patches_mutable_fields(client: TestClient) -> None:
    headers = _register(client, "amelie@example.com")
    create_response = client.post("/api/v1/accounts", json=ACCOUNT_PAYLOAD, headers=headers)
    account_id = create_response.json()["id"]

    response = client.patch(
        f"/api/v1/accounts/{account_id}",
        json={"name": "Livret A", "type": "savings"},
        headers=headers,
    )

    assert response.status_code == 200
    body = response.json()
    assert body["name"] == "Livret A"
    assert body["type"] == "savings"
    assert body["institution"] == ACCOUNT_PAYLOAD["institution"]


def test_update_account_patches_opening_balance_and_shifts_the_cache(
    client: TestClient,
) -> None:
    """The manual correction escape hatch: patching the opening balance moves the
    derived balance by the same delta, not to some independently-typed number.
    """
    headers = _register(client, "amelie@example.com")
    create_response = client.post("/api/v1/accounts", json=ACCOUNT_PAYLOAD, headers=headers)
    account_id = create_response.json()["id"]

    response = client.patch(
        f"/api/v1/accounts/{account_id}",
        json={"opening_balance_minor": 100_000},
        headers=headers,
    )

    assert response.status_code == 200
    body = response.json()
    assert body["opening_balance_minor"] == 100_000
    # 150 000 typed at creation was corrected down to 100 000; the balance (with no
    # transactions yet) moves by exactly that delta.
    assert body["balance_minor"] == 100_000


def test_delete_account_archives_not_hard_deletes(client: TestClient) -> None:
    headers = _register(client, "amelie@example.com")
    create_response = client.post("/api/v1/accounts", json=ACCOUNT_PAYLOAD, headers=headers)
    account_id = create_response.json()["id"]

    delete_response = client.delete(f"/api/v1/accounts/{account_id}", headers=headers)
    assert delete_response.status_code == 204

    get_response = client.get(f"/api/v1/accounts/{account_id}", headers=headers)
    assert get_response.status_code == 200
    assert get_response.json()["archived"] is True

    list_response = client.get("/api/v1/accounts", headers=headers)
    assert list_response.json() == []


def test_cross_user_get_returns_404(client: TestClient) -> None:
    headers_a = _register(client, "amelie@example.com")
    create_response = client.post("/api/v1/accounts", json=ACCOUNT_PAYLOAD, headers=headers_a)
    account_id = create_response.json()["id"]

    headers_b = _register(client, "bruno@example.com")
    response = client.get(f"/api/v1/accounts/{account_id}", headers=headers_b)

    assert response.status_code == 404
    assert response.json()["error"]["code"] == "ACCOUNT_NOT_FOUND"


def test_cross_user_update_returns_404(client: TestClient) -> None:
    headers_a = _register(client, "amelie@example.com")
    create_response = client.post("/api/v1/accounts", json=ACCOUNT_PAYLOAD, headers=headers_a)
    account_id = create_response.json()["id"]

    headers_b = _register(client, "bruno@example.com")
    response = client.patch(
        f"/api/v1/accounts/{account_id}", json={"name": "Hacked"}, headers=headers_b
    )

    assert response.status_code == 404
    assert response.json()["error"]["code"] == "ACCOUNT_NOT_FOUND"


def test_cross_user_delete_returns_404(client: TestClient) -> None:
    headers_a = _register(client, "amelie@example.com")
    create_response = client.post("/api/v1/accounts", json=ACCOUNT_PAYLOAD, headers=headers_a)
    account_id = create_response.json()["id"]

    headers_b = _register(client, "bruno@example.com")
    response = client.delete(f"/api/v1/accounts/{account_id}", headers=headers_b)

    assert response.status_code == 404
    assert response.json()["error"]["code"] == "ACCOUNT_NOT_FOUND"


def test_list_accounts_requires_auth(client: TestClient) -> None:
    response = client.get("/api/v1/accounts")

    assert response.status_code == 401


def test_create_deferred_card_account(client: TestClient) -> None:
    """The holding account a deferred-debit card posts to is an account type of its own."""
    headers = _register(client, "amelie@example.com")

    response = client.post(
        "/api/v1/accounts",
        json={**ACCOUNT_PAYLOAD, "name": "Carte à débit différé", "type": "deferred_card"},
        headers=headers,
    )

    assert response.status_code == 201
    assert response.json()["type"] == "deferred_card"


def test_create_account_rejects_an_unknown_type(client: TestClient) -> None:
    headers = _register(client, "amelie@example.com")

    response = client.post(
        "/api/v1/accounts", json={**ACCOUNT_PAYLOAD, "type": "crypto"}, headers=headers
    )

    assert response.status_code == 422
