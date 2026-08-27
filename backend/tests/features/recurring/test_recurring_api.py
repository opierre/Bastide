"""Tests for the subscription surface: listing, detail, and declared series."""

from datetime import date, timedelta
from pathlib import Path

from fastapi.testclient import TestClient

from tests.features.recurring.factories import (
    Owner,
    create_account,
    insert_series,
    insert_transaction,
    link_occurrence,
    register,
)

TODAY = date.today()


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


# --- auth -----------------------------------------------------------------------------------


def test_every_route_requires_authentication(client: TestClient) -> None:
    assert client.get("/api/v1/recurring").status_code == 401
    assert client.get("/api/v1/recurring/some-id").status_code == 401
    assert client.post("/api/v1/recurring", json={}).status_code == 401
