"""Data access for tax profiles, the parameter set, and the rows an estimate is assembled from.

The only place `tax_profiles` is queried. Everything else here is a read over another feature's
rows — the ledger for the prefill, `properties` and `mortgages` for the estimate — because both
of those are reads and write nothing (§5c). The estimate takes its property income and its IFI
base from `properties` rather than from a column of its own, so the Impôts and Synthèse panels
cannot disagree about the same rent or the same valuation (§4c).
"""

from collections.abc import Sequence
from datetime import date

from sqlalchemy import delete, extract, func, or_, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.features.accounts.models import Account
from app.features.categories.models import Category
from app.features.mortgages.models import Mortgage
from app.features.properties.models import Property
from app.features.tax.models import TaxBracket, TaxParameter, TaxProfile
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

    def list_parameters(self, user_id: str, tax_year: int) -> list[TaxParameter]:
        """The year's scalar parameters: the seeded rows and this user's, for `resolve` to sort.

        Both are returned rather than resolved in SQL, because resolution is one function shared
        with the parameters panel (§5c) — the numbers a user reads must be the numbers the
        estimate ran on, and two implementations cannot promise that.
        """
        return list(
            self._db.scalars(
                select(TaxParameter).where(
                    TaxParameter.tax_year == tax_year,
                    or_(TaxParameter.user_id == user_id, TaxParameter.user_id.is_(None)),
                )
            )
        )

    def list_brackets(self, user_id: str, tax_year: int) -> list[TaxBracket]:
        """The year's barème bands, seeded and user-owned. Resolved per kind by `resolve`."""
        return list(
            self._db.scalars(
                select(TaxBracket).where(
                    TaxBracket.tax_year == tax_year,
                    or_(TaxBracket.user_id == user_id, TaxBracket.user_id.is_(None)),
                )
            )
        )

    def system_parameter_units(self, tax_year: int) -> dict[str, str]:
        """The year's seeded keys and their units — the set of keys an override may name."""
        rows = self._db.execute(
            select(TaxParameter.key, TaxParameter.unit).where(
                TaxParameter.tax_year == tax_year, TaxParameter.user_id.is_(None)
            )
        ).all()
        return {key: unit for key, unit in rows}

    def set_user_parameter(
        self, user_id: str, tax_year: int, key: str, int_value: int, unit: str
    ) -> None:
        """Write the user's own row for one key, updating it if they already hold one.

        Only ever selects or creates a row carrying `user_id`, so a system row cannot be reached
        from here. Not committed.
        """
        row = self._db.scalar(
            select(TaxParameter).where(
                TaxParameter.user_id == user_id,
                TaxParameter.tax_year == tax_year,
                TaxParameter.key == key,
            )
        )
        if row is None:
            self._db.add(
                TaxParameter(
                    user_id=user_id, tax_year=tax_year, key=key, int_value=int_value, unit=unit
                )
            )
        else:
            row.int_value = int_value
            row.unit = unit

    def replace_user_brackets(
        self, user_id: str, tax_year: int, kind: str, bands: Sequence[tuple[int, int]]
    ) -> None:
        """Replace the user's whole set for one kind with `(lower_bound_minor, rate_bps)` bands.

        Deleted and flushed before the insert, so the new ordinals never meet the old ones on
        the unique constraint. Not committed.
        """
        self._db.execute(
            delete(TaxBracket).where(
                TaxBracket.user_id == user_id,
                TaxBracket.tax_year == tax_year,
                TaxBracket.kind == kind,
            )
        )
        self._db.flush()
        self._db.add_all(
            TaxBracket(
                user_id=user_id,
                tax_year=tax_year,
                kind=kind,
                ordinal=ordinal,
                lower_bound_minor=lower_bound_minor,
                rate_bps=rate_bps,
            )
            for ordinal, (lower_bound_minor, rate_bps) in enumerate(bands)
        )

    def delete_user_overrides(
        self, user_id: str, tax_year: int, key: str | None, kind: str | None
    ) -> None:
        """Drop the user's overrides for a year: all of them, or only the named key and/or kind.

        Every statement is filtered on `user_id`, so the seeded rows are never touched.
        Not committed.
        """
        everything = key is None and kind is None
        if everything or key is not None:
            parameters = delete(TaxParameter).where(
                TaxParameter.user_id == user_id, TaxParameter.tax_year == tax_year
            )
            if key is not None:
                parameters = parameters.where(TaxParameter.key == key)
            self._db.execute(parameters)
        if everything or kind is not None:
            brackets = delete(TaxBracket).where(
                TaxBracket.user_id == user_id, TaxBracket.tax_year == tax_year
            )
            if kind is not None:
                brackets = brackets.where(TaxBracket.kind == kind)
            self._db.execute(brackets)

    def commit(self) -> None:
        self._db.commit()

    def list_active_properties(self, user_id: str) -> list[Property]:
        """The user's non-archived properties, oldest first — §16's property income and IFI base.

        Archived ones leave every aggregate, exactly as they leave `/properties` and §18's assets.
        """
        return list(
            self._db.scalars(
                select(Property)
                .where(Property.user_id == user_id, Property.archived.is_(False))
                .order_by(Property.created_at)
            )
        )

    def list_active_property_loans(self, user_id: str) -> list[Mortgage]:
        """The user's active loans that are secured on a property, oldest first.

        Only these net off the IFI base (§16). An unlinked loan finances nothing the base counts,
        and an archived or repaid one is not a debt the base should shrink for.
        """
        return list(
            self._db.scalars(
                select(Mortgage)
                .where(
                    Mortgage.user_id == user_id,
                    Mortgage.status == "active",
                    Mortgage.property_id.is_not(None),
                )
                .order_by(Mortgage.created_at)
            )
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
