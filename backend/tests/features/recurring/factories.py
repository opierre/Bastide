"""Helpers shared by the recurring API and summary tests.

Series rows are inserted straight into the client's database rather than produced by a
detection pass: these tests are about the lifecycle and the read-time summary, and going
through the detector would make every assertion depend on the algorithm's verdict as well as
on the code under test.
"""

from datetime import date, timedelta
from pathlib import Path

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

from app.features.imports.models import ImportBatch
from app.features.recurring.models import RecurringOccurrence, RecurringSeries
from app.features.recurring.normalize import normalize_label
from app.features.recurring.service import NOMINAL_INTERVAL_DAYS
from app.features.transactions.models import Transaction
from tests.api import RegisteredUser as Owner

ACCOUNT_PAYLOAD = {
    "name": "Compte courant",
    "type": "checking",
    "institution": "BNP Paribas",
    "opening_balance_minor": 100_000,
}


def create_account(client: TestClient, owner: Owner, name: str = "Compte courant") -> str:
    """Open an account for ``owner`` and return its id."""
    response = client.post(
        "/api/v1/accounts", json={**ACCOUNT_PAYLOAD, "name": name}, headers=owner.headers
    )
    assert response.status_code == 201, response.json()
    return str(response.json()["id"])


def open_session(tmp_path: Path) -> Session:
    """A session on the very SQLite file the TestClient's dependency override points at."""
    engine = create_engine(
        f"sqlite:///{tmp_path / 'test.db'}", connect_args={"check_same_thread": False}
    )
    return sessionmaker(bind=engine)()


def insert_series(
    tmp_path: Path,
    owner: Owner,
    account_id: str,
    *,
    label: str,
    cadence: str = "monthly",
    expected_amount_minor: int = -1000,
    next_expected_date: date,
    status: str = "detected",
    is_manual: bool = False,
    occurrence_count: int = 3,
    price_change_minor: int | None = None,
    price_changed_at: date | None = None,
) -> str:
    """Insert one series and return its id.

    The observed dates are derived backwards from ``next_expected_date`` so a caller only has
    to state the one date the panel actually shows.
    """
    interval = NOMINAL_INTERVAL_DAYS[cadence]
    session = open_session(tmp_path)
    series = RecurringSeries(
        user_id=owner.user_id,
        account_id=account_id,
        merchant_key=normalize_label(label),
        label=label,
        cadence=cadence,
        median_interval_days=interval,
        expected_amount_minor=expected_amount_minor,
        currency="EUR",
        first_seen_date=next_expected_date - timedelta(days=interval * occurrence_count),
        last_seen_date=next_expected_date - timedelta(days=interval),
        next_expected_date=next_expected_date,
        occurrence_count=occurrence_count,
        status=status,
        is_manual=is_manual,
        price_change_minor=price_change_minor,
        price_changed_at=price_changed_at,
    )
    session.add(series)
    session.commit()
    series_id = series.id
    session.close()
    return series_id


def insert_transaction(
    tmp_path: Path,
    account_id: str,
    *,
    booked_date: date,
    amount_minor: int,
    description: str,
) -> str:
    """Insert one transaction and return its id."""
    session = open_session(tmp_path)
    batch = ImportBatch(
        user_id="unused",
        account_id=account_id,
        source_format="ofx",
        file_name="test.ofx",
        file_hash=f"hash-{account_id}-{description}-{booked_date}",
        period_start=booked_date,
        period_end=booked_date,
        transaction_count=1,
        new_count=1,
        duplicate_count=0,
        status="success",
    )
    session.add(batch)
    session.flush()
    transaction = Transaction(
        account_id=account_id,
        import_batch_id=batch.id,
        booked_date=booked_date,
        amount_minor=amount_minor,
        currency="EUR",
        description_raw=description,
        description_clean=description,
        categorization_source="uncategorized",
        needs_review=True,
        dedup_hash=f"dedup-{account_id}-{description}-{booked_date}",
    )
    session.add(transaction)
    session.commit()
    transaction_id = transaction.id
    session.close()
    return transaction_id


def link_occurrence(tmp_path: Path, series_id: str, transaction_id: str) -> None:
    """Attach a transaction to a series the way a detection pass would."""
    session = open_session(tmp_path)
    session.add(RecurringOccurrence(series_id=series_id, transaction_id=transaction_id))
    session.commit()
    session.close()


def read_series(tmp_path: Path, series_id: str) -> RecurringSeries | None:
    """Re-read a series straight from the database, detached from its session."""
    session = open_session(tmp_path)
    series = session.get(RecurringSeries, series_id)
    if series is not None:
        session.expunge(series)
    session.close()
    return series
