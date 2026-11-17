"""API tests for placements: CRUD, derived figures, closing, the transaction link, scoping.

All values are invented. What is at stake: money stays signed integer minor units, every
derived figure is computed on read, and a placement never reaches another user.
"""

from datetime import date
from pathlib import Path
from typing import Any, cast

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.features.placements.router import get_today
from app.features.transactions.models import Transaction
from tests.api import register, register_user
from tests.db import open_session
from tests.factories import make_account, make_import_batch

TODAY = date(2026, 5, 15)
BASE = "/api/v1/investments"

PEA = {
    "name": "PEA Bourse",
    "institution": "Banque Exemple",
    "envelope": "pea",
    "opened_on": "2023-03-10",
}


@pytest.fixture(autouse=True)
def pinned_today(client: TestClient) -> None:
    cast(FastAPI, client.app).dependency_overrides[get_today] = lambda: TODAY


def create(client: TestClient, headers: dict[str, str], **overrides: object) -> dict[str, Any]:
    response = client.post(BASE, json={**PEA, **overrides}, headers=headers)
    assert response.status_code == 201, response.json()
    return dict(response.json())


def post(client: TestClient, path: str, headers: dict[str, str], body: dict) -> Any:
    return client.post(f"{BASE}/{path}", json=body, headers=headers)


def get(client: TestClient, path: str, headers: dict[str, str]) -> Any:
    response = client.get(f"{BASE}/{path}" if path else BASE, headers=headers)
    assert response.status_code == 200, response.json()
    return response.json()


def error_code(response: Any, status: int) -> str:
    assert response.status_code == status, response.json()
    body = response.json()
    assert set(body) == {"error"}, body
    return str(body["error"]["code"])


def seed_transaction(tmp_path: Path, user_id: str, amount_minor: int, booked: date) -> str:
    """An imported transaction on a fresh account of the user's; returns its id."""
    with open_session(tmp_path / "test.db") as db:
        account = make_account(db, user_id=user_id, name="Compte joint")
        batch = make_import_batch(db, account)
        row = Transaction(
            account_id=account.id,
            import_batch_id=batch.id,
            booked_date=booked,
            amount_minor=amount_minor,
            currency="EUR",
            description_raw="VIR PEA EXEMPLE",
            description_clean="Virement PEA",
            categorization_source="uncategorized",
            needs_review=True,
            dedup_hash=f"hash-{amount_minor}-{booked}",
        )
        db.add(row)
        db.commit()
        return row.id


# --- creation and derived figures ------------------------------------------------------------


def test_create_derives_every_figure_and_stores_none(client: TestClient) -> None:
    headers = register(client)

    created = create(
        client,
        headers,
        initial_payments_minor=1_000_000,
        initial_value_minor=1_161_000,
        initial_value_on="2026-04-30",
    )

    assert created["currency"] == "EUR"
    assert created["paid_in_minor"] == 1_000_000
    assert created["withdrawn_minor"] == 0
    assert created["net_payments_minor"] == 1_000_000
    assert created["last_value_minor"] == 1_161_000
    assert created["last_valued_on"] == "2026-04-30"
    assert created["unrealised_gain_minor"] == 161_000
    assert created["gain_bps"] == 1_610
    assert created["age_months"] == 38
    assert created["payment_ceiling_minor"] == 15_000_000
    assert created["milestone_years"] == 5
    assert created["milestone_on"] == "2028-03-10"
    assert created["milestone_reached"] is False
    assert created["value_stale"] is False
    [opening] = created["movements"]
    assert opening["occurred_on"] == "2023-03-10"
    assert opening["amount_minor"] == 1_000_000
    for key, value in created.items():
        if key.endswith("_minor") and value is not None:
            assert type(value) is int, key


def test_initial_value_defaults_to_today(client: TestClient) -> None:
    headers = register(client)

    created = create(client, headers, initial_value_minor=50_000)

    assert created["last_valued_on"] == TODAY.isoformat()
    # No movements: the whole value reads as gain, and a share of nothing paid in is null.
    assert created["unrealised_gain_minor"] == 50_000
    assert created["gain_bps"] is None


def test_withdrawals_are_negative_and_a_loss_carries_its_sign(client: TestClient) -> None:
    headers = register(client)
    inv = create(client, headers, initial_payments_minor=800_000)

    response = post(
        client,
        f"{inv['id']}/movements",
        headers,
        {"occurred_on": "2025-06-01", "amount_minor": -100_000, "note": "Retrait partiel"},
    )
    assert response.status_code == 201, response.json()
    post(
        client,
        f"{inv['id']}/valuations",
        headers,
        {"valued_on": "2026-05-01", "value_minor": 630_000},
    )

    detail = get(client, inv["id"], headers)
    assert detail["paid_in_minor"] == 800_000
    assert detail["withdrawn_minor"] == -100_000
    assert detail["net_payments_minor"] == 700_000
    assert detail["unrealised_gain_minor"] == -70_000
    assert detail["gain_bps"] == -1_000
    assert [m["amount_minor"] for m in detail["movements"]] == [-100_000, 800_000]


def test_life_insurance_has_no_ceiling_and_reaches_its_milestone(client: TestClient) -> None:
    headers = register(client)

    created = create(client, headers, envelope="life_insurance", opened_on="2017-09-01")

    assert created["payment_ceiling_minor"] is None
    assert created["milestone_on"] == "2025-09-01"
    assert created["milestone_reached"] is True


def test_ceiling_is_hidden_for_a_user_outside_the_euro(client: TestClient) -> None:
    headers = register(client, currency="chf")

    created = create(client, headers)
    envelopes = {e["key"]: e for e in get(client, "envelopes", headers)}

    assert created["payment_ceiling_minor"] is None
    assert envelopes["pea"]["payment_ceiling_minor"] is None
    assert envelopes["pea"]["milestone_years"] == 5


def test_envelope_catalogue_lists_every_envelope(client: TestClient) -> None:
    headers = register(client)

    envelopes = get(client, "envelopes", headers)

    assert [e["key"] for e in envelopes] == [
        "pea",
        "pea_pme",
        "life_insurance",
        "per",
        "pee",
        "securities_account",
        "other",
    ]


def test_a_value_older_than_four_months_is_stale(client: TestClient) -> None:
    headers = register(client)

    stale = create(client, headers, initial_value_minor=10_000, initial_value_on="2026-01-14")
    fresh = create(client, headers, initial_value_minor=10_000, initial_value_on="2026-01-15")

    assert stale["value_stale"] is True
    assert fresh["value_stale"] is False


# --- validation ------------------------------------------------------------------------------


def test_dates_in_the_future_are_refused(client: TestClient) -> None:
    headers = register(client)
    inv = create(client, headers)

    assert (
        error_code(client.post(BASE, json={**PEA, "opened_on": "2026-05-16"}, headers=headers), 422)
        == "INVESTMENT_DATE_IN_FUTURE"
    )
    response = post(
        client, f"{inv['id']}/valuations", headers, {"valued_on": "2026-05-16", "value_minor": 1}
    )
    assert error_code(response, 422) == "INVESTMENT_DATE_IN_FUTURE"


def test_history_before_the_opening_is_refused(client: TestClient) -> None:
    headers = register(client)
    inv = create(client, headers)

    response = post(
        client, f"{inv['id']}/movements", headers, {"occurred_on": "2023-03-09", "amount_minor": 1}
    )
    assert error_code(response, 422) == "INVESTMENT_DATE_BEFORE_OPENING"


def test_moving_the_opening_after_the_history_is_refused(client: TestClient) -> None:
    headers = register(client)
    inv = create(client, headers, initial_payments_minor=100_000)

    response = client.patch(
        f"{BASE}/{inv['id']}", json={"opened_on": "2024-01-01"}, headers=headers
    )

    assert error_code(response, 422) == "INVESTMENT_DATE_BEFORE_OPENING"


@pytest.mark.parametrize("amount", [0, 10.5, "abc"])
def test_a_movement_amount_must_be_a_non_zero_integer(client: TestClient, amount: object) -> None:
    headers = register(client)
    inv = create(client, headers)

    response = post(
        client,
        f"{inv['id']}/movements",
        headers,
        {"occurred_on": "2024-01-01", "amount_minor": amount},
    )

    assert response.status_code == 422


def test_one_declared_value_per_date(client: TestClient) -> None:
    headers = register(client)
    inv = create(client, headers)
    body = {"valued_on": "2026-03-31", "value_minor": 123_400}
    assert post(client, f"{inv['id']}/valuations", headers, body).status_code == 201

    response = post(client, f"{inv['id']}/valuations", headers, body)

    assert error_code(response, 409) == "INVESTMENT_VALUATION_EXISTS"


# --- edits -----------------------------------------------------------------------------------


def test_patch_movement_and_valuation_clears_notes(client: TestClient) -> None:
    headers = register(client)
    inv = create(client, headers)
    movement = post(
        client,
        f"{inv['id']}/movements",
        headers,
        {"occurred_on": "2024-01-01", "amount_minor": 20_000, "note": "Versement"},
    ).json()
    valuation = post(
        client,
        f"{inv['id']}/valuations",
        headers,
        {"valued_on": "2024-06-30", "value_minor": 21_000, "note": "Relevé"},
    ).json()

    moved = client.patch(
        f"{BASE}/{inv['id']}/movements/{movement['id']}",
        json={"amount_minor": 25_000, "note": None},
        headers=headers,
    ).json()
    revalued = client.patch(
        f"{BASE}/{inv['id']}/valuations/{valuation['id']}",
        json={"value_minor": 26_000, "note": " "},
        headers=headers,
    ).json()

    assert (moved["amount_minor"], moved["note"]) == (25_000, None)
    assert (revalued["value_minor"], revalued["note"]) == (26_000, None)


def test_delete_movement_and_valuation(client: TestClient) -> None:
    headers = register(client)
    inv = create(client, headers, initial_payments_minor=10_000, initial_value_minor=11_000)
    movement_id = inv["movements"][0]["id"]
    valuation_id = inv["valuations"][0]["id"]

    assert (
        client.delete(f"{BASE}/{inv['id']}/movements/{movement_id}", headers=headers).status_code
        == 204
    )
    assert (
        client.delete(f"{BASE}/{inv['id']}/valuations/{valuation_id}", headers=headers).status_code
        == 204
    )

    detail = get(client, inv["id"], headers)
    assert detail["movements"] == [] and detail["valuations"] == []
    response = client.delete(f"{BASE}/{inv['id']}/movements/{movement_id}", headers=headers)
    assert error_code(response, 404) == "INVESTMENT_MOVEMENT_NOT_FOUND"


def test_delete_removes_the_placement_and_its_history(client: TestClient) -> None:
    headers = register(client)
    inv = create(client, headers, initial_payments_minor=10_000, initial_value_minor=11_000)

    assert client.delete(f"{BASE}/{inv['id']}", headers=headers).status_code == 204

    assert get(client, "", headers) == []
    assert (
        error_code(client.get(f"{BASE}/{inv['id']}", headers=headers), 404)
        == "INVESTMENT_NOT_FOUND"
    )


# --- closing ---------------------------------------------------------------------------------


def test_close_records_the_final_withdrawal_and_lists_it_last(client: TestClient) -> None:
    headers = register(client)
    closing = create(
        client, headers, name="Ancien PEE", envelope="pee", initial_payments_minor=300_000
    )
    still_open = create(client, headers, name="Assurance vie", envelope="life_insurance")

    response = post(
        client,
        f"{closing['id']}/close",
        headers,
        {"closed_on": "2026-02-10", "final_amount_minor": 345_000},
    )

    assert response.status_code == 200, response.json()
    closed = response.json()
    assert closed["closed_on"] == "2026-02-10"
    assert closed["withdrawn_minor"] == -345_000
    assert closed["net_payments_minor"] == -45_000
    assert closed["unrealised_gain_minor"] is None
    assert closed["age_months"] == 35
    assert [inv["id"] for inv in get(client, "", headers)] == [still_open["id"], closing["id"]]


def test_close_twice_conflicts_and_reopen_undoes_it(client: TestClient) -> None:
    headers = register(client)
    inv = create(client, headers)
    body = {"closed_on": "2026-01-10", "final_amount_minor": 0}
    assert post(client, f"{inv['id']}/close", headers, body).status_code == 200

    assert (
        error_code(post(client, f"{inv['id']}/close", headers, body), 409)
        == "INVESTMENT_ALREADY_CLOSED"
    )
    reopened = post(client, f"{inv['id']}/reopen", headers, {}).json()
    assert reopened["closed_on"] is None
    assert reopened["movements"] == []  # a zero final amount records no movement
    assert (
        error_code(post(client, f"{inv['id']}/reopen", headers, {}), 409) == "INVESTMENT_NOT_CLOSED"
    )


def test_close_before_the_last_movement_is_refused(client: TestClient) -> None:
    headers = register(client)
    inv = create(client, headers)
    post(
        client,
        f"{inv['id']}/movements",
        headers,
        {"occurred_on": "2026-03-01", "amount_minor": 5_000},
    )

    response = post(
        client, f"{inv['id']}/close", headers, {"closed_on": "2026-02-01", "final_amount_minor": 0}
    )

    assert error_code(response, 422) == "INVESTMENT_DATE_AFTER_CLOSING"


def test_history_after_the_closing_is_refused(client: TestClient) -> None:
    headers = register(client)
    inv = create(client, headers)
    post(
        client, f"{inv['id']}/close", headers, {"closed_on": "2026-02-01", "final_amount_minor": 0}
    )

    response = post(
        client, f"{inv['id']}/valuations", headers, {"valued_on": "2026-03-01", "value_minor": 1}
    )

    assert error_code(response, 422) == "INVESTMENT_DATE_AFTER_CLOSING"


# --- summary and series ----------------------------------------------------------------------


def test_summary_covers_open_placements_only(client: TestClient) -> None:
    headers = register(client)
    create(
        client,
        headers,
        initial_payments_minor=1_000_000,
        initial_value_minor=1_100_000,
        initial_value_on="2026-04-30",
    )
    create(client, headers, name="PEE", envelope="pee", initial_payments_minor=200_000)
    closed = create(
        client, headers, name="Ancien", initial_payments_minor=50_000, initial_value_minor=60_000
    )
    post(
        client,
        f"{closed['id']}/close",
        headers,
        {"closed_on": TODAY.isoformat(), "final_amount_minor": 60_000},
    )

    summary = get(client, "summary", headers)

    assert summary == {
        "open_count": 2,
        "closed_count": 1,
        "declared_value_minor": 1_100_000,
        "net_payments_minor": 1_200_000,
        "unrealised_gain_minor": 100_000,
        "gain_bps": 1_000,
        "valued_count": 1,
        "stale_count": 0,
        "last_valued_on": "2026-04-30",
        "currency": "EUR",
    }


def test_summary_of_no_placement_is_zero(client: TestClient) -> None:
    headers = register(client)

    summary = get(client, "summary", headers)

    assert summary["open_count"] == 0
    assert summary["declared_value_minor"] == 0
    assert summary["gain_bps"] is None
    assert summary["last_valued_on"] is None


def test_series_holds_values_flat_and_counts_payments_before_any(client: TestClient) -> None:
    headers = register(client)
    inv = create(client, headers, opened_on="2026-01-20", initial_payments_minor=100_000)
    post(
        client,
        f"{inv['id']}/valuations",
        headers,
        {"valued_on": "2026-02-28", "value_minor": 104_000},
    )
    post(
        client,
        f"{inv['id']}/movements",
        headers,
        {"occurred_on": "2026-03-05", "amount_minor": 20_000},
    )

    series = get(client, "series", headers)

    assert series["points"] == [
        {"month": "2026-01", "value_minor": 100_000, "net_payments_minor": 100_000},
        {"month": "2026-02", "value_minor": 104_000, "net_payments_minor": 100_000},
        {"month": "2026-03", "value_minor": 104_000, "net_payments_minor": 120_000},
        {"month": "2026-04", "value_minor": 104_000, "net_payments_minor": 120_000},
    ]


def test_series_drops_a_placement_from_its_closing_month(client: TestClient) -> None:
    headers = register(client)
    inv = create(client, headers, opened_on="2026-02-01", initial_payments_minor=100_000)
    post(
        client,
        f"{inv['id']}/close",
        headers,
        {"closed_on": "2026-03-10", "final_amount_minor": 100_000},
    )

    points = get(client, "series", headers)["points"]

    assert [(p["month"], p["value_minor"]) for p in points] == [
        ("2026-02", 100_000),
        ("2026-03", 0),
        ("2026-04", 0),
    ]


# --- the link to an imported transaction ------------------------------------------------------


def test_a_movement_links_to_the_transfer_that_funded_it(
    client: TestClient, tmp_path: Path
) -> None:
    user = register_user(client)
    inv = create(client, user.headers)
    transfer = seed_transaction(tmp_path, user.user_id, -150_000, date(2026, 4, 3))
    seed_transaction(tmp_path, user.user_id, -150_000, date(2026, 1, 3))  # outside the window

    [candidate] = client.get(
        f"{BASE}/{inv['id']}/link-candidates",
        params={"amount_minor": 150_000, "on": "2026-04-05"},
        headers=user.headers,
    ).json()
    assert candidate["transaction_id"] == transfer
    assert candidate["amount_minor"] == -150_000
    assert candidate["account_name"] == "Compte joint"

    response = post(
        client,
        f"{inv['id']}/movements",
        user.headers,
        {"occurred_on": "2026-04-05", "amount_minor": 150_000, "transaction_id": transfer},
    )
    assert response.status_code == 201, response.json()
    detail = get(client, inv["id"], user.headers)
    assert detail["linked_movement_count"] == 1
    # The link is reference only: it changes no total.
    assert detail["net_payments_minor"] == 150_000
    # Linked now, the transfer is no longer offered.
    assert (
        client.get(
            f"{BASE}/{inv['id']}/link-candidates",
            params={"amount_minor": 150_000, "on": "2026-04-05"},
            headers=user.headers,
        ).json()
        == []
    )

    again = post(
        client,
        f"{inv['id']}/movements",
        user.headers,
        {"occurred_on": "2026-04-06", "amount_minor": 150_000, "transaction_id": transfer},
    )
    assert error_code(again, 409) == "INVESTMENT_TRANSACTION_ALREADY_LINKED"


def test_a_link_to_another_users_transaction_is_refused(client: TestClient, tmp_path: Path) -> None:
    owner = register_user(client, "amelie@example.com")
    intruder = register(client, "bruno@example.com")
    foreign = seed_transaction(tmp_path, owner.user_id, -10_000, date(2026, 4, 3))
    inv = create(client, intruder)

    response = post(
        client,
        f"{inv['id']}/movements",
        intruder,
        {"occurred_on": "2026-04-03", "amount_minor": 10_000, "transaction_id": foreign},
    )

    assert error_code(response, 422) == "INVESTMENT_LINKED_TRANSACTION_NOT_FOUND"


def test_unlinking_a_movement(client: TestClient, tmp_path: Path) -> None:
    user = register_user(client)
    inv = create(client, user.headers)
    transfer = seed_transaction(tmp_path, user.user_id, -5_000, date(2026, 4, 3))
    movement = post(
        client,
        f"{inv['id']}/movements",
        user.headers,
        {"occurred_on": "2026-04-03", "amount_minor": 5_000, "transaction_id": transfer},
    ).json()

    unlinked = client.patch(
        f"{BASE}/{inv['id']}/movements/{movement['id']}",
        json={"transaction_id": None},
        headers=user.headers,
    ).json()

    assert unlinked["transaction_id"] is None


# --- scoping ---------------------------------------------------------------------------------


def test_another_users_placement_is_not_found(client: TestClient) -> None:
    owner = register(client, "amelie@example.com")
    intruder = register(client, "bruno@example.com")
    inv = create(client, owner)

    assert get(client, "", intruder) == []
    for method, path, body in [
        ("GET", inv["id"], None),
        ("PATCH", inv["id"], {"name": "Pris"}),
        ("DELETE", inv["id"], None),
        ("POST", f"{inv['id']}/movements", {"occurred_on": "2024-01-01", "amount_minor": 1}),
        ("POST", f"{inv['id']}/valuations", {"valued_on": "2024-01-01", "value_minor": 1}),
    ]:
        response = client.request(method, f"{BASE}/{path}", json=body, headers=intruder)
        assert error_code(response, 404) == "INVESTMENT_NOT_FOUND"
    assert get(client, "summary", intruder)["open_count"] == 0


def test_placements_require_auth(client: TestClient) -> None:
    for path in ("", "/summary", "/series", "/envelopes"):
        assert client.get(f"{BASE}{path}").status_code == 401
