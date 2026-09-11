"""Data access for `Category` rows. The only place that queries this table."""

from collections.abc import Sequence

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.features.categories.models import Category


class CategoryRepository:
    """Queries and writes for categories: system rows plus a user's own."""

    def __init__(self, db: Session) -> None:
        self._db = db

    def list_for_user(self, user_id: str) -> list[Category]:
        """System categories plus this user's own, system groups first."""
        return list(
            self._db.scalars(
                select(Category)
                .where((Category.user_id == user_id) | (Category.user_id.is_(None)))
                .order_by(Category.is_system.desc(), Category.name)
            )
        )

    def get_owned_by_id_for_user(self, category_id: str, user_id: str) -> Category | None:
        """Fetch a category the user owns (never a system row — those have `user_id=None`)."""
        return self._db.scalar(
            select(Category).where(Category.id == category_id, Category.user_id == user_id)
        )

    def get_visible_by_id_for_user(self, category_id: str, user_id: str) -> Category | None:
        """Fetch a category the user may *target*: their own, or a shared system row.

        Wider than `get_owned_by_id_for_user` on purpose: a system category is a perfectly
        good destination for a rule or a correction, it just can't be edited or deleted.
        """
        return self._db.scalar(
            select(Category).where(
                Category.id == category_id,
                (Category.user_id == user_id) | (Category.user_id.is_(None)),
            )
        )

    def list_system_by_names_for_user(self, names: Sequence[str], user_id: str) -> list[Category]:
        """Fetch the *system* categories whose i18n key is in ``names``, in one query.

        What a rule pack's `category_key` resolves against. Restricted to system rows because a
        pack references categories by the key `seed.py` stores in `name`, and only system rows
        carry one — a user-defined category's `name` is free text that happens to live in the
        same column. The user clause is then belt and braces: it makes it structurally impossible
        for a shared file to bind a row belonging to somebody else.
        """
        if not names:
            return []
        return list(
            self._db.scalars(
                select(Category).where(
                    Category.name.in_(names),
                    Category.is_system.is_(True),
                    (Category.user_id == user_id) | (Category.user_id.is_(None)),
                )
            )
        )

    def add(self, category: Category) -> Category:
        self._db.add(category)
        self._db.commit()
        self._db.refresh(category)
        return category

    def update(self, category: Category) -> Category:
        self._db.commit()
        self._db.refresh(category)
        return category

    def delete(self, category: Category) -> None:
        self._db.delete(category)
        self._db.commit()
