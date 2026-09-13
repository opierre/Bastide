"""Data access for tax profiles, plus the read the tax-year validator resolves its floor from.

The only place `tax_profiles` is queried.
"""

from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.features.tax.models import TaxParameter, TaxProfile


class TaxRepository:
    """Queries and writes for tax profiles, always scoped to a user."""

    def __init__(self, db: Session) -> None:
        self._db = db

    def list_profiles(self, user_id: str) -> list[TaxProfile]:
        """The user's profiles, newest declared year first (§5c)."""
        return list(
            self._db.scalars(
                select(TaxProfile)
                .where(TaxProfile.user_id == user_id)
                .order_by(TaxProfile.tax_year.desc())
            )
        )

    def get_profile(self, user_id: str, tax_year: int) -> TaxProfile | None:
        """One year's profile for this user, or `None` — never another user's row."""
        return self._db.scalar(
            select(TaxProfile).where(TaxProfile.user_id == user_id, TaxProfile.tax_year == tax_year)
        )

    def add_or_get_existing(self, profile: TaxProfile) -> TaxProfile:
        """Insert the row, or return the one a concurrent first read inserted first.

        Two simultaneous `GET /tax/profiles/2025` calls both find no row and both try to
        create one; the unique constraint on `(user_id, tax_year)` makes the loser fail
        rather than write a duplicate, and it simply adopts the winner's row — the same
        race `user_settings` settles (P2-01).
        """
        try:
            self._db.add(profile)
            self._db.commit()
        except IntegrityError:
            self._db.rollback()
            existing = self.get_profile(profile.user_id, profile.tax_year)
            if existing is None:
                raise  # Not the uniqueness race — a real constraint failure.
            return existing
        self._db.refresh(profile)
        return profile

    def save(self, profile: TaxProfile) -> TaxProfile:
        self._db.commit()
        self._db.refresh(profile)
        return profile

    def earliest_seeded_tax_year(self) -> int | None:
        """The oldest year the system parameter set covers, or `None` when nothing is seeded.

        System rows only (`user_id IS NULL`): a user's own override for some year is not
        evidence that the app can estimate that year, only that they edited a figure in it.
        """
        return self._db.scalar(
            select(func.min(TaxParameter.tax_year)).where(TaxParameter.user_id.is_(None))
        )
