"""Data access for full backups: every row a user owns, read out and replaced wholesale.

Works on the tables' Core metadata rather than on each feature's ORM classes: a backup copies
rows column for column, so it needs the schema, not the behaviour — and reading the columns
from the metadata means a column added later is carried without this file changing.
"""

from collections.abc import Iterator, Sequence
from dataclasses import dataclass
from datetime import date, datetime
from typing import Any

from sqlalchemy import ColumnElement, Table, delete, func, insert, select
from sqlalchemy.orm import Session

from app.core.db import Base

# Imported for their side effect: registering every archived table on `Base.metadata`.
from app.features.accounts import models as _accounts_models  # noqa: F401
from app.features.categories import models as _categories_models  # noqa: F401
from app.features.categorization import models as _categorization_models  # noqa: F401
from app.features.goals import models as _goals_models  # noqa: F401
from app.features.imports import models as _imports_models  # noqa: F401
from app.features.recurring import models as _recurring_models  # noqa: F401
from app.features.rules import models as _rules_models  # noqa: F401
from app.features.settings import models as _settings_models  # noqa: F401
from app.features.transactions import models as _transactions_models  # noqa: F401

# Insert order: each table after every table its foreign keys point at. Deletion runs it
# backwards. `users` and `auth_tokens` are deliberately absent — a restore lands in the account
# that is signed in, and credentials never travel in a file.
BACKUP_TABLES: tuple[str, ...] = (
    "categories",
    "accounts",
    "account_balance_snapshots",
    "import_batches",
    "transactions",
    "categorization_rules",
    "recurring_series",
    "recurring_occurrences",
    "goals",
    "goal_allocations",
    "categorization_runs",
    "user_settings",
)

# Tables with no `user_id` of their own, scoped through the parent that has one.
_SCOPED_THROUGH: dict[str, tuple[str, str]] = {
    "account_balance_snapshots": ("account_id", "accounts"),
    "transactions": ("account_id", "accounts"),
    "recurring_occurrences": ("series_id", "recurring_series"),
    "goal_allocations": ("goal_id", "goals"),
}

_INSERT_CHUNK = 500


@dataclass(frozen=True)
class ColumnSpec:
    """What a restore needs to know to decode and check one column."""

    name: str
    python_type: type
    nullable: bool
    references: str | None  # the table a foreign key points at, if any


def _table(name: str) -> Table:
    return Base.metadata.tables[name]


def _owned_by(name: str, user_id: str) -> ColumnElement[bool]:
    table = _table(name)
    if name in _SCOPED_THROUGH:
        column, parent_name = _SCOPED_THROUGH[name]
        parent = _table(parent_name)
        return table.c[column].in_(select(parent.c.id).where(parent.c.user_id == user_id))
    return table.c.user_id == user_id


def describe(name: str) -> list[ColumnSpec]:
    """The columns of an archived table, in schema order."""
    specs = []
    for column in _table(name).columns:
        foreign = next(iter(column.foreign_keys), None)
        specs.append(
            ColumnSpec(
                name=column.name,
                python_type=column.type.python_type,
                nullable=bool(column.nullable),
                references=foreign.column.table.name if foreign is not None else None,
            )
        )
    return specs


def _encode(value: Any) -> Any:
    if isinstance(value, datetime | date):
        return value.isoformat()
    return value


class BackupRepository:
    """Reads and replaces a user's rows. Never touches another user's data."""

    def __init__(self, db: Session) -> None:
        self._db = db

    def iter_rows(self, name: str, user_id: str) -> Iterator[dict[str, Any]]:
        """The user's rows of one table, JSON-ready, parents before children in `categories`."""
        table = _table(name)
        query = select(table).where(_owned_by(name, user_id))
        if name == "categories":
            # A subcategory must follow its parent so a restore can check the reference.
            query = query.order_by(table.c.parent_id.is_not(None))
        for row in self._db.execute(query).mappings():
            yield {key: _encode(value) for key, value in row.items()}

    def system_category_ids(self) -> set[str]:
        table = _table("categories")
        return set(self._db.scalars(select(table.c.id).where(table.c.user_id.is_(None))))

    def has_active_run(self, user_id: str) -> bool:
        table = _table("categorization_runs")
        count = self._db.scalar(
            select(func.count())
            .select_from(table)
            .where(table.c.user_id == user_id, table.c.status.in_(("pending", "running")))
        )
        return bool(count)

    def delete_user_data(self, user_id: str) -> None:
        """Delete every archived row the user owns, children first. Not committed."""
        for name in reversed(BACKUP_TABLES):
            table = _table(name)
            if name == "categories":
                # Subcategories before their parents, for databases that enforce the FK.
                self._db.execute(
                    delete(table).where(_owned_by(name, user_id), table.c.parent_id.is_not(None))
                )
            self._db.execute(delete(table).where(_owned_by(name, user_id)))

    def insert_rows(self, name: str, rows: Sequence[dict[str, Any]]) -> None:
        """Insert decoded rows in chunks. Not committed."""
        for start in range(0, len(rows), _INSERT_CHUNK):
            self._db.execute(insert(_table(name)), list(rows[start : start + _INSERT_CHUNK]))

    def commit(self) -> None:
        self._db.commit()

    def rollback(self) -> None:
        self._db.rollback()
