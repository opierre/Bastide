"""Tests for the properties surface: CRUD, the held share, archiving, scoping.

What is at stake is that a valuation is declared exactly once and read from here by everyone:
the held share is derived on the way out (§18's assets), never recomputed elsewhere.
"""

from datetime import date
from typing import cast

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.features.properties.router import get_today
from tests.api import register

TODAY = date(2026, 5, 15)

PROPERTY_PAYLOAD = {
    "label": "Appartement Lyon 3e",
    "kind": "primary_residence",
    "market_value_minor": 42_000_000,
    "valued_on": "2026-01-12",
}

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


def create_property(client: TestClient, headers: dict[str, str], **overrides: object) -> dict:
    response = client.post(
        "/api/v1/properties", json={**PROPERTY_PAYLOAD, **overrides}, headers=headers
    )
    assert response.status_code == 201, response.json()
    return dict(response.json())


def list_properties(client: TestClient, headers: dict[str, str], **params: str) -> list[dict]:
    response = client.get("/api/v1/properties", params=params, headers=headers)
    assert response.status_code == 200, response.json()
    return list(response.json())


def create_loan(client: TestClient, headers: dict[str, str], **overrides: object) -> dict:
    response = client.post("/api/v1/mortgages", json={**LOAN_PAYLOAD, **overrides}, headers=headers)
    assert response.status_code == 201, response.json()
    return dict(response.json())


def error_of(response) -> dict:  # noqa: ANN001 - httpx.Response, kept untyped like its siblings
    """The error envelope, asserted to be the documented shape."""
    body = response.json()
    assert set(body) == {"error"}, body
    assert {"code", "message"} <= set(body["error"]), body
    return dict(body["error"])


# --- CRUD ------------------------------------------------------------------------------------


def test_create_returns_the_declared_property(client: TestClient) -> None:
    headers = register(client)

    created = create_property(client, headers)

    assert created["label"] == "Appartement Lyon 3e"
    assert created["kind"] == "primary_residence"
    assert created["market_value_minor"] == 42_000_000
    assert created["valued_on"] == "2026-01-12"
    assert created["ownership_bps"] == 10_000
    assert created["archived"] is False
    assert created["linked_mortgages"] == []


def test_list_returns_the_user_properties_oldest_first(client: TestClient) -> None:
    headers = register(client)
    first = create_property(client, headers)
    second = create_property(client, headers, label="Studio Villeurbanne", kind="secondary")

    assert [prop["id"] for prop in list_properties(client, headers)] == [
        first["id"],
        second["id"],
    ]


def test_get_returns_one_property(client: TestClient) -> None:
    headers = register(client)
    created = create_property(client, headers)

    response = client.get(f"/api/v1/properties/{created['id']}", headers=headers)

    assert response.status_code == 200, response.json()
    assert response.json()["id"] == created["id"]


def test_patch_updates_only_the_fields_it_carries(client: TestClient) -> None:
    headers = register(client)
    created = create_property(client, headers)

    response = client.patch(
        f"/api/v1/properties/{created['id']}",
        json={"label": "Appartement Lyon 6e"},
        headers=headers,
    )

    assert response.status_code == 200, response.json()
    assert response.json()["label"] == "Appartement Lyon 6e"
    assert response.json()["market_value_minor"] == 42_000_000


def test_a_new_valuation_is_a_patch_of_the_value_and_its_date(client: TestClient) -> None:
    """No valuation history exists (§4c): a re-estimation replaces the single declared value."""
    headers = register(client)
    created = create_property(client, headers)

    response = client.patch(
        f"/api/v1/properties/{created['id']}",
        json={"market_value_minor": 44_000_000, "valued_on": "2026-05-01"},
        headers=headers,
    )

    assert response.status_code == 200, response.json()
    assert response.json()["market_value_minor"] == 44_000_000
    assert response.json()["valued_on"] == "2026-05-01"
    assert response.json()["user_share_value_minor"] == 44_000_000


def test_market_value_must_be_positive(client: TestClient) -> None:
    headers = register(client)

    response = client.post(
        "/api/v1/properties", json={**PROPERTY_PAYLOAD, "market_value_minor": 0}, headers=headers
    )

    assert response.status_code == 422, response.json()


def test_kind_must_be_one_of_the_four_values(client: TestClient) -> None:
    headers = register(client)

    response = client.post(
        "/api/v1/properties", json={**PROPERTY_PAYLOAD, "kind": "boat"}, headers=headers
    )

    assert response.status_code == 422, response.json()


@pytest.mark.parametrize("ownership_bps", [0, 10_001])
def test_ownership_must_sit_between_one_and_ten_thousand_bps(
    client: TestClient, ownership_bps: int
) -> None:
    headers = register(client)

    response = client.post(
        "/api/v1/properties",
        json={**PROPERTY_PAYLOAD, "ownership_bps": ownership_bps},
        headers=headers,
    )

    assert response.status_code == 422, response.json()


# --- the derived share -----------------------------------------------------------------------


def test_full_ownership_holds_the_whole_declared_value(client: TestClient) -> None:
    headers = register(client)

    created = create_property(client, headers, market_value_minor=42_000_000)

    assert created["ownership_bps"] == 10_000
    assert created["user_share_value_minor"] == 42_000_000


def test_half_ownership_halves_the_declared_value(client: TestClient) -> None:
    headers = register(client)

    created = create_property(client, headers, market_value_minor=14_500_000, ownership_bps=5_000)

    assert created["user_share_value_minor"] == 7_250_000


def test_a_half_unit_share_rounds_half_up(client: TestClient) -> None:
    """14 500 001 x 50 % is 7 250 000,5 minor units; the round goes up, never to a float."""
    headers = register(client)

    created = create_property(client, headers, market_value_minor=14_500_001, ownership_bps=5_000)

    assert created["user_share_value_minor"] == 7_250_001


def test_an_odd_share_rounds_to_the_nearest_minor_unit(client: TestClient) -> None:
    """14 500 001 x 33,33 % is 4 832 850,3333; the round goes down."""
    headers = register(client)

    created = create_property(client, headers, market_value_minor=14_500_001, ownership_bps=3_333)

    assert created["user_share_value_minor"] == 4_832_850


def test_acquisition_delta_is_on_the_held_share_basis(client: TestClient) -> None:
    headers = register(client)

    created = create_property(
        client,
        headers,
        kind="secondary",
        market_value_minor=14_500_000,
        ownership_bps=5_000,
        acquisition_price_minor=13_200_000,
        acquired_on="2021-06-14",
    )

    assert created["user_share_value_minor"] == 7_250_000
    assert created["acquisition_delta_minor"] == 650_000


def test_acquisition_delta_is_negative_below_the_acquisition_price(client: TestClient) -> None:
    headers = register(client)

    created = create_property(
        client, headers, market_value_minor=38_000_000, acquisition_price_minor=42_000_000
    )

    assert created["acquisition_delta_minor"] == -4_000_000


def test_acquisition_delta_is_null_without_an_acquisition_price(client: TestClient) -> None:
    headers = register(client)

    created = create_property(client, headers)

    assert created["acquisition_price_minor"] is None
    assert created["acquisition_delta_minor"] is None


def test_the_list_carries_the_share_figures_too(client: TestClient) -> None:
    """`15-synthese.md` prints both on every card, and the frontend derives no money."""
    headers = register(client)
    create_property(
        client,
        headers,
        market_value_minor=14_500_000,
        ownership_bps=5_000,
        acquisition_price_minor=13_200_000,
    )

    listed = list_properties(client, headers)[0]

    assert listed["user_share_value_minor"] == 7_250_000
    assert listed["acquisition_delta_minor"] == 650_000


# --- the valuation date ----------------------------------------------------------------------


def test_a_future_valuation_date_is_refused(client: TestClient) -> None:
    headers = register(client)

    response = client.post(
        "/api/v1/properties", json={**PROPERTY_PAYLOAD, "valued_on": "2026-05-16"}, headers=headers
    )

    assert response.status_code == 422, response.json()
    assert error_of(response)["code"] == "PROPERTY_VALUATION_IN_FUTURE"


def test_a_valuation_dated_today_is_accepted(client: TestClient) -> None:
    headers = register(client)

    created = create_property(client, headers, valued_on="2026-05-15")

    assert created["valued_on"] == "2026-05-15"


def test_a_patch_cannot_move_the_valuation_into_the_future(client: TestClient) -> None:
    headers = register(client)
    created = create_property(client, headers)

    response = client.patch(
        f"/api/v1/properties/{created['id']}", json={"valued_on": "2026-06-01"}, headers=headers
    )

    assert response.status_code == 422, response.json()
    assert error_of(response)["code"] == "PROPERTY_VALUATION_IN_FUTURE"
    assert (
        client.get(f"/api/v1/properties/{created['id']}", headers=headers).json()["valued_on"]
        == "2026-01-12"
    )


# --- rent fields are gone --------------------------------------------------------------------


@pytest.mark.parametrize("field", ["annual_rent_minor", "annual_charges_minor", "property_regime"])
def test_a_rent_field_is_refused_as_unknown(client: TestClient, field: str) -> None:
    """The rent block went with the tax estimate; `extra="forbid"` keeps it from coming back."""
    headers = register(client)
    value: object = "reel" if field == "property_regime" else 390_000

    response = client.post(
        "/api/v1/properties",
        json={**PROPERTY_PAYLOAD, "kind": "rental", field: value},
        headers=headers,
    )

    assert response.status_code == 422, response.json()


def test_a_read_carries_no_rent_fields(client: TestClient) -> None:
    headers = register(client)

    created = create_property(client, headers, kind="rental")

    assert not {"annual_rent_minor", "annual_charges_minor", "property_regime"} & set(created)


# --- archiving -------------------------------------------------------------------------------


def test_delete_archives_and_hides_from_the_default_list(client: TestClient) -> None:
    headers = register(client)
    created = create_property(client, headers)

    response = client.delete(f"/api/v1/properties/{created['id']}", headers=headers)

    assert response.status_code == 204, response.text
    assert list_properties(client, headers) == []


def test_an_archived_property_is_returned_under_the_archived_flag(client: TestClient) -> None:
    headers = register(client)
    created = create_property(client, headers)
    client.delete(f"/api/v1/properties/{created['id']}", headers=headers)

    archived = list_properties(client, headers, archived="true")

    assert [prop["id"] for prop in archived] == [created["id"]]
    assert archived[0]["archived"] is True


def test_an_archived_property_is_still_readable_by_id(client: TestClient) -> None:
    headers = register(client)
    created = create_property(client, headers)
    client.delete(f"/api/v1/properties/{created['id']}", headers=headers)

    response = client.get(f"/api/v1/properties/{created['id']}", headers=headers)

    assert response.status_code == 200, response.json()
    assert response.json()["archived"] is True


def test_a_property_can_be_unarchived(client: TestClient) -> None:
    headers = register(client)
    created = create_property(client, headers)
    client.delete(f"/api/v1/properties/{created['id']}", headers=headers)

    response = client.patch(
        f"/api/v1/properties/{created['id']}", json={"archived": False}, headers=headers
    )

    assert response.status_code == 200, response.json()
    assert [prop["id"] for prop in list_properties(client, headers)] == [created["id"]]


def test_archiving_keeps_the_loan_link_intact(client: TestClient) -> None:
    """The loan still exists; only the hard delete P3-01 guards against would cut the link."""
    headers = register(client)
    created = create_property(client, headers)
    loan = create_loan(client, headers, property_id=created["id"])

    client.delete(f"/api/v1/properties/{created['id']}", headers=headers)

    detail = client.get(f"/api/v1/properties/{created['id']}", headers=headers).json()
    assert detail["linked_mortgages"] == [loan["id"]]
    assert (
        client.get(f"/api/v1/mortgages/{loan['id']}", headers=headers).json()["property_id"]
        == created["id"]
    )


# --- linked mortgages ------------------------------------------------------------------------


def test_linked_mortgages_lists_the_loans_pointing_at_the_property(client: TestClient) -> None:
    headers = register(client)
    target = create_property(client, headers)
    other = create_property(client, headers, label="Studio Villeurbanne", kind="secondary")
    first = create_loan(client, headers, property_id=target["id"])
    second = create_loan(client, headers, label="Travaux", kind="works", property_id=target["id"])
    create_loan(client, headers, label="Studio", property_id=other["id"])
    create_loan(client, headers, label="Auto", kind="auto")

    detail = client.get(f"/api/v1/properties/{target['id']}", headers=headers).json()

    assert detail["linked_mortgages"] == [first["id"], second["id"]]


def test_linked_mortgages_is_empty_without_a_loan(client: TestClient) -> None:
    headers = register(client)
    created = create_property(client, headers)

    detail = client.get(f"/api/v1/properties/{created['id']}", headers=headers).json()

    assert detail["linked_mortgages"] == []


# --- user scoping and currency ---------------------------------------------------------------


def test_another_users_property_is_a_404(client: TestClient) -> None:
    owner = register(client)
    intruder = register(client, email="bruno@example.com")
    created = create_property(client, owner)

    for response in (
        client.get(f"/api/v1/properties/{created['id']}", headers=intruder),
        client.patch(
            f"/api/v1/properties/{created['id']}", json={"label": "Mine"}, headers=intruder
        ),
        client.delete(f"/api/v1/properties/{created['id']}", headers=intruder),
    ):
        assert response.status_code == 404, response.json()
        assert error_of(response)["code"] == "PROPERTY_NOT_FOUND"


def test_the_list_only_shows_the_callers_properties(client: TestClient) -> None:
    owner = register(client)
    intruder = register(client, email="bruno@example.com")
    create_property(client, owner)

    assert list_properties(client, intruder) == []


def test_linked_mortgages_never_shows_another_users_loan(client: TestClient) -> None:
    owner = register(client)
    intruder = register(client, email="bruno@example.com")
    created = create_property(client, owner)
    create_loan(client, owner, property_id=created["id"])

    assert client.get(f"/api/v1/properties/{created['id']}", headers=intruder).status_code == 404
    assert list_properties(client, intruder) == []


def test_anonymous_requests_are_refused(client: TestClient) -> None:
    assert client.get("/api/v1/properties").status_code == 401


def test_currency_is_copied_from_the_user(client: TestClient) -> None:
    """One currency per user (Phase 1); no per-property currency and no selector (§4c)."""
    headers = register(client)

    assert create_property(client, headers)["currency"] == "EUR"

    response = client.post(
        "/api/v1/properties", json={**PROPERTY_PAYLOAD, "currency": "USD"}, headers=headers
    )
    assert response.status_code == 422, response.json()
