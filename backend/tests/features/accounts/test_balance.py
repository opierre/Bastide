"""Tests for the balance helpers: cache delta, point-in-time via snapshot, and full recompute."""

from datetime import date
from uuid import uuid4

from sqlalchemy.orm import Session

from app.features.accounts import balance
from app.features.accounts.models import Account, AccountBalanceSnapshot
from app.features.transactions.models import Transaction


def _make_account(db: Session, **overrides: object) -> Account:
    kwargs: dict[str, object] = {
        "user_id": str(uuid4()),
        "name": "Compte courant",
        "type": "checking",
        "institution": "BNP Paribas",
        "currency": "EUR",
        "opening_balance_minor": 0,
        "cached_balance_minor": 0,
        "archived": False,
    }
    kwargs.update(overrides)
    account = Account(**kwargs)
    db.add(account)
    db.commit()
    db.refresh(account)
    return account


def _make_transaction(account_id: str, booked_date: date, amount_minor: int) -> Transaction:
    return Transaction(
        account_id=account_id,
        import_batch_id=str(uuid4()),
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
    db_session.add(_make_transaction(account.id, date(2026, 2, 5), -100))
    db_session.add(_make_transaction(account.id, date(2026, 2, 10), 50))
    db_session.add(_make_transaction(account.id, date(2026, 3, 1), 1000))
    db_session.commit()

    result = balance.point_in_time_balance(db_session, account, date(2026, 2, 10))

    assert result == 450


def test_point_in_time_balance_without_snapshot_falls_back_to_opening_balance(
    db_session: Session,
) -> None:
    account = _make_account(db_session, opening_balance_minor=1000, cached_balance_minor=800)
    db_session.add(_make_transaction(account.id, date(2026, 1, 15), -200))
    db_session.add(_make_transaction(account.id, date(2026, 2, 15), -500))
    db_session.commit()

    result = balance.point_in_time_balance(db_session, account, date(2026, 1, 31))

    assert result == 800


def test_recompute_balance_matches_cache_on_fresh_account(db_session: Session) -> None:
    account = _make_account(db_session, opening_balance_minor=1000, cached_balance_minor=1000)

    result = balance.recompute_balance(db_session, account)

    assert result == account.cached_balance_minor == 1000


def test_recompute_balance_matches_cache_after_series_of_inserts(db_session: Session) -> None:
    account = _make_account(db_session, opening_balance_minor=0, cached_balance_minor=0)

    for booked_date, amount_minor in (
        (date(2026, 1, 5), 10_000),
        (date(2026, 1, 20), -3_000),
        (date(2026, 2, 3), 2_000),
    ):
        db_session.add(_make_transaction(account.id, booked_date, amount_minor))
        balance.apply_delta(account, amount_minor)
    db_session.commit()

    result = balance.recompute_balance(db_session, account)

    assert result == account.cached_balance_minor == 9_000
