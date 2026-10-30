"""Tests for a deferred card's settlement rule: the proposal, and saving it."""

from datetime import date

from fastapi.testclient import TestClient

from app.features.accounts.models import Account
from app.features.accounts.settlement_rule import card_digits, suggest_settlement_pattern
from tests.api import register as _register

_CHECKING_OFX = b"""<OFX><BANKMSGSRSV1><STMTTRNRS><STMTRS><CURDEF>EUR
<BANKACCTFROM><BANKID>13306<ACCTID>0009876543<ACCTTYPE>CHECKING</BANKACCTFROM>
<BANKTRANLIST>
<STMTTRN><TRNAMT>-512.40<DTPOSTED>20260430<FITID>S1<NAME>DEPENSES CARTE X4821 AU 29/04/26</STMTTRN>
<STMTTRN><TRNAMT>-987.60<DTPOSTED>20260529<FITID>S2<NAME>DEPENSES CARTE X4821 AU 28/05/26</STMTTRN>
<STMTTRN><TRNAMT>-24.95<DTPOSTED>20260522<FITID>W1<NAME>X4821 RETRAIT DAB 21/05</STMTTRN>
<STMTTRN><TRNAMT>-12.40<DTPOSTED>20260512<FITID>P1<NAME>PRLV BOULANGERIE</STMTTRN>
</BANKTRANLIST></STMTRS></STMTTRNRS></BANKMSGSRSV1></OFX>"""


def _labels(*rows: tuple[str, str]) -> list[tuple[date, str]]:
    return [(date.fromisoformat(day), label) for day, label in rows]


def test_the_monthly_fragment_naming_the_card_is_proposed() -> None:
    labels = _labels(
        ("2026-04-30", "DEPENSES CARTE X4821 AU 29/04/26"),
        ("2026-05-29", "DEPENSES CARTE X4821 AU 28/05/26"),
        ("2026-05-22", "X4821 CAFE DU PORT 21/09"),
        ("2026-05-23", "X4821 RETRAIT DAB"),
        ("2026-02-27", "Cotisation carte 400000XXXXX4821"),
        ("2026-05-12", "PRLV BOULANGERIE"),
    )

    # Withdrawals made with the card also carry its digits, but not once a month.
    assert suggest_settlement_pattern("4821", labels) == "DEPENSES CARTE X4821"


def test_without_a_matching_label_the_digits_are_proposed() -> None:
    assert suggest_settlement_pattern("4821", _labels(("2026-05-12", "PRLV EDF"))) == "4821"
    assert suggest_settlement_pattern(None, _labels(("2026-05-12", "X4821"))) is None


def test_the_card_digits_come_from_its_bank_id_else_its_name() -> None:
    assert card_digits(Account(ofx_account_id="400000XXXXXX4821", name="Carte")) == "4821"
    assert card_digits(Account(ofx_account_id=None, name="Carte ••5390")) == "5390"
    assert card_digits(Account(ofx_account_id=None, name="Carte")) is None


def _setup(client: TestClient) -> tuple[dict[str, str], str, str]:
    headers = _register(client, "amelie@example.com")
    checking = client.post(
        "/api/v1/accounts",
        json={
            "name": "Courant",
            "type": "checking",
            "institution": "Crédit Agricole",
            "opening_balance_minor": 0,
        },
        headers=headers,
    ).json()["id"]
    card = client.post(
        "/api/v1/accounts",
        json={
            "name": "Carte",
            "type": "deferred_card",
            "institution": "Crédit Agricole",
            "opening_balance_minor": 0,
            "ofx_account_id": "400000XXXXXX4821",
            "settlement_account_id": checking,
        },
        headers=headers,
    ).json()["id"]
    imported = client.post(
        "/api/v1/imports",
        headers=headers,
        data={"account_id": checking},
        files={"file": ("releve.ofx", _CHECKING_OFX, "application/octet-stream")},
    )
    assert imported.status_code == 201, imported.json()
    return headers, checking, card


def _rows(client: TestClient, headers: dict[str, str], account_id: str) -> dict[str, dict]:
    items = client.get(
        "/api/v1/transactions", params={"account_id": account_id}, headers=headers
    ).json()["items"]
    return {item["description_raw"]: item for item in items}


def test_a_card_without_a_rule_is_proposed_one(client: TestClient) -> None:
    headers, _, card = _setup(client)

    response = client.get(f"/api/v1/accounts/{card}/settlement-rule", headers=headers)

    assert response.status_code == 200
    assert response.json() == {"rule": None, "suggested_pattern": "DEPENSES CARTE X4821"}


def test_saving_the_rule_files_the_debits_already_imported(client: TestClient) -> None:
    headers, checking, card = _setup(client)

    response = client.put(
        f"/api/v1/accounts/{card}/settlement-rule",
        json={"pattern": "DEPENSES CARTE X4821"},
        headers=headers,
    )

    assert response.status_code == 200, response.json()
    assert response.json()["recategorized_count"] == 2
    rows = _rows(client, headers, checking)
    settled = rows["DEPENSES CARTE X4821 AU 29/04/26"]
    assert settled["category"]["name"] == "category.finance.card_settlement"
    assert settled["categorization_source"] == "rule"
    assert rows["X4821 RETRAIT DAB 21/05"]["category"] is None or (
        rows["X4821 RETRAIT DAB 21/05"]["category"]["name"] != "category.finance.card_settlement"
    )
    # The card's rule goes ahead of every other, and is an ordinary rule in the list.
    rules = client.get("/api/v1/rules", headers=headers).json()
    assert rules[0]["pattern"] == "DEPENSES CARTE X4821"


def test_saving_again_replaces_the_cards_one_rule(client: TestClient) -> None:
    headers, _, card = _setup(client)
    url = f"/api/v1/accounts/{card}/settlement-rule"
    client.put(url, json={"pattern": "4821"}, headers=headers)

    response = client.put(url, json={"pattern": "DEPENSES CARTE X4821"}, headers=headers)

    assert response.status_code == 200
    rules = client.get("/api/v1/rules", headers=headers).json()
    assert [rule["pattern"] for rule in rules] == ["DEPENSES CARTE X4821"]
    assert client.get(url, headers=headers).json()["rule"]["pattern"] == "DEPENSES CARTE X4821"


def test_a_debit_the_user_filed_by_hand_stays_theirs(client: TestClient) -> None:
    headers, checking, card = _setup(client)
    debit = _rows(client, headers, checking)["DEPENSES CARTE X4821 AU 29/04/26"]
    categories = client.get("/api/v1/categories", headers=headers).json()
    other = next(c for c in categories if c["kind"] == "expense")
    client.patch(
        f"/api/v1/transactions/{debit['id']}", json={"category_id": other["id"]}, headers=headers
    )

    response = client.put(
        f"/api/v1/accounts/{card}/settlement-rule",
        json={"pattern": "DEPENSES CARTE X4821"},
        headers=headers,
    )

    assert response.json()["recategorized_count"] == 1
    kept = _rows(client, headers, checking)["DEPENSES CARTE X4821 AU 29/04/26"]
    assert kept["category"]["id"] == other["id"]


def test_only_a_deferred_card_has_a_settlement_rule(client: TestClient) -> None:
    headers, checking, _ = _setup(client)

    response = client.get(f"/api/v1/accounts/{checking}/settlement-rule", headers=headers)
    saved = client.put(
        f"/api/v1/accounts/{checking}/settlement-rule", json={"pattern": "X"}, headers=headers
    )

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "ACCOUNT_NOT_A_DEFERRED_CARD"
    assert saved.status_code == 422


def test_a_strangers_card_is_not_found(client: TestClient) -> None:
    _, _, card = _setup(client)
    other = _register(client, "bruno@example.com")

    response = client.get(f"/api/v1/accounts/{card}/settlement-rule", headers=other)

    assert response.status_code == 404
