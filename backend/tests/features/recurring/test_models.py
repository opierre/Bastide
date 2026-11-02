"""The recurring tables' own guarantees: unique series and occurrences, and the cascade."""

from datetime import date
from uuid import uuid4

import pytest
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.features.accounts.models import Account
from app.features.recurring.models import RecurringOccurrence, RecurringSeries
from app.features.transactions.models import Transaction
from tests.factories import make_account, make_import_batch


def _series(account: Account, **overrides: object) -> RecurringSeries:
    kwargs: dict[str, object] = {
        "user_id": account.user_id,
        "account_id": account.id,
        "merchant_key": "netflix",
        "label": "Netflix",
        "cadence": "monthly",
        "median_interval_days": 30,
        "expected_amount_minor": -1099,
        "currency": "EUR",
        "first_seen_date": date(2025, 11, 15),
        "last_seen_date": date(2026, 1, 15),
        "next_expected_date": date(2026, 2, 14),
        "occurrence_count": 3,
        "status": "detected",
        "is_manual": False,
    }
    kwargs.update(overrides)
    return RecurringSeries(**kwargs)


def _transaction(db: Session, account: Account) -> Transaction:
    transaction = Transaction(
        account_id=account.id,
        import_batch_id=make_import_batch(db, account).id,
        booked_date=date(2026, 1, 15),
        amount_minor=-1099,
        currency="EUR",
        description_raw="ABO NETFLIX",
        description_clean="Netflix",
        categorization_source="uncategorized",
        dedup_hash=str(uuid4()),
    )
    db.add(transaction)
    db.commit()
    return transaction


def test_a_second_series_for_the_same_account_and_merchant_key_is_rejected(
    db_session: Session,
) -> None:
    account = make_account(db_session)
    db_session.add(_series(account))
    db_session.commit()

    db_session.add(_series(account, label="Netflix again"))
    with pytest.raises(IntegrityError):
        db_session.commit()


def test_a_transaction_belongs_to_one_series_at_most(db_session: Session) -> None:
    account = make_account(db_session)
    transaction = _transaction(db_session, account)
    first = _series(account)
    second = _series(account, merchant_key="netflix premium")
    db_session.add_all([first, second])
    db_session.commit()

    db_session.add(RecurringOccurrence(series_id=first.id, transaction_id=transaction.id))
    db_session.commit()

    db_session.add(RecurringOccurrence(series_id=second.id, transaction_id=transaction.id))
    with pytest.raises(IntegrityError):
        db_session.commit()


def test_deleting_a_transaction_cascades_to_its_occurrence(db_session: Session) -> None:
    account = make_account(db_session)
    transaction = _transaction(db_session, account)
    series = _series(account)
    db_session.add(series)
    db_session.commit()
    db_session.add(RecurringOccurrence(series_id=series.id, transaction_id=transaction.id))
    db_session.commit()

    db_session.delete(transaction)
    db_session.commit()

    assert db_session.query(RecurringOccurrence).count() == 0
    # The series itself is detector state, not ledger state: it survives.
    assert db_session.query(RecurringSeries).count() == 1
