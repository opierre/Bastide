"""Tests for merging two series the bank split by renaming the merchant.

At stake: the merged series is rebuilt from both histories, the merge survives every later
detection pass, and a « these are two » is never asked again.
"""

from datetime import date, timedelta
from pathlib import Path

from fastapi.testclient import TestClient

from tests.api import RegisteredUser as Owner
from tests.api import register_user as register
from tests.features.recurring.factories import create_account, insert_series, insert_transaction

START = date(2025, 11, 4)
OLD_LABEL = "PRLV SEPA STREAMCO"
NEW_LABEL = "PRLV SEPA STREAMCO - STREAMCO TV"


def _renamed_subscription(tmp_path: Path, account_id: str) -> None:
    """Three charges under the old label, then three under the new one, a month apart."""
    for month in range(6):
        insert_transaction(
            tmp_path,
            account_id,
            booked_date=START + timedelta(days=30 * month),
            amount_minor=-2499,
            description=OLD_LABEL if month < 3 else NEW_LABEL,
        )


def _detect(client: TestClient, owner: Owner) -> None:
    response = client.post("/api/v1/recurring/detect", json={}, headers=owner.headers)
    assert response.status_code == 200, response.json()


def _series(client: TestClient, owner: Owner) -> list[dict]:
    response = client.get("/api/v1/recurring", headers=owner.headers)
    assert response.status_code == 200
    return list(response.json())


def _suggestions(client: TestClient, owner: Owner) -> list[dict]:
    response = client.get("/api/v1/recurring/merge-suggestions", headers=owner.headers)
    assert response.status_code == 200, response.json()
    return list(response.json())


def _merge(client: TestClient, owner: Owner, target_id: str, source_id: str) -> dict:
    response = client.post(
        f"/api/v1/recurring/{target_id}/merge",
        json={"source_id": source_id},
        headers=owner.headers,
    )
    assert response.status_code == 200, response.json()
    return dict(response.json())


def test_a_renamed_subscription_is_proposed_with_the_new_label_kept(
    client: TestClient, tmp_path: Path
) -> None:
    owner = register(client)
    account_id = create_account(client, owner)
    _renamed_subscription(tmp_path, account_id)
    _detect(client, owner)

    [suggestion] = _suggestions(client, owner)

    assert suggestion["target"]["label"] == NEW_LABEL
    assert suggestion["source"]["label"] == OLD_LABEL


def test_merging_rebuilds_one_series_that_later_passes_keep(
    client: TestClient, tmp_path: Path
) -> None:
    owner = register(client)
    account_id = create_account(client, owner)
    _renamed_subscription(tmp_path, account_id)
    _detect(client, owner)
    [suggestion] = _suggestions(client, owner)

    merged = _merge(client, owner, suggestion["target"]["id"], suggestion["source"]["id"])

    assert merged["label"] == NEW_LABEL
    assert merged["occurrence_count"] == 6
    assert merged["first_seen_date"] == START.isoformat()
    detail = client.get(f"/api/v1/recurring/{merged['id']}", headers=owner.headers).json()
    assert len(detail["occurrences"]) == 6

    # A later charge under the old label still lands in the merged series.
    insert_transaction(
        tmp_path,
        account_id,
        booked_date=START + timedelta(days=180),
        amount_minor=-2499,
        description=OLD_LABEL,
    )
    _detect(client, owner)

    [only] = _series(client, owner)
    assert only["id"] == merged["id"]
    assert only["occurrence_count"] == 7
    assert _suggestions(client, owner) == []


def test_merging_keeps_the_users_word_on_either_series(client: TestClient, tmp_path: Path) -> None:
    owner = register(client)
    account_id = create_account(client, owner)
    _renamed_subscription(tmp_path, account_id)
    _detect(client, owner)
    [suggestion] = _suggestions(client, owner)
    source_id = suggestion["source"]["id"]
    confirm = client.patch(
        f"/api/v1/recurring/{source_id}", json={"status": "confirmed"}, headers=owner.headers
    )
    assert confirm.status_code == 200

    merged = _merge(client, owner, suggestion["target"]["id"], source_id)

    assert merged["status"] == "confirmed"


def test_a_pair_kept_apart_is_not_proposed_again(client: TestClient, tmp_path: Path) -> None:
    owner = register(client)
    account_id = create_account(client, owner)
    _renamed_subscription(tmp_path, account_id)
    _detect(client, owner)
    [suggestion] = _suggestions(client, owner)

    response = client.post(
        "/api/v1/recurring/merge-suggestions/dismiss",
        json={"target_id": suggestion["target"]["id"], "source_id": suggestion["source"]["id"]},
        headers=owner.headers,
    )

    assert response.status_code == 204
    _detect(client, owner)
    assert _suggestions(client, owner) == []
    assert len(_series(client, owner)) == 2


def test_merging_a_series_into_itself_or_with_a_manual_one_is_refused(
    client: TestClient, tmp_path: Path
) -> None:
    owner = register(client)
    account_id = create_account(client, owner)
    detected = insert_series(
        tmp_path, owner, account_id, label="Streamco", next_expected_date=date(2026, 6, 1)
    )
    manual = insert_series(
        tmp_path,
        owner,
        account_id,
        label="Streamco TV",
        next_expected_date=date(2026, 6, 1),
        is_manual=True,
    )

    for target, source in [(detected, detected), (detected, manual), (manual, detected)]:
        response = client.post(
            f"/api/v1/recurring/{target}/merge", json={"source_id": source}, headers=owner.headers
        )
        assert response.status_code == 409
        assert response.json()["error"]["code"] == "RECURRING_MERGE_INVALID"


def test_merging_across_accounts_is_refused(client: TestClient, tmp_path: Path) -> None:
    owner = register(client)
    first = create_account(client, owner, name="Compte courant")
    second = create_account(client, owner, name="Compte joint")
    a = insert_series(tmp_path, owner, first, label="Streamco", next_expected_date=date(2026, 6, 1))
    b = insert_series(
        tmp_path, owner, second, label="Streamco TV", next_expected_date=date(2026, 6, 1)
    )

    response = client.post(
        f"/api/v1/recurring/{a}/merge", json={"source_id": b}, headers=owner.headers
    )

    assert response.status_code == 409


def test_another_users_series_cannot_be_merged_or_kept_apart(
    client: TestClient, tmp_path: Path
) -> None:
    owner = register(client)
    other = register(client, email="bruno@example.com")
    mine = insert_series(
        tmp_path,
        owner,
        create_account(client, owner),
        label="Streamco",
        next_expected_date=date(2026, 6, 1),
    )
    theirs = insert_series(
        tmp_path,
        other,
        create_account(client, other),
        label="Streamco TV",
        next_expected_date=date(2026, 6, 1),
    )

    merge = client.post(
        f"/api/v1/recurring/{mine}/merge", json={"source_id": theirs}, headers=owner.headers
    )
    dismiss = client.post(
        "/api/v1/recurring/merge-suggestions/dismiss",
        json={"target_id": mine, "source_id": theirs},
        headers=owner.headers,
    )

    assert merge.status_code == 404
    assert dismiss.status_code == 404
    assert _suggestions(client, owner) == []


def test_the_merge_endpoints_require_auth(client: TestClient) -> None:
    assert client.get("/api/v1/recurring/merge-suggestions").status_code == 401
    merge = client.post("/api/v1/recurring/some-id/merge", json={"source_id": "x"})
    assert merge.status_code == 401
    dismiss = client.post(
        "/api/v1/recurring/merge-suggestions/dismiss", json={"target_id": "a", "source_id": "b"}
    )
    assert dismiss.status_code == 401
