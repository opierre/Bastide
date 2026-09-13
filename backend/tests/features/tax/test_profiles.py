"""Tests for the tax profile surface: lazy creation, partial patch, validation, scoping.

What is at stake is that every figure in a profile got there because the user put it there. The
row appears with defaults and never twice; a patch touches only what it names; and the fields
the estimate derives elsewhere — property income above all — are refused rather than accepted
and quietly ignored, so a client cannot believe it declared a rent that was never stored.
"""

from datetime import date
from pathlib import Path
from typing import cast

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, func, select
from sqlalchemy.orm import Session, sessionmaker

from app.features.tax.models import TaxParameter, TaxProfile
from app.features.tax.router import get_today
from app.features.tax.seed import SYSTEM_TAX_SEED

TODAY = date(2026, 5, 15)

#: The oldest year the seeded parameter set covers, and so the oldest a profile may declare.
SEEDED_YEAR = SYSTEM_TAX_SEED.tax_year

#: Every default §4c pins, so a change to one of them fails here rather than in the estimate.
DEFAULTS = {
    "household": "single",
    "dependents_count": 0,
    "single_parent": False,
    "salaries_minor": 0,
    "pensions_minor": 0,
    "dividends_minor": 0,
    "interest_minor": 0,
    "capital_gains_minor": 0,
    "pfu_opt_out": False,
    "deductions_minor": 0,
    "credits_minor": 0,
}


@pytest.fixture(autouse=True)
def pinned_today(client: TestClient) -> None:
    cast(FastAPI, client.app).dependency_overrides[get_today] = lambda: TODAY


@pytest.fixture(autouse=True)
def seeded_parameters(client: TestClient, tmp_path: Path) -> None:
    """The client database is built from metadata, so the seed migration's rows are added here.

    Only the year matters to this module — it is the floor the year validator reads.
    """
    with db(tmp_path) as session:
        for key, parameter in SYSTEM_TAX_SEED.parameters.items():
            session.add(
                TaxParameter(
                    user_id=None,
                    tax_year=SEEDED_YEAR,
                    key=key,
                    int_value=parameter.int_value,
                    unit=parameter.unit,
                )
            )
        session.commit()


def db(tmp_path: Path) -> Session:
    engine = create_engine(f"sqlite:///{tmp_path / 'test.db'}")
    return sessionmaker(bind=engine)()


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


def read_profile(client: TestClient, headers: dict[str, str], year: int = SEEDED_YEAR) -> dict:
    response = client.get(f"/api/v1/tax/profiles/{year}", headers=headers)
    assert response.status_code == 200, response.json()
    return dict(response.json())


def patch_profile(
    client: TestClient, headers: dict[str, str], payload: dict, year: int = SEEDED_YEAR
):
    return client.patch(f"/api/v1/tax/profiles/{year}", json=payload, headers=headers)


def list_profiles(client: TestClient, headers: dict[str, str]) -> list[dict]:
    response = client.get("/api/v1/tax/profiles", headers=headers)
    assert response.status_code == 200, response.json()
    return list(response.json())


def profile_rows(tmp_path: Path) -> int:
    with db(tmp_path) as session:
        return int(session.scalar(select(func.count()).select_from(TaxProfile)) or 0)


def error_of(response) -> dict:  # noqa: ANN001 - httpx.Response, kept untyped like its siblings
    """The error envelope, asserted to be the documented shape."""
    body = response.json()
    assert set(body) == {"error"}, body
    assert {"code", "message"} <= set(body["error"]), body
    return dict(body["error"])


# --- lazy creation ---------------------------------------------------------------------------


def test_a_fresh_year_returns_the_defaults(client: TestClient) -> None:
    headers = register(client)

    profile = read_profile(client, headers)

    assert profile["tax_year"] == SEEDED_YEAR
    assert profile["currency"] == "EUR"
    assert {field: profile[field] for field in DEFAULTS} == DEFAULTS


def test_reading_a_fresh_year_creates_exactly_one_row(client: TestClient, tmp_path: Path) -> None:
    headers = register(client)

    read_profile(client, headers)

    assert profile_rows(tmp_path) == 1


def test_reading_twice_creates_no_second_row(client: TestClient, tmp_path: Path) -> None:
    headers = register(client)

    first = read_profile(client, headers)
    second = read_profile(client, headers)

    assert first["id"] == second["id"]
    assert profile_rows(tmp_path) == 1


def test_patching_an_undeclared_year_creates_it(client: TestClient, tmp_path: Path) -> None:
    headers = register(client)

    response = patch_profile(client, headers, {"salaries_minor": 6_180_000})

    assert response.status_code == 200, response.json()
    assert response.json()["salaries_minor"] == 6_180_000
    assert profile_rows(tmp_path) == 1


def test_listing_creates_nothing(client: TestClient, tmp_path: Path) -> None:
    headers = register(client)

    assert list_profiles(client, headers) == []
    assert profile_rows(tmp_path) == 0


def test_list_returns_the_declared_years_newest_first(client: TestClient) -> None:
    headers = register(client)
    read_profile(client, headers, SEEDED_YEAR)
    read_profile(client, headers, TODAY.year)

    assert [profile["tax_year"] for profile in list_profiles(client, headers)] == [
        TODAY.year,
        SEEDED_YEAR,
    ]


# --- partial patch ---------------------------------------------------------------------------


def test_patch_updates_only_the_supplied_fields(client: TestClient) -> None:
    headers = register(client)
    patch_profile(client, headers, {"salaries_minor": 6_180_000, "dependents_count": 2})

    response = patch_profile(client, headers, {"household": "couple"})

    assert response.status_code == 200, response.json()
    updated = response.json()
    assert updated["household"] == "couple"
    assert updated["salaries_minor"] == 6_180_000
    assert updated["dependents_count"] == 2


def test_patch_accepts_every_declarable_field(client: TestClient) -> None:
    headers = register(client)
    payload = {
        "household": "couple",
        "dependents_count": 3,
        "single_parent": True,
        "salaries_minor": 6_180_000,
        "pensions_minor": 120_000,
        "dividends_minor": 120_000,
        "interest_minor": 32_000,
        "capital_gains_minor": 450_000,
        "pfu_opt_out": True,
        "deductions_minor": 200_000,
        "credits_minor": 75_000,
    }

    response = patch_profile(client, headers, payload)

    assert response.status_code == 200, response.json()
    assert {field: response.json()[field] for field in payload} == payload


def test_an_empty_patch_changes_nothing(client: TestClient) -> None:
    headers = register(client)
    before = read_profile(client, headers)

    response = patch_profile(client, headers, {})

    assert response.status_code == 200, response.json()
    assert {field: response.json()[field] for field in DEFAULTS} == {
        field: before[field] for field in DEFAULTS
    }


# --- validation ------------------------------------------------------------------------------


@pytest.mark.parametrize(
    "field",
    [
        "salaries_minor",
        "pensions_minor",
        "dividends_minor",
        "interest_minor",
        "capital_gains_minor",
        "deductions_minor",
        "credits_minor",
    ],
)
def test_negative_money_is_refused(client: TestClient, field: str) -> None:
    headers = register(client)

    assert patch_profile(client, headers, {field: -1}).status_code == 422


def test_negative_dependents_is_refused(client: TestClient) -> None:
    headers = register(client)

    assert patch_profile(client, headers, {"dependents_count": -1}).status_code == 422


def test_an_unknown_household_is_refused(client: TestClient) -> None:
    headers = register(client)

    assert patch_profile(client, headers, {"household": "pacs"}).status_code == 422


def test_property_income_is_refused_rather_than_ignored(client: TestClient) -> None:
    """§4c derives property income from `properties`; accepting it here would let a client
    believe it declared a rent the estimate reads from somewhere else entirely."""
    headers = register(client)

    response = patch_profile(client, headers, {"property_income_minor": 1_200_000})

    assert response.status_code == 422, response.json()


def test_the_tax_year_is_not_a_body_field(client: TestClient) -> None:
    headers = register(client)

    assert patch_profile(client, headers, {"tax_year": TODAY.year}).status_code == 422


# --- the year range --------------------------------------------------------------------------


def test_a_future_year_is_refused(client: TestClient, tmp_path: Path) -> None:
    headers = register(client)

    response = client.get(f"/api/v1/tax/profiles/{TODAY.year + 1}", headers=headers)

    assert response.status_code == 422, response.json()
    assert error_of(response)["code"] == "TAX_YEAR_OUT_OF_RANGE"
    assert profile_rows(tmp_path) == 0


def test_a_year_older_than_the_seeded_set_is_refused(client: TestClient) -> None:
    headers = register(client)

    response = client.get(f"/api/v1/tax/profiles/{SEEDED_YEAR - 1}", headers=headers)

    assert response.status_code == 422, response.json()
    assert error_of(response)["code"] == "TAX_YEAR_OUT_OF_RANGE"


def test_the_current_year_is_accepted(client: TestClient) -> None:
    headers = register(client)

    assert read_profile(client, headers, TODAY.year)["tax_year"] == TODAY.year


def test_a_future_year_is_refused_on_patch_too(client: TestClient) -> None:
    headers = register(client)

    response = patch_profile(client, headers, {"salaries_minor": 1}, year=TODAY.year + 1)

    assert response.status_code == 422, response.json()
    assert error_of(response)["code"] == "TAX_YEAR_OUT_OF_RANGE"


# --- user scoping ----------------------------------------------------------------------------


def test_each_user_gets_their_own_row_for_the_same_year(client: TestClient, tmp_path: Path) -> None:
    amelie = register(client)
    patch_profile(client, amelie, {"salaries_minor": 6_180_000})
    bruno = register(client, "bruno@example.com")

    profile = read_profile(client, bruno)

    assert profile["salaries_minor"] == 0
    assert read_profile(client, amelie)["salaries_minor"] == 6_180_000
    assert profile_rows(tmp_path) == 2


def test_a_patch_never_reaches_another_users_year(client: TestClient) -> None:
    amelie = register(client)
    patch_profile(client, amelie, {"salaries_minor": 6_180_000})
    bruno = register(client, "bruno@example.com")

    patch_profile(client, bruno, {"salaries_minor": 42})

    assert read_profile(client, amelie)["salaries_minor"] == 6_180_000


def test_another_users_years_are_absent_from_the_list(client: TestClient) -> None:
    amelie = register(client)
    read_profile(client, amelie, SEEDED_YEAR)
    bruno = register(client, "bruno@example.com")
    read_profile(client, bruno, TODAY.year)

    assert [profile["tax_year"] for profile in list_profiles(client, bruno)] == [TODAY.year]


def test_the_profile_requires_authentication(client: TestClient) -> None:
    assert client.get(f"/api/v1/tax/profiles/{SEEDED_YEAR}").status_code == 401
    assert client.get("/api/v1/tax/profiles").status_code == 401
