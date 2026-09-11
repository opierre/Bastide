"""Pre-fills the « Toujours catégoriser ainsi » rule form from a transaction. Pure — no DB.

The suggestion is a *default*, never a constraint: the client may override every field before
posting it to `/rules/from-transaction`. So the goal here is a pattern a user recognises at a
glance and rarely has to edit — not a provably optimal one.
"""

import re
from dataclasses import dataclass

from app.features.rules.schemas import MatchField, MatchType
from app.features.transactions.models import Transaction

#: Mirrors the `pattern` limit on the rule schemas — a suggestion the API would reject is no use.
MAX_PATTERN_LENGTH = 255

# Wrapper words French banks prepend to the part of the label that identifies who was paid:
# « PRLV SEPA ASSUR MAIF » is a direct debit to ASSUR MAIF, and a rule on PRLV or SEPA would
# match half the statement. Deliberately only words that carry no merchant information.
_NOISE_WORDS = frozenset(
    {
        "ACHAT",
        "AVOIR",
        "CARTE",
        "CB",
        "CHEQUE",
        "CHQ",
        "DAB",
        "DU",
        "ECH",
        "ECHEANCE",
        "FACT",
        "FACTURE",
        "LE",
        "MANDAT",
        "NO",
        "N°",
        "PAIEMENT",
        "PRELEVEMENT",
        "PRELV",
        "PRLV",
        "REF",
        "REFERENCE",
        "REMISE",
        "RETRAIT",
        "RUM",
        "SEPA",
        "TPE",
        "VIR",
        "VIREMENT",
    }
)

#: Digits in a token beyond which it reads as an identifier (card sequence, mandate, reference)
#: rather than part of a name — « REF:4979123 » is noise, « CARREFOUR 15 » keeps its letters.
_IDENTIFIER_DIGIT_COUNT = 3

_LEADING_TRAILING_PUNCTUATION_RE = re.compile(r"^[^\w]+|[^\w]+$")
_DIGIT_RE = re.compile(r"\d")
_LETTER_RE = re.compile(r"[^\W\d_]")


@dataclass(frozen=True, slots=True)
class RuleSuggestion:
    """A `(match_field, match_type, pattern)` triplet the rule form can be pre-filled with."""

    match_field: MatchField
    match_type: MatchType
    pattern: str


def suggest_rule(transaction: Transaction) -> RuleSuggestion:
    """Propose the rule that would have categorized ``transaction`` the way the user just did.

    Prefers `merchant` + `equals` when the import extracted a merchant: that field is already
    the label with the bank's noise stripped, so an exact match on it is both the tightest and
    the most legible rule available. Falls back to `description_clean` + `contains` on the most
    distinctive run of words in the label.
    """
    merchant = (transaction.merchant or "").strip()
    if merchant:
        return RuleSuggestion("merchant", "equals", merchant[:MAX_PATTERN_LENGTH])

    description = transaction.description_clean
    return RuleSuggestion("description_clean", "contains", _distinctive_run(description))


def _distinctive_run(description_clean: str) -> str:
    """The longest run of consecutive words in the label that identify who was paid.

    Runs are joined with a single space, which keeps the result a literal substring of
    ``description_clean`` — descriptions arrive with their whitespace already collapsed (see
    `imports.canonical.clean_description`), so a `contains` rule on the run matches this very
    transaction. Ties go to the earliest run: the merchant is named before the reference data.
    """
    runs: list[list[str]] = [[]]
    for token in description_clean.split():
        if _is_noise(token):
            runs.append([])
        else:
            runs[-1].append(token)

    candidates = [run for run in runs if run]
    if not candidates:
        # Nothing but wrapper words and identifiers. The whole label is a poor pattern, but it
        # is the only honest one — the user edits it in the modal.
        return description_clean[:MAX_PATTERN_LENGTH]

    best = max(candidates, key=_letter_count)
    return _capped(best)


def _is_noise(token: str) -> bool:
    """True for wrapper words, dates, card-sequence digits, and reference numbers."""
    normalized = _LEADING_TRAILING_PUNCTUATION_RE.sub("", token).upper()
    if not normalized or normalized in _NOISE_WORDS:
        return True
    if not _LETTER_RE.search(normalized):
        # No letters at all: « 14/05/2026 », « 4979 », « 12,50 ».
        return True
    return len(_DIGIT_RE.findall(normalized)) >= _IDENTIFIER_DIGIT_COUNT


def _letter_count(tokens: list[str]) -> int:
    return sum(len(_LETTER_RE.findall(token)) for token in tokens)


def _capped(tokens: list[str]) -> str:
    """Join ``tokens``, dropping trailing words rather than cutting the last one mid-name."""
    pattern = " ".join(tokens)
    while len(pattern) > MAX_PATTERN_LENGTH and len(tokens) > 1:
        tokens = tokens[:-1]
        pattern = " ".join(tokens)
    return pattern[:MAX_PATTERN_LENGTH]
