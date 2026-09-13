"""Tests for `GET /tax/profiles/{year}/estimate` — the assembly around the engine (§16).

`test_engine.py` owns the arithmetic. What is at stake here is everything the route does around
it: that the estimate reads the *user's* profile, the *user's* properties and the loans secured on
them, that a parameter the user overrode is the parameter the figure ran on and says so, that a
year the user has never opened still answers, and that nothing about another user's data can reach
the response.
"""

from datetime import date
from pathlib import Path
from typing import Any, cast

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, select
from sqlalchemy.orm import Session, sessionmaker

from app.features.auth.models import User
from app.features.mortgages.router import get_today as mortgages_today
from app.features.properties.router import get_today as properties_today
from app.features.tax.models import TaxBracket, TaxParameter
from app.features.tax.router import get_today as tax_today
from app.features.tax.seed import SYSTEM_TAX_SEED

TODAY = date(2026, 5, 15)
YEAR = SYSTEM_TAX_SEED.tax_year


@pytest.fixture(autouse=True)
def pinned_today(client: TestClient) -> None:
    """One date for every panel the estimate reads, so no test depends on the wall clock."""
    overrides = cast(FastAPI, client.app).dependency_overrides
    overrides[tax_today] = lambda: TODAY
    overrides[properties_today] = lambda: TODAY
    overrides[mortgages_today] = lambda: TODAY


@pytest.fixture(autouse=True)
def seeded_parameters(tmp_path: Path) -> None:
    """The seed migration's system rows, which the client database is not built from."""
    with db(tmp_path) as session:
        for kind, bands in SYSTEM_TAX_SEED.brackets.items():
            for ordinal, band in enumerate(bands):
                session.add(
                    TaxBracket(
                        user_id=None,
                        tax_year=YEAR,
                        kind=kind,
                        ordinal=ordinal,
                        lower_bound_minor=band.lower_bound_minor,
                        rate_bps=band.rate_bps,
                    )
                )
        for key, parameter in SYSTEM_TAX_SEED.parameters.items():
            session.add(
                TaxParameter(
                    user_id=None,
                    tax_year=YEAR,
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


def user_id(tmp_path: Path, email: str = "amelie@example.com") -> str:
    with db(tmp_path) as session:
        found = session.scalar(select(User.id).where(User.email == email))
    assert found is not None
    return found


def patch_profile(client: TestClient, headers: dict[str, str], **fields: Any) -> dict:
    response = client.patch(f"/api/v1/tax/profiles/{YEAR}", json=fields, headers=headers)
    assert response.status_code == 200, response.json()
    return response.json()


def add_property(client: TestClient, headers: dict[str, str], **fields: Any) -> dict:
    payload: dict[str, Any] = {
        "label": "Bien",
        "kind": "secondary",
        "market_value_minor": 30_000_000,
        "valued_on": "2025-01-10",
        **fields,
    }
    response = client.post("/api/v1/properties", json=payload, headers=headers)
    assert response.status_code == 201, response.json()
    return response.json()


def add_mortgage(client: TestClient, headers: dict[str, str], **fields: Any) -> dict:
    payload: dict[str, Any] = {
        "label": "Prêt",
        "lender": "Banque",
        "kind": "mortgage",
        "repayment_type": "constant_payment",
        "principal_minor": 20_000_000,
        "annual_rate_bps": 300,
        "insurance_monthly_minor": 0,
        "term_months": 240,
        # After 1 January of the tax year, so no instalment has yet fallen due on the date the
        # IFI base reads the loan at: the whole principal still nets off.
        "first_payment_date": f"{YEAR}-06-01",
        **fields,
    }
    response = client.post("/api/v1/mortgages", json=payload, headers=headers)
    assert response.status_code == 201, response.json()
    return response.json()


def estimate(client: TestClient, headers: dict[str, str], year: int = YEAR) -> dict:
    response = client.get(f"/api/v1/tax/profiles/{year}/estimate", headers=headers)
    assert response.status_code == 200, response.json()
    return response.json()


def test_the_endpoint_assembles_profile_parameters_and_properties(
    client: TestClient, tmp_path: Path
) -> None:
    """One call, three sources: the declared profile, the seeded set, and the user's properties."""
    headers = register(client)
    patch_profile(client, headers, salaries_minor=4_000_000)
    add_property(
        client,
        headers,
        label="Studio",
        kind="rental",
        market_value_minor=20_000_000,
        annual_rent_minor=1_200_000,
        property_regime="micro_foncier",
    )

    body = estimate(client, headers)

    assert body["tax_year"] == YEAR
    assert body["currency"] == "EUR"
    assert body["parts"] == 1
    assert body["salary_pension_allowance_minor"] == 400_000
    # The salary's 36 000 € plus the rent's 8 400 € net, which the profile never declared.
    assert body["taxable_income_minor"] == 4_440_000
    assert body["property"] == {
        "regime": "micro_foncier",
        "gross_minor": 1_200_000,
        "allowance_minor": 360_000,
        "net_minor": 840_000,
        "social_charges_minor": 144_480,
    }
    assert body["parameter_source"] == "seeded"
    assert sum(entry["amount_minor"] for entry in body["breakdown"]) == body["total_due_minor"]


def test_property_income_follows_a_change_to_a_property(client: TestClient) -> None:
    """The rent lives in `properties`, so editing the property moves the estimate (§4c)."""
    headers = register(client)
    prop = add_property(
        client,
        headers,
        label="Studio",
        kind="rental",
        annual_rent_minor=1_200_000,
        property_regime="micro_foncier",
    )
    before = estimate(client, headers)

    response = client.patch(
        f"/api/v1/properties/{prop['id']}", json={"annual_rent_minor": 1_400_000}, headers=headers
    )
    assert response.status_code == 200, response.json()
    after = estimate(client, headers)

    assert before["property"]["gross_minor"] == 1_200_000
    assert after["property"]["gross_minor"] == 1_400_000
    assert after["taxable_income_minor"] > before["taxable_income_minor"]


def test_an_archived_property_leaves_the_estimate(client: TestClient) -> None:
    """Archiving removes a property from every aggregate, the estimate included."""
    headers = register(client)
    prop = add_property(
        client,
        headers,
        label="Studio",
        kind="rental",
        annual_rent_minor=1_200_000,
        property_regime="micro_foncier",
    )
    assert estimate(client, headers)["property"]["gross_minor"] == 1_200_000

    assert client.delete(f"/api/v1/properties/{prop['id']}", headers=headers).status_code == 204

    body = estimate(client, headers)
    assert body["property"]["gross_minor"] == 0
    assert body["ifi"]["components"] == []


def test_the_ifi_base_nets_only_loans_linked_to_counted_properties(client: TestClient) -> None:
    """One line per counted property, each netted loan, and they sum to the reported base."""
    headers = register(client)
    counted = add_property(client, headers, label="Maison", market_value_minor=135_000_000)
    other = add_property(client, headers, label="Garage", market_value_minor=5_000_000)
    linked = add_mortgage(client, headers, label="Prêt maison", property_id=counted["id"])
    add_mortgage(client, headers, label="Prêt sans bien", property_id=None)

    body = estimate(client, headers)

    components = body["ifi"]["components"]
    assert [(c["key"], c["reference_id"], c["amount_minor"]) for c in components] == [
        ("property", counted["id"], 135_000_000),
        ("property", other["id"], 5_000_000),
        ("mortgage", linked["id"], -20_000_000),
    ]
    assert sum(c["amount_minor"] for c in components) == body["ifi"]["base_minor"] == 120_000_000
    assert body["ifi"]["liable"] is False


def test_a_user_under_the_ifi_threshold_still_gets_the_component(client: TestClient) -> None:
    """« Non redevable » is a state with a base and a threshold, never a missing entry."""
    headers = register(client)

    body = estimate(client, headers)

    assert body["ifi"] == {
        "base_minor": 0,
        "threshold_minor": 130_000_000,
        "liable": False,
        "gross_minor": 0,
        "decote_minor": 0,
        "due_minor": 0,
        "components": [],
    }
    assert any(entry["key"] == "ifi" for entry in body["breakdown"])


def test_the_primary_residence_abattement_is_its_own_component(client: TestClient) -> None:
    """The 30 % abattement is a line of the build-up, not a value quietly reduced beforehand."""
    headers = register(client)
    residence = add_property(
        client,
        headers,
        label="Résidence",
        kind="primary_residence",
        market_value_minor=100_000_000,
        ownership_bps=5_000,
    )

    components = estimate(client, headers)["ifi"]["components"]

    assert [(c["key"], c["amount_minor"]) for c in components] == [
        ("property", 50_000_000),
        ("primary_residence_allowance", -15_000_000),
    ]
    assert all(c["reference_id"] == residence["id"] for c in components)


def test_an_override_shows_up_in_parameter_source(client: TestClient, tmp_path: Path) -> None:
    """The estimate runs on the resolved set, so a user's own figure changes it and says so."""
    headers = register(client)
    patch_profile(client, headers, dividends_minor=1_000_000)
    seeded = estimate(client, headers)
    assert seeded["parameter_source"] == "seeded"
    assert seeded["pfu"]["income_tax_minor"] == 128_000

    with db(tmp_path) as session:
        session.add(
            TaxParameter(
                user_id=user_id(tmp_path),
                tax_year=YEAR,
                key="pfu_income_tax_bps",
                int_value=2560,
                unit="bps",
            )
        )
        session.commit()

    overridden = estimate(client, headers)
    assert overridden["parameter_source"] == "overridden"
    assert overridden["pfu"]["income_tax_minor"] == 256_000


def test_an_override_for_another_year_does_not_leak(client: TestClient, tmp_path: Path) -> None:
    """Overrides are per year — the axis a barème actually changes on."""
    headers = register(client)
    with db(tmp_path) as session:
        session.add(
            TaxParameter(
                user_id=user_id(tmp_path),
                tax_year=YEAR + 1,
                key="pfu_income_tax_bps",
                int_value=2560,
                unit="bps",
            )
        )
        session.commit()

    assert estimate(client, headers)["parameter_source"] == "seeded"


def test_a_year_with_no_profile_is_created_lazily_and_estimated_at_zero(
    client: TestClient,
) -> None:
    """Zero income is an answer; a year the user never opened is not a 404."""
    headers = register(client)

    body = estimate(client, headers)

    assert body["taxable_income_minor"] == 0
    assert body["ir_minor"] == 0
    assert body["total_due_minor"] == 0
    assert body["average_rate_bps"] == 0
    assert body["marginal_rate_bps"] == 0
    # The lazy row is the only thing the call wrote, and a later read finds it.
    listed = client.get("/api/v1/tax/profiles", headers=headers)
    assert [profile["tax_year"] for profile in listed.json()] == [YEAR]


def test_the_estimate_is_never_persisted(client: TestClient, tmp_path: Path) -> None:
    """A stored estimate would go stale the moment a declared figure changed (§4c)."""
    headers = register(client)
    patch_profile(client, headers, salaries_minor=4_000_000)
    assert estimate(client, headers)["ir_minor"] == 390_400

    patch_profile(client, headers, salaries_minor=2_200_000)

    assert estimate(client, headers)["ir_minor"] == 41_300
    with db(tmp_path) as session:
        tables = set(session.get_bind().dialect.get_table_names(session.connection()))
    assert not {table for table in tables if "estimate" in table}


def test_the_two_capital_roads_are_exclusive_in_the_response(client: TestClient) -> None:
    """Exactly one of `pfu` and `barème_capital_minor` carries a figure, never both."""
    headers = register(client)
    patch_profile(client, headers, dividends_minor=1_000_000)

    pfu = estimate(client, headers)
    assert pfu["pfu"]["base_minor"] == 1_000_000
    assert pfu["barème_capital_minor"] is None
    assert {entry["key"] for entry in pfu["breakdown"]} >= {"pfu_income_tax", "pfu_social_charges"}

    patch_profile(client, headers, pfu_opt_out=True)

    bareme = estimate(client, headers)
    assert bareme["pfu"] is None
    assert bareme["barème_capital_minor"] == 600_000
    keys = {entry["key"] for entry in bareme["breakdown"]}
    assert "capital_social_charges" in keys
    assert "pfu_income_tax" not in keys


def test_ignored_keys_are_machine_keys_and_carry_no_prose(client: TestClient) -> None:
    """The frontend owns the wording, in fr and en; the response owns the keys (§5c)."""
    headers = register(client)

    keys = estimate(client, headers)["ignored_keys"]

    assert keys
    for key in keys:
        assert key == key.lower()
        assert " " not in key


def test_another_users_data_never_reaches_the_estimate(client: TestClient) -> None:
    """Every source the estimate reads is user-scoped: profile, properties and loans alike."""
    amelie = register(client)
    patch_profile(client, amelie, salaries_minor=4_000_000)
    add_property(
        client,
        amelie,
        label="Studio",
        kind="rental",
        market_value_minor=135_000_000,
        annual_rent_minor=1_200_000,
        property_regime="micro_foncier",
    )

    bruno = register(client, email="bruno@example.com")
    body = estimate(client, bruno)

    assert body["taxable_income_minor"] == 0
    assert body["property"]["gross_minor"] == 0
    assert body["ifi"]["components"] == []
    assert body["total_due_minor"] == 0


def test_the_estimate_requires_authentication(client: TestClient) -> None:
    """Same gate as every other route; the error envelope shape is the app's, not FastAPI's."""
    response = client.get(f"/api/v1/tax/profiles/{YEAR}/estimate")

    assert response.status_code == 401
    assert response.json()["error"]["code"]


def test_a_year_outside_the_estimable_range_is_refused(client: TestClient) -> None:
    """Next year's income cannot be estimated, and offering it would imply otherwise."""
    headers = register(client)

    response = client.get(f"/api/v1/tax/profiles/{TODAY.year + 1}/estimate", headers=headers)

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "TAX_YEAR_OUT_OF_RANGE"
