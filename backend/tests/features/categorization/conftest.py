"""Fixtures for the run tests: seeded ledgers, a stub runtime, and a hand-driven launcher.

Nothing here reaches an inference runtime, and nothing schedules a real background task. The
launcher is replaced by a spy that *collects* the executor coroutine so the test decides when —
and how far — it runs; a real `asyncio.create_task` would leave every assertion racing the
event loop.
"""

import asyncio
import json
import shutil
from collections.abc import Coroutine, Sequence
from dataclasses import dataclass, field
from datetime import UTC, date, datetime
from pathlib import Path
from typing import Any, cast
from uuid import uuid4

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import Engine, create_engine, select
from sqlalchemy.orm import Session, sessionmaker

from app.core.db import SessionFactory, configure_sqlite
from app.features.accounts.models import Account
from app.features.auth.models import User
from app.features.categories.models import Category
from app.features.categorization.runner import get_client_factory, get_run_launcher
from app.features.imports.models import ImportBatch
from app.features.inference.client import Message
from app.features.settings.models import UserSettings
from app.features.transactions.models import Transaction

GROCERIES_ID = "cat-groceries"
SALARY_ID = "cat-salary"


class StubRuntime:
    """An `InferenceClient` that replays queued replies, or raises a canned error.

    One entry is consumed per batch, so a test can make the first batch succeed and the second
    fail — which is how the `partial` status and the per-batch commit are exercised.
    """

    def __init__(self) -> None:
        self.replies: list[str | Exception] = []
        self.default: str | Exception = _reply([])
        self.calls: list[Sequence[Message]] = []
        #: Called just before each reply is handed back — the hook a test uses to cancel a
        #: run, or to simulate a crash, at a precise point mid-run.
        self.on_call: list[Any] = []

    def factory(self, settings: UserSettings) -> StubRuntime:
        """Match the `ClientFactory` shape; the settings pick nothing here."""
        return self

    async def list_models(self) -> list[str]:
        return ["stub-model"]

    async def complete(
        self,
        messages: Sequence[Message],
        *,
        model: str,
        response_format: dict[str, Any] | None = None,
        timeout: float | None = None,
    ) -> str:
        self.calls.append(list(messages))
        for hook in self.on_call:
            hook(len(self.calls))

        reply = self.replies.pop(0) if self.replies else self.default
        if isinstance(reply, Exception):
            raise reply
        return reply


def assign_all(count: int, category_id: str = GROCERIES_ID, confidence: float = 0.95) -> str:
    """A reply confidently assigning every row of a ``count``-row batch."""
    return _reply(
        [
            {"index": index, "category_id": category_id, "confidence": confidence}
            for index in range(count)
        ]
    )


def _reply(suggestions: list[dict[str, Any]]) -> str:
    return json.dumps({"suggestions": suggestions})


class RunLauncherSpy:
    """Collects executor coroutines instead of scheduling them."""

    def __init__(self) -> None:
        self.pending: list[Coroutine[Any, Any, None]] = []

    def __call__(self, coro: Coroutine[Any, Any, None]) -> None:
        self.pending.append(coro)

    def drain(self) -> int:
        """Run every collected coroutine to completion; return how many there were."""
        count = 0
        while self.pending:
            asyncio.run(self.pending.pop(0))
            count += 1
        return count

    def discard(self) -> None:
        """Close collected coroutines without running them (silences 'never awaited')."""
        while self.pending:
            self.pending.pop(0).close()


@dataclass
class Ledger:
    """A seeded user with one account and the transactions a test asked for."""

    user_id: str
    account_id: str
    batch_id: str
    transaction_ids: list[str] = field(default_factory=list)


def seed_ledger(
    session_factory: SessionFactory,
    rows: Sequence[tuple[str, str, bool]],
    *,
    user_id: str | None = None,
    ai_enabled: bool = True,
    model_tag: str | None = "stub-model",
) -> Ledger:
    """Create a user, settings, categories, an account, and ``rows`` transactions.

    Args:
        session_factory: where to write; the same temp database the code under test reads.
        rows: one `(description_clean, categorization_source, needs_review)` per transaction.
        user_id: reuse an existing user instead of creating one.
        ai_enabled: the settings flag the import enqueue path gates on.
        model_tag: `None` reproduces "no model configured", which defers every row.
    """
    db = session_factory()
    try:
        if user_id is None:
            user_id = str(uuid4())
            db.add(
                User(
                    id=user_id,
                    email=f"{user_id}@example.com",
                    password_hash="x",
                    display_name="Amelie",
                    locale="fr",
                    currency="EUR",
                )
            )
            db.flush()
        # Both are idempotent, so a ledger added to a user registered through the API — who
        # already exists but has neither — gets them here.
        _seed_settings(db, user_id, ai_enabled=ai_enabled, model_tag=model_tag)
        _seed_categories(db)

        account_id = str(uuid4())
        batch_id = str(uuid4())
        db.add(
            Account(
                id=account_id,
                user_id=user_id,
                name="Compte courant",
                type="checking",
                institution="BNP",
                currency="EUR",
                opening_balance_minor=0,
                cached_balance_minor=0,
            )
        )
        db.add(
            ImportBatch(
                id=batch_id,
                user_id=user_id,
                account_id=account_id,
                source_format="ofx",
                file_name="statement.ofx",
                file_hash=str(uuid4()),
                period_start=date(2026, 7, 1),
                period_end=date(2026, 7, 31),
                transaction_count=len(rows),
                new_count=len(rows),
                duplicate_count=0,
                status="success",
            )
        )

        transaction_ids: list[str] = []
        for index, (description, source, needs_review) in enumerate(rows):
            transaction_id = str(uuid4())
            transaction_ids.append(transaction_id)
            db.add(
                Transaction(
                    id=transaction_id,
                    account_id=account_id,
                    import_batch_id=batch_id,
                    booked_date=date(2026, 7, 1 + index % 28),
                    amount_minor=-4235,
                    currency="EUR",
                    description_raw=description,
                    description_clean=description,
                    merchant=None,
                    category_id=SALARY_ID if source in ("user", "rule") else None,
                    categorization_source=source,
                    needs_review=needs_review,
                    dedup_hash=str(uuid4()),
                )
            )
        db.commit()
        return Ledger(user_id, account_id, batch_id, transaction_ids)
    finally:
        db.close()


def _seed_settings(db: Session, user_id: str, *, ai_enabled: bool, model_tag: str | None) -> None:
    """Write the settings row the service would otherwise create lazily with defaults."""
    existing = db.scalar(select(UserSettings).where(UserSettings.user_id == user_id))
    if existing is not None:
        existing.ai_enabled = ai_enabled
        existing.model_tag = model_tag
        return
    db.add(
        UserSettings(
            id=str(uuid4()),
            user_id=user_id,
            ai_enabled=ai_enabled,
            inference_base_url="http://127.0.0.1:11434/v1",
            model_tag=model_tag,
            confidence_threshold=0.80,
            created_at=datetime.now(UTC),
            updated_at=datetime.now(UTC),
        )
    )


def seed_categories(session_factory: SessionFactory) -> None:
    """Add the stub leaf categories to a database built with `create_all`.

    The app's real catalog is seeded at startup, which a database driven directly never goes
    through — so
    a run against one of them would be offered no categories at all and could assign nothing.
    """
    db = session_factory()
    try:
        _seed_categories(db)
        db.commit()
    finally:
        db.close()


def _seed_categories(db: Session) -> None:
    """Two system leaf categories — enough for the parser to accept an assignment.

    System categories are shared across users (`user_id = None`), so a test seeding a second
    user must not insert them again.
    """
    if db.get(Category, GROCERIES_ID) is not None:
        return
    db.add(
        Category(
            id=GROCERIES_ID,
            name="Courses",
            kind="expense",
            icon="cart",
            color="#7C7CF0",
            is_system=True,
        )
    )
    db.add(
        Category(
            id=SALARY_ID,
            name="Salaire",
            kind="income",
            icon="wallet",
            color="#5CC8A8",
            is_system=True,
        )
    )


def read_transaction(session_factory: SessionFactory, transaction_id: str) -> Transaction:
    """Re-read one transaction on a fresh session, so no cached row can mask a missing write."""
    db = session_factory()
    try:
        row = db.get(Transaction, transaction_id)
        assert row is not None
        db.expunge_all()
        return row
    finally:
        db.close()


def _wal_engine(path: Path) -> Engine:
    """A temp-file engine in WAL mode, as `app.core.db` configures the real one.

    WAL matters here rather than being incidental: these tests write from a second connection
    (cancelling a run) while the executor holds one open, which is exactly the one-writer,
    many-readers case WAL exists for. Under the default journal mode it deadlocks.
    """
    return configure_sqlite(
        create_engine(f"sqlite:///{path}", connect_args={"check_same_thread": False})
    )


@pytest.fixture
def session_factory(tmp_path: Path, schema_template: Path) -> SessionFactory:
    """A session factory on a temp database, for tests that drive the executor directly."""
    db_path = tmp_path / "runner.db"
    shutil.copyfile(schema_template, db_path)
    return sessionmaker(bind=_wal_engine(db_path), autoflush=False, autocommit=False)


@pytest.fixture
def api_session_factory(tmp_path: Path) -> SessionFactory:
    """A session factory on the `client` fixture's own temp database."""
    return sessionmaker(bind=_wal_engine(tmp_path / "test.db"), autoflush=False, autocommit=False)


@pytest.fixture
def launcher(client: TestClient) -> RunLauncherSpy:
    """Replace the background launcher so tests run the executor when they choose to."""
    spy = RunLauncherSpy()
    cast(FastAPI, client.app).dependency_overrides[get_run_launcher] = lambda: spy
    return spy


@pytest.fixture
def runtime(client: TestClient) -> StubRuntime:
    """Replace the runtime client factory so no request ever leaves the process."""
    stub = StubRuntime()
    cast(FastAPI, client.app).dependency_overrides[get_client_factory] = lambda: stub.factory
    return stub
