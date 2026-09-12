"""Tests for the mortgages surface: CRUD, validation, archiving, derived figures, user scoping.

What is at stake is that a loan stays *declared*: every figure is the engine's, computed per
request, and nothing but the mortgage row itself is ever written.
"""

from datetime import date
from pathlib import Path
from typing import cast

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, func, inspect, select, text
from sqlalchemy.orm import sessionmaker

from app.features.mortgages.engine import RepaymentType, build_schedule, taeg_bps
from app.features.mortgages.router import get_today
from app.features.properties.models import Property

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


@pytest.fixture(autouse=True)
def pinned_today(client: TestClient) -> None:
    cast(FastAPI, client.app).dependency_overrides[get_today] = lambda: TODAY


def register(client: TestClient, email: str = "amelie@example.com") -> dict[str, str]:
    """Register a user and return the auth header their requests carry."""
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


def list_loans(client: TestClient, headers: dict[str, str], **params: str) -> list[dict]:
    response = client.get("/api/v1/mortgages", params=params, headers=headers)
    assert response.status_code == 200, response.json()
    return list(response.json())


def user_id_of(client: TestClient, headers: dict[str, str]) -> str:
    return str(client.get("/api/v1/auth/me", headers=headers).json()["user"]["id"])


def insert_property(tmp_path: Path, user_id: str) -> str:
    """Insert a property straight into the client's database (its API is another card)."""
    engine = create_engine(f"sqlite:///{tmp_path / 'test.db'}")
    with sessionmaker(bind=engine)() as session:
        prop = Property(
            user_id=user_id,
            label="Appartement Lyon 3e",
            kind="primary_residence",
            market_value_minor=31_000_000,
            valued_on=date(2026, 1, 1),
        )
        session.add(prop)
        session.commit()
        property_id = prop.id
    engine.dispose()
    return property_id


def row_counts(tmp_path: Path) -> dict[str, int]:
    engine = create_engine(f"sqlite:///{tmp_path / 'test.db'}")
    with engine.connect() as connection:
        counts = {
            table: int(connection.scalar(select(func.count()).select_from(text(table))) or 0)
            for table in inspect(connection).get_table_names()
        }
    engine.dispose()
    return counts


# --- creation and derived figures -----------------------------------------------------------


def test_a_declared_loan_reports_the_engines_figures(client: TestClient) -> None:
    headers = register(client)

    loan = create_loan(client, headers)

    schedule = build_schedule(
        principal_minor=24_000_000,
        annual_rate_bps=345,
        term_months=300,
        insurance_monthly_minor=2_880,
        repayment_type=RepaymentType.CONSTANT_PAYMENT,
        first_payment_date=date(2023, 9, 1),
        upfront_fees_minor=145_000,
    )
    first = schedule.rows[0]
    outstanding = schedule.outstanding_at(TODAY)
    upcoming = [row for row in schedule.rows if row.due_on > TODAY]
    assert loan["status"] == "active"
    assert loan["monthly_payment_minor"] == first.interest_minor + first.principal_minor
    assert loan["total_instalment_minor"] == first.instalment_minor
    assert loan["outstanding_principal_minor"] == outstanding
    assert loan["paid_principal_pct"] == round((24_000_000 - outstanding) * 10_000 / 24_000_000)
    assert loan["remaining_months"] == len(upcoming)
    assert loan["next_payment_on"] == upcoming[0].due_on.isoformat() == "2026-06-01"
    assert loan["total_interest_minor"] == schedule.total_interest_minor
    assert loan["total_insurance_minor"] == schedule.total_insurance_minor
    assert loan["total_cost_minor"] == schedule.total_cost_minor
    assert loan["taeg_bps"] == taeg_bps(schedule)
    assert loan["last_payment_on"] == "2048-08-01"


def test_list_and_detail_agree_with_each_other(client: TestClient) -> None:
    headers = register(client)
    loan = create_loan(client, headers)

    detail = client.get(f"/api/v1/mortgages/{loan['id']}", headers=headers).json()
    (listed,) = list_loans(client, headers)

    assert detail == loan
    assert {key: detail[key] for key in listed} == listed
    assert "taeg_bps" not in listed


def test_a_future_dated_loan_owes_its_whole_principal(client: TestClient) -> None:
    headers = register(client)

    loan = create_loan(client, headers, first_payment_date="2027-01-10")

    assert loan["outstanding_principal_minor"] == 24_000_000
    assert loan["paid_principal_pct"] == 0
    assert loan["remaining_months"] == 300
    assert loan["next_payment_on"] == "2027-01-10"


def test_a_run_out_loan_is_not_auto_repaid(client: TestClient) -> None:
    """Status is user intent: a finished schedule reads 0 months left and stays active."""
    headers = register(client)

    loan = create_loan(client, headers, first_payment_date="2020-01-01", term_months=24)

    assert loan["status"] == "active"
    assert loan["remaining_months"] == 0
    assert loan["outstanding_principal_minor"] == 0
    assert loan["paid_principal_pct"] == 10_000
    assert loan["next_payment_on"] is None
    assert list_loans(client, headers, status="repaid") == []


def test_currency_is_copied_from_the_user(client: TestClient) -> None:
    headers = register(client)

    assert create_loan(client, headers)["currency"] == "EUR"
    response = client.post(
        "/api/v1/mortgages", json={**LOAN_PAYLOAD, "currency": "USD"}, headers=headers
    )
    assert response.status_code == 422


def test_nothing_but_the_mortgage_row_is_written(client: TestClient, tmp_path: Path) -> None:
    headers = register(client)
    before = row_counts(tmp_path)

    loan = create_loan(client, headers)
    client.patch(f"/api/v1/mortgages/{loan['id']}", json={"annual_rate_bps": 300}, headers=headers)
    client.get(f"/api/v1/mortgages/{loan['id']}", headers=headers)
    list_loans(client, headers)

    after = row_counts(tmp_path)
    assert after.pop("mortgages") == before.pop("mortgages") + 1
    assert after == before


# --- validation ------------------------------------------------------------------------------


@pytest.mark.parametrize(
    ("field", "value"),
    [
        ("principal_minor", 0),
        ("principal_minor", -1),
        ("term_months", 0),
        ("term_months", -12),
        ("annual_rate_bps", -1),
        ("insurance_monthly_minor", -1),
        ("upfront_fees_minor", -1),
        ("repayment_type", "stepped"),
        ("kind", "student"),
        ("label", ""),
        ("first_payment_date", "not-a-date"),
    ],
)
def test_the_validation_matrix(client: TestClient, field: str, value: object) -> None:
    headers = register(client)

    response = client.post(
        "/api/v1/mortgages", json={**LOAN_PAYLOAD, field: value}, headers=headers
    )

    assert response.status_code == 422, (field, value)


def test_every_kind_and_both_repayment_types_are_accepted(client: TestClient) -> None:
    headers = register(client)

    for kind in ("mortgage", "works", "consumer", "auto"):
        for repayment_type in ("constant_payment", "interest_only"):
            loan = create_loan(client, headers, kind=kind, repayment_type=repayment_type)
            assert (loan["kind"], loan["repayment_type"]) == (kind, repayment_type)


def test_a_zero_rate_loan_is_accepted(client: TestClient) -> None:
    headers = register(client)

    loan = create_loan(client, headers, annual_rate_bps=0, principal_minor=1_200_000)

    assert loan["monthly_payment_minor"] == 4_000
    assert loan["total_interest_minor"] == 0


def test_a_degenerate_loan_is_refused_in_the_error_envelope(client: TestClient) -> None:
    """An instalment rounding to less than its own interest has no schedule to draw."""
    headers = register(client)

    response = client.post(
        "/api/v1/mortgages",
        json={**LOAN_PAYLOAD, "principal_minor": 100, "upfront_fees_minor": 0},
        headers=headers,
    )

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "MORTGAGE_NON_AMORTIZING"
    assert list_loans(client, headers) == []


def test_fees_swallowing_the_principal_are_refused(client: TestClient) -> None:
    headers = register(client)

    response = client.post(
        "/api/v1/mortgages",
        json={**LOAN_PAYLOAD, "principal_minor": 145_000, "upfront_fees_minor": 145_000},
        headers=headers,
    )

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "MORTGAGE_FEES_EXCEED_PRINCIPAL"


def test_a_degenerate_patch_leaves_the_loan_untouched(client: TestClient) -> None:
    headers = register(client)
    loan = create_loan(client, headers)

    response = client.patch(
        f"/api/v1/mortgages/{loan['id']}",
        json={"principal_minor": 100, "upfront_fees_minor": 0, "label": "Renamed"},
        headers=headers,
    )

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "MORTGAGE_NON_AMORTIZING"
    assert client.get(f"/api/v1/mortgages/{loan['id']}", headers=headers).json() == loan


def test_patching_refuses_invalid_values(client: TestClient) -> None:
    headers = register(client)
    loan_id = create_loan(client, headers)["id"]

    for payload in (
        {"principal_minor": 0},
        {"term_months": 0},
        {"annual_rate_bps": -1},
        {"kind": "student"},
        {"status": "paused"},
        {"currency": "USD"},
    ):
        response = client.patch(f"/api/v1/mortgages/{loan_id}", json=payload, headers=headers)
        assert response.status_code == 422, payload


# --- properties -------------------------------------------------------------------------------


def test_a_loan_links_to_the_users_own_property(client: TestClient, tmp_path: Path) -> None:
    headers = register(client)
    property_id = insert_property(tmp_path, user_id_of(client, headers))

    assert create_loan(client, headers, property_id=property_id)["property_id"] == property_id


def test_another_users_property_is_refused(client: TestClient, tmp_path: Path) -> None:
    owner = register(client)
    other = register(client, email="bruno@example.com")
    property_id = insert_property(tmp_path, user_id_of(client, owner))
    loan_id = create_loan(client, other)["id"]

    created = client.post(
        "/api/v1/mortgages", json={**LOAN_PAYLOAD, "property_id": property_id}, headers=other
    )
    patched = client.patch(
        f"/api/v1/mortgages/{loan_id}", json={"property_id": property_id}, headers=other
    )
    missing = client.post(
        "/api/v1/mortgages", json={**LOAN_PAYLOAD, "property_id": "no-such-id"}, headers=other
    )

    for response in (created, patched, missing):
        assert response.status_code == 422
        assert response.json()["error"]["code"] == "MORTGAGE_PROPERTY_INVALID"


# --- patching and status ---------------------------------------------------------------------


def test_patching_recomputes_the_derived_figures(client: TestClient) -> None:
    headers = register(client)
    loan = create_loan(client, headers)

    response = client.patch(
        f"/api/v1/mortgages/{loan['id']}",
        json={"annual_rate_bps": 200, "lender": "LCL"},
        headers=headers,
    )

    assert response.status_code == 200, response.json()
    patched = response.json()
    assert patched["lender"] == "LCL"
    assert patched["annual_rate_bps"] == 200
    assert patched["monthly_payment_minor"] < loan["monthly_payment_minor"]
    assert patched["total_interest_minor"] < loan["total_interest_minor"]


def test_repaid_is_reached_only_by_patch(client: TestClient) -> None:
    headers = register(client)
    loan_id = create_loan(client, headers)["id"]

    response = client.patch(
        f"/api/v1/mortgages/{loan_id}", json={"status": "repaid"}, headers=headers
    )

    assert response.status_code == 200, response.json()
    assert response.json()["status"] == "repaid"
    assert [loan["id"] for loan in list_loans(client, headers)] == [loan_id]
    assert [loan["id"] for loan in list_loans(client, headers, status="repaid")] == [loan_id]


def test_deleting_archives_and_hides_the_loan(client: TestClient) -> None:
    headers = register(client)
    kept = create_loan(client, headers, label="Appartement")
    archived = create_loan(client, headers, label="Travaux")

    response = client.delete(f"/api/v1/mortgages/{archived['id']}", headers=headers)

    assert response.status_code == 204
    assert [loan["id"] for loan in list_loans(client, headers)] == [kept["id"]]
    assert [loan["id"] for loan in list_loans(client, headers, status="archived")] == [
        archived["id"]
    ]
    detail = client.get(f"/api/v1/mortgages/{archived['id']}", headers=headers)
    assert detail.json()["status"] == "archived"


def test_an_archived_loan_can_be_restored(client: TestClient) -> None:
    headers = register(client)
    loan_id = create_loan(client, headers)["id"]
    client.delete(f"/api/v1/mortgages/{loan_id}", headers=headers)

    response = client.patch(
        f"/api/v1/mortgages/{loan_id}", json={"status": "active"}, headers=headers
    )

    assert response.status_code == 200, response.json()
    assert response.json()["status"] == "active"
    assert [loan["id"] for loan in list_loans(client, headers)] == [loan_id]


# --- user scoping ----------------------------------------------------------------------------


def test_another_users_loan_is_not_found(client: TestClient) -> None:
    owner = register(client)
    other = register(client, email="bruno@example.com")
    loan_id = create_loan(client, owner)["id"]

    for method, url in (
        ("GET", f"/api/v1/mortgages/{loan_id}"),
        ("PATCH", f"/api/v1/mortgages/{loan_id}"),
        ("DELETE", f"/api/v1/mortgages/{loan_id}"),
    ):
        response = client.request(method, url, json={"label": "Vol"}, headers=other)
        assert response.status_code == 404, url
        assert response.json()["error"]["code"] == "MORTGAGE_NOT_FOUND"

    assert list_loans(client, other) == []
    assert (
        client.get(f"/api/v1/mortgages/{loan_id}", headers=owner).json()["label"]
        == (LOAN_PAYLOAD["label"])
    )


def test_unauthenticated_requests_are_rejected(client: TestClient) -> None:
    for method, url in (("GET", "/api/v1/mortgages"), ("POST", "/api/v1/mortgages")):
        assert client.request(method, url, json=LOAN_PAYLOAD).status_code == 401, url
