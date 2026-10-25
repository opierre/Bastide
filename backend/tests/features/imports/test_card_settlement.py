"""Tests for recognising a deferred-debit card's monthly settlement at import time."""

import pytest
from fastapi.testclient import TestClient

from app.features.imports.card_settlement import CARD_SETTLEMENT_CATEGORY_KEY, is_card_settlement
from tests.api import register as _register

_CHECKING_OFX = b"""<OFX>
<BANKMSGSRSV1><STMTTRNRS><STMTRS>
<CURDEF>EUR
<BANKACCTFROM><BANKID>30004<ACCTID>0001234567<ACCTTYPE>CHECKING</BANKACCTFROM>
<BANKTRANLIST>
<STMTTRN><TRNAMT>-452.10<DTPOSTED>20260131<FITID>S1<NAME>FACTURE CARTE DU 310126</STMTTRN>
<STMTTRN><TRNAMT>-12.40<DTPOSTED>20260112<FITID>P1<NAME>CB BOULANGERIE DU PARC</STMTTRN>
</BANKTRANLIST>
</STMTRS></STMTTRNRS></BANKMSGSRSV1>
</OFX>
"""


def _create_account(client: TestClient, headers: dict[str, str], type_: str, name: str) -> str:
    response = client.post(
        "/api/v1/accounts",
        json={
            "name": name,
            "type": type_,
            "institution": "BNP Paribas",
            "opening_balance_minor": 0,
        },
        headers=headers,
    )
    assert response.status_code == 201, response.json()
    return response.json()["id"]


def _import(client: TestClient, headers: dict[str, str], account_id: str) -> dict[str, dict]:
    response = client.post(
        "/api/v1/imports",
        headers=headers,
        data={"account_id": account_id},
        files={"file": ("releve.ofx", _CHECKING_OFX, "application/octet-stream")},
    )
    assert response.status_code == 201, response.json()
    items = client.get(
        "/api/v1/transactions", params={"account_id": account_id}, headers=headers
    ).json()["items"]
    return {item["description_raw"]: item for item in items}


@pytest.mark.parametrize(
    "label",
    [
        "FACTURE CARTE DU 310126",
        "RELEVÉ CB 4970XXXX1234",
        "Carte X1234 débit différé",
        "PRLV TOTAL CB JANVIER",
    ],
)
def test_settlement_labels_are_recognised(label: str) -> None:
    assert is_card_settlement(label, -45_210)


@pytest.mark.parametrize(
    ("label", "amount_minor"),
    [
        ("CB BOULANGERIE DU PARC", -1_240),
        ("CARTE X1234 CARREFOUR", -3_500),
        # A credit is a refund or a reversal, never the settlement debit.
        ("FACTURE CARTE DU 310126", 45_210),
    ],
)
def test_other_rows_are_not_settlements(label: str, amount_minor: int) -> None:
    assert not is_card_settlement(label, amount_minor)


def test_a_settlement_is_a_transfer_when_the_card_is_tracked(client: TestClient) -> None:
    headers = _register(client)
    checking_id = _create_account(client, headers, "checking", "Compte courant")
    _create_account(client, headers, "deferred_card", "Carte")

    rows = _import(client, headers, checking_id)

    settlement = rows["FACTURE CARTE DU 310126"]
    assert settlement["category"]["name"] == CARD_SETTLEMENT_CATEGORY_KEY
    assert settlement["category"]["kind"] == "transfer"
    # Proposed, not decided: the row waits in the review queue for the user's confirmation.
    assert settlement["categorization_source"] == "detected"
    assert settlement["needs_review"] is True
    assert settlement["amount_minor"] == -45_210
    # An ordinary card purchase on the current account is left to the usual pipeline.
    assert rows["CB BOULANGERIE DU PARC"]["category"] is None


def test_a_settlement_stays_spending_without_a_card_account(client: TestClient) -> None:
    # Without the card's own account, the settlement is the only record of that month's card
    # spending — filing it as a transfer would make it vanish from every total.
    headers = _register(client)
    checking_id = _create_account(client, headers, "checking", "Compte courant")

    rows = _import(client, headers, checking_id)

    settlement = rows["FACTURE CARTE DU 310126"]
    assert settlement["category"] is None
    assert settlement["needs_review"] is True


def test_a_user_rule_outranks_the_settlement_reading(client: TestClient) -> None:
    headers = _register(client)
    checking_id = _create_account(client, headers, "checking", "Compte courant")
    _create_account(client, headers, "deferred_card", "Carte")
    categories = client.get("/api/v1/categories", headers=headers).json()
    chosen = next(c for c in categories if c["name"] == "category.other.uncategorized")
    client.post(
        "/api/v1/rules",
        json={
            "priority": 1,
            "match_field": "description_clean",
            "match_type": "contains",
            "pattern": "FACTURE CARTE",
            "category_id": chosen["id"],
        },
        headers=headers,
    )

    rows = _import(client, headers, checking_id)

    assert rows["FACTURE CARTE DU 310126"]["category"]["id"] == chosen["id"]
