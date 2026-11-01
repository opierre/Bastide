"""Tests for marking a transaction as recurring: the preview, and the series confirmed from it.

What is at stake: the preview groups the right transactions and says how sure it is, and a
series saved from it owns exactly the ticked transactions — so a later detection pass neither
duplicates it nor steals its charges.
"""

from datetime import date, timedelta
from pathlib import Path

from fastapi.testclient import TestClient

from tests.api import RegisteredUser as Owner
from tests.api import register_user as register
from tests.features.recurring.factories import (
    create_account,
    insert_series,
    insert_transaction,
    link_occurrence,
)

START = date(2026, 1, 15)


def _charges(
    tmp_path: Path,
    account_id: str,
    offsets: list[int],
    amounts: list[int],
    description: str = "PRLV SEPA STREAMCO",
) -> list[str]:
    return [
        insert_transaction(
            tmp_path,
            account_id,
            booked_date=START + timedelta(days=offset),
            amount_minor=amount,
            description=description,
        )
        for offset, amount in zip(offsets, amounts, strict=True)
    ]


def _preview(client: TestClient, owner: Owner, transaction_id: str) -> dict:
    response = client.post(
        "/api/v1/recurring/preview", json={"transaction_id": transaction_id}, headers=owner.headers
    )
    assert response.status_code == 200, response.json()
    return dict(response.json())


def _series(client: TestClient, owner: Owner) -> list[dict]:
    return list(client.get("/api/v1/recurring", headers=owner.headers).json())


# --- the preview ----------------------------------------------------------------------------


def test_a_regular_history_previews_with_high_confidence(
    client: TestClient, tmp_path: Path
) -> None:
    owner = register(client)
    account_id = create_account(client, owner)
    ids = _charges(tmp_path, account_id, [0, 30, 61], [-999, -999, -999])
    _charges(tmp_path, account_id, [10], [-4500], description="CB BOULANGERIE DU PORT")

    body = _preview(client, owner, ids[-1])

    assert body["series"] is None
    preview = body["preview"]
    assert preview["confidence"] == "high"
    assert preview["cadence"] == "monthly"
    assert preview["expected_amount_minor"] == -999
    assert preview["currency"] == "EUR"
    assert preview["account_id"] == account_id
    assert "cadence_monthly" in preview["reasons"]
    assert [t["id"] for t in preview["transactions"]] == ids


def test_two_charges_preview_with_medium_confidence(client: TestClient, tmp_path: Path) -> None:
    owner = register(client)
    account_id = create_account(client, owner)
    ids = _charges(tmp_path, account_id, [0, 30], [-999, -999])

    preview = _preview(client, owner, ids[0])["preview"]

    assert preview["confidence"] == "medium"
    assert "too_few_occurrences" in preview["reasons"]


def test_no_rhythm_previews_with_low_confidence_as_irregular(
    client: TestClient, tmp_path: Path
) -> None:
    owner = register(client)
    account_id = create_account(client, owner)
    ids = _charges(tmp_path, account_id, [0, 14, 60], [-1200, -1200, -1200])

    preview = _preview(client, owner, ids[0])["preview"]

    assert preview["confidence"] == "low"
    assert preview["cadence"] == "irregular"
    assert "no_rhythm" in preview["reasons"]


def test_a_renamed_merchant_at_a_close_amount_is_a_near_match(
    client: TestClient, tmp_path: Path
) -> None:
    owner = register(client)
    account_id = create_account(client, owner)
    old = _charges(tmp_path, account_id, [0, 30], [-999, -999])
    renamed = _charges(tmp_path, account_id, [60], [-1099], description="PRLV SEPA STREAMCO TV")
    _charges(tmp_path, account_id, [45], [-8000], description="PRLV SEPA STREAMCO SHOP")

    preview = _preview(client, owner, renamed[0])["preview"]

    assert [t["id"] for t in preview["transactions"]] == [*old, *renamed]


def test_another_accounts_charges_are_left_out(client: TestClient, tmp_path: Path) -> None:
    owner = register(client)
    first = create_account(client, owner, name="Compte courant")
    second = create_account(client, owner, name="Compte joint")
    ids = _charges(tmp_path, first, [0, 30], [-999, -999])
    _charges(tmp_path, second, [60], [-999])

    preview = _preview(client, owner, ids[0])["preview"]

    assert [t["id"] for t in preview["transactions"]] == ids


def test_a_transaction_already_in_a_series_returns_that_series(
    client: TestClient, tmp_path: Path
) -> None:
    owner = register(client)
    account_id = create_account(client, owner)
    (transaction_id,) = _charges(tmp_path, account_id, [0], [-999])
    series_id = insert_series(
        tmp_path, owner, account_id, label="Abonnement vidéo", next_expected_date=START
    )
    link_occurrence(tmp_path, series_id, transaction_id)

    body = _preview(client, owner, transaction_id)

    assert body["preview"] is None
    assert body["series"]["id"] == series_id


def test_a_merchant_already_tracked_returns_its_series(client: TestClient, tmp_path: Path) -> None:
    owner = register(client)
    account_id = create_account(client, owner)
    series_id = insert_series(
        tmp_path, owner, account_id, label="STREAMCO", next_expected_date=START
    )
    (transaction_id,) = _charges(tmp_path, account_id, [0], [-999])

    assert _preview(client, owner, transaction_id)["series"]["id"] == series_id


def test_an_inflow_is_refused(client: TestClient, tmp_path: Path) -> None:
    owner = register(client)
    account_id = create_account(client, owner)
    (transaction_id,) = _charges(tmp_path, account_id, [0], [250_000], description="VIR SALAIRE")

    response = client.post(
        "/api/v1/recurring/preview", json={"transaction_id": transaction_id}, headers=owner.headers
    )

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "RECURRING_PREVIEW_INFLOW"


def test_another_users_transaction_is_not_found(client: TestClient, tmp_path: Path) -> None:
    owner = register(client)
    other = register(client, email="bruno@example.com")
    (transaction_id,) = _charges(tmp_path, create_account(client, other), [0], [-999])

    response = client.post(
        "/api/v1/recurring/preview", json={"transaction_id": transaction_id}, headers=owner.headers
    )

    assert response.status_code == 404
    assert response.json()["error"]["code"] == "TRANSACTION_NOT_FOUND"


# --- confirming -----------------------------------------------------------------------------


def _create(client: TestClient, owner: Owner, account_id: str, **extra: object) -> dict:
    payload = {
        "label": "Streamco",
        "account_id": account_id,
        "expected_amount_minor": -999,
        "cadence": "monthly",
        **extra,
    }
    response = client.post("/api/v1/recurring", json=payload, headers=owner.headers)
    assert response.status_code == 201, response.json()
    return dict(response.json())


def test_confirming_links_exactly_the_selected_transactions(
    client: TestClient, tmp_path: Path
) -> None:
    owner = register(client)
    account_id = create_account(client, owner)
    ids = _charges(tmp_path, account_id, [0, 30, 60, 90], [-999, -999, -999, -999])
    ticked = [ids[0], ids[1], ids[3]]

    created = _create(client, owner, account_id, transaction_ids=ticked)

    assert created["is_manual"] is True
    assert created["occurrence_count"] == 3
    assert created["first_seen_date"] == str(START)
    assert created["last_seen_date"] == str(START + timedelta(days=90))
    assert created["median_interval_days"] == 30
    detail = client.get(f"/api/v1/recurring/{created['id']}", headers=owner.headers).json()
    assert sorted(o["transaction"]["id"] for o in detail["occurrences"]) == sorted(ticked)


def test_a_detection_pass_after_confirming_creates_no_duplicate(
    client: TestClient, tmp_path: Path
) -> None:
    owner = register(client)
    account_id = create_account(client, owner)
    old = _charges(tmp_path, account_id, [0, 30, 60, 90], [-999, -999, -999, -999])
    renamed = _charges(
        tmp_path, account_id, [120, 150, 180], [-999, -999, -999], "PRLV SEPA STREAMCO TV"
    )
    created = _create(client, owner, account_id, transaction_ids=[*old, *renamed])

    result = client.post("/api/v1/recurring/detect", json={}, headers=owner.headers).json()

    assert result == {"created_count": 0, "updated_count": 0}
    assert [series["id"] for series in _series(client, owner)] == [created["id"]]
    detail = client.get(f"/api/v1/recurring/{created['id']}", headers=owner.headers).json()
    assert len(detail["occurrences"]) == 7


def test_confirming_rejects_a_transaction_already_in_a_series(
    client: TestClient, tmp_path: Path
) -> None:
    owner = register(client)
    account_id = create_account(client, owner)
    ids = _charges(tmp_path, account_id, [0, 30], [-999, -999])
    series_id = insert_series(
        tmp_path, owner, account_id, label="Abonnement vidéo", next_expected_date=START
    )
    link_occurrence(tmp_path, series_id, ids[0])

    response = client.post(
        "/api/v1/recurring",
        json={
            "label": "Streamco",
            "account_id": account_id,
            "expected_amount_minor": -999,
            "cadence": "monthly",
            "transaction_ids": ids,
        },
        headers=owner.headers,
    )

    assert response.status_code == 409
    assert response.json()["error"]["code"] == "RECURRING_TRANSACTION_LINKED"
    assert len(_series(client, owner)) == 1


def test_confirming_rejects_an_inflow_or_another_accounts_transaction(
    client: TestClient, tmp_path: Path
) -> None:
    owner = register(client)
    account_id = create_account(client, owner)
    other_account = create_account(client, owner, name="Compte joint")
    (inflow,) = _charges(tmp_path, account_id, [0], [999], description="VIR STREAMCO")
    (elsewhere,) = _charges(tmp_path, other_account, [0], [-999])

    response = client.post(
        "/api/v1/recurring",
        json={
            "label": "Streamco",
            "account_id": account_id,
            "expected_amount_minor": -999,
            "cadence": "monthly",
            "transaction_ids": [inflow, elsewhere],
        },
        headers=owner.headers,
    )

    assert response.status_code == 422
    error = response.json()["error"]
    assert error["code"] == "RECURRING_TRANSACTIONS_INVALID"
    assert error["details"]["transaction_ids"] == [inflow, elsewhere]
