"""Data access for `Mortgage` rows. The only place the table is queried."""

from collections.abc import Sequence

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.features.mortgages.models import Mortgage
from app.features.properties.models import Property


class MortgageRepository:
    """Queries and writes for declared loans, always scoped to a user."""

    def __init__(self, db: Session) -> None:
        self._db = db

    def list_for_user(self, user_id: str, statuses: Sequence[str]) -> list[Mortgage]:
        """The user's loans in the given statuses, oldest first."""
        return list(
            self._db.scalars(
                select(Mortgage)
                .where(Mortgage.user_id == user_id, Mortgage.status.in_(statuses))
                .order_by(Mortgage.created_at)
            )
        )

    def get_for_user(self, mortgage_id: str, user_id: str) -> Mortgage | None:
        """One loan the user owns, or `None` — including another user's."""
        return self._db.scalar(
            select(Mortgage).where(Mortgage.id == mortgage_id, Mortgage.user_id == user_id)
        )

    def property_belongs_to(self, property_id: str, user_id: str) -> bool:
        """Whether the property exists and is the user's."""
        found = self._db.scalar(
            select(Property.id).where(Property.id == property_id, Property.user_id == user_id)
        )
        return found is not None

    def add(self, mortgage: Mortgage) -> Mortgage:
        self._db.add(mortgage)
        self._db.commit()
        self._db.refresh(mortgage)
        return mortgage

    def save(self, mortgage: Mortgage) -> Mortgage:
        self._db.commit()
        self._db.refresh(mortgage)
        return mortgage
