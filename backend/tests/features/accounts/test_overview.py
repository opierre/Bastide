"""Tests for the account detail page's figures: history, period stats, card settlement."""

from collections.abc import Generator
from datetime import date
from uuid import uuid4

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.features.accounts.overview import (
    add_months,
    balance_history,
    consecutive_rises,
    next_debit_date,
)
from app.features.accounts.router import today
from app.features.accounts.schemas import BalancePoint
from tests.api import register as _register

TODAY = date(2026, 2, 10)

_CHECKING_OFX = b"""<OFX><BANKMSGSRSV1><STMTTRNRS><STMTRS><CURDEF>EUR
<BANKACCTFROM><BANKID>13306<ACCTID>0009876543<ACCTTYPE>CHECKING</BANKACCTFROM>
<BANKTRANLIST>
<STMTTRN><TRNAMT>2500.00<DTPOSTED>20251115<FITID>K1<NAME>VIREMENT SALAIRE</STMTTRN>
<STMTTRN><TRNAMT>-600.00<DTPOSTED>20251205<FITID>K2<NAME>DEPENSES CARTE X4821 AU 04/12/25</STMTTRN>
<STMTTRN><TRNAMT>-450.00<DTPOSTED>20260105<FITID>K3<NAME>DEPENSES CARTE X4821 AU 04/01/26</STMTTRN>
<STMTTRN><TRNAMT>-100.00<DTPOSTED>20260120<FITID>K4<NAME>PRLV EDF</STMTTRN>
</BANKTRANLIST></STMTRS></STMTTRNRS></BANKMSGSRSV1></OFX>"""

_CARD_OFX = b"""<OFX><CREDITCARDMSGSRSV1><CCSTMTTRNRS><CCSTMTRS><CURDEF>EUR
<CCACCTFROM><ACCTID>400000XXXXXX4821</CCACCTFROM>
<BANKTRANLIST>
<STMTTRN><TRNAMT>-200.00<DTPOSTED>20251210<FITID>C1<NAME>CAFE DU PORT</STMTTRN>
<STMTTRN><TRNAMT>-150.00<DTPOSTED>20251220<FITID>C2<NAME>LIBRAIRIE</STMTTRN>
<STMTTRN><TRNAMT>-50.00<DTPOSTED>20260108<FITID>C3<NAME>BOULANGERIE</STMTTRN>
<STMTTRN><TRNAMT>-30.00<DTPOSTED>20260112<FITID>C4<NAME>PRESSE</STMTTRN>
</BANKTRANLIST></CCSTMTRS></CCSTMTTRNRS></CREDITCARDMSGSRSV1></OFX>"""


def _point(day: str, balance_minor: int) -> BalancePoint:
    return BalancePoint(as_of=date.fromisoformat(day), balance_minor=balance_minor)


def test_months_are_added_with_the_day_clamped() -> None:
    assert add_months(date(2026, 1, 31), 1) == date(2026, 2, 28)
    assert add_months(date(2026, 1, 15), -12) == date(2025, 1, 15)
    assert add_months(date(2025, 12, 5), 1) == date(2026, 1, 5)


def test_the_history_has_a_point_per_month_even_without_rows() -> None:
    sums = {(2025, 11): 1000, (2026, 1): -400}

    points = balance_history(500, sums, date(2026, 2, 10))

    assert points == [
        _point("2025-11-30", 1500),
        _point("2025-12-31", 1500),
        _point("2026-01-31", 1100),
        _point("2026-02-10", 1100),
    ]


def test_an_account_without_rows_has_no_history() -> None:
    assert balance_history(500, {}, date(2026, 2, 10)) == []


def test_rises_are_counted_back_from_the_last_month() -> None:
    values = [300, 100, 200, 250, 400]
    points = [_point(f"2026-0{i + 1}-28", value) for i, value in enumerate(values)]

    assert consecutive_rises(points) == 3
    assert consecutive_rises(points[:2]) == 0
    assert consecutive_rises(points[:1]) == 0


def test_the_next_debit_is_a_month_after_the_last() -> None:
    assert next_debit_date(date(2026, 1, 5)) == date(2026, 2, 5)
    assert next_debit_date(None) is None


@pytest.fixture
def pinned(app: FastAPI, client: TestClient) -> Generator[TestClient]:
    """The client, with the overview computed as of `TODAY`."""
    app.dependency_overrides[today] = lambda: TODAY
    yield client


def _import(client: TestClient, headers: dict[str, str], account_id: str, content: bytes) -> None:
    response = client.post(
        "/api/v1/imports",
        headers=headers,
        data={"account_id": account_id},
        files={"file": (f"{uuid4()}.ofx", content, "application/octet-stream")},
    )
    assert response.status_code == 201, response.json()


def _setup(client: TestClient) -> tuple[dict[str, str], str, str]:
    headers = _register(client, "amelie@example.com")
    checking = client.post(
        "/api/v1/accounts",
        json={
            "name": "Courant",
            "type": "checking",
            "institution": "Caisse Locale",
            "opening_balance_minor": 100000,
        },
        headers=headers,
    ).json()["id"]
    card = client.post(
        "/api/v1/accounts",
        json={
            "name": "Carte",
            "type": "deferred_card",
            "institution": "Caisse Locale",
            "opening_balance_minor": 0,
            "ofx_account_id": "400000XXXXXX4821",
            "settlement_account_id": checking,
        },
        headers=headers,
    ).json()["id"]
    _import(client, headers, checking, _CHECKING_OFX)
    _import(client, headers, card, _CARD_OFX)
    return headers, checking, card


def _overview(client: TestClient, headers: dict[str, str], account_id: str) -> dict:
    response = client.get(f"/api/v1/accounts/{account_id}/overview", headers=headers)
    assert response.status_code == 200, response.json()
    return response.json()


def test_a_checking_accounts_history_and_period(pinned: TestClient) -> None:
    headers, checking, _ = _setup(pinned)

    body = _overview(pinned, headers, checking)

    assert body["account"]["id"] == checking
    assert body["card_last_digits"] is None
    assert body["first_transaction_date"] == "2025-11-15"
    assert body["last_import_at"] is not None
    assert body["balance_history"] == [
        {"as_of": "2025-11-30", "balance_minor": 350000},
        {"as_of": "2025-12-31", "balance_minor": 290000},
        {"as_of": "2026-01-31", "balance_minor": 235000},
        {"as_of": "2026-02-10", "balance_minor": 235000},
    ]
    # The last point is the balance the account shows.
    assert body["account"]["balance_minor"] == 235000
    assert body["period"] == {
        "since": "2025-02-28",
        "change_minor": 135000,
        "inflow_minor": 250000,
        "outflow_minor": -115000,
        "consecutive_rising_months": 0,
    }
    assert body["card_settlement"] is None


def test_a_card_without_a_rule_is_listed_with_its_issue(pinned: TestClient) -> None:
    headers, checking, card = _setup(pinned)

    (linked,) = _overview(pinned, headers, checking)["linked_cards"]

    # No settlement is known: the cycle falls back to this month, which has no purchase yet.
    assert linked == {
        "id": card,
        "name": "Carte",
        "institution": "Caisse Locale",
        "card_last_digits": "4821",
        "cycle_amount_minor": 0,
        "next_debit_date": None,
        "issue": "no_rule",
    }


def test_a_settled_card_shows_its_open_cycle_on_the_paying_account(pinned: TestClient) -> None:
    headers, checking, card = _setup(pinned)
    pinned.put(
        f"/api/v1/accounts/{card}/settlement-rule",
        json={"pattern": "DEPENSES CARTE X4821"},
        headers=headers,
    )

    (linked,) = _overview(pinned, headers, checking)["linked_cards"]

    assert linked["cycle_amount_minor"] == -8000
    assert linked["next_debit_date"] == "2026-02-05"
    assert linked["issue"] is None


def test_a_cards_cycles_end_with_the_open_one(pinned: TestClient) -> None:
    headers, checking, card = _setup(pinned)
    pinned.put(
        f"/api/v1/accounts/{card}/settlement-rule",
        json={"pattern": "DEPENSES CARTE X4821"},
        headers=headers,
    )

    body = _overview(pinned, headers, card)

    assert body["card_last_digits"] == "4821"
    assert body["linked_cards"] == []
    settlement = body["card_settlement"]
    assert settlement["settlement_account_id"] == checking
    assert settlement["rule"]["pattern"] == "DEPENSES CARTE X4821"
    assert settlement["cycles"] == [
        {"settled_on": "2025-12-05", "amount_minor": -60000},
        {"settled_on": "2026-01-05", "amount_minor": -45000},
        {"settled_on": None, "amount_minor": -8000},
    ]
    assert settlement["next_debit_date"] == "2026-02-05"


def test_a_card_without_a_rule_has_only_its_open_cycle(pinned: TestClient) -> None:
    headers, _, card = _setup(pinned)

    settlement = _overview(pinned, headers, card)["card_settlement"]

    assert settlement["rule"] is None
    assert settlement["cycles"] == [{"settled_on": None, "amount_minor": 0}]
    assert settlement["next_debit_date"] is None


def test_a_fresh_account_has_empty_figures(pinned: TestClient) -> None:
    headers = _register(pinned, "amelie@example.com")
    account = pinned.post(
        "/api/v1/accounts",
        json={
            "name": "Compte joint",
            "type": "checking",
            "institution": "Caisse Locale",
            "opening_balance_minor": 0,
        },
        headers=headers,
    ).json()["id"]

    body = _overview(pinned, headers, account)

    assert body["first_transaction_date"] is None
    assert body["last_import_at"] is None
    assert body["balance_history"] == []
    assert body["period"]["change_minor"] == 0
    assert body["linked_cards"] == []


def test_a_strangers_account_is_not_found(pinned: TestClient) -> None:
    _, checking, _ = _setup(pinned)
    stranger = _register(pinned, "bruno@example.com")

    response = pinned.get(f"/api/v1/accounts/{checking}/overview", headers=stranger)

    assert response.status_code == 404
    assert response.json()["error"]["code"] == "ACCOUNT_NOT_FOUND"


def test_the_overview_requires_authentication(client: TestClient) -> None:
    response = client.get(f"/api/v1/accounts/{uuid4()}/overview")

    assert response.status_code == 401
