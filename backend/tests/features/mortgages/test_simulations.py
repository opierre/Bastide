"""Tests for saved simulator scenarios: CRUD, validation, hard delete, the cap and user scoping.

What is at stake is that a scenario is a user's scratchpad of inputs — never a stored result,
never visible to anyone else, gone for good when deleted — and that no HCSF reading refuses it.
"""

from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, func, select
from sqlalchemy.orm import Session, sessionmaker

from app.features.mortgages.models import MortgageSimulation
from app.features.mortgages.simulations_service import MAX_SIMULATIONS_PER_USER
from tests.api import register

SCENARIO = {
    "label": "Lyon 3e — 320 k€",
    "property_price_minor": 32_000_000,
    "down_payment_minor": 4_000_000,
    "principal_minor": 28_450_000,
    "annual_rate_bps": 325,
    "insurance_monthly_minor": 3_200,
    "term_months": 300,
    "upfront_fees_minor": 450_000,
}

INPUT_FIELDS = set(SCENARIO) - {"label"}


def db(tmp_path: Path) -> Session:
    engine = create_engine(f"sqlite:///{tmp_path / 'test.db'}")
    return sessionmaker(bind=engine)()


def create(client: TestClient, headers: dict[str, str], **overrides: object) -> dict:
    response = client.post("/api/v1/simulations", json={**SCENARIO, **overrides}, headers=headers)
    assert response.status_code == 201, response.json()
    return dict(response.json())


def listed(client: TestClient, headers: dict[str, str]) -> list[dict]:
    response = client.get("/api/v1/simulations", headers=headers)
    assert response.status_code == 200, response.json()
    return list(response.json())


# --- CRUD ------------------------------------------------------------------------------------


def test_create_returns_the_inputs_and_the_user_currency(client: TestClient) -> None:
    headers = register(client)

    body = create(client, headers)

    assert {key: body[key] for key in SCENARIO} == SCENARIO
    assert body["currency"] == "EUR"
    assert body["id"]


def test_upfront_fees_default_to_zero(client: TestClient) -> None:
    headers = register(client)
    payload = {key: value for key, value in SCENARIO.items() if key != "upfront_fees_minor"}

    response = client.post("/api/v1/simulations", json=payload, headers=headers)

    assert response.status_code == 201
    assert response.json()["upfront_fees_minor"] == 0


def test_list_returns_the_scenarios_oldest_first(client: TestClient) -> None:
    headers = register(client)
    first = create(client, headers)
    second = create(client, headers, label="Villeurbanne — 265 k€")

    assert [item["id"] for item in listed(client, headers)] == [first["id"], second["id"]]


def test_patch_changes_only_the_given_fields(client: TestClient) -> None:
    headers = register(client)
    scenario = create(client, headers)

    response = client.patch(
        f"/api/v1/simulations/{scenario['id']}",
        json={"label": "Lyon 7e — 350 k€", "annual_rate_bps": 340},
        headers=headers,
    )

    assert response.status_code == 200
    body = response.json()
    assert (body["label"], body["annual_rate_bps"]) == ("Lyon 7e — 350 k€", 340)
    assert body["principal_minor"] == SCENARIO["principal_minor"]
    assert listed(client, headers)[0]["annual_rate_bps"] == 340


def test_delete_is_a_hard_delete(client: TestClient, tmp_path: Path) -> None:
    headers = register(client)
    scenario = create(client, headers)

    response = client.delete(f"/api/v1/simulations/{scenario['id']}", headers=headers)

    assert response.status_code == 204
    assert listed(client, headers) == []
    with db(tmp_path) as session:
        assert session.scalar(select(func.count()).select_from(MortgageSimulation)) == 0
    again = client.delete(f"/api/v1/simulations/{scenario['id']}", headers=headers)
    assert again.status_code == 404
    assert again.json()["error"]["code"] == "SIMULATION_NOT_FOUND"


def test_no_computed_result_is_stored_on_a_scenario(client: TestClient) -> None:
    headers = register(client)

    body = create(client, headers)

    columns = {column.name for column in MortgageSimulation.__table__.columns}
    assert columns == INPUT_FIELDS | {"id", "user_id", "label", "created_at", "updated_at"}
    assert set(body) == INPUT_FIELDS | {"id", "label", "currency", "created_at", "updated_at"}


# --- validation ------------------------------------------------------------------------------


@pytest.mark.parametrize(
    "overrides",
    [
        {"label": ""},
        {"property_price_minor": 0},
        {"down_payment_minor": -1},
        {"principal_minor": 0},
        {"annual_rate_bps": -1},
        {"insurance_monthly_minor": -1},
        {"term_months": 0},
        {"upfront_fees_minor": -1},
        {"principal_minor": 1.5},
        {"lender": "BNP Paribas"},
    ],
)
def test_invalid_inputs_are_rejected(client: TestClient, overrides: dict) -> None:
    headers = register(client)

    response = client.post("/api/v1/simulations", json={**SCENARIO, **overrides}, headers=headers)

    assert response.status_code == 422


def test_a_missing_input_is_rejected(client: TestClient) -> None:
    headers = register(client)
    payload = {key: value for key, value in SCENARIO.items() if key != "principal_minor"}

    assert client.post("/api/v1/simulations", json=payload, headers=headers).status_code == 422


def test_fees_swallowing_the_principal_are_rejected(client: TestClient) -> None:
    headers = register(client)

    response = client.post(
        "/api/v1/simulations",
        json={**SCENARIO, "upfront_fees_minor": SCENARIO["principal_minor"]},
        headers=headers,
    )

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "MORTGAGE_FEES_EXCEED_PRINCIPAL"


def test_a_rejected_patch_leaves_the_scenario_unchanged(client: TestClient) -> None:
    headers = register(client)
    scenario = create(client, headers)

    response = client.patch(
        f"/api/v1/simulations/{scenario['id']}",
        json={"principal_minor": 100_000, "label": "Renamed"},
        headers=headers,
    )

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "MORTGAGE_FEES_EXCEED_PRINCIPAL"
    stored = listed(client, headers)[0]
    assert (stored["principal_minor"], stored["label"]) == (
        SCENARIO["principal_minor"],
        SCENARIO["label"],
    )


def test_an_hcsf_breach_is_still_saved(client: TestClient) -> None:
    headers = register(client)

    created = client.post(
        "/api/v1/simulations", json={**SCENARIO, "term_months": 360}, headers=headers
    )
    patched = client.patch(
        f"/api/v1/simulations/{created.json()['id']}",
        json={"term_months": 420, "principal_minor": 90_000_000},
        headers=headers,
    )

    assert created.status_code == 201
    assert patched.status_code == 200


# --- the cap ---------------------------------------------------------------------------------


def test_the_per_user_cap_returns_422(client: TestClient) -> None:
    headers = register(client)
    scenarios = [create(client, headers) for _ in range(MAX_SIMULATIONS_PER_USER)]

    over = client.post("/api/v1/simulations", json=SCENARIO, headers=headers)

    assert MAX_SIMULATIONS_PER_USER == 20
    assert over.status_code == 422
    assert over.json()["error"]["code"] == "SIMULATION_LIMIT_REACHED"
    # The cap is per user, and deleting one frees a slot.
    create(client, register(client, email="bruno@example.com"))
    client.delete(f"/api/v1/simulations/{scenarios[0]['id']}", headers=headers)
    create(client, headers)


# --- user scoping ----------------------------------------------------------------------------


def test_scenarios_are_user_scoped(client: TestClient) -> None:
    owner = register(client)
    other = register(client, email="bruno@example.com")
    scenario = create(client, owner)

    assert listed(client, other) == []
    patched = client.patch(
        f"/api/v1/simulations/{scenario['id']}", json={"label": "Mine now"}, headers=other
    )
    deleted = client.delete(f"/api/v1/simulations/{scenario['id']}", headers=other)

    assert patched.status_code == 404
    assert deleted.status_code == 404
    assert listed(client, owner)[0]["label"] == SCENARIO["label"]


def test_every_route_requires_authentication(client: TestClient) -> None:
    assert client.get("/api/v1/simulations").status_code == 401
    assert client.post("/api/v1/simulations", json=SCENARIO).status_code == 401
    assert client.patch("/api/v1/simulations/any", json={"label": "x"}).status_code == 401
    assert client.delete("/api/v1/simulations/any").status_code == 401
