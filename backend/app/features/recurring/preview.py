"""Grading a group of transactions the user says is recurring. Pure — no DB access.

Detection answers yes or no: a group either qualifies as a series or yields nothing. A user who
marks a charge as recurring is asking a softer question — *how sure* would the app be — so the
same tolerances are applied here and graded rather than gated:

- `high`: the detector would accept the group as it is.
- `medium`: the cadence is recognised, but only two charges back it, or exactly one gap or one
  amount steps outside the tolerance.
- `low`: no rhythm — the group can only become an `irregular` series.
"""

from collections.abc import Sequence
from dataclasses import dataclass
from itertools import pairwise
from statistics import median_low

from app.features.recurring.detector import (
    MIN_OCCURRENCES,
    amount_baseline,
    amount_within,
    classify_cadence,
    interval_within,
    series_label,
)
from app.features.recurring.schemas import (
    Cadence,
    DetectedCadence,
    PreviewConfidence,
    PreviewReason,
)
from app.features.transactions.models import Transaction

_CADENCE_REASONS: dict[DetectedCadence, PreviewReason] = {
    "weekly": "cadence_weekly",
    "monthly": "cadence_monthly",
    "quarterly": "cadence_quarterly",
    "yearly": "cadence_yearly",
}


@dataclass(frozen=True, slots=True)
class Grade:
    """What a group of transactions would make as a series, and how sure that is."""

    confidence: PreviewConfidence
    reasons: tuple[PreviewReason, ...]
    cadence: Cadence
    #: `0` when there is no rhythm, as for a declared `irregular` series.
    median_interval_days: int
    label: str
    #: Signed, so negative — the group is made of outflows.
    expected_amount_minor: int
    #: The graded transactions, oldest first.
    transactions: tuple[Transaction, ...]


def grade(transactions: Sequence[Transaction]) -> Grade:
    """Grade ``transactions`` (at least one) as a would-be series.

    Raises:
        ValueError: ``transactions`` is empty — there is nothing to grade.
    """
    if not transactions:
        raise ValueError("Cannot grade an empty group.")
    occurrences = tuple(sorted(transactions, key=lambda t: (t.booked_date, t.id)))
    amounts = [occurrence.amount_minor for occurrence in occurrences]
    label = series_label(occurrences)

    if len(occurrences) < 2:
        return _low(occurrences, label, amounts, ("occurrences", "too_few_occurrences"))

    gaps = [
        (later.booked_date - earlier.booked_date).days for earlier, later in pairwise(occurrences)
    ]
    interval = median_low(gaps)
    cadence = classify_cadence(interval)
    if cadence is None:
        return _low(occurrences, label, amounts, ("occurrences", "no_rhythm"))

    gaps_outside = sum(1 for gap in gaps if not interval_within(gap, interval))
    baseline = amount_baseline(amounts)
    if baseline is not None:
        expected = baseline.expected_amount_minor
        amounts_outside = 0
        amount_reason: PreviewReason = (
            "amount_stable" if baseline.price_change_minor is None else "amount_changed"
        )
    else:
        expected = median_low(amounts)
        amounts_outside = sum(1 for amount in amounts if not amount_within(amount, expected))
        amount_reason = "amount_outside_tolerance"

    reasons: list[PreviewReason] = ["occurrences", _CADENCE_REASONS[cadence], amount_reason]
    if gaps_outside:
        reasons.append("gap_outside_tolerance")
    too_few = len(occurrences) < MIN_OCCURRENCES
    if too_few:
        reasons.append("too_few_occurrences")

    deviations = gaps_outside + amounts_outside
    if deviations > 1:
        return _low(occurrences, label, amounts, (*reasons, "no_rhythm"))
    confidence: PreviewConfidence = "medium" if too_few or deviations else "high"
    return Grade(
        confidence=confidence,
        reasons=tuple(reasons),
        cadence=cadence,
        median_interval_days=interval,
        label=label,
        expected_amount_minor=expected,
        transactions=occurrences,
    )


def _low(
    occurrences: tuple[Transaction, ...],
    label: str,
    amounts: list[int],
    reasons: tuple[PreviewReason, ...],
) -> Grade:
    """A group with no rhythm: it can only be saved as an `irregular` series."""
    return Grade(
        confidence="low",
        reasons=reasons,
        cadence="irregular",
        median_interval_days=0,
        label=label,
        expected_amount_minor=median_low(amounts),
        transactions=occurrences,
    )
