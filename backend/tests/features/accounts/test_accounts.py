"""Tests for account CRUD, archive-on-delete, and user-scoping."""

from fastapi.testclient import TestClient

from tests.api import register as _register

ACCOUNT_PAYLOAD = {
    "name": "Compte courant",
    "type": "checking",
    "institution": "BNP Paribas",
    "opening_balance_minor": 150_000,
}


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


def test_create_account_takes_a_declared_currency_over_the_users(client: TestClient) -> None:
    """A statement's `CURDEF` describes the account; the profile is only the fallback.

    Storing the profile currency for an account an OFX file declares in dollars would
    relabel every figure the import goes on to write, not convert it.
    """
    headers = _register(client, "amelie@example.com", currency="eur")

    response = client.post(
        "/api/v1/accounts",
        json={**ACCOUNT_PAYLOAD, "currency": "usd"},
        headers=headers,
    )

    assert response.status_code == 201
    assert response.json()["currency"] == "USD"


def test_create_account_rejects_a_currency_that_is_not_a_three_letter_code(
    client: TestClient,
) -> None:
    headers = _register(client, "amelie@example.com")

    response = client.post(
        "/api/v1/accounts",
        json={**ACCOUNT_PAYLOAD, "currency": "€"},
        headers=headers,
    )

    assert response.status_code == 422


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


def _card_payload(**overrides: object) -> dict[str, object]:
    return {
        **ACCOUNT_PAYLOAD,
        "name": "Carte à débit différé",
        "type": "deferred_card",
        **overrides,
    }


def test_create_deferred_card_account(client: TestClient) -> None:
    """The holding account a deferred-debit card posts to is an account type of its own, and
    it names the account its debit is drawn from."""
    headers = _register(client, "amelie@example.com")
    checking_id = client.post("/api/v1/accounts", json=ACCOUNT_PAYLOAD, headers=headers).json()[
        "id"
    ]

    response = client.post(
        "/api/v1/accounts",
        json=_card_payload(settlement_account_id=checking_id),
        headers=headers,
    )

    assert response.status_code == 201
    assert response.json()["type"] == "deferred_card"
    assert response.json()["settlement_account_id"] == checking_id


def test_a_deferred_card_needs_its_settlement_account(client: TestClient) -> None:
    headers = _register(client, "amelie@example.com")

    response = client.post("/api/v1/accounts", json=_card_payload(), headers=headers)

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "ACCOUNT_SETTLEMENT_ACCOUNT_REQUIRED"


def test_a_card_cannot_be_settled_from_another_card_or_a_strangers_account(
    client: TestClient,
) -> None:
    headers = _register(client, "amelie@example.com")
    checking_id = client.post("/api/v1/accounts", json=ACCOUNT_PAYLOAD, headers=headers).json()[
        "id"
    ]
    card_id = client.post(
        "/api/v1/accounts", json=_card_payload(settlement_account_id=checking_id), headers=headers
    ).json()["id"]
    other = _register(client, "bruno@example.com")
    strangers_id = client.post("/api/v1/accounts", json=ACCOUNT_PAYLOAD, headers=other).json()["id"]

    for settling in (card_id, strangers_id):
        response = client.post(
            "/api/v1/accounts", json=_card_payload(settlement_account_id=settling), headers=headers
        )
        assert response.status_code == 422
        assert response.json()["error"]["code"] == "ACCOUNT_SETTLEMENT_ACCOUNT_INVALID"
    response = client.post(
        "/api/v1/accounts",
        json={**ACCOUNT_PAYLOAD, "settlement_account_id": checking_id},
        headers=headers,
    )
    assert response.json()["error"]["code"] == "ACCOUNT_SETTLEMENT_ACCOUNT_INVALID"


def test_an_existing_card_is_given_its_settlement_account_by_patch(client: TestClient) -> None:
    headers = _register(client, "amelie@example.com")
    checking_id = client.post("/api/v1/accounts", json=ACCOUNT_PAYLOAD, headers=headers).json()[
        "id"
    ]
    savings_id = client.post(
        "/api/v1/accounts", json={**ACCOUNT_PAYLOAD, "type": "savings"}, headers=headers
    ).json()["id"]
    card_id = client.post(
        "/api/v1/accounts", json=_card_payload(settlement_account_id=checking_id), headers=headers
    ).json()["id"]

    moved = client.patch(
        f"/api/v1/accounts/{card_id}", json={"settlement_account_id": savings_id}, headers=headers
    )
    renamed = client.patch(f"/api/v1/accounts/{card_id}", json={"name": "Visa"}, headers=headers)
    retyped = client.patch(f"/api/v1/accounts/{card_id}", json={"type": "credit"}, headers=headers)

    assert moved.json()["settlement_account_id"] == savings_id
    # A patch that doesn't mention it leaves it alone; one that ends the card clears it.
    assert renamed.json()["settlement_account_id"] == savings_id
    assert retyped.json()["settlement_account_id"] is None


def test_create_account_rejects_an_unknown_type(client: TestClient) -> None:
    headers = _register(client, "amelie@example.com")

    response = client.post(
        "/api/v1/accounts", json={**ACCOUNT_PAYLOAD, "type": "crypto"}, headers=headers
    )

    assert response.status_code == 422
