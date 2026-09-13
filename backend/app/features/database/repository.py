"""Data access for the database reset: count a user's rows, then delete them.

Scoped by `app.core.user_data`, so the reset covers exactly the rows a backup would have
archived — minus `user_settings`, which is the profile's preferences rather than its contents.
"""

from sqlalchemy import delete, func, select
from sqlalchemy.orm import Session

from app.core.user_data import USER_DATA_TABLES, owned_by, table

#: Deleted by a reset, in insert order; deletion runs it backwards. `user_settings` is absent:
#: the locale, the AI configuration and the last-backup stamp survive a reset by design
#: (`docs/design/09-settings.md` §Zone de danger).
RESET_TABLES: tuple[str, ...] = tuple(name for name in USER_DATA_TABLES if name != "user_settings")

#: The counts the confirmation modal lists, and the tables each one sums.
COUNTED_TABLES: dict[str, tuple[str, ...]] = {
    "accounts": ("accounts",),
    "transactions": ("transactions",),
    "categories": ("categories",),
    "rules": ("categorization_rules",),
    "recurring": ("recurring_series",),
    "goals": ("goals",),
    "mortgages": ("mortgages",),
    "properties": ("properties",),
    "simulations": ("mortgage_simulations",),
}


class DatabaseRepository:
    """Counts and deletes one user's rows. Never touches another user's data."""

    def __init__(self, db: Session) -> None:
        self._db = db

    def count_rows(self, user_id: str) -> dict[str, int]:
        """How many rows of each counted table the user owns, keyed as the schema names them."""
        return {
            key: sum(
                self._db.scalar(
                    select(func.count()).select_from(table(name)).where(owned_by(name, user_id))
                )
                or 0
                for name in names
            )
            for key, names in COUNTED_TABLES.items()
        }

    def has_active_run(self, user_id: str) -> bool:
        runs = table("categorization_runs")
        count = self._db.scalar(
            select(func.count())
            .select_from(runs)
            .where(runs.c.user_id == user_id, runs.c.status.in_(("pending", "running")))
        )
        return bool(count)

    def delete_user_data(self, user_id: str) -> None:
        """Delete every resettable row the user owns, children first. Not committed."""
        for name in reversed(RESET_TABLES):
            target = table(name)
            if name == "categories":
                # Subcategories before their parents, for databases that enforce the FK.
                self._db.execute(
                    delete(target).where(owned_by(name, user_id), target.c.parent_id.is_not(None))
                )
            self._db.execute(delete(target).where(owned_by(name, user_id)))

    def commit(self) -> None:
        self._db.commit()

    def rollback(self) -> None:
        self._db.rollback()
