"""Business logic for recurring series: the detection pass, and the lifecycle above it.

Two services, because they answer to different rules. `RecurringDetectionService` runs the
detector and persists what it found, under idempotence and the primacy of user intent:
running detection twice over unchanged history must leave the same rows
behind as running it once, and must never talk back to a user who has already had their say.
`RecurringService` *is* the user — listing, editing, the status lifecycle, and the read-time
summary — and its only constraint is that the states it writes are states the lifecycle allows.
"""

from dataclasses import dataclass
from datetime import date, timedelta

from sqlalchemy.orm import Session

from app.core.errors import ConflictError, NotFoundError
from app.features.accounts.service import AccountService
from app.features.categories.repository import CategoryRepository
from app.features.categories.service import CategoryInvalidError
from app.features.recurring.detector import (
    INTERVAL_TOLERANCE_FLOOR_DAYS,
    INTERVAL_TOLERANCE_PERCENT,
    SeriesCandidate,
)
from app.features.recurring.detector import detect as detect_candidates
from app.features.recurring.models import RecurringOccurrence, RecurringSeries
from app.features.recurring.normalize import merchant_key, normalize_label
from app.features.recurring.repository import RecurringRepository
from app.features.recurring.schemas import (
    MissedCharge,
    NextCharge,
    PriceIncrease,
    RecurringSummary,
    SeriesCreate,
    SeriesStatus,
    SeriesUpdate,
)
from app.features.transactions.models import Transaction
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


class SeriesNotFoundError(NotFoundError):
    """Raised when a series doesn't exist or doesn't belong to the caller."""

    code = "RECURRING_SERIES_NOT_FOUND"


class SeriesAlreadyTrackedError(ConflictError):
    """Raised when a declared series would collide with one already tracked in that account."""

    code = "RECURRING_SERIES_EXISTS"


class InvalidSeriesTransitionError(ConflictError):
    """Raised when a status change is not one the lifecycle allows."""

    code = "RECURRING_INVALID_TRANSITION"


#: The lifecycle, exhaustively. `detected` is where both detection and a user declaration start;
#: `dismissed` is the end of the line — the detector never revives it (`FROZEN_STATUSES`) and
#: nothing else may either, because a "no" undoable by a stray patch is not an answer.
#: `cancelled → confirmed` exists for the user who resubscribes. Anything absent here is a 409
#: rather than a silent no-op: a client asking for a transition the panel never offers is
#: mistaken about the series' state, and writing the state it imagined would hide that.
LEGAL_TRANSITIONS: dict[str, frozenset[str]] = {
    "detected": frozenset({"confirmed", "dismissed"}),
    "confirmed": frozenset({"cancelled", "dismissed"}),
    "cancelled": frozenset({"confirmed"}),
    "dismissed": frozenset(),
}

#: Statuses a series still counts as running under: everything the user has not ruled out.
#: `cancelled` is a subscription that existed and ended, so it stays listed and counted on its
#: own line, but never enters the burden.
ACTIVE_STATUSES: frozenset[str] = frozenset({"detected", "confirmed"})

#: The interval a *declared* series is seeded with, having no occurrences to measure one from.
#: `irregular` gets none — that is what irregular means — so its `next_expected_date` is a
#: placeholder the date-derived signals skip rather than a claim about when it will be charged.
NOMINAL_INTERVAL_DAYS: dict[str, int] = {
    "weekly": 7,
    "monthly": 30,
    "quarterly": 91,
    "yearly": 365,
    "irregular": 0,
}

#: Numerator and denominator converting one cadence's charge to a monthly figure.
#: `irregular` is absent: a series with no period has no monthly equivalent,
#: and inventing one would put a number the user never agreed to into the burden.
MONTHLY_FACTORS: dict[str, tuple[int, int]] = {
    "weekly": (52, 12),
    "monthly": (1, 1),
    "quarterly": (1, 3),
    "yearly": (1, 12),
}

#: How long a price rise stays news. Past a quarter it is simply what the subscription costs.
PRICE_INCREASE_WINDOW_DAYS = 90


def monthly_equivalent_minor(amount_minor: int, cadence: str) -> int | None:
    """``amount_minor`` charged at ``cadence`` as a monthly figure, or `None` if it has none.

    Integer minor units throughout: the conversion is one exact rational
    multiplication rounded once, never a float that would carry its own error into a sum.
    """
    factors = MONTHLY_FACTORS.get(cadence)
    if factors is None:
        return None
    numerator, denominator = factors
    return _divide_rounding_half_away(amount_minor * numerator, denominator)


def _divide_rounding_half_away(numerator: int, denominator: int) -> int:
    """``numerator / denominator`` rounded to the nearest minor unit, halves away from zero.

    Away from zero rather than Python's banker's rounding so the rule is symmetric in the sign:
    an outflow and an inflow of the same size normalise to the same magnitude, which they would
    not if ties broke toward even.
    """
    magnitude = (abs(numerator) * 2 + denominator) // (denominator * 2)
    return -magnitude if numerator < 0 else magnitude


def missed_tolerance_days(median_interval_days: int) -> int:
    """How late a charge may be before it counts as missed, for a series of this interval.

    The detector's own gap tolerance, reused deliberately: a charge still
    within the spread detection accepts between two occurrences has not gone missing, it has
    landed on a working day.
    """
    return max(
        INTERVAL_TOLERANCE_FLOOR_DAYS,
        median_interval_days * INTERVAL_TOLERANCE_PERCENT // 100,
    )


class RecurringService:
    """The user-facing surface over series: listing, detail, lifecycle, and the summary.

    Separate from `RecurringDetectionService` because the two answer to different rules. That
    one is a batch pass that must never contradict the user; this one *is* the user, and its
    only constraint is that the states it writes are states the lifecycle allows.
    """

    def __init__(
        self,
        repository: RecurringRepository,
        transactions: TransactionRepository,
        accounts: AccountService,
        categories: CategoryRepository,
    ) -> None:
        self._repository = repository
        self._transactions = transactions
        self._accounts = accounts
        self._categories = categories

    def list_for_user(
        self, user_id: str, *, status: str | None = None, account_id: str | None = None
    ) -> list[RecurringSeries]:
        """The user's series, soonest charge first.

        Raises:
            AccountNotFoundError: `account_id` is set and is not one of the user's accounts.
        """
        if account_id is not None:
            self._accounts.get(user_id, account_id)
        return self._repository.list_for_user(user_id, account_id=account_id, status=status)

    def get(self, user_id: str, series_id: str) -> RecurringSeries:
        """One series the user owns.

        Raises:
            SeriesNotFoundError: no such series, or it belongs to another user.
        """
        series = self._repository.get_for_user(series_id, user_id)
        if series is None:
            raise SeriesNotFoundError("Recurring series not found.")
        return series

    def occurrences(
        self, user_id: str, series_id: str
    ) -> tuple[RecurringSeries, list[tuple[RecurringOccurrence, Transaction]]]:
        """A series and the transactions it was deduced from, newest first.

        Raises:
            SeriesNotFoundError: no such series, or it belongs to another user.
        """
        series = self.get(user_id, series_id)
        return series, self._repository.list_occurrences(series.id)

    def create(self, user_id: str, data: SeriesCreate, today: date) -> RecurringSeries:
        """Declare a subscription detection has not found.

        The observed columns have nothing to observe yet, so they are seeded from the creation
        date and the nominal length of the chosen cadence: `occurrence_count` is `0`, and
        `first_seen_date` records when the user started tracking the series rather than claiming
        when it started. `is_manual` keeps detection off it for good.

        Raises:
            AccountNotFoundError: the account is not one of the user's.
            CategoryInvalidError: `category_id` is set and is not one the caller may assign.
            SeriesAlreadyTrackedError: that account already tracks a series under this name.
        """
        account = self._accounts.get(user_id, data.account_id)
        self._require_assignable_category(user_id, data.category_id)
        key = normalize_label(data.label)
        existing = self._repository.get_by_merchant_key(user_id, account.id, key)
        if existing is not None:
            raise SeriesAlreadyTrackedError(
                "This account already tracks a subscription under that name.",
                details={"series_id": existing.id},
            )

        interval = NOMINAL_INTERVAL_DAYS[data.cadence]
        series = RecurringSeries(
            user_id=user_id,
            account_id=account.id,
            merchant_key=key,
            label=data.label,
            category_id=data.category_id,
            cadence=data.cadence,
            median_interval_days=interval,
            expected_amount_minor=data.expected_amount_minor,
            currency=account.currency,
            first_seen_date=today,
            last_seen_date=today,
            next_expected_date=today + timedelta(days=interval),
            occurrence_count=0,
            status=INITIAL_STATUS,
            is_manual=True,
        )
        return self._repository.add(series)

    def update(self, user_id: str, series_id: str, data: SeriesUpdate) -> RecurringSeries:
        """Patch a series' user-owned fields, validating a status change against the lifecycle.

        Raises:
            SeriesNotFoundError: no such series, or it belongs to another user.
            CategoryInvalidError: `category_id` is set and is not one the caller may assign.
            InvalidSeriesTransitionError: the requested status is not reachable from the
                current one.
        """
        series = self.get(user_id, series_id)
        self._require_assignable_category(user_id, data.category_id)
        # Checked before anything is assigned, so a rejected transition leaves the whole patch
        # unapplied rather than half of it.
        if data.status is not None:
            _check_transition(series.status, data.status)
            series.status = data.status
        if data.label is not None:
            series.label = data.label
        if data.category_id is not None:
            series.category_id = data.category_id
        if data.cadence is not None:
            series.cadence = data.cadence
        if data.expected_amount_minor is not None:
            series.expected_amount_minor = data.expected_amount_minor
        return self._repository.save(series)

    def _require_assignable_category(self, user_id: str, category_id: str | None) -> None:
        """Reject a `category_id` the caller cannot see. `None` means "leave it alone".

        The foreign key only proves the row exists — it knows nothing about users — so without
        this a series could carry another user's private category and render its label and
        colour on this user's subscriptions.

        Raises:
            CategoryInvalidError: no such category, or it is another user's.
        """
        if category_id is None:
            return
        if self._categories.get_visible_by_id_for_user(category_id, user_id) is None:
            raise CategoryInvalidError(
                "Category not found.", {"field": "category_id", "category_id": category_id}
            )

    def delete(self, user_id: str, series_id: str) -> None:
        """Remove a declared series; dismiss a detected one.

        A manual series is pure user data, so deleting it deletes it. A detected one is a
        conclusion the ledger still supports: hard-deleting it would only invite the next
        detection pass to recreate it, so the delete is recorded as `dismissed` — the one place
        the user's "no" can live where detection will respect it.

        Raises:
            SeriesNotFoundError: no such series, or it belongs to another user.
        """
        series = self.get(user_id, series_id)
        if series.is_manual:
            self._repository.delete(series)
            return
        series.status = "dismissed"
        self._repository.save(series)

    def summary(self, user_id: str, currency: str, today: date) -> RecurringSummary:
        """The monthly burden, the counts, and the price-increase and missed-charge signals.

        Everything here is derived at read time and nothing is written: a missed charge stops
        being true the moment the charge lands, so persisting it would mean carrying a flag that
        is wrong between an import and the next detection pass.
        """
        series = self._repository.list_for_user(user_id)
        active = [row for row in series if row.status in ACTIVE_STATUSES]

        monthly_total = 0
        cadence_counts = dict.fromkeys(NOMINAL_INTERVAL_DAYS, 0)
        for row in active:
            cadence_counts[row.cadence] += 1
            monthly = monthly_equivalent_minor(row.expected_amount_minor, row.cadence)
            if monthly is not None:
                monthly_total += monthly

        return RecurringSummary(
            monthly_total_minor=monthly_total,
            active_count=len(active),
            cancelled_count=sum(1 for row in series if row.status == "cancelled"),
            cadence_counts=cadence_counts,
            next_charge=_next_charge(active, today),
            price_increases=_price_increases(active, today),
            missed=self._missed(user_id, active, today),
            currency=currency,
        )

    def _missed(
        self, user_id: str, active: list[RecurringSeries], today: date
    ) -> list[MissedCharge]:
        """Which active series are overdue past their tolerance with no charge to show for it.

        The second half is why this reads the ledger rather than the occurrence links: those are
        refreshed only by a detection pass, so a charge imported this morning would still look
        missing until the user ran one. Matching on the same merchant key the detector groups by
        lets an imported charge clear the signal on its own, with no write to the series.

        The scan is skipped entirely when nothing is overdue, which is the ordinary case.
        """
        overdue = [
            row
            for row in active
            if row.cadence != "irregular"
            and (today - row.next_expected_date).days
            > missed_tolerance_days(row.median_interval_days)
        ]
        if not overdue:
            return []

        newest_charge = self._newest_charge_dates(user_id)
        return [
            MissedCharge(
                series_id=row.id,
                expected_on=row.next_expected_date,
                days_late=(today - row.next_expected_date).days,
            )
            for row in overdue
            if newest_charge.get((row.account_id, row.merchant_key), row.last_seen_date)
            <= row.last_seen_date
        ]

    def _newest_charge_dates(self, user_id: str) -> dict[tuple[str, str], date]:
        """The most recent outflow per `(account_id, merchant_key)` across the user's ledger.

        Outflows only, and keyed exactly as the detector groups, so "has this subscription been
        charged since we last looked" is answered by the same notion of "this subscription".
        """
        newest: dict[tuple[str, str], date] = {}
        for transaction in self._transactions.list_all_for_user(user_id):
            if transaction.amount_minor >= 0:
                continue
            key = (transaction.account_id, merchant_key(transaction))
            previous = newest.get(key)
            if previous is None or transaction.booked_date > previous:
                newest[key] = transaction.booked_date
        return newest


def _check_transition(current: str, requested: str) -> None:
    """Guard a status change against `LEGAL_TRANSITIONS`.

    Raises:
        InvalidSeriesTransitionError: the transition is not one the lifecycle allows.
    """
    if requested not in LEGAL_TRANSITIONS[current]:
        raise InvalidSeriesTransitionError(
            "That status change is not allowed for this series.",
            details={"from": current, "to": requested},
        )


def _next_charge(active: list[RecurringSeries], today: date) -> NextCharge | None:
    """The soonest charge still ahead, or `None` when no active series expects one.

    ``active`` arrives ordered by `next_expected_date`, so the first series that expects a
    charge at all is the answer — but only among the dates that have not passed. A series whose
    charge was due last week is late, not next: the panel prints it as a missed charge on its
    own row, and calling it « Prochain prélèvement » would put a date in the past on a card
    whose whole job is to say what is coming.
    """
    for row in active:
        if row.cadence == "irregular" or row.next_expected_date < today:
            continue
        return NextCharge(
            series_id=row.id,
            label=row.label,
            amount_minor=row.expected_amount_minor,
            due_on=row.next_expected_date,
        )
    return None


def _price_increases(active: list[RecurringSeries], today: date) -> list[PriceIncrease]:
    """Recent price *rises*, newest first.

    Filtered to rises because a subscription that got cheaper is not something to flag, and on
    an outflow a rise is the step growing more negative. The detector wrote both the delta and
    its date; this only decides what is still recent enough to be worth showing.
    """
    window_start = today - timedelta(days=PRICE_INCREASE_WINDOW_DAYS)
    increases = [
        PriceIncrease(
            series_id=row.id,
            delta_minor=row.price_change_minor,
            changed_at=row.price_changed_at,
        )
        for row in active
        if row.price_change_minor is not None
        and row.price_change_minor < 0
        and row.price_changed_at is not None
        and row.price_changed_at >= window_start
    ]
    return sorted(increases, key=lambda increase: increase.changed_at, reverse=True)
