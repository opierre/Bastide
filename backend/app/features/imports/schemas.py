"""Request/response schemas for the imports feature."""

from datetime import date, datetime

from pydantic import BaseModel


class ImportBatchRead(BaseModel):
    """An import batch as returned by the API: counts, coverage window, and outcome.

    `balance_mismatch_minor` is set only when this statement declared a balance that
    disagrees with what the ledger implies at `balance_mismatch_as_of` — e.g. a missed
    statement, an un-imported gap, or a bad prior correction. `None` means either there
    was nothing to compare (an OFX file without a `LEDGERBAL`) or the two agreed.
    """

    id: str
    account_id: str
    source_format: str
    file_name: str
    file_hash: str
    period_start: date
    period_end: date
    transaction_count: int
    new_count: int
    duplicate_count: int
    status: str
    error_message: str | None
    balance_mismatch_minor: int | None
    balance_mismatch_as_of: date | None
    imported_at: datetime


class UnmatchedCardPurchases(BaseModel):
    """A deferred card's purchases that no settlement has claimed, though one is overdue.

    Until the debit paying them is filed as a card settlement, they count as spending twice:
    once on the card, once as that debit on the current account.
    """

    account_id: str
    #: Their total — signed, so negative.
    amount_minor: int
    count: int
    #: The oldest of them.
    since: date


class CardSettlementStatus(BaseModel):
    """What the user still has to settle for their deferred cards to count once."""

    #: Settlements recognised by their label, waiting in the review queue.
    proposed_count: int
    unmatched: list[UnmatchedCardPurchases]
