"""The recurring-charge detection algorithm. Pure — no DB access.

`PROJECT.md` §12, implemented literally: group a user's outflows per account by merchant key,
qualify a group as a series only when both its cadence and its amounts are regular, and report
a price change when the newest charge steps outside the tolerance the earlier ones agree on.

A group that fails either regularity test yields *nothing*. There is no `irregular` fallback
here: that cadence belongs to series the user declares by hand, and emitting it from detection
would turn "I could not find a rhythm" into "I found an irregular subscription".
"""

from collections import Counter
from collections.abc import Iterable, Sequence
from dataclasses import dataclass
from datetime import date, timedelta
from itertools import pairwise
from statistics import median_low

from app.features.recurring.normalize import merchant_key
from app.features.recurring.schemas import DetectedCadence
from app.features.transactions.models import Transaction

#: Two charges are a coincidence; three are a rhythm (`PROJECT.md` §12).
MIN_OCCURRENCES = 3

#: Inclusive day bands classifying the median gap. A median outside every band is not a cadence
#: we recognise, so the group yields no series at all.
CADENCE_BANDS: tuple[tuple[DetectedCadence, int, int], ...] = (
    ("weekly", 5, 9),
    ("monthly", 26, 35),
    ("quarterly", 85, 95),
    ("yearly", 350, 380),
)

#: Gap tolerance: ±25 % of the median, but never tighter than ±3 days — a monthly charge lands
#: on a working day, so a weekend shifts it without making it irregular.
INTERVAL_TOLERANCE_PERCENT = 25
INTERVAL_TOLERANCE_FLOOR_DAYS = 3

#: Amount tolerance: ±10 % of the median, but never tighter than ±200 minor units. The floor
#: keeps small subscriptions from failing on a two-cent rounding difference; the percentage
#: keeps large ones from quietly absorbing a real price change.
AMOUNT_TOLERANCE_PERCENT = 10
AMOUNT_TOLERANCE_FLOOR_MINOR = 200


@dataclass(frozen=True, slots=True)
class SeriesCandidate:
    """One qualifying series as detection sees it, before anything is persisted.

    Carries only what detection observed. `status`, `is_manual` and the user's edits are the
    service's business, and `label` here is just the default a *new* series starts with.
    """

    account_id: str
    merchant_key: str
    label: str
    currency: str
    cadence: DetectedCadence
    median_interval_days: int
    #: Signed, so negative — a subscription is an outflow.
    expected_amount_minor: int
    first_seen_date: date
    last_seen_date: date
    next_expected_date: date
    occurrence_count: int
    #: Signed step in `expected_amount_minor`; a price *rise* on an outflow is negative.
    price_change_minor: int | None
    price_changed_at: date | None
    #: The transactions backing the series, oldest first.
    transaction_ids: tuple[str, ...]


@dataclass(frozen=True, slots=True)
class _AmountBaseline:
    """The amount the occurrences agree on, and the step that got them there."""

    expected_amount_minor: int
    price_change_minor: int | None


def detect(transactions: Iterable[Transaction]) -> list[SeriesCandidate]:
    """Find every recurring series in ``transactions``, ordered by account then merchant key.

    Only outflows are considered: a salary arriving every month is a rhythm, but it is not a
    subscription, and the feature exists to show what the user is paying for.
    """
    groups: dict[tuple[str, str], list[Transaction]] = {}
    for transaction in transactions:
        if transaction.amount_minor >= 0:
            continue
        group_key = (transaction.account_id, merchant_key(transaction))
        groups.setdefault(group_key, []).append(transaction)

    candidates = []
    for (account_id, key), group in sorted(groups.items()):
        candidate = _qualify(account_id, key, group)
        if candidate is not None:
            candidates.append(candidate)
    return candidates


def _qualify(account_id: str, key: str, group: list[Transaction]) -> SeriesCandidate | None:
    """Turn one merchant group into a series, or `None` if it is not regular enough to be one."""
    if len(group) < MIN_OCCURRENCES:
        return None

    # Ties on `booked_date` are broken by id so a group's order — and therefore which occurrence
    # counts as "the newest" — never depends on the order the rows came back in.
    occurrences = sorted(group, key=lambda t: (t.booked_date, t.id))
    gaps = [
        (later.booked_date - earlier.booked_date).days for earlier, later in pairwise(occurrences)
    ]

    interval = median_low(gaps)
    cadence = classify_cadence(interval)
    if cadence is None or not all(_interval_within(gap, interval) for gap in gaps):
        return None

    baseline = _amount_baseline([occurrence.amount_minor for occurrence in occurrences])
    if baseline is None:
        return None

    last_seen_date = occurrences[-1].booked_date
    price_changed = baseline.price_change_minor is not None
    return SeriesCandidate(
        account_id=account_id,
        merchant_key=key,
        label=_label(occurrences),
        currency=occurrences[0].currency,
        cadence=cadence,
        median_interval_days=interval,
        expected_amount_minor=baseline.expected_amount_minor,
        first_seen_date=occurrences[0].booked_date,
        last_seen_date=last_seen_date,
        next_expected_date=last_seen_date + timedelta(days=interval),
        occurrence_count=len(occurrences),
        price_change_minor=baseline.price_change_minor,
        price_changed_at=last_seen_date if price_changed else None,
        transaction_ids=tuple(occurrence.id for occurrence in occurrences),
    )


def classify_cadence(interval_days: int) -> DetectedCadence | None:
    """The cadence whose band contains ``interval_days``, or `None` if no band does."""
    for cadence, low, high in CADENCE_BANDS:
        if low <= interval_days <= high:
            return cadence
    return None


def _interval_within(gap: int, interval: int) -> bool:
    """True if ``gap`` sits within the cadence tolerance of the median ``interval``."""
    deviation = abs(gap - interval)
    if deviation <= INTERVAL_TOLERANCE_FLOOR_DAYS:
        return True
    # Cross-multiplied rather than divided so the tolerance is exactly ±25 % with no rounding.
    return deviation * 100 <= interval * INTERVAL_TOLERANCE_PERCENT


def _amount_within(amount: int, baseline: int) -> bool:
    """True if ``amount`` sits within the amount tolerance of ``baseline``."""
    deviation = abs(amount - baseline)
    if deviation <= AMOUNT_TOLERANCE_FLOOR_MINOR:
        return True
    # Integer arithmetic, because a percentage of a money value is still a money value and
    # floats are forbidden on those anywhere (database skill).
    return deviation * 100 <= abs(baseline) * AMOUNT_TOLERANCE_PERCENT


def _amount_baseline(amounts: Sequence[int]) -> _AmountBaseline | None:
    """The amount the occurrences agree on, or `None` if they never agree on one.

    Two ways to agree. Either every amount sits within tolerance of the median — the ordinary
    case — or all but the newest do and the newest steps outside it, which is a price change:
    the series keeps its rhythm, re-baselines on the new amount, and records the signed step.
    Regularity is judged on the pre-change occurrences precisely so that a price change cannot
    make a series fail the very test it is the explanation for.
    """
    median_all = median_low(amounts)
    if all(_amount_within(amount, median_all) for amount in amounts):
        return _AmountBaseline(median_all, None)

    earlier, newest = amounts[:-1], amounts[-1]
    median_earlier = median_low(earlier)
    if not all(_amount_within(amount, median_earlier) for amount in earlier):
        return None
    if _amount_within(newest, median_earlier):
        # The group failed the amount test and the newest occurrence is not the explanation —
        # a tolerance measured off a different baseline is not a second chance at qualifying.
        return None
    return _AmountBaseline(newest, newest - median_earlier)


def _label(occurrences: Sequence[Transaction]) -> str:
    """The prettiest observed merchant: the most frequent label, the shortest one when tied.

    Only the default a new series is created with — the user renames it and detection never
    writes over that (`PROJECT.md` §12).
    """
    counts = Counter(
        label
        for occurrence in occurrences
        if (label := (occurrence.merchant or occurrence.description_clean).strip())
    )
    if not counts:
        return occurrences[-1].description_clean
    # Shortest breaks a frequency tie because the extra characters are the bank's, not the
    # merchant's; the alphabetical last resort only exists to keep the choice deterministic.
    return min(counts, key=lambda label: (-counts[label], len(label), label))
