"""What "everything one user owns" means, as table metadata rather than as ORM behaviour.

Two features need the same answer — a backup copies those rows out and replaces them,
a database reset deletes them (`docs/design/09-settings.md` §Zone de danger)
— so the table order, the ownership predicate and the column specs live here instead of in
either one. Working on the Core metadata rather than on each feature's ORM classes also means a
column added later is carried without this file changing.
"""

from dataclasses import dataclass
from datetime import date, datetime
from typing import Any

from sqlalchemy import ColumnElement, Table, select

from app.core.db import Base

# Imported for their side effect: registering every one of these tables on `Base.metadata`.
from app.features.accounts import models as _accounts_models  # noqa: F401
from app.features.categories import models as _categories_models  # noqa: F401
from app.features.categorization import models as _categorization_models  # noqa: F401
from app.features.goals import models as _goals_models  # noqa: F401
from app.features.imports import models as _imports_models  # noqa: F401
from app.features.mortgages import models as _mortgages_models  # noqa: F401
from app.features.properties import models as _properties_models  # noqa: F401
from app.features.recurring import models as _recurring_models  # noqa: F401
from app.features.rules import models as _rules_models  # noqa: F401
from app.features.settings import models as _settings_models  # noqa: F401
from app.features.transactions import models as _transactions_models  # noqa: F401

# Insert order: each table after every table its foreign keys point at. Deletion runs it
# backwards. `users` and `auth_tokens` are deliberately absent — they are the account itself,
# not its contents.
USER_DATA_TABLES: tuple[str, ...] = (
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
    "properties",
    "mortgages",
    "mortgage_simulations",
    "user_settings",
)

# Tables with no `user_id` of their own, scoped through the parent that has one.
_SCOPED_THROUGH: dict[str, tuple[str, str]] = {
    "account_balance_snapshots": ("account_id", "accounts"),
    "transactions": ("account_id", "accounts"),
    "recurring_occurrences": ("series_id", "recurring_series"),
    "goal_allocations": ("goal_id", "goals"),
}


@dataclass(frozen=True)
class ColumnSpec:
    """What a restore needs to know to decode and check one column."""

    name: str
    python_type: type
    nullable: bool
    references: str | None  # the table a foreign key points at, if any


def table(name: str) -> Table:
    return Base.metadata.tables[name]


def owned_by(name: str, user_id: str) -> ColumnElement[bool]:
    """The predicate selecting the rows of `name` that belong to `user_id`."""
    target = table(name)
    if name in _SCOPED_THROUGH:
        column, parent_name = _SCOPED_THROUGH[name]
        parent = table(parent_name)
        return target.c[column].in_(select(parent.c.id).where(parent.c.user_id == user_id))
    return target.c.user_id == user_id


def describe(name: str) -> list[ColumnSpec]:
    """The columns of one of these tables, in schema order."""
    specs = []
    for column in table(name).columns:
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


def encode(value: Any) -> Any:
    """JSON-ready form of one column value."""
    if isinstance(value, datetime | date):
        return value.isoformat()
    return value
