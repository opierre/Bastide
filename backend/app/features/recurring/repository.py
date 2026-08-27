"""Data access for `RecurringSeries` and `RecurringOccurrence` rows. The only place either
table is queried.

Writes here stage rather than commit: a detection pass rewrites series and their occurrence
links together, and half of that landing would leave a series pointing at the transactions of
its previous shape. The service owns the transaction boundary.
"""

from collections.abc import Sequence

from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from app.features.recurring.models import RecurringOccurrence, RecurringSeries

# SQLite caps the parameters of one statement, so id lists are sent in chunks rather than as one
# `IN (...)` of unbounded length.
_ID_CHUNK_SIZE = 500


class RecurringRepository:
    """Queries and writes for recurring series, always scoped to a user."""

    def __init__(self, db: Session) -> None:
        self._db = db

    def list_for_user(
        self, user_id: str, *, account_id: str | None = None
    ) -> list[RecurringSeries]:
        """The user's series, optionally narrowed to one account."""
        query = select(RecurringSeries).where(RecurringSeries.user_id == user_id)
        if account_id is not None:
            query = query.where(RecurringSeries.account_id == account_id)
        return list(self._db.scalars(query.order_by(RecurringSeries.created_at)))

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

    def flush(self) -> None:
        """Push staged changes to the database, still inside the caller's transaction.

        Needed between the two halves of a detection pass: new series must have their ids, and
        the deletes must have landed, before the occurrence links are inserted against the
        unique constraint on `transaction_id`.
        """
        self._db.flush()


def _chunks(ids: Sequence[str]) -> list[Sequence[str]]:
    return [ids[start : start + _ID_CHUNK_SIZE] for start in range(0, len(ids), _ID_CHUNK_SIZE)]
