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


def test_accounts_report_the_date_of_their_latest_transaction(client: TestClient) -> None:
    headers = _register(client, "amelie@example.com")
    active_id = client.post("/api/v1/accounts", json=ACCOUNT_PAYLOAD, headers=headers).json()["id"]
    dormant_id = client.post(
        "/api/v1/accounts", json={**ACCOUNT_PAYLOAD, "name": "Livret"}, headers=headers
    ).json()["id"]
    ofx = b"""<OFX><BANKMSGSRSV1><STMTTRNRS><STMTRS><CURDEF>EUR
<BANKACCTFROM><BANKID>30004<ACCTID>0001234567<ACCTTYPE>CHECKING</BANKACCTFROM>
<BANKTRANLIST>
<STMTTRN><TRNAMT>-12.40<DTPOSTED>20260112<FITID>P1<NAME>CB BOULANGERIE</STMTTRN>
<STMTTRN><TRNAMT>-8.00<DTPOSTED>20260203<FITID>P2<NAME>CB PRESSE</STMTTRN>
</BANKTRANLIST></STMTRS></STMTTRNRS></BANKMSGSRSV1></OFX>"""
    imported = client.post(
        "/api/v1/imports",
        headers=headers,
        data={"account_id": active_id},
        files={"file": ("releve.ofx", ofx, "application/octet-stream")},
    )
    assert imported.status_code == 201, imported.json()

    listed = {a["id"]: a for a in client.get("/api/v1/accounts", headers=headers).json()}
    single = client.get(f"/api/v1/accounts/{active_id}", headers=headers).json()

    assert listed[active_id]["last_transaction_date"] == "2026-02-03"
    assert listed[dormant_id]["last_transaction_date"] is None
    assert single["last_transaction_date"] == "2026-02-03"
