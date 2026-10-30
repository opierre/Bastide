"""Tests for a deferred card's settlement rule: the proposal, and saving it."""

from datetime import date
from uuid import uuid4

from fastapi.testclient import TestClient

from app.features.accounts.models import Account
from app.features.accounts.settlement_rule import (
    card_digits,
    suggest_applies_from,
    suggest_settlement_pattern,
)
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
    # The card has no transaction yet: no history to start the rule from.
    assert response.json() == {
        "rule": None,
        "suggested_pattern": "DEPENSES CARTE X4821",
        "suggested_applies_from": None,
    }


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


_CARD_OFX = b"""<OFX><CREDITCARDMSGSRSV1><CCSTMTTRNRS><CCSTMTRS><CURDEF>EUR
<CCACCTFROM><ACCTID>400000XXXXXX4821</CCACCTFROM>
<BANKTRANLIST>
<STMTTRN><TRNAMT>-80.00<DTPOSTED>20260410<FITID>C1<NAME>FNAC</STMTTRN>
<STMTTRN><TRNAMT>-30.00<DTPOSTED>20260602<FITID>C2<NAME>LECLERC</STMTTRN>
<STMTTRN><TRNAMT>-12.00<DTPOSTED>20260605<FITID>C3<NAME>PRESSE</STMTTRN>
<STMTTRN><TRNAMT>15.00<DTPOSTED>20260606<FITID>C4<NAME>REMBOURSEMENT</STMTTRN>
</BANKTRANLIST></CCSTMTRS></CCSTMTTRNRS></CREDITCARDMSGSRSV1></OFX>"""

#: The paying account, imported through the end of August: the debit for June's purchases
#: should have landed by then, and none matches the card's rule.
_LATER_CHECKING_OFX = b"""<OFX><BANKMSGSRSV1><STMTTRNRS><STMTRS><CURDEF>EUR
<BANKACCTFROM><BANKID>13306<ACCTID>0009876543<ACCTTYPE>CHECKING</BANKACCTFROM>
<BANKTRANLIST>
<STMTTRN><TRNAMT>-42.00<DTPOSTED>20260630<FITID>S3<NAME>PRELEVEMENT CB 4821 JUIN</STMTTRN>
<STMTTRN><TRNAMT>-9.00<DTPOSTED>20260831<FITID>P9<NAME>PRLV EDF</STMTTRN>
</BANKTRANLIST></STMTRS></STMTTRNRS></BANKMSGSRSV1></OFX>"""


def _status(client: TestClient, headers: dict[str, str]) -> list[dict]:
    response = client.get("/api/v1/accounts/settlement-status", headers=headers)
    assert response.status_code == 200
    return response.json()["cards"]


def _import(client: TestClient, headers: dict[str, str], account_id: str, content: bytes) -> None:
    response = client.post(
        "/api/v1/imports",
        headers=headers,
        data={"account_id": account_id},
        files={"file": (f"{uuid4()}.ofx", content, "application/octet-stream")},
    )
    assert response.status_code == 201, response.json()


def test_a_card_without_its_settlement_account_or_rule_is_flagged(client: TestClient) -> None:
    headers, checking, card = _setup(client)

    assert _status(client, headers) == [
        {"account_id": card, "issue": "no_rule", "amount_minor": None, "count": None, "since": None}
    ]

    client.patch(f"/api/v1/accounts/{card}", json={"settlement_account_id": None}, headers=headers)
    assert [card_issue["issue"] for card_issue in _status(client, headers)] == [
        "no_settlement_account"
    ]


def test_a_card_whose_rule_matches_its_debits_is_not_flagged(client: TestClient) -> None:
    headers, _, card = _setup(client)
    _import(client, headers, card, _CARD_OFX.replace(b"202606", b"202604"))
    client.put(
        f"/api/v1/accounts/{card}/settlement-rule",
        json={"pattern": "DEPENSES CARTE X4821"},
        headers=headers,
    )

    assert _status(client, headers) == []


def test_purchases_no_debit_matched_long_after_are_flagged(client: TestClient) -> None:
    headers, checking, card = _setup(client)
    client.put(
        f"/api/v1/accounts/{card}/settlement-rule",
        json={"pattern": "DEPENSES CARTE X4821"},
        headers=headers,
    )
    _import(client, headers, card, _CARD_OFX)
    _import(client, headers, checking, _LATER_CHECKING_OFX)

    # The April purchase came before the last matched debit (29 May); June's two did not, and
    # the paying account runs to 31 August — more than 45 days past them. The refund is no
    # purchase.
    assert _status(client, headers) == [
        {
            "account_id": card,
            "issue": "unsettled",
            "amount_minor": -4_200,
            "count": 2,
            "since": "2026-06-02",
        }
    ]


def test_the_rule_starts_at_the_first_debit_the_cards_history_fully_covers() -> None:
    # A card ••4821: history from 30/12/2025; the 31/12 debit paid purchases since 28/11.
    debits = [date(2025, 10, 31), date(2025, 11, 28), date(2025, 12, 31), date(2026, 1, 30)]

    assert suggest_applies_from(date(2025, 12, 30), debits) == date(2026, 1, 30)
    # A card whose history reaches back before every debit: the first one counts already.
    assert suggest_applies_from(date(2025, 9, 1), debits) == date(2025, 10, 31)
    # No debit qualifies yet: from the card's first day. No history: nothing to propose.
    assert suggest_applies_from(date(2026, 1, 15), debits) == date(2026, 1, 15)
    assert suggest_applies_from(None, debits) is None


_EARLY_CARD_OFX = b"""<OFX><CREDITCARDMSGSRSV1><CCSTMTTRNRS><CCSTMTRS><CURDEF>EUR
<CCACCTFROM><ACCTID>400000XXXXXX4821</CCACCTFROM>
<BANKTRANLIST>
<STMTTRN><TRNAMT>-80.00<DTPOSTED>20260430<FITID>C1<NAME>FNAC</STMTTRN>
</BANKTRANLIST></CCSTMTRS></CCSTMTTRNRS></CREDITCARDMSGSRSV1></OFX>"""


def test_a_card_with_history_is_proposed_a_start_date(client: TestClient) -> None:
    headers, _, card = _setup(client)
    _import(client, headers, card, _EARLY_CARD_OFX)

    response = client.get(f"/api/v1/accounts/{card}/settlement-rule", headers=headers)

    # The card's history starts 30/04: the 30/04 debit paid the month before it, the 29/05 one
    # paid purchases the card's statements hold.
    assert response.json()["suggested_applies_from"] == "2026-05-29"


def test_debits_before_the_start_date_stay_spending(client: TestClient) -> None:
    headers, checking, card = _setup(client)
    url = f"/api/v1/accounts/{card}/settlement-rule"

    client.put(url, json={"pattern": "DEPENSES CARTE X4821"}, headers=headers)
    response = client.put(
        url, json={"pattern": "DEPENSES CARTE X4821", "applies_from": "2026-05-01"}, headers=headers
    )

    # The April debit the first save filed goes back to the review queue.
    assert response.json()["recategorized_count"] == 1
    assert response.json()["rule"]["applies_from"] == "2026-05-01"
    rows = _rows(client, headers, checking)
    april = rows["DEPENSES CARTE X4821 AU 29/04/26"]
    assert april["category"] is None
    assert april["needs_review"] is True
    may = rows["DEPENSES CARTE X4821 AU 28/05/26"]
    assert may["category"]["name"] == "category.finance.card_settlement"
    rule = client.get("/api/v1/rules", headers=headers).json()[0]
    assert rule["applies_from"] == "2026-05-01"


def test_a_preview_counts_from_the_start_date(client: TestClient) -> None:
    headers, _, _ = _setup(client)
    body = {
        "match_field": "description_clean",
        "match_type": "contains",
        "pattern": "DEPENSES CARTE X4821",
    }

    every = client.post("/api/v1/rules/preview", json=body, headers=headers).json()
    since = client.post(
        "/api/v1/rules/preview", json={**body, "applies_from": "2026-05-01"}, headers=headers
    ).json()

    assert (every["match_count"], since["match_count"]) == (2, 1)
