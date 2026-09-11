"""Data access for full backups: every row a user owns, read out and replaced wholesale.

The table order, the ownership predicate and the column specs come from `app.core.user_data`,
which is also what the database reset deletes — one definition of "everything this user owns"
for both features.
"""

from collections.abc import Iterator, Sequence
from typing import Any

from sqlalchemy import delete, func, insert, select
from sqlalchemy.orm import Session

from app.core.user_data import (
    USER_DATA_TABLES,
    ColumnSpec,
    describe,
    encode,
    owned_by,
    table,
)

__all__ = ["BACKUP_TABLES", "BackupRepository", "ColumnSpec", "describe"]

#: The archived tables, in insert order. A restore writes them forwards, deletes backwards.
BACKUP_TABLES: tuple[str, ...] = USER_DATA_TABLES

_INSERT_CHUNK = 500


class BackupRepository:
    """Reads and replaces a user's rows. Never touches another user's data."""

    def __init__(self, db: Session) -> None:
        self._db = db

    def iter_rows(self, name: str, user_id: str) -> Iterator[dict[str, Any]]:
        """The user's rows of one table, JSON-ready, parents before children in `categories`."""
        target = table(name)
        query = select(target).where(owned_by(name, user_id))
        if name == "categories":
            # A subcategory must follow its parent so a restore can check the reference.
            query = query.order_by(target.c.parent_id.is_not(None))
        for row in self._db.execute(query).mappings():
            yield {key: encode(value) for key, value in row.items()}

    def system_category_ids(self) -> set[str]:
        categories = table("categories")
        return set(self._db.scalars(select(categories.c.id).where(categories.c.user_id.is_(None))))

    def has_active_run(self, user_id: str) -> bool:
        runs = table("categorization_runs")
        count = self._db.scalar(
            select(func.count())
            .select_from(runs)
            .where(runs.c.user_id == user_id, runs.c.status.in_(("pending", "running")))
        )
        return bool(count)

    def delete_user_data(self, user_id: str) -> None:
        """Delete every archived row the user owns, children first. Not committed."""
        for name in reversed(BACKUP_TABLES):
            target = table(name)
            if name == "categories":
                # Subcategories before their parents, for databases that enforce the FK.
                self._db.execute(
                    delete(target).where(owned_by(name, user_id), target.c.parent_id.is_not(None))
                )
            self._db.execute(delete(target).where(owned_by(name, user_id)))

    def insert_rows(self, name: str, rows: Sequence[dict[str, Any]]) -> None:
        """Insert decoded rows in chunks. Not committed."""
        for start in range(0, len(rows), _INSERT_CHUNK):
            self._db.execute(insert(table(name)), list(rows[start : start + _INSERT_CHUNK]))

    def commit(self) -> None:
        self._db.commit()

    def rollback(self) -> None:
        self._db.rollback()
