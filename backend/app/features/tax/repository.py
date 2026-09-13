"""Data access for tax profiles, plus the two reads the prefill and the year validator need.

The only place `tax_profiles` is queried. `monthly_totals_by_category_key` reads the ledger the
way the dashboard and the debt ratio read it — a grouped, read-only lookup over another
feature's rows — because the prefill is a read and writes nothing (§5c).
"""

from datetime import date

from sqlalchemy import extract, func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.features.accounts.models import Account
from app.features.categories.models import Category
from app.features.tax.models import TaxParameter, TaxProfile
from app.features.transactions.models import Transaction


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

    def monthly_totals_by_category_key(
        self, user_id: str, category_keys: tuple[str, ...], start: date, end: date
    ) -> dict[str, list[int]]:
        """Per-month totals over `[start, end)` for each named system category.

        Keyed by the category's i18n key (`categories.name` holds it for system rows — see
        `app/core/seed.py`), and holding one entry per month that carries at least one
        transaction, so the caller can count coverage and judge stability from the same list.
        A key with no rows at all is simply absent.

        Archived accounts are excluded, as they are from the debt ratio and the dashboard:
        a closed account's history is kept, but it is not this year's income.

        Grouped with `extract()` so the query stays portable to PostgreSQL.
        """
        if not category_keys:
            return {}
        year = extract("year", Transaction.booked_date)
        month = extract("month", Transaction.booked_date)
        rows = self._db.execute(
            select(Category.name, year, month, func.sum(Transaction.amount_minor))
            .select_from(Transaction)
            .join(Account, Account.id == Transaction.account_id)
            .join(Category, Category.id == Transaction.category_id)
            .where(
                Account.user_id == user_id,
                Account.archived.is_(False),
                Category.is_system.is_(True),
                Category.name.in_(category_keys),
                Transaction.booked_date >= start,
                Transaction.booked_date < end,
            )
            .group_by(Category.name, year, month)
        ).all()
        totals: dict[str, list[int]] = {}
        for key, _, _, total in rows:
            totals.setdefault(str(key), []).append(int(total))
        return totals
