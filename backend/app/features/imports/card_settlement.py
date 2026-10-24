"""Recognise the monthly settlement of a deferred-debit card on the account it is drawn from.

A deferred-debit card posts each purchase to its own holding account and settles the month's
total against the current account in one debit. Counted as spending, that debit would book the
month's card purchases a second time, so it is filed under a `transfer`-kind category instead.

Only ever applied for a user who tracks a deferred-debit card account: without one, the
settlement is the *only* record of that spending, and filing it as a transfer would erase it.
"""

import hashlib
import unicodedata
from collections.abc import Sequence
from datetime import timedelta

from app.features.imports.ledger import Booked

#: The system category a settlement is filed under (seeded in `app/core/seed.py`).
CARD_SETTLEMENT_CATEGORY_KEY = "category.finance.card_settlement"

#: How far from the settlement a card statement's own reset line may sit and still be taken for
#: it. Banks date that line on the cycle close or on the debit, rarely more than a few days apart.
RESET_WINDOW = timedelta(days=10)


#: Label fragments French banks use for the settlement debit, accent-folded and uppercased.
#: Each names the settlement itself; a bare `CARTE` or `CB` would match every card purchase.
_SETTLEMENT_MARKERS = (
    "FACTURE CARTE",
    "FACTURE CB",
    "RELEVE CARTE",
    "RELEVE CB",
    "RELEVE DIFFERE",
    "DEBIT DIFFERE",
    "DEBIT MENSUEL CARTE",
    "CARTE DIFFEREE",
    "CB DIFFERE",
    "TOTAL CB",
)


def _fold(text: str) -> str:
    """Uppercase with accents stripped, so `RELEVÉ` and `RELEVE` read the same."""
    decomposed = unicodedata.normalize("NFKD", text)
    return "".join(c for c in decomposed if not unicodedata.combining(c)).upper()


def is_card_settlement(description_clean: str, amount_minor: int) -> bool:
    """Whether a row reads as a deferred-debit card settlement.

    Only an outflow qualifies: a settlement is a debit on the current account, and a credit
    carrying one of these labels (a refund, a reversal) is something else.
    """
    if amount_minor >= 0:
        return False
    label = _fold(description_clean)
    return any(marker in label for marker in _SETTLEMENT_MARKERS)


def cycle_length(card_rows: Sequence[Booked], settlement_minor: int) -> int | None:
    """How many of a card's unsettled rows the settlement pays, or `None` when none fit.

    ``card_rows`` are the card's rows no settlement has claimed yet, in booking order. A cycle
    is the run from the oldest of them up to a cycle close — a day boundary, since a bank
    closes a cycle at the end of a day — whose total is exactly the settlement. Rows booked
    after the close but before the debit lands belong to the next cycle, which is why the
    whole list is not simply summed.

    The earliest fitting boundary wins: a later one can only fit too if the rows between net to
    zero (a purchase and its refund), and those then wait for the next settlement rather than
    being pulled into this one.
    """
    total = 0
    for index, row in enumerate(card_rows):
        total += row.amount_minor
        at_day_end = (
            index + 1 == len(card_rows) or card_rows[index + 1].booked_date != row.booked_date
        )
        if at_day_end and total == settlement_minor:
            return index + 1
    return None


def offset_dedup_hash(settlement_id: str) -> str:
    """The dedup hash of the card-side credit posted for a settlement.

    Derived from the settlement rather than from the row's content, so it can never collide
    with a statement row's hash and a second posting for the same settlement is detectable.
    """
    return hashlib.sha256(f"card-settlement:{settlement_id}".encode()).hexdigest()
