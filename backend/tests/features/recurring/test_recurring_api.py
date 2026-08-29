"""Tests for the subscription surface: listing, detail, the lifecycle, and manual series.

What is at stake here is that the states the API writes are states the lifecycle allows, and
that a user's "no" outlives the next detection pass.
"""

from datetime import date, timedelta
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from app.features.recurring.service import LEGAL_TRANSITIONS, NOMINAL_INTERVAL_DAYS
from tests.features.recurring.factories import (
    Owner,
    create_account,
    insert_series,
    insert_transaction,
    link_occurrence,
    read_series,
    register,
)

TODAY = date.today()
STATUSES = ("detected", "confirmed", "dismissed", "cancelled")


def _list(client: TestClient, owner: Owner, **params: str) -> list[dict]:
    response = client.get("/api/v1/recurring", params=params, headers=owner.headers)
    assert response.status_code == 200, response.json()
    return list(response.json())


# --- listing --------------------------------------------------------------------------------


def test_listing_is_ordered_by_next_expected_date(client: TestClient, tmp_path: Path) -> None:
    owner = register(client)
    account_id = create_account(client, owner)
    insert_series(
        tmp_path, owner, account_id, label="MAIF", next_expected_date=TODAY + timedelta(days=90)
    )
    insert_series(
        tmp_path, owner, account_id, label="Netflix", next_expected_date=TODAY + timedelta(days=1)
    )

    assert [series["label"] for series in _list(client, owner)] == ["Netflix", "MAIF"]


def test_listing_filters_by_status_and_account(client: TestClient, tmp_path: Path) -> None:
    owner = register(client)
    first = create_account(client, owner, name="Compte courant")
    second = create_account(client, owner, name="Compte joint")
    insert_series(
        tmp_path, owner, first, label="Netflix", next_expected_date=TODAY + timedelta(days=1)
    )
    insert_series(
        tmp_path,
        owner,
        first,
        label="Canal+",
        status="cancelled",
        next_expected_date=TODAY + timedelta(days=2),
    )
    insert_series(
        tmp_path, owner, second, label="Spotify", next_expected_date=TODAY + timedelta(days=3)
    )

    assert [series["label"] for series in _list(client, owner, status="cancelled")] == ["Canal+"]
    assert [series["label"] for series in _list(client, owner, account_id=second)] == ["Spotify"]
    assert len(_list(client, owner)) == 3


def test_listing_rejects_an_account_of_another_user(client: TestClient) -> None:
    owner = register(client)
    other = register(client, email="bruno@example.com")
    foreign_account = create_account(client, other)

    response = client.get(
        "/api/v1/recurring", params={"account_id": foreign_account}, headers=owner.headers
    )
    assert response.status_code == 404
    assert response.json()["error"]["code"] == "ACCOUNT_NOT_FOUND"


# --- detail ---------------------------------------------------------------------------------


def test_detail_returns_the_occurrences_with_their_transactions(
    client: TestClient, tmp_path: Path
) -> None:
    owner = register(client)
    account_id = create_account(client, owner)
    series_id = insert_series(
        tmp_path,
        owner,
        account_id,
        label="Netflix",
        expected_amount_minor=-1549,
        next_expected_date=TODAY + timedelta(days=1),
    )
    older = insert_transaction(
        tmp_path,
        account_id,
        booked_date=TODAY - timedelta(days=59),
        amount_minor=-1349,
        description="PRLV SEPA NETFLIX.COM",
    )
    newer = insert_transaction(
        tmp_path,
        account_id,
        booked_date=TODAY - timedelta(days=29),
        amount_minor=-1549,
        description="PRLV SEPA NETFLIX.COM",
    )
    link_occurrence(tmp_path, series_id, older)
    link_occurrence(tmp_path, series_id, newer)

    response = client.get(f"/api/v1/recurring/{series_id}", headers=owner.headers)
    assert response.status_code == 200, response.json()
    body = response.json()
    assert body["label"] == "Netflix"
    assert body["expected_amount_minor"] == -1549
    # Newest first, the order the detail screen's history table reads in.
    assert [occurrence["transaction"]["id"] for occurrence in body["occurrences"]] == [
        newer,
        older,
    ]
    assert body["occurrences"][0]["transaction"]["amount_minor"] == -1549


def test_detail_of_another_users_series_is_not_found(client: TestClient, tmp_path: Path) -> None:
    owner = register(client)
    other = register(client, email="bruno@example.com")
    series_id = insert_series(
        tmp_path,
        other,
        create_account(client, other),
        label="Netflix",
        next_expected_date=TODAY,
    )

    response = client.get(f"/api/v1/recurring/{series_id}", headers=owner.headers)
    assert response.status_code == 404
    assert response.json()["error"]["code"] == "RECURRING_SERIES_NOT_FOUND"


# --- the transition matrix ------------------------------------------------------------------


@pytest.mark.parametrize("current", STATUSES)
@pytest.mark.parametrize("requested", STATUSES)
def test_every_transition_is_accepted_exactly_when_the_lifecycle_allows_it(
    client: TestClient, tmp_path: Path, current: str, requested: str
) -> None:
    owner = register(client)
    account_id = create_account(client, owner)
    series_id = insert_series(
        tmp_path, owner, account_id, label="Netflix", status=current, next_expected_date=TODAY
    )

    response = client.patch(
        f"/api/v1/recurring/{series_id}", json={"status": requested}, headers=owner.headers
    )

    if requested in LEGAL_TRANSITIONS[current]:
        assert response.status_code == 200, response.json()
        assert response.json()["status"] == requested
        return
    assert response.status_code == 409
    error = response.json()["error"]
    assert error["code"] == "RECURRING_INVALID_TRANSITION"
    assert error["details"] == {"from": current, "to": requested}
    series = read_series(tmp_path, series_id)
    assert series is not None
    assert series.status == current


def test_a_rejected_transition_leaves_the_rest_of_the_patch_unapplied(
    client: TestClient, tmp_path: Path
) -> None:
    owner = register(client)
    account_id = create_account(client, owner)
    series_id = insert_series(
        tmp_path,
        owner,
        account_id,
        label="Netflix",
        status="dismissed",
        next_expected_date=TODAY,
    )

    response = client.patch(
        f"/api/v1/recurring/{series_id}",
        json={"label": "Netflix Famille", "status": "confirmed"},
        headers=owner.headers,
    )

    assert response.status_code == 409
    series = read_series(tmp_path, series_id)
    assert series is not None
    assert series.label == "Netflix"


def test_editable_fields_are_patched_without_a_status_change(
    client: TestClient, tmp_path: Path
) -> None:
    owner = register(client)
    account_id = create_account(client, owner)
    series_id = insert_series(
        tmp_path, owner, account_id, label="Netflix", next_expected_date=TODAY
    )

    response = client.patch(
        f"/api/v1/recurring/{series_id}",
        json={"label": "Netflix Famille", "expected_amount_minor": -1999, "cadence": "yearly"},
        headers=owner.headers,
    )

    assert response.status_code == 200, response.json()
    body = response.json()
    assert body["label"] == "Netflix Famille"
    assert body["expected_amount_minor"] == -1999
    assert body["cadence"] == "yearly"
    assert body["status"] == "detected"
    # The observed median is what the ledger showed, not a consequence of the cadence label.
    assert body["median_interval_days"] == NOMINAL_INTERVAL_DAYS["monthly"]


def test_patching_another_users_series_is_not_found(client: TestClient, tmp_path: Path) -> None:
    owner = register(client)
    other = register(client, email="bruno@example.com")
    series_id = insert_series(
        tmp_path,
        other,
        create_account(client, other),
        label="Netflix",
        next_expected_date=TODAY,
    )

    response = client.patch(
        f"/api/v1/recurring/{series_id}", json={"status": "confirmed"}, headers=owner.headers
    )
    assert response.status_code == 404
    assert read_series(tmp_path, series_id) is not None


# --- manual series --------------------------------------------------------------------------


def test_manual_creation_marks_the_series_and_seeds_it_from_the_cadence(
    client: TestClient,
) -> None:
    owner = register(client)
    account_id = create_account(client, owner)

    response = client.post(
        "/api/v1/recurring",
        json={
            "label": "Basic-Fit",
            "account_id": account_id,
            "expected_amount_minor": -2999,
            "cadence": "monthly",
        },
        headers=owner.headers,
    )

    assert response.status_code == 201, response.json()
    body = response.json()
    assert body["is_manual"] is True
    assert body["occurrence_count"] == 0
    assert body["status"] == "detected"
    assert body["expected_amount_minor"] == -2999
    assert body["currency"] == "EUR"
    assert body["median_interval_days"] == 30
    assert body["next_expected_date"] == str(date.today() + timedelta(days=30))


def test_manual_creation_accepts_the_irregular_cadence_detection_never_produces(
    client: TestClient,
) -> None:
    owner = register(client)
    account_id = create_account(client, owner)

    response = client.post(
        "/api/v1/recurring",
        json={
            "label": "Assurance scolaire",
            "account_id": account_id,
            "expected_amount_minor": -4500,
            "cadence": "irregular",
        },
        headers=owner.headers,
    )

    assert response.status_code == 201, response.json()
    assert response.json()["cadence"] == "irregular"


def test_manual_creation_rejects_a_name_the_account_already_tracks(client: TestClient) -> None:
    owner = register(client)
    account_id = create_account(client, owner)
    payload = {
        "label": "Basic-Fit",
        "account_id": account_id,
        "expected_amount_minor": -2999,
        "cadence": "monthly",
    }
    first = client.post("/api/v1/recurring", json=payload, headers=owner.headers).json()

    response = client.post("/api/v1/recurring", json=payload, headers=owner.headers)

    assert response.status_code == 409
    error = response.json()["error"]
    assert error["code"] == "RECURRING_SERIES_EXISTS"
    assert error["details"] == {"series_id": first["id"]}


def test_manual_creation_rejects_an_account_of_another_user(client: TestClient) -> None:
    owner = register(client)
    other = register(client, email="bruno@example.com")

    response = client.post(
        "/api/v1/recurring",
        json={
            "label": "Basic-Fit",
            "account_id": create_account(client, other),
            "expected_amount_minor": -2999,
            "cadence": "monthly",
        },
        headers=owner.headers,
    )

    assert response.status_code == 404
    assert response.json()["error"]["code"] == "ACCOUNT_NOT_FOUND"



def test_manual_creation_rejects_a_category_of_another_user(client: TestClient) -> None:
    """A series' category is a field, so an id the caller cannot see is a bad value (422).

    The foreign key alone would accept it and the panel would then render another user's
    private label and colour on this user's subscriptions.
    """
    owner = register(client)
    other = register(client, email="bruno@example.com")
    category_id = client.post(
        "/api/v1/categories",
        json={"name": "Sport", "kind": "expense", "icon": "fitness", "color": "#10B981"},
        headers=other.headers,
    ).json()["id"]

    response = client.post(
        "/api/v1/recurring",
        json={
            "label": "Basic-Fit",
            "account_id": create_account(client, owner),
            "expected_amount_minor": -2999,
            "cadence": "monthly",
            "category_id": category_id,
        },
        headers=owner.headers,
    )

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "CATEGORY_INVALID"
    assert _list(client, owner) == []


def test_patching_a_category_of_another_user_is_rejected(
    client: TestClient, tmp_path: Path
) -> None:
    owner = register(client)
    account_id = create_account(client, owner)
    series_id = insert_series(
        tmp_path, owner, account_id, label="Netflix", next_expected_date=TODAY
    )
    other = register(client, email="bruno@example.com")
    category_id = client.post(
        "/api/v1/categories",
        json={"name": "Sport", "kind": "expense", "icon": "fitness", "color": "#10B981"},
        headers=other.headers,
    ).json()["id"]

    response = client.patch(
        f"/api/v1/recurring/{series_id}",
        json={"category_id": category_id, "label": "Netflix Premium"},
        headers=owner.headers,
    )

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "CATEGORY_INVALID"
    # Checked before anything is assigned, so the label edit does not land either.
    series = read_series(tmp_path, series_id)
    assert series is not None
    assert series.label == "Netflix"

# --- delete ---------------------------------------------------------------------------------


def test_deleting_a_manual_series_removes_it(client: TestClient, tmp_path: Path) -> None:
    owner = register(client)
    account_id = create_account(client, owner)
    series_id = insert_series(
        tmp_path,
        owner,
        account_id,
        label="Basic-Fit",
        is_manual=True,
        occurrence_count=0,
        next_expected_date=TODAY,
    )

    response = client.delete(f"/api/v1/recurring/{series_id}", headers=owner.headers)

    assert response.status_code == 204
    assert read_series(tmp_path, series_id) is None


def test_deleting_a_detected_series_dismisses_it_instead(
    client: TestClient, tmp_path: Path
) -> None:
    owner = register(client)
    account_id = create_account(client, owner)
    series_id = insert_series(
        tmp_path, owner, account_id, label="Netflix", next_expected_date=TODAY
    )

    response = client.delete(f"/api/v1/recurring/{series_id}", headers=owner.headers)

    assert response.status_code == 204
    series = read_series(tmp_path, series_id)
    assert series is not None
    assert series.status == "dismissed"


def test_deleting_another_users_series_is_not_found(client: TestClient, tmp_path: Path) -> None:
    owner = register(client)
    other = register(client, email="bruno@example.com")
    series_id = insert_series(
        tmp_path,
        other,
        create_account(client, other),
        label="Netflix",
        is_manual=True,
        next_expected_date=TODAY,
    )

    response = client.delete(f"/api/v1/recurring/{series_id}", headers=owner.headers)

    assert response.status_code == 404
    assert read_series(tmp_path, series_id) is not None


def test_a_dismissed_series_stays_dismissed_across_a_detection_re_run(
    client: TestClient, tmp_path: Path
) -> None:
    owner = register(client)
    account_id = create_account(client, owner)
    start = date(2026, 1, 15)
    for offset in (0, 30, 60):
        insert_transaction(
            tmp_path,
            account_id,
            booked_date=start + timedelta(days=offset),
            amount_minor=-1549,
            description=f"PRLV SEPA NETFLIX.COM REF {offset}0114887",
        )
    assert client.post("/api/v1/recurring/detect", json={}, headers=owner.headers).json() == {
        "created_count": 1,
        "updated_count": 0,
    }
    series_id = _list(client, owner)[0]["id"]
    assert client.delete(f"/api/v1/recurring/{series_id}", headers=owner.headers).status_code == 204

    assert client.post("/api/v1/recurring/detect", json={}, headers=owner.headers).json() == {
        "created_count": 0,
        "updated_count": 0,
    }

    series = read_series(tmp_path, series_id)
    assert series is not None
    assert series.status == "dismissed"


# --- auth -----------------------------------------------------------------------------------


def test_every_route_requires_authentication(client: TestClient) -> None:
    assert client.get("/api/v1/recurring").status_code == 401
    assert client.get("/api/v1/recurring/summary").status_code == 401
    assert client.get("/api/v1/recurring/some-id").status_code == 401
    assert client.post("/api/v1/recurring", json={}).status_code == 401
    assert client.patch("/api/v1/recurring/some-id", json={}).status_code == 401
    assert client.delete("/api/v1/recurring/some-id").status_code == 401
