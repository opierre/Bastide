"""Data access for `Property` rows, plus the one read that resolves the loans linked to one.

The only place the properties table is queried. `linked_mortgage_ids` reads the mortgages table
the way the dashboard reads the ledger: a read-only lookup over another feature's rows, never a
write.
"""

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.features.mortgages.models import Mortgage
from app.features.properties.models import Property


class PropertyRepository:
    """Queries and writes for declared properties, always scoped to a user."""

    def __init__(self, db: Session) -> None:
        self._db = db

    def list_for_user(self, user_id: str, archived: bool) -> list[Property]:
        """The user's properties in the requested archive state, oldest first."""
        return list(
            self._db.scalars(
                select(Property)
                .where(Property.user_id == user_id, Property.archived.is_(archived))
                .order_by(Property.created_at)
            )
        )

    def get_for_user(self, property_id: str, user_id: str) -> Property | None:
        """One property the user owns, or `None` — including another user's."""
        return self._db.scalar(
            select(Property).where(Property.id == property_id, Property.user_id == user_id)
        )

    def linked_mortgage_ids(self, property_id: str, user_id: str) -> list[str]:
        """Ids of the caller's loans pointing at this property, oldest first.

        No status filter: archiving a property keeps the link intact because the loan still
        exists (P3-01's `ON DELETE SET NULL` covers the hard delete this API never does).
        """
        return list(
            self._db.scalars(
                select(Mortgage.id)
                .where(Mortgage.property_id == property_id, Mortgage.user_id == user_id)
                .order_by(Mortgage.created_at)
            )
        )

    def add(self, prop: Property) -> Property:
        self._db.add(prop)
        self._db.commit()
        self._db.refresh(prop)
        return prop

    def save(self, prop: Property) -> Property:
        self._db.commit()
        self._db.refresh(prop)
        return prop
