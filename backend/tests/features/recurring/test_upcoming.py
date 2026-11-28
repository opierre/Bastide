"""Tests for the dashboard's « À venir »: what the active series still charge this month.

Most tests call the service with a fixed ``today``, as the summary tests do; the endpoint tests
place their dates around the real clock, since the route reads it.
"""

import io
from datetime import date, timedelta
from pathlib import Path

from fastapi.testclient import TestClient
from PIL import Image
from sqlalchemy.orm import Session

from app.core.months import last_of_month, month_index
from app.features.accounts.repository import AccountRepository
from app.features.accounts.service import AccountService
from app.features.categories.repository import CategoryRepository
from app.features.recurring.repository import RecurringRepository
from app.features.recurring.service import RecurringService, UpcomingResult
from app.features.transactions.repository import TransactionRepository
from tests.api import RegisteredUser as Owner
from tests.api import register_user as register
from tests.features.recurring.factories import (
    create_account,
    insert_series,
    insert_transaction,
    link_occurrence,
    open_session,
)

TODAY = date(2026, 5, 14)


def _service(session: Session) -> RecurringService:
    return RecurringService(
        RecurringRepository(session),
        TransactionRepository(session),
        AccountService(AccountRepository(session), session),
        CategoryRepository(session),
    )


def _upcoming(owner: Owner, tmp_path: Path, today: date = TODAY) -> UpcomingResult:
    """Build « À venir » on the client's own database, anchored on a fixed ``today``."""
    session = open_session(tmp_path)
    try:
        return _service(session).upcoming(owner.user_id, today)
    finally:
        session.close()


def _picture() -> bytes:
    output = io.BytesIO()
    Image.new("RGB", (64, 64), (0, 0, 0)).save(output, format="PNG")
    return output.getvalue()


def _labels(result: UpcomingResult) -> list[str]:
    return [charge.series.label for charge in result.due]


def _setup(client: TestClient) -> tuple[Owner, str]:
    owner = register(client)
    return owner, create_account(client, owner)


def test_charges_due_from_today_to_the_end_of_the_month_soonest_first(
    client: TestClient, tmp_path: Path
) -> None:
    owner, account_id = _setup(client)
    for label, due in (
        ("Studio Gym", date(2026, 5, 22)),
        ("Cloud Box", date(2026, 5, 15)),
        ("Next Month", date(2026, 6, 1)),
        ("Yesterday", date(2026, 5, 13)),
    ):
        insert_series(tmp_path, owner, account_id, label=label, next_expected_date=due)

    result = _upcoming(owner, tmp_path)

    assert result.through == date(2026, 5, 31)
    assert _labels(result) == ["Cloud Box", "Studio Gym"]


def test_a_charge_due_today_is_still_due(client: TestClient, tmp_path: Path) -> None:
    owner, account_id = _setup(client)
    insert_series(tmp_path, owner, account_id, label="Cloud Box", next_expected_date=TODAY)

    assert _labels(_upcoming(owner, tmp_path)) == ["Cloud Box"]


def test_on_the_last_day_of_the_month_only_that_days_charges_are_left(
    client: TestClient, tmp_path: Path
) -> None:
    owner, account_id = _setup(client)
    last_day = date(2026, 2, 28)
    insert_series(tmp_path, owner, account_id, label="Cloud Box", next_expected_date=last_day)
    insert_series(
        tmp_path, owner, account_id, label="Studio Gym", next_expected_date=date(2026, 3, 1)
    )

    result = _upcoming(owner, tmp_path, today=last_day)

    assert result.through == last_day
    assert _labels(result) == ["Cloud Box"]


def test_an_irregular_series_has_no_date_to_be_due_on(client: TestClient, tmp_path: Path) -> None:
    owner, account_id = _setup(client)
    insert_series(
        tmp_path,
        owner,
        account_id,
        label="Odd Jobs",
        cadence="irregular",
        next_expected_date=date(2026, 5, 20),
    )

    result = _upcoming(owner, tmp_path)

    assert result.due == ()
    assert result.missed == ()
    assert result.total_minor == 0


def test_cancelled_dismissed_and_archived_series_never_show(
    client: TestClient, tmp_path: Path
) -> None:
    owner, account_id = _setup(client)
    due = date(2026, 5, 20)
    insert_series(tmp_path, owner, account_id, label="Kept", next_expected_date=due)
    insert_series(
        tmp_path, owner, account_id, label="Cancelled", next_expected_date=due, status="cancelled"
    )
    insert_series(
        tmp_path, owner, account_id, label="Dismissed", next_expected_date=due, status="dismissed"
    )
    insert_series(
        tmp_path, owner, account_id, label="Archived", next_expected_date=due, archived=True
    )
    # Long overdue, so it would be missed if it were active.
    insert_series(
        tmp_path,
        owner,
        account_id,
        label="Cancelled Late",
        next_expected_date=date(2026, 4, 1),
        status="cancelled",
    )

    result = _upcoming(owner, tmp_path)

    assert _labels(result) == ["Kept"]
    assert result.missed == ()


def test_a_missed_charge_is_listed_apart_and_left_out_of_the_total(
    client: TestClient, tmp_path: Path
) -> None:
    owner, account_id = _setup(client)
    insert_series(
        tmp_path,
        owner,
        account_id,
        label="Cloud Box",
        expected_amount_minor=-1_250,
        next_expected_date=date(2026, 5, 18),
    )
    insert_series(
        tmp_path,
        owner,
        account_id,
        label="Studio Gym",
        expected_amount_minor=-2_490,
        next_expected_date=date(2026, 5, 29),
    )
    insert_series(
        tmp_path,
        owner,
        account_id,
        label="Late Mag",
        expected_amount_minor=-990,
        next_expected_date=date(2026, 5, 2),
    )

    result = _upcoming(owner, tmp_path)

    assert result.total_minor == -3_740
    assert isinstance(result.total_minor, int)
    assert [(c.series.label, c.missed.expected_on, c.missed.days_late) for c in result.missed] == [
        ("Late Mag", date(2026, 5, 2), 12)
    ]


def test_a_late_charge_that_landed_since_is_not_missed(client: TestClient, tmp_path: Path) -> None:
    owner, account_id = _setup(client)
    insert_series(
        tmp_path,
        owner,
        account_id,
        label="Late Mag",
        expected_amount_minor=-990,
        next_expected_date=date(2026, 5, 2),
    )
    insert_transaction(
        tmp_path,
        account_id,
        booked_date=date(2026, 5, 4),
        amount_minor=-990,
        description="LATE MAG",
    )

    assert _upcoming(owner, tmp_path).missed == ()


def test_a_recent_price_rise_is_flagged_with_its_signed_step(
    client: TestClient, tmp_path: Path
) -> None:
    owner, account_id = _setup(client)
    insert_series(
        tmp_path,
        owner,
        account_id,
        label="Risen",
        expected_amount_minor=-1_190,
        next_expected_date=date(2026, 5, 15),
        price_change_minor=-200,
        price_changed_at=date(2026, 4, 15),
    )
    insert_series(
        tmp_path,
        owner,
        account_id,
        label="Cheaper",
        next_expected_date=date(2026, 5, 16),
        price_change_minor=150,
        price_changed_at=date(2026, 4, 16),
    )
    insert_series(
        tmp_path,
        owner,
        account_id,
        label="Old Rise",
        next_expected_date=date(2026, 5, 17),
        price_change_minor=-100,
        price_changed_at=date(2025, 11, 17),
    )

    result = _upcoming(owner, tmp_path)

    assert [(c.series.label, c.price_increase_minor) for c in result.due] == [
        ("Risen", -200),
        ("Cheaper", None),
        ("Old Rise", None),
    ]


def test_another_users_series_never_show(client: TestClient, tmp_path: Path) -> None:
    owner, account_id = _setup(client)
    insert_series(tmp_path, owner, account_id, label="Cloud Box", next_expected_date=TODAY)
    other = register(client, "other@example.com")

    assert _upcoming(other, tmp_path).due == ()


# --- the endpoint ---------------------------------------------------------------------------


def test_the_endpoint_returns_the_month_left_with_its_logos(
    client: TestClient, tmp_path: Path
) -> None:
    owner, account_id = _setup(client)
    today = date.today()
    category_id = client.post(
        "/api/v1/categories",
        json={"name": "Loisirs", "kind": "expense", "icon": "movie", "color": "cat3"},
        headers=owner.headers,
    ).json()["id"]
    rule = client.post(
        "/api/v1/rules",
        json={
            "priority": 1,
            "match_field": "description_clean",
            "match_type": "contains",
            "pattern": "CLOUD BOX",
            "category_id": category_id,
            "enabled": True,
        },
        headers=owner.headers,
    ).json()
    logo = client.put(
        f"/api/v1/rules/{rule['id']}/logo",
        headers=owner.headers,
        files={"file": ("logo.png", _picture(), "image/png")},
    )
    assert logo.status_code == 200, logo.json()
    series_id = insert_series(
        tmp_path,
        owner,
        account_id,
        label="Cloud Box",
        expected_amount_minor=-1_250,
        next_expected_date=today,
    )
    link_occurrence(
        tmp_path,
        series_id,
        insert_transaction(
            tmp_path,
            account_id,
            booked_date=today - timedelta(days=30),
            amount_minor=-1_250,
            description="CLOUD BOX",
        ),
    )
    insert_series(
        tmp_path,
        owner,
        account_id,
        label="Late Mag",
        expected_amount_minor=-990,
        next_expected_date=today - timedelta(days=20),
    )

    response = client.get("/api/v1/recurring/upcoming", headers=owner.headers)

    assert response.status_code == 200, response.json()
    body = response.json()
    assert body["through"] == last_of_month(month_index(today)).isoformat()
    assert body["total_minor"] == -1_250
    assert body["currency"] == "EUR"
    assert body["charges"] == [
        {
            "series_id": series_id,
            "label": "Cloud Box",
            "amount_minor": -1_250,
            "due_on": today.isoformat(),
            "price_increase_minor": None,
            "logo_rule_id": rule["id"],
            "logo_updated_at": logo.json()["logo_updated_at"],
        }
    ]
    assert [(m["label"], m["amount_minor"], m["days_late"]) for m in body["missed"]] == [
        ("Late Mag", -990, 20)
    ]
    assert body["missed"][0]["logo_rule_id"] is None


def test_the_endpoint_requires_authentication(client: TestClient) -> None:
    assert client.get("/api/v1/recurring/upcoming").status_code == 401
