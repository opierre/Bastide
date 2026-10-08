"""Tests for the balance helpers: cache delta, point-in-time via snapshot, and full recompute."""

from datetime import date
from uuid import uuid4

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.features.accounts import balance
from app.features.accounts.models import Account, AccountBalanceSnapshot
from app.features.transactions.models import Transaction
from tests.factories import make_account, make_import_batch


def _make_account(db: Session, **overrides: object) -> Account:
    account = make_account(db, **overrides)
    db.commit()
    db.refresh(account)
    return account


def _make_transaction(
    db: Session, account: Account, booked_date: date, amount_minor: int
) -> Transaction:
    return Transaction(
        account_id=account.id,
        import_batch_id=make_import_batch(db, account).id,
        booked_date=booked_date,
        amount_minor=amount_minor,
        currency="EUR",
        description_raw="raw",
        description_clean="clean",
        categorization_source="uncategorized",
        needs_review=True,
        dedup_hash=str(uuid4()),
    )


def test_apply_delta_updates_cached_balance(db_session: Session) -> None:
    account = _make_account(db_session, cached_balance_minor=1000)

    balance.apply_delta(account, -300)
    assert account.cached_balance_minor == 700

    balance.apply_delta(account, 500)
    assert account.cached_balance_minor == 1200


def test_point_in_time_balance_uses_nearest_snapshot_plus_rows_since(db_session: Session) -> None:
    account = _make_account(db_session, opening_balance_minor=0, cached_balance_minor=450)
    db_session.add(
        AccountBalanceSnapshot(
            account_id=account.id, period_end=date(2026, 1, 31), balance_minor=500
        )
    )
    db_session.add(_make_transaction(db_session, account, date(2026, 2, 5), -100))
    db_session.add(_make_transaction(db_session, account, date(2026, 2, 10), 50))
    db_session.add(_make_transaction(db_session, account, date(2026, 3, 1), 1000))
    db_session.commit()

    result = balance.point_in_time_balance(db_session, account, date(2026, 2, 10))

    assert result == 450


def test_point_in_time_balance_without_snapshot_falls_back_to_opening_balance(
    db_session: Session,
) -> None:
    account = _make_account(db_session, opening_balance_minor=1000, cached_balance_minor=800)
    db_session.add(_make_transaction(db_session, account, date(2026, 1, 15), -200))
    db_session.add(_make_transaction(db_session, account, date(2026, 2, 15), -500))
    db_session.commit()

    result = balance.point_in_time_balance(db_session, account, date(2026, 1, 31))

    assert result == 800


def test_shift_opening_balance_moves_the_cache_by_the_same_delta(db_session: Session) -> None:
    account = _make_account(db_session, opening_balance_minor=1000, cached_balance_minor=1800)

    balance.shift_opening_balance(db_session, account, 1500)

    assert account.opening_balance_minor == 1500
    assert account.cached_balance_minor == 2300


def test_shift_opening_balance_is_a_no_op_when_unchanged(db_session: Session) -> None:
    account = _make_account(db_session, opening_balance_minor=1000, cached_balance_minor=1800)

    balance.shift_opening_balance(db_session, account, 1000)

    assert account.opening_balance_minor == 1000
    assert account.cached_balance_minor == 1800


def test_shift_opening_balance_moves_existing_snapshots_by_the_same_delta(
    db_session: Session,
) -> None:
    """A snapshot is a cached balance too — leaving it behind would make point-in-time
    balances before the correction disagree with the ones after it, for no real change
    on the ledger.
    """
    account = _make_account(db_session, opening_balance_minor=1000, cached_balance_minor=1800)
    db_session.add(
        AccountBalanceSnapshot(
            account_id=account.id, period_end=date(2026, 1, 31), balance_minor=1500
        )
    )
    db_session.commit()

    balance.shift_opening_balance(db_session, account, 1500)
    db_session.commit()

    snapshot = db_session.scalar(
        select(AccountBalanceSnapshot).where(AccountBalanceSnapshot.account_id == account.id)
    )
    assert snapshot is not None
    assert snapshot.balance_minor == 2000
