"""Data access for `Mortgage` rows and the few figures the debt ratio reads around them.

The only place the mortgages table is queried. The ratio's inputs — the declared income and the
ledger's income totals — are read-only aggregates over other features' tables, the way the
dashboard reads the ledger.
"""

from collections.abc import Sequence
from datetime import date

from sqlalchemy import extract, func, select
from sqlalchemy.orm import Session

from app.features.accounts.models import Account
from app.features.categories.models import Category
from app.features.mortgages.models import Mortgage, MortgageSimulation
from app.features.properties.models import Property
from app.features.settings.models import UserSettings
from app.features.transactions.models import Transaction


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

    def declared_monthly_income_minor(self, user_id: str) -> int | None:
        """The user's declared monthly income; `None` when undeclared or no settings row yet."""
        return self._db.scalar(
            select(UserSettings.declared_monthly_income_minor).where(
                UserSettings.user_id == user_id
            )
        )

    def monthly_income_totals(self, user_id: str, start: date, end: date) -> list[int]:
        """Income-kind category totals per month over `[start, end)`, non-archived accounts.

        Only months holding at least one income-kind transaction appear. Grouped with
        `extract()` so the query stays portable to PostgreSQL (see the dashboard repository).
        """
        year = extract("year", Transaction.booked_date)
        month = extract("month", Transaction.booked_date)
        rows = self._db.execute(
            select(year, month, func.sum(Transaction.amount_minor))
            .select_from(Transaction)
            .join(Account, Account.id == Transaction.account_id)
            .join(Category, Category.id == Transaction.category_id)
            .where(
                Account.user_id == user_id,
                Account.archived.is_(False),
                Category.kind == "income",
                Transaction.booked_date >= start,
                Transaction.booked_date < end,
            )
            .group_by(year, month)
        ).all()
        return [int(total) for _, _, total in rows]


class SimulationRepository:
    """Queries and writes for saved simulator scenarios, always scoped to a user."""

    def __init__(self, db: Session) -> None:
        self._db = db

    def list_for_user(self, user_id: str) -> list[MortgageSimulation]:
        """The user's scenarios, oldest first. Bounded by the per-user cap, so unpaginated."""
        return list(
            self._db.scalars(
                select(MortgageSimulation)
                .where(MortgageSimulation.user_id == user_id)
                .order_by(MortgageSimulation.created_at)
            )
        )

    def count_for_user(self, user_id: str) -> int:
        return (
            self._db.scalar(
                select(func.count())
                .select_from(MortgageSimulation)
                .where(MortgageSimulation.user_id == user_id)
            )
            or 0
        )

    def get_for_user(self, simulation_id: str, user_id: str) -> MortgageSimulation | None:
        """One scenario the user owns, or `None` — including another user's."""
        return self._db.scalar(
            select(MortgageSimulation).where(
                MortgageSimulation.id == simulation_id, MortgageSimulation.user_id == user_id
            )
        )

    def add(self, simulation: MortgageSimulation) -> MortgageSimulation:
        self._db.add(simulation)
        self._db.commit()
        self._db.refresh(simulation)
        return simulation

    def save(self, simulation: MortgageSimulation) -> MortgageSimulation:
        self._db.commit()
        self._db.refresh(simulation)
        return simulation

    def delete(self, simulation: MortgageSimulation) -> None:
        """Remove the row for good: a scenario is a scratchpad, not history."""
        self._db.delete(simulation)
        self._db.commit()
