"""Business logic for a detection pass: run the detector, then persist what it found.

The whole pass is one database transaction. Its two rules — idempotence and the primacy of
user intent (`PROJECT.md` §12) — are what most of this module is about: running detection twice
over unchanged history must leave the same rows behind as running it once, and must never talk
back to a user who has already had their say about a series.
"""

from dataclasses import dataclass

from sqlalchemy.orm import Session

from app.features.accounts.service import AccountService
from app.features.recurring.detector import SeriesCandidate
from app.features.recurring.detector import detect as detect_candidates
from app.features.recurring.models import RecurringOccurrence, RecurringSeries
from app.features.recurring.repository import RecurringRepository
from app.features.recurring.schemas import SeriesStatus
from app.features.transactions.repository import TransactionRepository

#: The status a newly detected series starts in — the detector has found it, the user has not
#: yet said anything about it.
INITIAL_STATUS: SeriesStatus = "detected"

#: Statuses that are the user's verdict on a series. Re-detection never resurrects one: a
#: dismissed series would come straight back on the next import, and a cancelled subscription
#: still has all of its history sitting in the ledger to be re-detected from.
FROZEN_STATUSES: frozenset[str] = frozenset({"dismissed", "cancelled"})


@dataclass(frozen=True, slots=True)
class DetectionResult:
    """What one pass did. Series it deliberately left alone count in neither number."""

    created_count: int
    updated_count: int


class RecurringDetectionService:
    """Runs detection over a user's transactions and upserts the series it finds."""

    def __init__(
        self,
        repository: RecurringRepository,
        transactions: TransactionRepository,
        accounts: AccountService,
        db: Session,
    ) -> None:
        self._repository = repository
        self._transactions = transactions
        self._accounts = accounts
        # The pass writes series and occurrence links that only make sense together, so the
        # service — not the repository — owns when they land.
        self._db = db

    def detect(self, user_id: str, account_id: str | None = None) -> DetectionResult:
        """Detect the user's recurring series, over one account or over all of them.

        Args:
            user_id: the owner; every read and write below is scoped to them.
            account_id: narrows the pass to one account; `None` covers every account.

        Raises:
            AccountNotFoundError: `account_id` is set and is not one of the user's accounts.
        """
        if account_id is not None:
            self._accounts.get(user_id, account_id)

        transactions = self._transactions.list_all_for_user(user_id, account_id=account_id)
        existing = {
            (series.account_id, series.merchant_key): series
            for series in self._repository.list_for_user(user_id, account_id=account_id)
        }

        created_count = 0
        updated_count = 0
        written: list[tuple[RecurringSeries, SeriesCandidate]] = []
        for candidate in detect_candidates(transactions):
            series = existing.get((candidate.account_id, candidate.merchant_key))
            if series is None:
                series = _new_series(user_id, candidate)
                self._repository.stage(series)
                created_count += 1
            elif _is_frozen(series):
                continue
            else:
                _refresh(series, candidate)
                updated_count += 1
            written.append((series, candidate))

        self._link_occurrences(written)
        self._db.commit()
        return DetectionResult(created_count=created_count, updated_count=updated_count)

    def _link_occurrences(self, written: list[tuple[RecurringSeries, SeriesCandidate]]) -> None:
        """Replace the occurrence links of every series this pass wrote.

        Deletes first and in bulk, because a transaction may have moved between two series in
        this same pass and the unique constraint on `transaction_id` would catch the insert
        before the delete that made room for it.
        """
        # Flushed so newly staged series have the ids the links point at.
        self._repository.flush()
        self._repository.delete_occurrences_for_series([series.id for series, _ in written])
        self._repository.flush()

        candidate_ids = [
            transaction_id
            for _, candidate in written
            for transaction_id in candidate.transaction_ids
        ]
        # Whatever is still linked belongs to a series this pass left alone — manual, dismissed
        # or cancelled — and that link is the user's, not the detector's, to break.
        claimed = self._repository.linked_transaction_ids(candidate_ids)
        for series, candidate in written:
            for transaction_id in candidate.transaction_ids:
                if transaction_id in claimed:
                    continue
                self._repository.stage_occurrence(
                    RecurringOccurrence(series_id=series.id, transaction_id=transaction_id)
                )


def _is_frozen(series: RecurringSeries) -> bool:
    """True for a series detection must not write to at all."""
    return series.is_manual or series.status in FROZEN_STATUSES


def _new_series(user_id: str, candidate: SeriesCandidate) -> RecurringSeries:
    """A series row for a candidate seen for the first time."""
    return RecurringSeries(
        user_id=user_id,
        account_id=candidate.account_id,
        merchant_key=candidate.merchant_key,
        label=candidate.label,
        cadence=candidate.cadence,
        median_interval_days=candidate.median_interval_days,
        expected_amount_minor=candidate.expected_amount_minor,
        currency=candidate.currency,
        first_seen_date=candidate.first_seen_date,
        last_seen_date=candidate.last_seen_date,
        next_expected_date=candidate.next_expected_date,
        occurrence_count=candidate.occurrence_count,
        status=INITIAL_STATUS,
        is_manual=False,
        price_change_minor=candidate.price_change_minor,
        price_changed_at=candidate.price_changed_at,
    )


def _refresh(series: RecurringSeries, candidate: SeriesCandidate) -> None:
    """Write the observed fields of ``candidate`` onto an existing series.

    Only the observations: `label`, `category_id` and `status` are left exactly as they are,
    because by the time a series has been seen once they may be the user's answer and there is
    no signal here that could tell an edited one from an untouched one.

    `price_change_minor` is written even when it is `None`. It describes what the current
    history shows, not a log of every step ever taken, so leaving a stale value behind would
    make a second pass over unchanged rows disagree with the first.
    """
    series.cadence = candidate.cadence
    series.median_interval_days = candidate.median_interval_days
    series.expected_amount_minor = candidate.expected_amount_minor
    series.currency = candidate.currency
    series.first_seen_date = candidate.first_seen_date
    series.last_seen_date = candidate.last_seen_date
    series.next_expected_date = candidate.next_expected_date
    series.occurrence_count = candidate.occurrence_count
    series.price_change_minor = candidate.price_change_minor
    series.price_changed_at = candidate.price_changed_at
