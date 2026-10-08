"""Tests for the goals, recurring and run tables: migration, unique constraints, cascades."""

import shutil
from datetime import date
from pathlib import Path
from uuid import uuid4

import pytest
from sqlalchemy import create_engine, inspect
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.features.accounts.models import Account
from app.features.auth.models import User
from app.features.categorization.models import CategorizationRun
from app.features.goals.models import Goal, GoalAllocation
from app.features.imports.models import ImportBatch
from app.features.recurring.models import RecurringOccurrence, RecurringSeries
from app.features.transactions.models import Transaction
from tests.migrations import downgrade, upgrade

# The revision *below* the migration adding these tables. Named rather than reached with
# `downgrade -1`, which only meant "undo it" while that migration happened to be
# head — every migration added since silently retargeted the test.
PRE_MIGRATION_REVISION = "e4a1c6f20b73"

MIGRATION_TABLES = {
    "categorization_runs",
    "recurring_series",
    "recurring_occurrences",
    "goals",
    "goal_allocations",
}


def test_alembic_upgrade_builds_its_tables_on_empty_db(migrated_template: Path) -> None:
    engine = create_engine(f"sqlite:///{migrated_template}")
    assert MIGRATION_TABLES.issubset(inspect(engine).get_table_names())
    engine.dispose()


def test_downgrade_then_upgrade_is_clean(tmp_path: Path, migrated_template: Path) -> None:
    db_path = tmp_path / "roundtrip.db"
    shutil.copyfile(migrated_template, db_path)

    downgrade(db_path, PRE_MIGRATION_REVISION)
    engine = create_engine(f"sqlite:///{db_path}")
    assert not (MIGRATION_TABLES & set(inspect(engine).get_table_names()))
    engine.dispose()

    upgrade(db_path)
    engine = create_engine(f"sqlite:///{db_path}")
    assert MIGRATION_TABLES.issubset(inspect(engine).get_table_names())
    engine.dispose()


def _seed_user(db: Session) -> User:
    user = User(
        email=f"{uuid4()}@example.test",
        password_hash="hash",
        display_name=f"camille-{uuid4().hex[:8]}",
        locale="fr",
        currency="EUR",
    )
    db.add(user)
    db.commit()
    return user


def _seed_account(db: Session, user: User) -> Account:
    account = Account(
        user_id=user.id,
        name="Compte courant",
        type="checking",
        institution="Banque",
        currency="EUR",
        opening_balance_minor=0,
        cached_balance_minor=0,
    )
    db.add(account)
    db.commit()
    return account


def _seed_transaction(db: Session, user: User, account: Account) -> Transaction:
    batch = ImportBatch(
        user_id=user.id,
        account_id=account.id,
        source_format="ofx",
        file_name=f"{uuid4()}.ofx",
        file_hash=str(uuid4()),
        period_start=date(2026, 1, 1),
        period_end=date(2026, 1, 31),
        transaction_count=1,
        new_count=1,
        duplicate_count=0,
        status="success",
    )
    db.add(batch)
    db.commit()

    transaction = Transaction(
        account_id=account.id,
        import_batch_id=batch.id,
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


def _series_kwargs(user: User, account: Account, **overrides: object) -> dict[str, object]:
    kwargs: dict[str, object] = {
        "user_id": user.id,
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
    return kwargs


def test_recurring_series_unique_constraint_rejects_duplicate_account_merchant_key(
    migrated_session: Session,
) -> None:
    user = _seed_user(migrated_session)
    account = _seed_account(migrated_session, user)

    migrated_session.add(RecurringSeries(**_series_kwargs(user, account)))
    migrated_session.commit()

    migrated_session.add(RecurringSeries(**_series_kwargs(user, account, label="Netflix again")))
    with pytest.raises(IntegrityError):
        migrated_session.commit()


def test_recurring_occurrence_unique_constraint_rejects_second_series_for_a_transaction(
    migrated_session: Session,
) -> None:
    user = _seed_user(migrated_session)
    account = _seed_account(migrated_session, user)
    transaction = _seed_transaction(migrated_session, user, account)

    first = RecurringSeries(**_series_kwargs(user, account))
    second = RecurringSeries(**_series_kwargs(user, account, merchant_key="netflix premium"))
    migrated_session.add_all([first, second])
    migrated_session.commit()

    migrated_session.add(RecurringOccurrence(series_id=first.id, transaction_id=transaction.id))
    migrated_session.commit()

    migrated_session.add(RecurringOccurrence(series_id=second.id, transaction_id=transaction.id))
    with pytest.raises(IntegrityError):
        migrated_session.commit()


def test_deleting_a_transaction_cascades_to_its_occurrence(migrated_session: Session) -> None:
    user = _seed_user(migrated_session)
    account = _seed_account(migrated_session, user)
    transaction = _seed_transaction(migrated_session, user, account)

    series = RecurringSeries(**_series_kwargs(user, account))
    migrated_session.add(series)
    migrated_session.commit()
    migrated_session.add(RecurringOccurrence(series_id=series.id, transaction_id=transaction.id))
    migrated_session.commit()

    migrated_session.delete(transaction)
    migrated_session.commit()

    assert migrated_session.query(RecurringOccurrence).count() == 0
    # The series itself is detector state, not ledger state: it survives.
    assert migrated_session.query(RecurringSeries).count() == 1


def test_deleting_a_goal_cascades_to_its_allocations(migrated_session: Session) -> None:
    user = _seed_user(migrated_session)
    goal = Goal(
        user_id=user.id,
        name="Vacances",
        target_minor=200_000,
        currency="EUR",
        icon="beach",
        color="iris",
        status="active",
    )
    migrated_session.add(goal)
    migrated_session.commit()

    migrated_session.add_all(
        [
            GoalAllocation(goal_id=goal.id, amount_minor=50_000, allocated_on=date(2026, 1, 31)),
            # Signed: taking money back out of the envelope is a negative allocation.
            GoalAllocation(goal_id=goal.id, amount_minor=-10_000, allocated_on=date(2026, 2, 28)),
        ]
    )
    migrated_session.commit()
    assert migrated_session.query(GoalAllocation).count() == 2

    migrated_session.delete(goal)
    migrated_session.commit()

    assert migrated_session.query(GoalAllocation).count() == 0


def test_categorization_run_accepts_a_run_covering_every_account(
    migrated_session: Session,
) -> None:
    user = _seed_user(migrated_session)

    run = CategorizationRun(
        user_id=user.id,
        account_id=None,
        import_batch_id=None,
        trigger="manual",
        status="pending",
        total_count=42,
        processed_count=0,
        assigned_count=0,
        deferred_count=0,
        failed_count=0,
    )
    migrated_session.add(run)
    migrated_session.commit()

    stored = migrated_session.query(CategorizationRun).one()
    assert stored.account_id is None
    assert stored.status == "pending"
