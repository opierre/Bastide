"""Data access for placements, their movements and their declared values.

The only place these tables are queried. The two reads of `transactions` and `accounts` — to
check a link and to propose candidates — are read-only lookups over another feature's rows,
as the net-worth repository reads the ledger; nothing here writes them.
"""

from collections.abc import Sequence
from datetime import date

from sqlalchemy import delete, func, select
from sqlalchemy.orm import Session

from app.features.accounts.models import Account
from app.features.placements.models import Investment, InvestmentMovement, InvestmentValuation
from app.features.transactions.models import Transaction


class PlacementRepository:
    """Queries and writes for placements, always scoped to a user."""

    def __init__(self, db: Session) -> None:
        self._db = db

    # --- placements ---------------------------------------------------------------------------

    def list_for_user(self, user_id: str) -> list[Investment]:
        """The user's placements: open ones first, then closed ones, each oldest first."""
        return list(
            self._db.scalars(
                select(Investment)
                .where(Investment.user_id == user_id)
                .order_by(Investment.closed_on.is_not(None), Investment.created_at)
            )
        )

    def get_for_user(self, investment_id: str, user_id: str) -> Investment | None:
        """One placement the user owns, or `None` — including another user's."""
        return self._db.scalar(
            select(Investment).where(Investment.id == investment_id, Investment.user_id == user_id)
        )

    def delete_investment(self, investment: Investment) -> None:
        """Delete a placement and its whole history.

        The children are deleted explicitly rather than left to the FK cascade, so the delete
        holds on a connection that does not enforce foreign keys.
        """
        for model in (InvestmentMovement, InvestmentValuation):
            self._db.execute(delete(model).where(model.investment_id == investment.id))
        self._db.delete(investment)
        self._db.commit()

    # --- history ------------------------------------------------------------------------------

    def movements_for(self, investment_ids: Sequence[str]) -> list[InvestmentMovement]:
        """The movements of these placements, newest first."""
        if not investment_ids:
            return []
        return list(
            self._db.scalars(
                select(InvestmentMovement)
                .where(InvestmentMovement.investment_id.in_(investment_ids))
                .order_by(
                    InvestmentMovement.occurred_on.desc(), InvestmentMovement.created_at.desc()
                )
            )
        )

    def valuations_for(self, investment_ids: Sequence[str]) -> list[InvestmentValuation]:
        """The declared values of these placements, newest first."""
        if not investment_ids:
            return []
        return list(
            self._db.scalars(
                select(InvestmentValuation)
                .where(InvestmentValuation.investment_id.in_(investment_ids))
                .order_by(InvestmentValuation.valued_on.desc())
            )
        )

    def get_movement(self, movement_id: str, investment_id: str) -> InvestmentMovement | None:
        return self._db.scalar(
            select(InvestmentMovement).where(
                InvestmentMovement.id == movement_id,
                InvestmentMovement.investment_id == investment_id,
            )
        )

    def get_valuation(self, valuation_id: str, investment_id: str) -> InvestmentValuation | None:
        return self._db.scalar(
            select(InvestmentValuation).where(
                InvestmentValuation.id == valuation_id,
                InvestmentValuation.investment_id == investment_id,
            )
        )

    def valuation_on(self, investment_id: str, valued_on: date) -> InvestmentValuation | None:
        """The placement's declared value for that exact date, or `None`."""
        return self._db.scalar(
            select(InvestmentValuation).where(
                InvestmentValuation.investment_id == investment_id,
                InvestmentValuation.valued_on == valued_on,
            )
        )

    def history_bounds(self, investment_id: str) -> tuple[date | None, date | None]:
        """The earliest and latest dates of the placement's movements and declared values."""
        movements = self._db.execute(
            select(
                func.min(InvestmentMovement.occurred_on), func.max(InvestmentMovement.occurred_on)
            ).where(InvestmentMovement.investment_id == investment_id)
        ).one()
        valuations = self._db.execute(
            select(
                func.min(InvestmentValuation.valued_on), func.max(InvestmentValuation.valued_on)
            ).where(InvestmentValuation.investment_id == investment_id)
        ).one()
        earliest = [day for day in (movements[0], valuations[0]) if day is not None]
        latest = [day for day in (movements[1], valuations[1]) if day is not None]
        return min(earliest, default=None), max(latest, default=None)

    # --- the link to an imported transaction ----------------------------------------------------

    def user_transaction(self, transaction_id: str, user_id: str) -> Transaction | None:
        """One transaction on one of the user's accounts, or `None` — including another user's."""
        return self._db.scalar(
            select(Transaction)
            .join(Account, Account.id == Transaction.account_id)
            .where(Transaction.id == transaction_id, Account.user_id == user_id)
        )

    def movement_linked_to(self, transaction_id: str) -> InvestmentMovement | None:
        return self._db.scalar(
            select(InvestmentMovement).where(InvestmentMovement.transaction_id == transaction_id)
        )

    def link_candidates(
        self,
        user_id: str,
        amount_minor: int,
        start: date,
        end: date,
        keep_movement_id: str | None,
    ) -> list[tuple[Transaction, str]]:
        """`(transaction, account name)` of the user's rows of exactly `amount_minor`, booked
        between `start` and `end`, not already linked to a movement other than
        `keep_movement_id`. Bounded by the amount and the date window, so the result is small.
        """
        linked = select(InvestmentMovement.transaction_id).where(
            InvestmentMovement.transaction_id.is_not(None)
        )
        if keep_movement_id is not None:
            linked = linked.where(InvestmentMovement.id != keep_movement_id)
        rows = self._db.execute(
            select(Transaction, Account.name)
            .join(Account, Account.id == Transaction.account_id)
            .where(
                Account.user_id == user_id,
                Transaction.amount_minor == amount_minor,
                Transaction.booked_date >= start,
                Transaction.booked_date <= end,
                Transaction.id.not_in(linked),
            )
        ).all()
        return [(transaction, name) for transaction, name in rows]

    # --- writes -------------------------------------------------------------------------------

    def add(self, *rows: Investment | InvestmentMovement | InvestmentValuation) -> None:
        """Insert rows in one commit, in the order given (a placement before its history)."""
        for row in rows:
            self._db.add(row)
            self._db.flush()
        self._db.commit()
        for row in rows:
            self._db.refresh(row)

    def save(self) -> None:
        self._db.commit()

    def delete(self, row: InvestmentMovement | InvestmentValuation) -> None:
        self._db.delete(row)
        self._db.commit()
