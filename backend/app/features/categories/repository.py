"""Data access for `Category` rows. The only place that queries this table."""

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
