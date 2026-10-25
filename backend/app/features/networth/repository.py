"""Data access for the net-worth summary and the declared month-end totals.

Every other query here reads another feature's rows — accounts, snapshots, the ledger,
properties, loans — the way the dashboard reads the ledger: aggregates over them, never a write.
One query per table for the whole summary, so the cost does not grow with the number of accounts
or loans. The declared totals are this feature's own table, and the only one it writes.
"""

from collections.abc import Sequence
from datetime import date

from sqlalchemy import extract, func, select
from sqlalchemy.orm import Session

from app.core.months import MONTHS_PER_YEAR
from app.features.accounts.models import Account, AccountBalanceSnapshot
from app.features.mortgages.models import Mortgage
from app.features.networth.models import DeclaredBalance
from app.features.properties.models import Property
from app.features.transactions.models import Transaction


class NetWorthRepository:
    """The rows net worth is derived from, always scoped to a user."""

    def __init__(self, db: Session) -> None:
        self._db = db

    def accounts(self, user_id: str) -> list[Account]:
        """The user's non-archived accounts, oldest first."""
        return list(
            self._db.scalars(
                select(Account)
                .where(Account.user_id == user_id, Account.archived.is_(False))
                .order_by(Account.created_at)
            )
        )

    def properties(self, user_id: str) -> list[Property]:
        """The user's non-archived properties, oldest first."""
        return list(
            self._db.scalars(
                select(Property)
                .where(Property.user_id == user_id, Property.archived.is_(False))
                .order_by(Property.created_at)
            )
        )

    def mortgages(self, user_id: str, statuses: Sequence[str]) -> list[Mortgage]:
        """The user's loans in the given statuses, oldest first."""
        return list(
            self._db.scalars(
                select(Mortgage)
                .where(Mortgage.user_id == user_id, Mortgage.status.in_(statuses))
                .order_by(Mortgage.created_at)
            )
        )

    def snapshots(
        self, user_id: str, account_ids: Sequence[str], before: date
    ) -> list[tuple[str, date, int]]:
        """`(account_id, period_end, balance_minor)` for every snapshot dated before `before`."""
        if not account_ids:
            return []
        rows = self._db.execute(
            select(
                AccountBalanceSnapshot.account_id,
                AccountBalanceSnapshot.period_end,
                AccountBalanceSnapshot.balance_minor,
            )
            .join(Account, Account.id == AccountBalanceSnapshot.account_id)
            .where(
                Account.user_id == user_id,
                AccountBalanceSnapshot.account_id.in_(account_ids),
                AccountBalanceSnapshot.period_end < before,
            )
        ).all()
        return [(account_id, period_end, balance) for account_id, period_end, balance in rows]

    def monthly_row_sums(
        self, user_id: str, account_ids: Sequence[str], before: date
    ) -> dict[str, dict[int, int]]:
        """Ledger totals per account, then per month index, for rows booked before `before`.

        A month index is `year * 12 + month - 1`. Grouped with `extract()` so the query stays
        portable to PostgreSQL (see the dashboard repository).
        """
        if not account_ids:
            return {}
        year = extract("year", Transaction.booked_date)
        month = extract("month", Transaction.booked_date)
        rows = self._db.execute(
            select(Transaction.account_id, year, month, func.sum(Transaction.amount_minor))
            .join(Account, Account.id == Transaction.account_id)
            .where(
                Account.user_id == user_id,
                Transaction.account_id.in_(account_ids),
                Transaction.booked_date < before,
            )
            .group_by(Transaction.account_id, year, month)
        ).all()
        sums: dict[str, dict[int, int]] = {}
        for account_id, y, m, total in rows:
            sums.setdefault(account_id, {})[int(y) * MONTHS_PER_YEAR + int(m) - 1] = int(total)
        return sums

    def snapshot_month_ends(self, user_id: str) -> set[date]:
        """Every month end at which at least one of the user's non-archived accounts has a snapshot.

        Archived accounts are left out as the summary leaves them out: a month only they cover
        is not a month the series draws from the ledger.
        """
        return set(
            self._db.scalars(
                select(AccountBalanceSnapshot.period_end)
                .join(Account, Account.id == AccountBalanceSnapshot.account_id)
                .where(Account.user_id == user_id, Account.archived.is_(False))
                .distinct()
            )
        )

    def declared(self, user_id: str, before: date | None = None) -> list[DeclaredBalance]:
        """The user's declared totals, oldest first; only those dated before `before` if given."""
        query = select(DeclaredBalance).where(DeclaredBalance.user_id == user_id)
        if before is not None:
            query = query.where(DeclaredBalance.period_end < before)
        return list(self._db.scalars(query.order_by(DeclaredBalance.period_end)))

    def declared_at(self, user_id: str, period_end: date) -> DeclaredBalance | None:
        """The user's declared total for one month end, or `None`."""
        return self._db.scalar(
            select(DeclaredBalance).where(
                DeclaredBalance.user_id == user_id, DeclaredBalance.period_end == period_end
            )
        )

    def save_declared(self, row: DeclaredBalance) -> DeclaredBalance:
        """Insert or update one declared total."""
        self._db.add(row)
        self._db.commit()
        self._db.refresh(row)
        return row

    def delete_declared(self, row: DeclaredBalance) -> None:
        self._db.delete(row)
        self._db.commit()
