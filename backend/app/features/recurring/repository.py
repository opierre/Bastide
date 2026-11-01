"""Data access for `RecurringSeries` and `RecurringOccurrence` rows. The only place either
table is queried.

Writes here stage rather than commit: a detection pass rewrites series and their occurrence
links together, and half of that landing would leave a series pointing at the transactions of
its previous shape. The service owns the transaction boundary.
"""

from collections.abc import Sequence

from sqlalchemy import delete, select, update
from sqlalchemy.orm import Session

from app.features.recurring.models import (
    RecurringMerchantAlias,
    RecurringMergeDismissal,
    RecurringOccurrence,
    RecurringSeries,
)
from app.features.transactions.models import Transaction

# SQLite caps the parameters of one statement, so id lists are sent in chunks rather than as one
# `IN (...)` of unbounded length.
_ID_CHUNK_SIZE = 500


class RecurringRepository:
    """Queries and writes for recurring series, always scoped to a user."""

    def __init__(self, db: Session) -> None:
        self._db = db

    def list_for_user(
        self, user_id: str, *, account_id: str | None = None, status: str | None = None
    ) -> list[RecurringSeries]:
        """The user's series, soonest charge first, optionally narrowed by account and status.

        The panel is a list of what is coming, so due date is the order it reads in; `created_at`
        only breaks ties, and only so the order is stable rather than whatever the database
        returns. Detection keys its own results by `(account_id, merchant_key)` and does not
        care which order they arrive in.
        """
        query = select(RecurringSeries).where(RecurringSeries.user_id == user_id)
        if account_id is not None:
            query = query.where(RecurringSeries.account_id == account_id)
        if status is not None:
            query = query.where(RecurringSeries.status == status)
        return list(
            self._db.scalars(
                query.order_by(RecurringSeries.next_expected_date, RecurringSeries.created_at)
            )
        )

    def get_for_user(self, series_id: str, user_id: str) -> RecurringSeries | None:
        """One series the user owns, or `None` — including for a series of another user."""
        return self._db.scalar(
            select(RecurringSeries).where(
                RecurringSeries.id == series_id, RecurringSeries.user_id == user_id
            )
        )

    def list_occurrences(self, series_id: str) -> list[tuple[RecurringOccurrence, Transaction]]:
        """A series' occurrences with the transaction each points at, newest charge first.

        Joined rather than lazily loaded per row: the detail screen shows every occurrence, so
        the alternative is one query per line of the history table.
        """
        rows = self._db.execute(
            select(RecurringOccurrence, Transaction)
            .join(Transaction, Transaction.id == RecurringOccurrence.transaction_id)
            .where(RecurringOccurrence.series_id == series_id)
            .order_by(Transaction.booked_date.desc(), Transaction.id.desc())
        )
        return [(occurrence, transaction) for occurrence, transaction in rows]

    def add(self, series: RecurringSeries) -> RecurringSeries:
        """Insert a series and commit.

        Unlike the staging writes below, a lifecycle write is one row with nothing to keep it
        consistent with, so it owns its own transaction the way every other feature's does.
        """
        self._db.add(series)
        self._db.commit()
        self._db.refresh(series)
        return series

    def save(self, series: RecurringSeries) -> RecurringSeries:
        """Commit pending changes to a series already in the session."""
        self._db.commit()
        self._db.refresh(series)
        return series

    def delete(self, series: RecurringSeries) -> None:
        """Remove a series and its occurrence links, and commit."""
        self.delete_occurrences_for_series([series.id])
        self._db.delete(series)
        self._db.commit()

    def get_by_merchant_key(
        self, user_id: str, account_id: str, merchant_key: str
    ) -> RecurringSeries | None:
        """The series already holding this grouping key in this account, if any.

        Checked before a manual insert so the caller gets the error envelope instead of the
        integrity error from `uq_recurring_series_account_merchant`.
        """
        return self._db.scalar(
            select(RecurringSeries).where(
                RecurringSeries.user_id == user_id,
                RecurringSeries.account_id == account_id,
                RecurringSeries.merchant_key == merchant_key,
            )
        )

    def series_for_transaction(self, transaction_id: str, user_id: str) -> RecurringSeries | None:
        """The user's series ``transaction_id`` is an occurrence of, if any."""
        return self._db.scalar(
            select(RecurringSeries)
            .join(RecurringOccurrence, RecurringOccurrence.series_id == RecurringSeries.id)
            .where(
                RecurringOccurrence.transaction_id == transaction_id,
                RecurringSeries.user_id == user_id,
            )
        )

    def add_with_occurrences(
        self,
        series: RecurringSeries,
        transaction_ids: Sequence[str],
        alias_keys: Sequence[str],
    ) -> RecurringSeries:
        """Insert a series with its occurrence links and merged-in keys, in one commit.

        The links and aliases only make sense with the series they point at, so a half-written
        result would leave transactions claimed by nothing or a series without its history.
        """
        self._db.add(series)
        self._db.flush()
        for transaction_id in transaction_ids:
            self._db.add(RecurringOccurrence(series_id=series.id, transaction_id=transaction_id))
        for key in alias_keys:
            self._db.add(
                RecurringMerchantAlias(
                    user_id=series.user_id,
                    account_id=series.account_id,
                    series_id=series.id,
                    merchant_key=key,
                )
            )
        self._db.commit()
        self._db.refresh(series)
        return series

    def stage(self, series: RecurringSeries) -> None:
        """Add a series to the session without committing."""
        self._db.add(series)

    def stage_occurrence(self, occurrence: RecurringOccurrence) -> None:
        """Add an occurrence link to the session without committing."""
        self._db.add(occurrence)

    def delete_occurrences_for_series(self, series_ids: Sequence[str]) -> None:
        """Drop every occurrence link of the given series, without committing.

        Detection replaces a series' links rather than reconciling them: the transactions
        backing a series are its output, so recomputing them and diffing would be the same work
        twice with a chance of disagreeing with itself.
        """
        for chunk in _chunks(series_ids):
            self._db.execute(
                delete(RecurringOccurrence).where(RecurringOccurrence.series_id.in_(chunk))
            )

    def linked_transaction_ids(self, transaction_ids: Sequence[str]) -> set[str]:
        """Which of ``transaction_ids`` already belong to a series.

        A transaction belongs to at most one series, so this is what keeps a detection pass
        from claiming rows the user attached to a manual series or one they dismissed — the
        series detection deliberately did not touch, and whose links it therefore did not clear.
        """
        linked: set[str] = set()
        for chunk in _chunks(transaction_ids):
            linked.update(
                self._db.scalars(
                    select(RecurringOccurrence.transaction_id).where(
                        RecurringOccurrence.transaction_id.in_(chunk)
                    )
                )
            )
        return linked

    def aliases_for_user(
        self, user_id: str, *, account_id: str | None = None
    ) -> dict[tuple[str, str], tuple[str, str]]:
        """`(account_id, merged-away key)` → `(account_id, key)` of the series that absorbed it."""
        query = (
            select(
                RecurringMerchantAlias.account_id,
                RecurringMerchantAlias.merchant_key,
                RecurringSeries.account_id,
                RecurringSeries.merchant_key,
            )
            .join(RecurringSeries, RecurringSeries.id == RecurringMerchantAlias.series_id)
            .where(RecurringMerchantAlias.user_id == user_id)
        )
        if account_id is not None:
            query = query.where(RecurringMerchantAlias.account_id == account_id)
        return {
            (account, alias_key): (series_account, series_key)
            for account, alias_key, series_account, series_key in self._db.execute(query)
        }

    def stage_alias(self, alias: RecurringMerchantAlias) -> None:
        """Add an alias to the session without committing."""
        self._db.add(alias)

    def repoint_to(self, from_series_id: str, to_series_id: str) -> None:
        """Move one series' aliases and occurrence links onto another, without committing."""
        self._db.execute(
            update(RecurringMerchantAlias)
            .where(RecurringMerchantAlias.series_id == from_series_id)
            .values(series_id=to_series_id)
        )
        self._db.execute(
            update(RecurringOccurrence)
            .where(RecurringOccurrence.series_id == from_series_id)
            .values(series_id=to_series_id)
        )

    def stage_delete(self, series: RecurringSeries) -> None:
        """Mark a series for deletion without committing."""
        self._db.delete(series)

    def dismissed_pairs(self, user_id: str) -> set[tuple[tuple[str, str], tuple[str, str]]]:
        """`((account_id, key), (account_id, key))` of every pair the user kept apart."""
        rows = self._db.execute(
            select(
                RecurringMergeDismissal.first_account_id,
                RecurringMergeDismissal.first_key,
                RecurringMergeDismissal.second_account_id,
                RecurringMergeDismissal.second_key,
            ).where(RecurringMergeDismissal.user_id == user_id)
        )
        return {((a1, k1), (a2, k2)) for a1, k1, a2, k2 in rows}

    def add_dismissal(self, dismissal: RecurringMergeDismissal) -> None:
        """Record a pair the user kept apart, and commit."""
        self._db.add(dismissal)
        self._db.commit()

    def commit(self) -> None:
        self._db.commit()

    def refresh(self, series: RecurringSeries) -> None:
        self._db.refresh(series)

    def flush(self) -> None:
        """Push staged changes to the database, still inside the caller's transaction.

        Needed between the two halves of a detection pass: new series must have their ids, and
        the deletes must have landed, before the occurrence links are inserted against the
        unique constraint on `transaction_id`.
        """
        self._db.flush()


def _chunks(ids: Sequence[str]) -> list[Sequence[str]]:
    return [ids[start : start + _ID_CHUNK_SIZE] for start in range(0, len(ids), _ID_CHUNK_SIZE)]
