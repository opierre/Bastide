"""Keeping an account's history in step when rows land on (or leave) its ledger after the fact.

Used by the import pipeline, which adds rows behind snapshots and recorded mismatches that
were computed without them. A removal is passed as a
movement of the opposite sign.
"""

from collections.abc import Sequence
from datetime import date
from typing import Protocol

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.features.accounts.models import Account, AccountBalanceSnapshot
from app.features.imports.models import ImportBatch


class Booked(Protocol):
    """A ledger movement as far as history cares: when, and by how much."""

    @property
    def booked_date(self) -> date: ...

    @property
    def amount_minor(self) -> int: ...


def shift_later_snapshots(db: Session, account: Account, new_rows: Sequence[Booked]) -> None:
    """Add the newly imported rows to every snapshot already taken after them.

    A snapshot is cumulative — the whole balance at its month end — so rows booked on or
    before that date belong in it, even when they arrive after it was written. That is
    the case when a statement fills a gap behind later imports: without this, every
    balance read from a later snapshot (and the net-worth history) would still be missing
    the gap's rows.
    """
    earliest = min(row.booked_date for row in new_rows)
    snapshots = db.scalars(
        select(AccountBalanceSnapshot).where(
            AccountBalanceSnapshot.account_id == account.id,
            AccountBalanceSnapshot.period_end >= earliest,
        )
    )
    for snapshot in snapshots:
        snapshot.balance_minor += sum(
            row.amount_minor for row in new_rows if row.booked_date <= snapshot.period_end
        )
    # The session doesn't autoflush, and the balance reads that follow query the table.
    db.flush()


def settle_earlier_mismatches(db: Session, account: Account, new_rows: Sequence[Booked]) -> None:
    """Take the newly imported rows off the mismatches earlier imports recorded.

    A mismatch is the declared balance minus the ledger's at its as-of date, so each row
    that arrives on or before that date moves it by its own amount. Importing the missing
    statement brings it to zero, which clears it: left as it was, the history would
    still warn about a gap that has been filled.
    """
    earliest = min(row.booked_date for row in new_rows)
    batches = db.scalars(
        select(ImportBatch).where(
            ImportBatch.account_id == account.id,
            ImportBatch.balance_mismatch_minor.is_not(None),
            ImportBatch.balance_mismatch_as_of >= earliest,
        )
    )
    for batch in batches:
        as_of = batch.balance_mismatch_as_of
        mismatch = (batch.balance_mismatch_minor or 0) - sum(
            row.amount_minor for row in new_rows if as_of and row.booked_date <= as_of
        )
        if mismatch == 0:
            batch.balance_mismatch_minor = None
            batch.balance_mismatch_as_of = None
        else:
            batch.balance_mismatch_minor = mismatch
