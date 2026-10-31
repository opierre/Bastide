"""Which pairs of recurring series look like one subscription under two labels. Pure — no DB.

A merchant that renames itself mid-subscription (« STREAMCO », then « STREAMCO - STREAMCO
TV ») splits into two series, because detection groups on the label. This module only
*proposes* the pair; the user decides, and a merge or a « these are two » is remembered by
the service.

The test is deliberately narrow — same account, same cadence, close amounts, and labels where
one extends the other or both share their leading word and most of the rest — because a wrong
proposal costs the user a click, but the two series it names must at least plausibly be one.
"""

from collections.abc import Collection, Sequence
from dataclasses import dataclass

from app.features.recurring.models import RecurringSeries

#: Two expected amounts within this share of the larger are close enough: wider than the
#: detector's own ±10 %, since a renamed offer often comes with a new price.
AMOUNT_TOLERANCE_PERCENT = 25

#: Shared share of the two keys' words, past which labels with the same leading word match.
MIN_SHARED_WORDS_PERCENT = 50

#: A leading word shorter than this (« e », « sa ») says nothing about the merchant.
MIN_LEADING_WORD_LENGTH = 3

#: Statuses that never take part: a dismissed series is the user's « not a subscription ».
_EXCLUDED_STATUSES = frozenset({"dismissed"})


@dataclass(frozen=True, slots=True)
class MergeProposal:
    """Two series to merge: `source` folds into `target`."""

    target: RecurringSeries
    source: RecurringSeries


def dismissal_key(account_id: str, key_a: str, key_b: str) -> tuple[str, str, str]:
    """The order-free identity of a pair, as `recurring_merge_dismissals` stores it."""
    first, second = sorted((key_a, key_b))
    return account_id, first, second


def propose_merges(
    series: Sequence[RecurringSeries], dismissed: Collection[tuple[str, str, str]]
) -> list[MergeProposal]:
    """Every pair of ``series`` that looks like one subscription, newest-charging target first.

    The target is the series still charging (the later `last_seen_date`), so the merged series
    keeps the label the bank uses now; a tie keeps the older series. Manual series are left
    out: the user declared them, and detection does not group their charges.
    """
    eligible = [one for one in series if not one.is_manual and one.status not in _EXCLUDED_STATUSES]
    proposals: list[MergeProposal] = []
    for index, first in enumerate(eligible):
        for second in eligible[index + 1 :]:
            if not _alike(first, second):
                continue
            if dismissal_key(first.account_id, first.merchant_key, second.merchant_key) in (
                dismissed
            ):
                continue
            target, source = _order(first, second)
            proposals.append(MergeProposal(target=target, source=source))
    proposals.sort(key=lambda p: (p.target.label.casefold(), p.source.label.casefold()))
    return proposals


def _alike(a: RecurringSeries, b: RecurringSeries) -> bool:
    return (
        a.account_id == b.account_id
        and a.cadence == b.cadence
        and _amounts_close(a.expected_amount_minor, b.expected_amount_minor)
        and keys_alike(a.merchant_key, b.merchant_key)
    )


def keys_alike(key_a: str, key_b: str) -> bool:
    """Whether two merchant keys plausibly name the same merchant.

    Either one key's words open the other's (« streamco » and « streamco streamco tv »),
    or both open on the same word and share most of their words.
    """
    words_a, words_b = key_a.split(), key_b.split()
    if not words_a or not words_b or key_a == key_b:
        return False
    if words_a[0] != words_b[0] or len(words_a[0]) < MIN_LEADING_WORD_LENGTH:
        return False
    shorter, longer = sorted((words_a, words_b), key=len)
    if longer[: len(shorter)] == shorter:
        return True
    set_a, set_b = set(words_a), set(words_b)
    return len(set_a & set_b) * 100 >= len(set_a | set_b) * MIN_SHARED_WORDS_PERCENT


def _amounts_close(a: int, b: int) -> bool:
    # Integer arithmetic: a share of a money value is still money, and floats are forbidden.
    return abs(a - b) * 100 <= max(abs(a), abs(b)) * AMOUNT_TOLERANCE_PERCENT


def _order(a: RecurringSeries, b: RecurringSeries) -> tuple[RecurringSeries, RecurringSeries]:
    """`(target, source)`: the series charging most recently is kept."""
    if (b.last_seen_date, a.created_at) > (a.last_seen_date, b.created_at):
        return b, a
    return a, b
