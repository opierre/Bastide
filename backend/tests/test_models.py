"""Tests for the Phase 1 schema: the migration, and the dedup unique constraints."""

import os
import subprocess
import sys
from datetime import date
from pathlib import Path
from uuid import uuid4

import pytest
from sqlalchemy import create_engine, inspect
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.features.accounts.models import AccountBalanceSnapshot
from app.features.imports.models import ImportBatch
from app.features.transactions.models import Transaction

BACKEND_DIR = Path(__file__).resolve().parent.parent
EXPECTED_TABLES = {
    "users",
    "auth_tokens",
    "accounts",
    "categories",
    "csv_templates",
    "account_balance_snapshots",
    "categorization_rules",
    "import_batches",
    "transactions",
    "user_settings",
    "categorization_runs",
    "recurring_series",
    "recurring_occurrences",
    "goals",
    "goal_allocations",
    "alembic_version",
}


def test_alembic_upgrade_builds_full_schema_on_empty_db(tmp_path: Path) -> None:
    db_path = tmp_path / "migrated.db"
    env = os.environ.copy()
    env["FINSTRIDE_DB_PATH"] = str(db_path)

    subprocess.run(
        [sys.executable, "-m", "alembic", "upgrade", "head"],
        cwd=BACKEND_DIR,
        env=env,
        check=True,
        capture_output=True,
        text=True,
    )

    engine = create_engine(f"sqlite:///{db_path}")
    assert set(inspect(engine).get_table_names()) == EXPECTED_TABLES


def _transaction_kwargs(**overrides: object) -> dict[str, object]:
    kwargs: dict[str, object] = {
        "account_id": str(uuid4()),
        "import_batch_id": str(uuid4()),
        "booked_date": date(2026, 1, 1),
        "amount_minor": -1000,
        "currency": "EUR",
        "description_raw": "CARREFOUR CB",
        "description_clean": "Carrefour",
        "categorization_source": "uncategorized",
        "needs_review": True,
        "fitid": "OFX-1",
        "dedup_hash": "hash-1",
    }
    kwargs.update(overrides)
    return kwargs


def test_transaction_unique_constraint_rejects_duplicate_account_fitid(
    db_session: Session,
) -> None:
    kwargs = _transaction_kwargs()
    db_session.add(Transaction(**kwargs))
    db_session.commit()

    db_session.add(Transaction(**{**kwargs, "dedup_hash": "hash-2"}))
    with pytest.raises(IntegrityError):
        db_session.commit()


def test_transaction_allows_multiple_rows_without_fitid(db_session: Session) -> None:
    account_id = str(uuid4())
    db_session.add(
        Transaction(**_transaction_kwargs(account_id=account_id, fitid=None, dedup_hash="hash-a"))
    )
    db_session.add(
        Transaction(**_transaction_kwargs(account_id=account_id, fitid=None, dedup_hash="hash-b"))
    )
    db_session.commit()

    count = db_session.query(Transaction).filter_by(account_id=account_id).count()
    assert count == 2


def test_import_batch_unique_constraint_rejects_duplicate_file_hash_per_account(
    db_session: Session,
) -> None:
    kwargs = {
        "user_id": str(uuid4()),
        "account_id": str(uuid4()),
        "source_format": "ofx",
        "file_name": "jan.ofx",
        "file_hash": "abc123",
        "period_start": date(2026, 1, 1),
        "period_end": date(2026, 1, 31),
        "transaction_count": 10,
        "new_count": 10,
        "duplicate_count": 0,
        "status": "success",
    }
    db_session.add(ImportBatch(**kwargs))
    db_session.commit()

    db_session.add(ImportBatch(**{**kwargs, "file_name": "jan-again.ofx"}))
    with pytest.raises(IntegrityError):
        db_session.commit()


def test_account_balance_snapshot_unique_per_account_and_period_end(db_session: Session) -> None:
    kwargs = {
        "account_id": str(uuid4()),
        "period_end": date(2026, 1, 31),
        "balance_minor": 150_000,
    }
    db_session.add(AccountBalanceSnapshot(**kwargs))
    db_session.commit()

    db_session.add(AccountBalanceSnapshot(**{**kwargs, "balance_minor": 999}))
    with pytest.raises(IntegrityError):
        db_session.commit()
