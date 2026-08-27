"""Tests for the persistence half of detection: POST /recurring/detect.

The algorithm is covered in `test_detector.py`; what is at stake here is idempotence and the
primacy of user intent — a second pass over unchanged history must change nothing, and no pass
may talk back to a user who has already had their say about a series.
"""

from datetime import date, timedelta
from pathlib import Path

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

from app.features.imports.models import ImportBatch
from app.features.recurring.models import RecurringOccurrence, RecurringSeries
from app.features.transactions.models import Transaction

START = date(2026, 1, 15)
MONTHLY_OFFSETS = (0, 30, 60)

ACCOUNT_PAYLOAD = {
    "name": "Compte courant",
    "type": "checking",
    "institution": "BNP Paribas",
    "opening_balance_minor": 100_000,
}


def _register(client: TestClient, email: str = "amelie@example.com") -> dict[str, str]:
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
    return {"Authorization": f"Bearer {response.json()['token']}"}


def _create_account(client: TestClient, headers: dict[str, str], name: str = "Compte") -> str:
    payload = {**ACCOUNT_PAYLOAD, "name": name}
    return client.post("/api/v1/accounts", json=payload, headers=headers).json()["id"]


def _session(tmp_path: Path) -> Session:
    """A session on the very SQLite file the TestClient's dependency override points at."""
    engine = create_engine(
        f"sqlite:///{tmp_path / 'test.db'}", connect_args={"check_same_thread": False}
    )
    return sessionmaker(bind=engine)()


def _insert_subscription(
    tmp_path: Path,
    account_id: str,
    *,
    label: str = "PRLV SEPA NETFLIX.COM",
    amounts: tuple[int, ...] | None = None,
    offsets: tuple[int, ...] = MONTHLY_OFFSETS,
) -> list[str]:
    """Insert one merchant's occurrences straight into the client's database."""
    amounts = amounts if amounts is not None else (-1799,) * len(offsets)
    session = _session(tmp_path)
    batch = ImportBatch(
        user_id="unused",
        account_id=account_id,
        source_format="csv",
        file_name="test.csv",
        file_hash=f"hash-{account_id}-{label}",
        period_start=START,
        period_end=START + timedelta(days=max(offsets)),
        transaction_count=len(offsets),
        new_count=len(offsets),
        duplicate_count=0,
        status="success",
    )
    session.add(batch)
    session.flush()

    ids = []
    for offset, amount in zip(offsets, amounts, strict=True):
        description = f"{label} REF {offset}0114887"
        transaction = Transaction(
            account_id=account_id,
            import_batch_id=batch.id,
            booked_date=START + timedelta(days=offset),
            amount_minor=amount,
            currency="EUR",
            description_raw=description,
            description_clean=description,
            categorization_source="uncategorized",
            needs_review=True,
            dedup_hash=f"dedup-{account_id}-{label}-{offset}",
        )
        session.add(transaction)
        session.flush()
        ids.append(transaction.id)
    session.commit()
    session.close()
    return ids


def _detect(client: TestClient, headers: dict[str, str], **payload: object) -> dict:
    response = client.post("/api/v1/recurring/detect", json=payload, headers=headers)
    assert response.status_code == 200, response.json()
    return response.json()


def _series_rows(tmp_path: Path) -> list[RecurringSeries]:
    session = _session(tmp_path)
    rows = list(session.query(RecurringSeries).order_by(RecurringSeries.created_at))
    session.expunge_all()
    session.close()
    return rows


def _occurrence_rows(tmp_path: Path) -> list[RecurringOccurrence]:
    session = _session(tmp_path)
    rows = list(session.query(RecurringOccurrence))
    session.expunge_all()
    session.close()
    return rows


def _update_series(tmp_path: Path, series_id: str, **fields: object) -> None:
    """Stand in for the lifecycle endpoints, which are a later slice."""
    session = _session(tmp_path)
    series = session.get(RecurringSeries, series_id)
    assert series is not None
    for name, value in fields.items():
        setattr(series, name, value)
    session.commit()
    session.close()


# --- a first pass ----------------------------------------------------------------------------


def test_detection_persists_a_series_and_its_occurrences(
    client: TestClient, tmp_path: Path
) -> None:
    headers = _register(client)
    account_id = _create_account(client, headers)
    transaction_ids = _insert_subscription(tmp_path, account_id)

    assert _detect(client, headers) == {"created_count": 1, "updated_count": 0}

    series = _series_rows(tmp_path)
    assert len(series) == 1
    assert series[0].account_id == account_id
    assert series[0].merchant_key == "netflix.com"
    assert series[0].cadence == "monthly"
    assert series[0].expected_amount_minor == -1799
    assert series[0].currency == "EUR"
    assert series[0].occurrence_count == 3
    assert series[0].last_seen_date == START + timedelta(days=60)
    assert series[0].next_expected_date == START + timedelta(days=90)
    assert series[0].status == "detected"
    assert series[0].is_manual is False

    occurrences = _occurrence_rows(tmp_path)
    assert {occurrence.transaction_id for occurrence in occurrences} == set(transaction_ids)
    assert {occurrence.series_id for occurrence in occurrences} == {series[0].id}


def test_a_group_that_does_not_qualify_persists_nothing(client: TestClient, tmp_path: Path) -> None:
    headers = _register(client)
    account_id = _create_account(client, headers)
    _insert_subscription(tmp_path, account_id, offsets=(0, 30))

    assert _detect(client, headers) == {"created_count": 0, "updated_count": 0}
    assert _series_rows(tmp_path) == []


# --- idempotence -----------------------------------------------------------------------------


def test_re_running_updates_in_place_and_duplicates_nothing(
    client: TestClient, tmp_path: Path
) -> None:
    headers = _register(client)
    account_id = _create_account(client, headers)
    _insert_subscription(tmp_path, account_id)
    _detect(client, headers)
    first = _series_rows(tmp_path)[0]

    assert _detect(client, headers) == {"created_count": 0, "updated_count": 1}

    series = _series_rows(tmp_path)
    assert len(series) == 1
    assert series[0].id == first.id
    assert series[0].expected_amount_minor == first.expected_amount_minor
    assert series[0].occurrence_count == first.occurrence_count
    assert series[0].next_expected_date == first.next_expected_date


def test_re_running_replaces_the_occurrence_links_rather_than_adding_to_them(
    client: TestClient, tmp_path: Path
) -> None:
    headers = _register(client)
    account_id = _create_account(client, headers)
    transaction_ids = _insert_subscription(tmp_path, account_id)
    _detect(client, headers)

    _detect(client, headers)

    occurrences = _occurrence_rows(tmp_path)
    assert len(occurrences) == len(transaction_ids)
    assert {occurrence.transaction_id for occurrence in occurrences} == set(transaction_ids)


def test_a_new_occurrence_refreshes_the_observed_fields(client: TestClient, tmp_path: Path) -> None:
    headers = _register(client)
    account_id = _create_account(client, headers)
    _insert_subscription(tmp_path, account_id)
    _detect(client, headers)

    _insert_subscription(
        tmp_path, account_id, label="PRLV SEPA NETFLIX.COM ", offsets=(90,), amounts=(-2199,)
    )
    assert _detect(client, headers) == {"created_count": 0, "updated_count": 1}

    series = _series_rows(tmp_path)[0]
    assert series.occurrence_count == 4
    assert series.last_seen_date == START + timedelta(days=90)
    assert series.next_expected_date == START + timedelta(days=120)
    # €17.99 → €21.99, re-baselined, with the signed step recorded.
    assert series.expected_amount_minor == -2199
    assert series.price_change_minor == -400
    assert series.price_changed_at == START + timedelta(days=90)
    assert len(_occurrence_rows(tmp_path)) == 4


# --- user intent is sacred -------------------------------------------------------------------


def test_a_user_edited_label_and_category_survive_re_detection(
    client: TestClient, tmp_path: Path
) -> None:
    headers = _register(client)
    account_id = _create_account(client, headers)
    _insert_subscription(tmp_path, account_id)
    _detect(client, headers)
    category_id = client.post(
        "/api/v1/categories",
        json={"name": "Abonnements", "kind": "expense", "icon": "tv", "color": "#10B981"},
        headers=headers,
    ).json()["id"]
    series_id = _series_rows(tmp_path)[0].id
    _update_series(tmp_path, series_id, label="Netflix", category_id=category_id)

    _detect(client, headers)

    series = _series_rows(tmp_path)[0]
    assert series.label == "Netflix"
    assert series.category_id == category_id


def test_a_dismissed_series_is_never_resurrected(client: TestClient, tmp_path: Path) -> None:
    headers = _register(client)
    account_id = _create_account(client, headers)
    _insert_subscription(tmp_path, account_id)
    _detect(client, headers)
    series_id = _series_rows(tmp_path)[0].id
    _update_series(tmp_path, series_id, status="dismissed", occurrence_count=99)

    assert _detect(client, headers) == {"created_count": 0, "updated_count": 0}

    series = _series_rows(tmp_path)[0]
    assert series.status == "dismissed"
    assert series.occurrence_count == 99


def test_a_cancelled_series_is_left_alone(client: TestClient, tmp_path: Path) -> None:
    headers = _register(client)
    account_id = _create_account(client, headers)
    _insert_subscription(tmp_path, account_id)
    _detect(client, headers)
    series_id = _series_rows(tmp_path)[0].id
    _update_series(tmp_path, series_id, status="cancelled", expected_amount_minor=-1)

    assert _detect(client, headers) == {"created_count": 0, "updated_count": 0}
    assert _series_rows(tmp_path)[0].expected_amount_minor == -1


def test_a_manual_series_is_never_overwritten(client: TestClient, tmp_path: Path) -> None:
    headers = _register(client)
    account_id = _create_account(client, headers)
    _insert_subscription(tmp_path, account_id)
    _detect(client, headers)
    series_id = _series_rows(tmp_path)[0].id
    _update_series(tmp_path, series_id, is_manual=True, expected_amount_minor=-500)

    assert _detect(client, headers) == {"created_count": 0, "updated_count": 0}

    assert _series_rows(tmp_path)[0].expected_amount_minor == -500


def test_a_series_left_alone_keeps_its_occurrence_links(client: TestClient, tmp_path: Path) -> None:
    """The links of an untouched series are the user's; a later pass must not clear them."""
    headers = _register(client)
    account_id = _create_account(client, headers)
    transaction_ids = _insert_subscription(tmp_path, account_id)
    _detect(client, headers)
    _update_series(tmp_path, _series_rows(tmp_path)[0].id, is_manual=True)

    _detect(client, headers)

    occurrences = _occurrence_rows(tmp_path)
    assert {occurrence.transaction_id for occurrence in occurrences} == set(transaction_ids)


# --- scoping ---------------------------------------------------------------------------------


def test_detection_covers_every_account_by_default(client: TestClient, tmp_path: Path) -> None:
    headers = _register(client)
    first = _create_account(client, headers, name="Courant")
    second = _create_account(client, headers, name="Joint")
    _insert_subscription(tmp_path, first)
    _insert_subscription(tmp_path, second, label="PRLV SEPA SPOTIFY")

    assert _detect(client, headers) == {"created_count": 2, "updated_count": 0}
    assert {series.account_id for series in _series_rows(tmp_path)} == {first, second}


def test_account_id_narrows_the_pass_to_that_account(client: TestClient, tmp_path: Path) -> None:
    headers = _register(client)
    first = _create_account(client, headers, name="Courant")
    second = _create_account(client, headers, name="Joint")
    _insert_subscription(tmp_path, first)
    _insert_subscription(tmp_path, second, label="PRLV SEPA SPOTIFY")

    assert _detect(client, headers, account_id=first) == {
        "created_count": 1,
        "updated_count": 0,
    }

    assert [series.account_id for series in _series_rows(tmp_path)] == [first]


def test_another_user_s_account_is_not_found(client: TestClient, tmp_path: Path) -> None:
    owner_headers = _register(client)
    account_id = _create_account(client, owner_headers)
    _insert_subscription(tmp_path, account_id)
    intruder_headers = _register(client, email="bruno@example.com")

    response = client.post(
        "/api/v1/recurring/detect", json={"account_id": account_id}, headers=intruder_headers
    )

    assert response.status_code == 404
    assert response.json()["error"]["code"] == "ACCOUNT_NOT_FOUND"


def test_detection_never_reaches_another_user_s_transactions(
    client: TestClient, tmp_path: Path
) -> None:
    owner_headers = _register(client)
    account_id = _create_account(client, owner_headers)
    _insert_subscription(tmp_path, account_id)
    intruder_headers = _register(client, email="bruno@example.com")

    assert _detect(client, intruder_headers) == {"created_count": 0, "updated_count": 0}
    assert _series_rows(tmp_path) == []


def test_detection_requires_authentication(client: TestClient) -> None:
    assert client.post("/api/v1/recurring/detect", json={}).status_code == 401
