"""Tests for the schedule endpoint: date windows, yearly aggregation, the term cap.

The endpoint is a view over the P3-03 engine's rows, so every assertion reconciles against the
engine itself — the endpoint must never become a second formula.
"""

import calendar
from collections import defaultdict
from datetime import date
from typing import cast

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.features.mortgages.engine import RepaymentType, Schedule, build_schedule
from app.features.mortgages.router import get_today

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

AMOUNT_FIELDS = ("instalment_minor", "interest_minor", "principal_minor", "insurance_minor")


@pytest.fixture(autouse=True)
def pinned_today(client: TestClient) -> None:
    cast(FastAPI, client.app).dependency_overrides[get_today] = lambda: TODAY


def register(client: TestClient, email: str = "amelie@example.com") -> dict[str, str]:
    response = client.post(
        "/api/v1/auth/register",
        json={
            "email": email,
            "password": "correct-horse-battery-staple",
            "display_name": "Amelie",
            "locale": "fr",
            "currency": "eur",
        },
    )
    assert response.status_code == 201, response.json()
    return {"Authorization": f"Bearer {response.json()['token']}"}


def create_loan(client: TestClient, headers: dict[str, str], **overrides: object) -> dict:
    response = client.post("/api/v1/mortgages", json={**LOAN_PAYLOAD, **overrides}, headers=headers)
    assert response.status_code == 201, response.json()
    return dict(response.json())


def get_schedule(client: TestClient, headers: dict[str, str], loan_id: str, **params: str) -> dict:
    response = client.get(f"/api/v1/mortgages/{loan_id}/schedule", params=params, headers=headers)
    assert response.status_code == 200, response.json()
    return dict(response.json())


def engine_schedule(**overrides: object) -> Schedule:
    payload = {**LOAN_PAYLOAD, **overrides}
    return build_schedule(
        principal_minor=cast(int, payload["principal_minor"]),
        annual_rate_bps=cast(int, payload["annual_rate_bps"]),
        term_months=cast(int, payload["term_months"]),
        insurance_monthly_minor=cast(int, payload["insurance_monthly_minor"]),
        repayment_type=RepaymentType(cast(str, payload["repayment_type"])),
        first_payment_date=date.fromisoformat(cast(str, payload["first_payment_date"])),
        upfront_fees_minor=cast(int, payload["upfront_fees_minor"]),
    )


def as_json(schedule: Schedule, start: date, end: date) -> list[dict]:
    return [
        {
            "ordinal": row.ordinal,
            "due_on": row.due_on.isoformat(),
            "instalment_minor": row.instalment_minor,
            "interest_minor": row.interest_minor,
            "principal_minor": row.principal_minor,
            "insurance_minor": row.insurance_minor,
            "outstanding_after_minor": row.outstanding_after_minor,
        }
        for row in schedule.rows
        if start <= row.due_on <= end
    ]


# --- windows ---------------------------------------------------------------------------------


def test_a_year_window_returns_exactly_that_years_engine_rows(client: TestClient) -> None:
    headers = register(client)
    loan_id = create_loan(client, headers)["id"]

    body = get_schedule(client, headers, loan_id, **{"from": "2026-01-01", "to": "2026-12-31"})

    expected = as_json(engine_schedule(), date(2026, 1, 1), date(2026, 12, 31))
    assert body["granularity"] == "month"
    assert body["rows"] == expected
    assert len(body["rows"]) == 12
    assert body["totals"] == {
        "interest_minor": sum(row["interest_minor"] for row in expected),
        "principal_minor": sum(row["principal_minor"] for row in expected),
        "insurance_minor": sum(row["insurance_minor"] for row in expected),
    }
    assert body["currency"] == "EUR"


def test_both_window_bounds_are_inclusive(client: TestClient) -> None:
    headers = register(client)
    loan_id = create_loan(client, headers)["id"]

    body = get_schedule(client, headers, loan_id, **{"from": "2026-03-01", "to": "2026-05-01"})

    assert [row["due_on"] for row in body["rows"]] == ["2026-03-01", "2026-04-01", "2026-05-01"]


def test_an_unbounded_request_is_capped_at_the_term(client: TestClient) -> None:
    headers = register(client)
    loan_id = create_loan(client, headers)["id"]

    for params in ({}, {"to": "2100-01-01"}, {"from": "1990-01-01", "to": "2100-01-01"}):
        rows = get_schedule(client, headers, loan_id, **params)["rows"]
        assert len(rows) == 300, params
        assert rows[0]["due_on"] == "2023-09-01"
        assert rows[-1]["ordinal"] == 300
        assert rows[-1]["due_on"] == "2048-08-01"
        assert rows[-1]["outstanding_after_minor"] == 0
        assert sum(row["principal_minor"] for row in rows) == 24_000_000


def test_an_open_ended_window_runs_to_the_last_instalment(client: TestClient) -> None:
    headers = register(client)
    loan_id = create_loan(client, headers)["id"]

    rows = get_schedule(client, headers, loan_id, **{"from": "2048-01-01"})["rows"]

    assert [row["ordinal"] for row in rows] == list(range(293, 301))


def test_a_window_outside_the_loan_is_empty(client: TestClient) -> None:
    headers = register(client)
    loan_id = create_loan(client, headers)["id"]

    body = get_schedule(client, headers, loan_id, **{"from": "2050-01-01", "to": "2050-12-31"})

    assert body["rows"] == []
    assert body["totals"] == {"interest_minor": 0, "principal_minor": 0, "insurance_minor": 0}


def test_a_window_whose_start_is_after_its_end_is_refused(client: TestClient) -> None:
    headers = register(client)
    loan_id = create_loan(client, headers)["id"]

    response = client.get(
        f"/api/v1/mortgages/{loan_id}/schedule",
        params={"from": "2027-01-01", "to": "2026-01-01"},
        headers=headers,
    )

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "MORTGAGE_SCHEDULE_WINDOW_INVALID"


def test_an_unknown_granularity_is_refused(client: TestClient) -> None:
    headers = register(client)
    loan_id = create_loan(client, headers)["id"]

    response = client.get(
        f"/api/v1/mortgages/{loan_id}/schedule", params={"granularity": "week"}, headers=headers
    )

    assert response.status_code == 422


# --- yearly aggregation ----------------------------------------------------------------------


def test_yearly_totals_equal_the_month_rows_they_aggregate(client: TestClient) -> None:
    headers = register(client)
    loan_id = create_loan(client, headers)["id"]

    months = get_schedule(client, headers, loan_id)
    years = get_schedule(client, headers, loan_id, granularity="year")

    by_year: dict[int, list[dict]] = defaultdict(list)
    for row in months["rows"]:
        by_year[int(row["due_on"][:4])].append(row)
    assert years["granularity"] == "year"
    assert [row["year"] for row in years["rows"]] == list(range(2023, 2049))
    for year_row in years["rows"]:
        month_rows = by_year[year_row["year"]]
        for field in AMOUNT_FIELDS:
            assert year_row[field] == sum(row[field] for row in month_rows), (year_row, field)
        assert year_row["outstanding_after_minor"] == month_rows[-1]["outstanding_after_minor"]
    assert years["totals"] == months["totals"]


def test_a_partial_first_year_aggregates_only_its_instalments(client: TestClient) -> None:
    headers = register(client)
    loan_id = create_loan(client, headers)["id"]

    (first_year, *_) = get_schedule(client, headers, loan_id, granularity="year")["rows"]

    september_to_december = engine_schedule().rows[:4]
    assert first_year["year"] == 2023
    assert first_year["principal_minor"] == sum(
        row.principal_minor for row in september_to_december
    )


def test_yearly_granularity_respects_the_window(client: TestClient) -> None:
    headers = register(client)
    loan_id = create_loan(client, headers)["id"]
    window = {"from": "2026-07-01", "to": "2027-06-30"}

    months = get_schedule(client, headers, loan_id, **window)
    years = get_schedule(client, headers, loan_id, granularity="year", **window)

    assert [row["year"] for row in years["rows"]] == [2026, 2027]
    assert [row["interest_minor"] for row in years["rows"]] == [
        sum(row["interest_minor"] for row in months["rows"][:6]),
        sum(row["interest_minor"] for row in months["rows"][6:]),
    ]
    assert years["totals"] == months["totals"]


# --- loan shapes -----------------------------------------------------------------------------


def test_a_future_dated_loan_starts_at_its_first_payment(client: TestClient) -> None:
    headers = register(client)
    loan_id = create_loan(client, headers, first_payment_date="2027-01-10", term_months=60)["id"]

    rows = get_schedule(client, headers, loan_id)["rows"]

    engine = engine_schedule(first_payment_date="2027-01-10", term_months=60)
    assert rows == as_json(engine, date.min, date.max)
    assert rows[0]["due_on"] == "2027-01-10"
    assert rows[0]["outstanding_after_minor"] == 24_000_000 - rows[0]["principal_minor"]
    assert get_schedule(client, headers, loan_id, to="2026-12-31")["rows"] == []


def test_an_interest_only_loan_repays_its_principal_in_the_last_row(client: TestClient) -> None:
    headers = register(client)
    loan_id = create_loan(client, headers, repayment_type="interest_only", term_months=120)["id"]

    rows = get_schedule(client, headers, loan_id)["rows"]

    assert [row["principal_minor"] for row in rows[:-1]] == [0] * 119
    assert rows[-1]["principal_minor"] == 24_000_000
    assert rows[-1]["outstanding_after_minor"] == 0


def test_the_schedule_is_user_scoped(client: TestClient) -> None:
    owner = register(client)
    other = register(client, email="bruno@example.com")
    loan_id = create_loan(client, owner)["id"]

    response = client.get(f"/api/v1/mortgages/{loan_id}/schedule", headers=other)

    assert response.status_code == 404
    assert response.json()["error"]["code"] == "MORTGAGE_NOT_FOUND"


# --- the summary's combined trajectory -------------------------------------------------------

WORKS_OVERRIDES = {
    "label": "Travaux cuisine",
    "lender": "Crédit Agricole",
    "kind": "works",
    "principal_minor": 1_500_000,
    "annual_rate_bps": 490,
    "insurance_monthly_minor": 0,
    "term_months": 60,
    "first_payment_date": "2025-03-01",
    "upfront_fees_minor": 0,
}


def month_end(key: str) -> date:
    year, month = int(key[:4]), int(key[5:])
    return date(year, month, calendar.monthrange(year, month)[1])


def outstanding_in(schedule: Schedule, key: str) -> int:
    """One loan's outstanding after the month `key`, 0 before its first instalment's month."""
    end = month_end(key)
    if schedule.rows[0].due_on > end:
        return 0
    return schedule.outstanding_at(end)


def test_the_series_reconciles_with_each_loans_own_schedule(client: TestClient) -> None:
    headers = register(client)
    home = create_loan(client, headers)
    works = create_loan(client, headers, **WORKS_OVERRIDES)

    response = client.get("/api/v1/mortgages/summary", headers=headers)
    assert response.status_code == 200, response.json()
    body = response.json()

    home_schedule = engine_schedule()
    works_schedule = engine_schedule(**WORKS_OVERRIDES)
    series = {point["month"]: point["outstanding_minor"] for point in body["outstanding_series"]}
    months = list(series)
    assert months[0] == "2023-09"
    assert months[-1] == "2048-08"
    assert len(months) == 300
    assert series["2048-08"] == 0
    for key, value in series.items():
        assert value == outstanding_in(home_schedule, key) + outstanding_in(works_schedule, key), (
            key
        )

    # The travaux loan starts in 03/2025: February carries only the home loan, March adds the
    # step of the works loan's outstanding after its first instalment.
    assert series["2025-02"] == home_schedule.outstanding_at(date(2025, 2, 28))
    assert series["2025-03"] == (
        home_schedule.outstanding_at(date(2025, 3, 31))
        + works_schedule.rows[0].outstanding_after_minor
    )
    assert series["2025-03"] > series["2025-02"]
    # After the works loan ends, only the home loan remains.
    assert series["2030-03"] == home_schedule.outstanding_at(date(2030, 3, 31))

    assert body["loan_ends"] == [
        {"mortgage_id": home["id"], "label": "Appartement Lyon 3e", "month": "2048-08"},
        {"mortgage_id": works["id"], "label": "Travaux cuisine", "month": "2030-02"},
    ]
    today_key = f"{TODAY.year:04d}-{TODAY.month:02d}"
    assert series[today_key] == body["total_outstanding_minor"]


def test_the_series_of_a_single_future_loan_starts_at_its_first_payment(
    client: TestClient,
) -> None:
    headers = register(client)
    create_loan(client, headers, first_payment_date="2027-01-10", term_months=24)

    body = client.get("/api/v1/mortgages/summary", headers=headers).json()

    schedule = engine_schedule(first_payment_date="2027-01-10", term_months=24)
    points = body["outstanding_series"]
    assert [point["month"] for point in points][:2] == ["2027-01", "2027-02"]
    assert [point["outstanding_minor"] for point in points] == [
        row.outstanding_after_minor for row in schedule.rows
    ]
    assert points[-1] == {"month": "2028-12", "outstanding_minor": 0}
