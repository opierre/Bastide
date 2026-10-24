"""Recognise the monthly settlement of a deferred-debit card on the account it is drawn from.

A deferred-debit card posts each purchase to its own holding account and settles the month's
total against the current account in one debit. Counted as spending, that debit would book the
month's card purchases a second time, so it is filed under a `transfer`-kind category instead.

Only ever applied for a user who tracks a deferred-debit card account: without one, the
settlement is the *only* record of that spending, and filing it as a transfer would erase it.
"""

import unicodedata

#: The system category a settlement is filed under (seeded in `app/core/seed.py`).
CARD_SETTLEMENT_CATEGORY_KEY = "category.finance.card_settlement"

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
