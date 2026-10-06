"""Tests for the net-worth summary: reconciliation, exclusions, the series, scoping.

What is at stake is that net worth is a measurement: every figure reconciles with its parts to
the minor unit, nothing already counted elsewhere (goals) or not yet owed (subscriptions) creeps
in, and the series never reports a month it has no data for.
"""

from collections.abc import Iterator
from contextlib import contextmanager
from datetime import date
from types import SimpleNamespace
from typing import cast
from unittest.mock import MagicMock

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.core.db import get_db
from app.features.accounts.models import Account, AccountBalanceSnapshot
from app.features.auth.models import User
from app.features.mortgages.engine import RepaymentType, build_schedule
from app.features.networth.repository import NetWorthRepository
from app.features.networth.router import get_today
from app.features.networth.service import NetWorthService, shares_bps
from tests.api import register

TODAY = date(2026, 5, 15)

LOAN_PAYLOAD = {
    "label": "Appartement Lyon 3e",
    "lender": "BNP Paribas",
    "kind": "mortgage",
    "repayment_type": "constant_payment",
    "principal_minor": 24_000_000,
    "annual_rate_bps": 345,
    "insurance_monthly_minor": 2_880,
    "term_months": 300,
    "first_payment_date": "2023-09-01",
    "upfront_fees_minor": 145_000,
}

LOAN_SCHEDULE = build_schedule(
    principal_minor=24_000_000,
    annual_rate_bps=345,
    term_months=300,
    insurance_monthly_minor=2_880,
    repayment_type=RepaymentType.CONSTANT_PAYMENT,
    first_payment_date=date(2023, 9, 1),
    upfront_fees_minor=145_000,
)


@pytest.fixture(autouse=True)
def pinned_today(client: TestClient) -> None:
    cast(FastAPI, client.app).dependency_overrides[get_today] = lambda: TODAY


def post(client: TestClient, path: str, headers: dict[str, str], payload: dict) -> dict:
    response = client.post(path, json=payload, headers=headers)
    assert response.status_code == 201, response.json()
    return dict(response.json())


def create_account(
    client: TestClient, headers: dict[str, str], balance: int, type_: str = "checking"
) -> dict:
    return post(
        client,
        "/api/v1/accounts",
        headers,
        {
            "name": f"Compte {type_}",
            "type": type_,
            "institution": "BNP Paribas",
            "opening_balance_minor": balance,
        },
    )


def create_property(client: TestClient, headers: dict[str, str], **overrides: object) -> dict:
    payload = {
        "label": "Appartement Lyon 3e",
        "kind": "primary_residence",
        "market_value_minor": 42_000_000,
        "valued_on": "2026-01-12",
    }
    return post(client, "/api/v1/properties", headers, {**payload, **overrides})


def create_loan(client: TestClient, headers: dict[str, str], **overrides: object) -> dict:
    return post(client, "/api/v1/mortgages", headers, {**LOAN_PAYLOAD, **overrides})


def summary(client: TestClient, headers: dict[str, str]) -> dict:
    response = client.get("/api/v1/networth/summary", headers=headers)
    assert response.status_code == 200, response.json()
    return dict(response.json())


@contextmanager
def session_of(client: TestClient) -> Iterator[Session]:
    """A session on the test client's database, for rows no endpoint writes (snapshots)."""
    sessions = cast(FastAPI, client.app).dependency_overrides[get_db]()
    try:
        yield next(sessions)
    finally:
        sessions.close()


def add_snapshot(client: TestClient, account_id: str, period_end: date, balance: int) -> None:
    with session_of(client) as db:
        db.add(
            AccountBalanceSnapshot(
                account_id=account_id, period_end=period_end, balance_minor=balance
            )
        )
        db.commit()


def seed_household(client: TestClient, headers: dict[str, str]) -> None:
    """Two accounts, a full and a half-held property, one active loan."""
    create_account(client, headers, 1_180_000, "checking")
    create_account(client, headers, 1_250_000, "savings")
    create_property(client, headers)
    create_property(
        client,
        headers,
        label="Studio Villeurbanne",
        kind="rental",
        market_value_minor=14_500_000,
        ownership_bps=5_000,
        valued_on="2026-03-05",
    )
    create_loan(client, headers)


# --- reconciliation --------------------------------------------------------------------------


def test_figures_reconcile_with_their_parts(client: TestClient) -> None:
    headers = register(client)
    seed_household(client, headers)

    body = summary(client, headers)

    outstanding = LOAN_SCHEDULE.outstanding_at(TODAY)
    assert body["assets"] == {"accounts_minor": 2_430_000, "properties_minor": 49_250_000}
    assert body["liabilities"] == {"mortgages_minor": outstanding}
    assert body["net_worth_minor"] == 2_430_000 + 49_250_000 - outstanding
    assert body["currency"] == "EUR"


def test_composition_breaks_assets_down_by_account_type_and_property_kind(
    client: TestClient,
) -> None:
    headers = register(client)
    seed_household(client, headers)

    body = summary(client, headers)

    assert [(e["group"], e["key"], e["amount_minor"]) for e in body["composition"]] == [
        ("account", "checking", 1_180_000),
        ("account", "savings", 1_250_000),
        ("property", "primary_residence", 42_000_000),
        ("property", "rental", 7_250_000),
    ]
    total = body["assets"]["accounts_minor"] + body["assets"]["properties_minor"]
    assert sum(e["amount_minor"] for e in body["composition"]) == total
    assert sum(e["share_bps"] for e in body["composition"]) == 10_000
    assert [e["share_bps"] for e in body["composition"]] == [228, 242, 8127, 1403]


def test_two_accounts_of_one_type_make_one_composition_entry(client: TestClient) -> None:
    headers = register(client)
    create_account(client, headers, 100_000)
    create_account(client, headers, 50_000)

    assert summary(client, headers)["composition"] == [
        {"group": "account", "key": "checking", "amount_minor": 150_000, "share_bps": 10_000}
    ]


def test_loans_exceeding_assets_give_a_negative_net_worth(client: TestClient) -> None:
    headers = register(client)
    create_account(client, headers, 100_000)
    create_loan(client, headers)

    body = summary(client, headers)

    assert body["net_worth_minor"] == 100_000 - LOAN_SCHEDULE.outstanding_at(TODAY)
    assert body["net_worth_minor"] < 0


def test_money_stays_integer(client: TestClient) -> None:
    headers = register(client)
    seed_household(client, headers)

    body = summary(client, headers)

    for value in (
        body["net_worth_minor"],
        *body["assets"].values(),
        *body["liabilities"].values(),
        *(e["amount_minor"] for e in body["composition"]),
        *(e["share_bps"] for e in body["composition"]),
    ):
        assert type(value) is int


# --- exclusions ------------------------------------------------------------------------------


def test_an_archived_account_is_excluded(client: TestClient) -> None:
    headers = register(client)
    create_account(client, headers, 100_000)
    archived = create_account(client, headers, 900_000, "savings")
    client.delete(f"/api/v1/accounts/{archived['id']}", headers=headers)

    body = summary(client, headers)

    assert body["assets"]["accounts_minor"] == 100_000
    assert [e["key"] for e in body["composition"]] == ["checking"]


def test_an_archived_property_is_excluded(client: TestClient) -> None:
    headers = register(client)
    archived = create_property(client, headers)
    client.delete(f"/api/v1/properties/{archived['id']}", headers=headers)

    body = summary(client, headers)

    assert body["assets"]["properties_minor"] == 0
    assert body["composition"] == []
    assert body["property_values_held_flat"] is False


@pytest.mark.parametrize("retire", ["archive", "repaid"])
def test_a_non_active_loan_is_excluded(client: TestClient, retire: str) -> None:
    headers = register(client)
    loan = create_loan(client, headers)
    if retire == "archive":
        client.delete(f"/api/v1/mortgages/{loan['id']}", headers=headers)
    else:
        response = client.patch(
            f"/api/v1/mortgages/{loan['id']}", json={"status": "repaid"}, headers=headers
        )
        assert response.status_code == 200, response.json()

    body = summary(client, headers)

    assert body["liabilities"]["mortgages_minor"] == 0
    assert body["net_worth_minor"] == 0


def test_a_funded_goal_is_not_counted(client: TestClient) -> None:
    """An allocation labels money already inside an account (§13); counting it is double."""
    headers = register(client)
    create_account(client, headers, 1_250_000, "savings")
    before = summary(client, headers)
    goal = post(
        client,
        "/api/v1/goals",
        headers,
        {"name": "Voyage", "target_minor": 500_000, "icon": "plane", "color": "#5AA9FF"},
    )
    post(
        client,
        f"/api/v1/goals/{goal['id']}/allocations",
        headers,
        {"amount_minor": 400_000, "allocated_on": "2026-05-01"},
    )

    assert summary(client, headers) == before


def test_an_active_subscription_is_not_counted(client: TestClient) -> None:
    """A future charge is not a debt."""
    headers = register(client)
    account = create_account(client, headers, 1_180_000)
    before = summary(client, headers)
    post(
        client,
        "/api/v1/recurring",
        headers,
        {
            "label": "Netflix",
            "account_id": account["id"],
            "expected_amount_minor": -1_799,
            "cadence": "monthly",
        },
    )

    assert summary(client, headers) == before


def test_the_summary_carries_only_assets_and_loan_liabilities(client: TestClient) -> None:
    headers = register(client)

    body = summary(client, headers)

    assert set(body) == {
        "assets",
        "liabilities",
        "net_worth_minor",
        "composition",
        "month_delta_minor",
        "series",
        "property_values_held_flat",
        "valued_on_oldest",
        "currency",
    }
    assert set(body["liabilities"]) == {"mortgages_minor"}


# --- the series ------------------------------------------------------------------------------


def test_the_series_follows_snapshots_and_the_amortising_loan(client: TestClient) -> None:
    headers = register(client)
    account = create_account(client, headers, 1_180_000)
    create_property(client, headers)
    create_loan(client, headers)
    add_snapshot(client, account["id"], date(2026, 2, 28), 1_000_000)
    add_snapshot(client, account["id"], date(2026, 3, 31), 1_050_000)
    add_snapshot(client, account["id"], date(2026, 4, 30), 1_120_000)

    body = summary(client, headers)

    expected = [
        ("2026-02", 1_000_000, date(2026, 2, 28)),
        ("2026-03", 1_050_000, date(2026, 3, 31)),
        ("2026-04", 1_120_000, date(2026, 4, 30)),
    ]
    assert body["series"] == [
        {
            "month": month,
            "net_worth_minor": balance + 42_000_000 - LOAN_SCHEDULE.outstanding_at(month_end),
        }
        for month, balance, month_end in expected
    ]
    outstanding = [LOAN_SCHEDULE.outstanding_at(month_end) for _, _, month_end in expected]
    assert outstanding == sorted(outstanding, reverse=True)
    assert len(set(outstanding)) == 3


def test_month_delta_is_the_last_two_points_difference(client: TestClient) -> None:
    headers = register(client)
    account = create_account(client, headers, 1_180_000)
    create_loan(client, headers)
    add_snapshot(client, account["id"], date(2026, 3, 31), 1_050_000)
    add_snapshot(client, account["id"], date(2026, 4, 30), 1_120_000)

    body = summary(client, headers)

    points = body["series"]
    assert (
        body["month_delta_minor"] == points[-1]["net_worth_minor"] - points[-2]["net_worth_minor"]
    )


def test_month_delta_is_null_with_a_single_point(client: TestClient) -> None:
    headers = register(client)
    account = create_account(client, headers, 1_180_000)
    add_snapshot(client, account["id"], date(2026, 4, 30), 1_120_000)

    body = summary(client, headers)

    assert len(body["series"]) == 1
    assert body["month_delta_minor"] is None


def test_months_without_a_snapshot_are_omitted_not_zeroed(client: TestClient) -> None:
    headers = register(client)
    account = create_account(client, headers, 1_180_000)
    add_snapshot(client, account["id"], date(2026, 1, 31), 900_000)
    add_snapshot(client, account["id"], date(2026, 4, 30), 1_120_000)

    months = [point["month"] for point in summary(client, headers)["series"]]

    assert months == ["2026-01", "2026-04"]


def test_the_window_is_the_twelve_closed_months_before_today(client: TestClient) -> None:
    """The current month has no snapshot and is never in the series."""
    headers = register(client)
    account = create_account(client, headers, 1_180_000)
    add_snapshot(client, account["id"], date(2025, 4, 30), 800_000)
    add_snapshot(client, account["id"], date(2025, 5, 31), 810_000)

    months = [point["month"] for point in summary(client, headers)["series"]]

    assert months == ["2025-05"]


def test_an_account_without_that_months_snapshot_counts_at_its_point_in_time_balance(
    client: TestClient,
) -> None:
    headers = register(client)
    first = create_account(client, headers, 1_180_000)
    second = create_account(client, headers, 1_250_000, "savings")
    create_account(client, headers, 30_000, "cash")
    add_snapshot(client, first["id"], date(2026, 3, 31), 1_050_000)
    add_snapshot(client, first["id"], date(2026, 4, 30), 1_120_000)
    add_snapshot(client, second["id"], date(2026, 3, 31), 1_200_000)

    series = summary(client, headers)["series"]

    # April: first's snapshot, second's March snapshot carried, cash at its opening balance.
    assert series[-1] == {"month": "2026-04", "net_worth_minor": 1_120_000 + 1_200_000 + 30_000}


def test_a_user_with_no_snapshot_has_an_empty_series(client: TestClient) -> None:
    headers = register(client)
    seed_household(client, headers)

    body = summary(client, headers)

    assert body["series"] == []
    assert body["month_delta_minor"] is None


def test_rows_after_the_nearest_snapshot_are_added_to_it() -> None:
    """The ledger half of §4's point-in-time balance, over a mocked repository."""
    account = Account(id="a1", type="checking", opening_balance_minor=0, cached_balance_minor=0)
    fresh = Account(id="a2", type="cash", opening_balance_minor=5_000, cached_balance_minor=0)
    repository = MagicMock(spec=NetWorthRepository)
    repository.accounts.return_value = [account, fresh]
    repository.properties.return_value = []
    repository.mortgages.return_value = []
    repository.snapshots.return_value = [
        ("a1", date(2026, 2, 28), 10_000),
        ("a2", date(2026, 4, 30), 7_000),
    ]
    months = {(2026, 2): 999_999, (2026, 3): 1_500, (2026, 4): -700}
    repository.monthly_row_sums.return_value = {
        "a1": {year * 12 + month - 1: total for (year, month), total in months.items()},
        "a2": {2026 * 12 + 1: 250},
    }
    user = cast(User, SimpleNamespace(id="u1", currency="EUR"))

    series = NetWorthService(repository).summary(user, TODAY).series

    # February: a1's snapshot (its own month's rows are inside it), a2 at opening + rows.
    # April: a1's February snapshot plus March and April rows, a2's own snapshot.
    assert [point.net_worth_minor for point in series] == [10_000 + 5_250, 10_800 + 7_000]


# --- the flat-property caveat ----------------------------------------------------------------


def test_properties_counted_raise_the_flat_flag_with_the_oldest_valuation(
    client: TestClient,
) -> None:
    headers = register(client)
    create_property(client, headers, valued_on="2026-03-05")
    create_property(client, headers, label="Studio", kind="secondary", valued_on="2026-01-12")

    body = summary(client, headers)

    assert body["property_values_held_flat"] is True
    assert body["valued_on_oldest"] == "2026-01-12"


def test_no_property_leaves_the_flag_down(client: TestClient) -> None:
    headers = register(client)
    create_account(client, headers, 100_000)

    body = summary(client, headers)

    assert body["property_values_held_flat"] is False
    assert body["valued_on_oldest"] is None


def test_past_points_hold_the_property_value_flat(client: TestClient) -> None:
    headers = register(client)
    account = create_account(client, headers, 0)
    create_property(client, headers, valued_on="2026-04-02")
    add_snapshot(client, account["id"], date(2025, 6, 30), 0)

    assert summary(client, headers)["series"] == [
        {"month": "2025-06", "net_worth_minor": 42_000_000}
    ]


# --- empty user, scoping ---------------------------------------------------------------------


def test_an_empty_user_gets_zeros_and_an_empty_series(client: TestClient) -> None:
    headers = register(client)

    assert summary(client, headers) == {
        "assets": {"accounts_minor": 0, "properties_minor": 0},
        "liabilities": {"mortgages_minor": 0},
        "net_worth_minor": 0,
        "composition": [],
        "month_delta_minor": None,
        "series": [],
        "property_values_held_flat": False,
        "valued_on_oldest": None,
        "currency": "EUR",
    }


def test_every_figure_is_scoped_to_the_caller(client: TestClient) -> None:
    owner = register(client)
    intruder = register(client, email="bruno@example.com")
    seed_household(client, owner)
    account = create_account(client, owner, 10_000, "cash")
    add_snapshot(client, account["id"], date(2026, 4, 30), 10_000)

    body = summary(client, intruder)

    assert body["assets"] == {"accounts_minor": 0, "properties_minor": 0}
    assert body["liabilities"] == {"mortgages_minor": 0}
    assert body["net_worth_minor"] == 0
    assert body["composition"] == []
    assert body["series"] == []
    assert body["property_values_held_flat"] is False


def test_anonymous_requests_are_refused(client: TestClient) -> None:
    assert client.get("/api/v1/networth/summary").status_code == 401


# --- share rounding --------------------------------------------------------------------------


def test_shares_sum_to_ten_thousand_by_largest_remainder() -> None:
    assert shares_bps([1, 1, 1]) == [3334, 3333, 3333]
    assert sum(shares_bps([11_800_000, 12_500_000, 420_000_000, 72_500_000])) == 10_000


def test_shares_carry_a_negative_account() -> None:
    shares = shares_bps([-2_000, 12_000])
    assert shares == [-2000, 12000]
    assert sum(shares) == 10_000


def test_shares_are_zero_when_assets_are_not_positive() -> None:
    assert shares_bps([-5_000, 2_000]) == [0, 0]
    assert shares_bps([]) == []
