"""Tests for adding a charge to a series the user picks: the candidates, and what is learned.

What is at stake: the picker on a series offers the outflows that could join it, closest
first, never one already in a series or another user's; and a charge added under another label
teaches the series that label, so the next charge under it is offered that series by the preview
and grouped with it by detection — for a detected series and a hand-created one alike.
"""

from datetime import date, timedelta
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from app.features.recurring import router as recurring_router
from tests.api import RegisteredUser as Owner
from tests.api import register_user as register
from tests.features.recurring.factories import (
    create_account,
    insert_series,
    insert_transaction,
    link_occurrence,
)

START = date(2026, 1, 15)
PAYPAL = "PAYPAL *STREAMCO"


def _charge(
    tmp_path: Path,
    account_id: str,
    offset: int,
    amount: int = -999,
    description: str = "PRLV SEPA STREAMCO",
) -> str:
    return insert_transaction(
        tmp_path,
        account_id,
        booked_date=START + timedelta(days=offset),
        amount_minor=amount,
        description=description,
    )


def _attach(client: TestClient, owner: Owner, series_id: str, ids: list[str]) -> None:
    response = client.post(
        f"/api/v1/recurring/{series_id}/occurrences",
        json={"transaction_ids": ids},
        headers=owner.headers,
    )
    assert response.status_code == 200, response.json()


def _preview(client: TestClient, owner: Owner, transaction_id: str) -> dict:
    response = client.post(
        "/api/v1/recurring/preview", json={"transaction_id": transaction_id}, headers=owner.headers
    )
    assert response.status_code == 200, response.json()
    return dict(response.json())


def _occurrence_ids(client: TestClient, owner: Owner, series_id: str) -> set[str]:
    detail = client.get(f"/api/v1/recurring/{series_id}", headers=owner.headers).json()
    return {occurrence["transaction"]["id"] for occurrence in detail["occurrences"]}


def _candidates(client: TestClient, owner: Owner, series_id: str, **params: object) -> dict:
    response = client.get(
        f"/api/v1/recurring/{series_id}/candidates", params=params, headers=owner.headers
    )
    assert response.status_code == 200, response.json()
    return dict(response.json())


def _streamco_series(
    client: TestClient, owner: Owner, tmp_path: Path, account_id: str, origin: str
) -> str:
    """A « STREAMCO » series charged on days 0, 30 and 60, detected or created by hand."""
    ids = [_charge(tmp_path, account_id, offset) for offset in (0, 30, 60)]
    if origin == "detected":
        client.post("/api/v1/recurring/detect", json={}, headers=owner.headers)
        (series,) = client.get("/api/v1/recurring", headers=owner.headers).json()
        return str(series["id"])
    response = client.post(
        "/api/v1/recurring",
        json={
            "label": "Streamco",
            "account_id": account_id,
            "cadence": "monthly",
            "expected_amount_minor": -999,
            "transaction_ids": ids,
        },
        headers=owner.headers,
    )
    assert response.status_code == 201, response.json()
    return str(response.json()["id"])


# --- learning a label ----------------------------------------------------------------------


@pytest.mark.parametrize("origin", ["detected", "manual"])
def test_a_label_added_to_a_series_is_learned(
    client: TestClient, tmp_path: Path, origin: str
) -> None:
    owner = register(client)
    account_id = create_account(client, owner)
    series_id = _streamco_series(client, owner, tmp_path, account_id, origin)
    _attach(client, owner, series_id, [_charge(tmp_path, account_id, 90, description=PAYPAL)])
    later = _charge(tmp_path, account_id, 120, description=PAYPAL)

    preview = _preview(client, owner, later)
    assert preview["series"]["id"] == series_id
    assert [t["id"] for t in preview["addable_transactions"]] == [later]

    client.post("/api/v1/recurring/detect", json={}, headers=owner.headers)

    assert later in _occurrence_ids(client, owner, series_id)
    assert [s["id"] for s in client.get("/api/v1/recurring", headers=owner.headers).json()] == [
        series_id
    ]


def test_a_label_another_series_tracks_is_not_stolen(client: TestClient, tmp_path: Path) -> None:
    owner = register(client)
    account_id = create_account(client, owner)
    streamco = insert_series(
        tmp_path, owner, account_id, label="STREAMCO", next_expected_date=START
    )
    paypal = insert_series(tmp_path, owner, account_id, label=PAYPAL, next_expected_date=START)

    _attach(client, owner, streamco, [_charge(tmp_path, account_id, 90, description=PAYPAL)])
    later = _charge(tmp_path, account_id, 120, description=PAYPAL)

    assert _preview(client, owner, later)["series"]["id"] == paypal


# --- the candidates -------------------------------------------------------------------------


def test_candidates_are_ranked_closest_first(client: TestClient, tmp_path: Path) -> None:
    owner = register(client)
    account_id = create_account(client, owner)
    other_account = create_account(client, owner, name="Joint")
    series_id = insert_series(
        tmp_path,
        owner,
        account_id,
        label="PRLV SEPA STREAMCO",
        expected_amount_minor=-999,
        next_expected_date=START,
    )
    unrelated_far = _charge(tmp_path, account_id, 120, -5000, "CB BOULANGERIE DU PORT")
    unrelated_close = _charge(tmp_path, account_id, 110, -999, "CB BOULANGERIE DU PORT")
    alike = _charge(tmp_path, account_id, 100, -999, "PRLV SEPA STREAMCO TV")
    own_older = _charge(tmp_path, account_id, 60)
    own_newer = _charge(tmp_path, other_account, 90, description="PRLV SEPA STREAMCO")
    # Never offered: an inflow, and a charge already in a series.
    _charge(tmp_path, account_id, 95, 999, "VIR STREAMCO REMBOURSEMENT")
    linked = _charge(tmp_path, account_id, 30)
    link_occurrence(tmp_path, series_id, linked)

    page = _candidates(client, owner, series_id)

    # The series' own key first; then the same merchant elsewhere — a similar key, or the same
    # key on another account — newest first; then the rest, a close amount first.
    assert [item["id"] for item in page["items"]] == [
        own_older,
        alike,
        own_newer,
        unrelated_close,
        unrelated_far,
    ]
    assert page["total"] == 5
    assert page["page"] == 1


def test_candidates_filter_on_the_label(client: TestClient, tmp_path: Path) -> None:
    owner = register(client)
    account_id = create_account(client, owner)
    series_id = insert_series(
        tmp_path, owner, account_id, label="PRLV SEPA STREAMCO", next_expected_date=START
    )
    _charge(tmp_path, account_id, 60)
    bakery = _charge(tmp_path, account_id, 70, -450, "CB BOULANGERIE DU PORT")

    page = _candidates(client, owner, series_id, q="boulang")

    assert [item["id"] for item in page["items"]] == [bakery]
    assert page["total"] == 1


def test_candidates_are_paginated(
    client: TestClient, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(recurring_router, "CANDIDATE_PAGE_SIZE", 2)
    owner = register(client)
    account_id = create_account(client, owner)
    series_id = insert_series(
        tmp_path, owner, account_id, label="PRLV SEPA STREAMCO", next_expected_date=START
    )
    newest_first = [_charge(tmp_path, account_id, offset) for offset in (90, 60, 30)]

    first = _candidates(client, owner, series_id)
    second = _candidates(client, owner, series_id, page=2)

    assert [item["id"] for item in first["items"]] == newest_first[:2]
    assert [item["id"] for item in second["items"]] == newest_first[2:]
    assert first["total"] == second["total"] == 3
    assert first["page_size"] == 2


def test_candidates_never_include_another_users_outflows(
    client: TestClient, tmp_path: Path
) -> None:
    owner = register(client)
    other = register(client, email="bruno@example.com")
    series_id = insert_series(
        tmp_path,
        owner,
        create_account(client, owner),
        label="PRLV SEPA STREAMCO",
        next_expected_date=START,
    )
    _charge(tmp_path, create_account(client, other), 60)

    assert _candidates(client, owner, series_id)["items"] == []


def test_candidates_of_another_users_series_are_not_found(
    client: TestClient, tmp_path: Path
) -> None:
    owner = register(client)
    other = register(client, email="bruno@example.com")
    foreign = insert_series(
        tmp_path, other, create_account(client, other), label="STREAMCO", next_expected_date=START
    )

    response = client.get(f"/api/v1/recurring/{foreign}/candidates", headers=owner.headers)

    assert response.status_code == 404
    assert response.json()["error"]["code"] == "RECURRING_SERIES_NOT_FOUND"


def test_candidates_require_authentication(client: TestClient) -> None:
    assert client.get("/api/v1/recurring/any/candidates").status_code == 401
