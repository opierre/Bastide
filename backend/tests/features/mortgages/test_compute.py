"""Tests for the stateless simulation: parity with a declared loan, the yearly projection, the
HCSF reading and the borrowing capacity.

What is at stake is that the simulator is the mortgages engine and nothing else — a simulated loan
and a declared one agree to the cent — that computing never writes, and that a breach of the HCSF
references is a reading returned with a 2xx, never a refusal.
"""

from datetime import date
from pathlib import Path
from typing import cast

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, func, select
from sqlalchemy.orm import Session, sessionmaker

from app.features.mortgages.models import Mortgage, MortgageSimulation
from app.features.mortgages.router import get_today
from app.features.settings.models import UserSettings
from tests.api import register

TODAY = date(2026, 5, 15)
#: The first instalment of a loan simulated on TODAY.
FIRST_PAYMENT = "2026-06-01"

SIMULATION = {
    "principal_minor": 28_450_000,
    "annual_rate_bps": 325,
    "insurance_monthly_minor": 3_200,
    "term_months": 300,
    "upfront_fees_minor": 450_000,
    "property_price_minor": 32_000_000,
    "down_payment_minor": 4_000_000,
}

EXISTING_LOAN = {
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

INCOME = 460_000


@pytest.fixture(autouse=True)
def pinned_today(client: TestClient) -> None:
    cast(FastAPI, client.app).dependency_overrides[get_today] = lambda: TODAY


def db(tmp_path: Path) -> Session:
    engine = create_engine(f"sqlite:///{tmp_path / 'test.db'}")
    return sessionmaker(bind=engine)()


def declare_income(
    client: TestClient, headers: dict[str, str], tmp_path: Path, amount: int
) -> None:
    user_id = str(client.get("/api/v1/auth/me", headers=headers).json()["user"]["id"])
    with db(tmp_path) as session:
        session.add(UserSettings(user_id=user_id, declared_monthly_income_minor=amount))
        session.commit()


def compute(client: TestClient, headers: dict[str, str], **overrides: object) -> dict:
    response = client.post(
        "/api/v1/simulations/compute", json={**SIMULATION, **overrides}, headers=headers
    )
    assert response.status_code == 200, response.json()
    return dict(response.json())


def create_loan(client: TestClient, headers: dict[str, str], **overrides: object) -> dict:
    response = client.post(
        "/api/v1/mortgages", json={**EXISTING_LOAN, **overrides}, headers=headers
    )
    assert response.status_code == 201, response.json()
    return dict(response.json())


def expected_ratio(charge: int, income: int) -> int:
    return (2 * charge * 10_000 + income) // (2 * income)


def scaled_insurance(principal: int) -> int:
    """The simulation's insurance held at its own ratio for another principal, half-up."""
    reference = SIMULATION["principal_minor"]
    return (2 * SIMULATION["insurance_monthly_minor"] * principal + reference) // (2 * reference)


# --- one engine ------------------------------------------------------------------------------


def test_figures_match_a_declared_loan_with_the_same_inputs(client: TestClient) -> None:
    headers = register(client)
    declared = create_loan(
        client,
        headers,
        principal_minor=SIMULATION["principal_minor"],
        annual_rate_bps=SIMULATION["annual_rate_bps"],
        insurance_monthly_minor=SIMULATION["insurance_monthly_minor"],
        term_months=SIMULATION["term_months"],
        upfront_fees_minor=SIMULATION["upfront_fees_minor"],
        first_payment_date=FIRST_PAYMENT,
    )

    body = compute(client, headers)

    for field in (
        "monthly_payment_minor",
        "total_instalment_minor",
        "total_interest_minor",
        "total_insurance_minor",
        "total_cost_minor",
        "taeg_bps",
    ):
        assert body[field] == declared[field], field
    assert body["total_instalment_minor"] == body["monthly_payment_minor"] + 3_200
    assert body["total_cost_minor"] == (
        body["total_interest_minor"] + body["total_insurance_minor"] + 450_000
    )
    assert body["currency"] == "EUR"


def test_yearly_rows_sum_the_engine_month_rows_to_the_cent(client: TestClient) -> None:
    headers = register(client)
    declared = create_loan(
        client,
        headers,
        principal_minor=SIMULATION["principal_minor"],
        annual_rate_bps=SIMULATION["annual_rate_bps"],
        insurance_monthly_minor=SIMULATION["insurance_monthly_minor"],
        term_months=SIMULATION["term_months"],
        upfront_fees_minor=SIMULATION["upfront_fees_minor"],
        first_payment_date=FIRST_PAYMENT,
    )
    months = client.get(f"/api/v1/mortgages/{declared['id']}/schedule", headers=headers).json()[
        "rows"
    ]

    yearly = compute(client, headers)["yearly"]

    assert [row["year"] for row in yearly] == list(range(2026, 2052))
    for row in yearly:
        in_year = [month for month in months if month["due_on"].startswith(str(row["year"]))]
        for field in ("instalment_minor", "interest_minor", "principal_minor", "insurance_minor"):
            assert row[field] == sum(month[field] for month in in_year), (row["year"], field)
        assert row["outstanding_after_minor"] == in_year[-1]["outstanding_after_minor"]
        # The capital / interest split the panel stacks, with insurance apart, is the whole
        # instalment: nothing left for the panel to derive.
        split = row["principal_minor"] + row["interest_minor"] + row["insurance_minor"]
        assert split == row["instalment_minor"]
    assert sum(row["principal_minor"] for row in yearly) == SIMULATION["principal_minor"]
    assert yearly[-1]["outstanding_after_minor"] == 0
    assert len([m for m in months if m["due_on"].startswith("2026")]) == 7


def test_compute_writes_nothing(client: TestClient, tmp_path: Path) -> None:
    headers = register(client)
    declare_income(client, headers, tmp_path, INCOME)

    compute(client, headers)
    compute(client, headers, include_existing_loans=True)

    with db(tmp_path) as session:
        assert session.scalar(select(func.count()).select_from(MortgageSimulation)) == 0
        assert session.scalar(select(func.count()).select_from(Mortgage)) == 0


# --- cost over price -------------------------------------------------------------------------


def test_cost_over_price_is_null_without_a_price(client: TestClient) -> None:
    headers = register(client)

    body = compute(client, headers, property_price_minor=None)

    assert body["cost_over_price_bps"] is None


def test_cost_over_price_divides_the_total_cost_by_the_price(client: TestClient) -> None:
    headers = register(client)

    body = compute(client, headers)

    assert body["cost_over_price_bps"] == expected_ratio(body["total_cost_minor"], 32_000_000)


# --- the debt ratio --------------------------------------------------------------------------


def test_existing_loans_change_only_the_ratio(client: TestClient, tmp_path: Path) -> None:
    headers = register(client)
    declare_income(client, headers, tmp_path, INCOME)
    existing = create_loan(client, headers)

    alone = compute(client, headers)
    too = compute(client, headers, include_existing_loans=True)

    reading_fields = {
        "debt_ratio_bps",
        "hcsf",
        "max_borrowable_minor",
        "available_instalment_minor",
    }
    assert {k: v for k, v in alone.items() if k not in reading_fields} == {
        k: v for k, v in too.items() if k not in reading_fields
    }
    assert alone["debt_ratio_bps"] == expected_ratio(alone["total_instalment_minor"], INCOME)
    assert too["debt_ratio_bps"] == expected_ratio(
        too["total_instalment_minor"] + existing["total_instalment_minor"], INCOME
    )


def test_an_archived_or_repaid_loan_is_not_an_existing_charge(
    client: TestClient, tmp_path: Path
) -> None:
    headers = register(client)
    declare_income(client, headers, tmp_path, INCOME)
    archived = create_loan(client, headers)
    repaid = create_loan(client, headers)
    client.delete(f"/api/v1/mortgages/{archived['id']}", headers=headers)
    client.patch(f"/api/v1/mortgages/{repaid['id']}", json={"status": "repaid"}, headers=headers)

    body = compute(client, headers, include_existing_loans=True)

    assert body["debt_ratio_bps"] == expected_ratio(body["total_instalment_minor"], INCOME)


def test_unknown_income_yields_no_ratio_and_no_capacity(client: TestClient) -> None:
    headers = register(client)

    body = compute(client, headers, include_existing_loans=True)

    assert body["debt_ratio_bps"] is None
    assert body["max_borrowable_minor"] is None
    assert body["available_instalment_minor"] is None
    assert body["hcsf"] == {
        "within_ratio": None,
        "within_term": True,
        "limit_bps": 3500,
        "max_term_months": 300,
    }


# --- the borrowing capacity ------------------------------------------------------------------


def test_max_borrowable_fed_back_lands_on_the_limit(client: TestClient, tmp_path: Path) -> None:
    headers = register(client)
    declare_income(client, headers, tmp_path, INCOME)

    body = compute(client, headers)
    capacity = body["max_borrowable_minor"]
    assert body["available_instalment_minor"] == 3500 * INCOME // 10_000

    fed_back = compute(
        client,
        headers,
        principal_minor=capacity,
        insurance_monthly_minor=scaled_insurance(capacity),
    )

    assert abs(fed_back["debt_ratio_bps"] - 3500) <= 1
    assert fed_back["total_instalment_minor"] <= body["available_instalment_minor"]
    # One cent more no longer fits: the capacity is the largest principal under the limit.
    over = compute(
        client,
        headers,
        principal_minor=capacity + 1,
        insurance_monthly_minor=scaled_insurance(capacity + 1),
    )
    assert over["total_instalment_minor"] > body["available_instalment_minor"]


def test_capacity_with_existing_loans_counts_only_what_is_left(
    client: TestClient, tmp_path: Path
) -> None:
    headers = register(client)
    declare_income(client, headers, tmp_path, INCOME)
    existing = create_loan(client, headers)
    charge = existing["total_instalment_minor"]

    alone = compute(client, headers)
    too = compute(client, headers, include_existing_loans=True)

    assert too["available_instalment_minor"] == 3500 * INCOME // 10_000 - charge
    assert too["max_borrowable_minor"] < alone["max_borrowable_minor"]
    capacity = too["max_borrowable_minor"]
    fed_back = compute(
        client,
        headers,
        principal_minor=capacity,
        insurance_monthly_minor=scaled_insurance(capacity),
        include_existing_loans=True,
    )
    assert abs(fed_back["debt_ratio_bps"] - 3500) <= 1


def test_existing_loans_over_the_limit_leave_no_capacity(
    client: TestClient, tmp_path: Path
) -> None:
    headers = register(client)
    declare_income(client, headers, tmp_path, 300_000)
    create_loan(client, headers)
    create_loan(client, headers)

    body = compute(client, headers, include_existing_loans=True)

    assert body["available_instalment_minor"] == 0
    assert body["max_borrowable_minor"] == 0


# --- a reading, never a refusal --------------------------------------------------------------


def test_a_breach_still_returns_2xx(client: TestClient, tmp_path: Path) -> None:
    headers = register(client)
    declare_income(client, headers, tmp_path, 200_000)

    response = client.post(
        "/api/v1/simulations/compute",
        json={**SIMULATION, "term_months": 360},
        headers=headers,
    )

    assert response.status_code == 200
    body = response.json()
    assert body["debt_ratio_bps"] > 3500
    assert body["hcsf"]["within_ratio"] is False
    assert body["hcsf"]["within_term"] is False


def test_a_ratio_on_the_limit_is_within_it(client: TestClient, tmp_path: Path) -> None:
    headers = register(client)
    instalment = compute(client, headers)["total_instalment_minor"]
    declare_income(client, headers, tmp_path, instalment * 2)

    body = compute(client, headers)

    assert body["debt_ratio_bps"] == 5_000
    assert body["hcsf"]["within_ratio"] is False


# --- validation ------------------------------------------------------------------------------


@pytest.mark.parametrize(
    "overrides",
    [
        {"principal_minor": 0},
        {"annual_rate_bps": -1},
        {"insurance_monthly_minor": -1},
        {"term_months": 0},
        {"upfront_fees_minor": -1},
        {"property_price_minor": 0},
        {"principal_minor": 1.5},
        {"unexpected": True},
    ],
)
def test_invalid_inputs_are_rejected(client: TestClient, overrides: dict) -> None:
    headers = register(client)

    response = client.post(
        "/api/v1/simulations/compute", json={**SIMULATION, **overrides}, headers=headers
    )

    assert response.status_code == 422


def test_fees_swallowing_the_principal_are_rejected_in_the_envelope(client: TestClient) -> None:
    headers = register(client)

    response = client.post(
        "/api/v1/simulations/compute",
        json={**SIMULATION, "upfront_fees_minor": SIMULATION["principal_minor"]},
        headers=headers,
    )

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "MORTGAGE_FEES_EXCEED_PRINCIPAL"


def test_compute_requires_authentication(client: TestClient) -> None:
    assert client.post("/api/v1/simulations/compute", json=SIMULATION).status_code == 401
