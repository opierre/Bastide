"""Normalising a bank label into the key occurrences are grouped by. Pure — no DB access.

Every grouping decision the detector makes rests on this key, so it has one job with two
failure modes that cost the same: two charges from the same merchant must produce the same
string even though the bank writes a different date and card sequence into each one, and two
genuinely different merchants must never collapse into one.

Deliberately independent of `rules.suggest`, which strips a superficially similar vocabulary:
that module picks a *pattern a user will read and edit*, this one builds a *stable machine key*.
Sharing one implementation would tie two different definitions of "good" to the same knobs, and
the architecture skill forbids reaching into another feature for it either way.
"""

import re

from app.features.transactions.models import Transaction

# Wrapper words French banks prepend or interleave around the part of the label that identifies
# who was paid. « CB CARREFOUR » and « PAIEMENT CB CARREFOUR » are the same merchant, so none of
# these may survive into the key. Only words that carry no merchant information at all.
_NOISE_WORDS = frozenset(
    {
        "achat",
        "avoir",
        "carte",
        "cb",
        "cheque",
        "chq",
        "dab",
        "du",
        "ech",
        "echeance",
        "fact",
        "facture",
        "le",
        "mandat",
        "no",
        "n°",
        "paiement",
        "prelevement",
        "prelv",
        "prlv",
        "ref",
        "reference",
        "remise",
        "retrait",
        "rum",
        "sepa",
        "tpe",
        "vir",
        "virement",
    }
)

#: Digits in a token beyond which it reads as an identifier the bank varies per occurrence — a
#: card sequence, a mandate, a reference number — rather than part of a name. « CB4979 » and
#: « REF:250114887 » are noise; « CARREFOUR 15 » and « E15 » keep theirs.
_IDENTIFIER_DIGIT_COUNT = 3

_WHITESPACE_RE = re.compile(r"\s+")
_EDGE_PUNCTUATION_RE = re.compile(r"^[^\w]+|[^\w]+$")
_DIGIT_RE = re.compile(r"\d")
_LETTER_RE = re.compile(r"[^\W\d_]")


def merchant_key(transaction: Transaction) -> str:
    """The key ``transaction`` is grouped under: its merchant, stripped of per-occurrence noise.

    Prefers `merchant` over `description_clean` (`PROJECT.md` §12) — the import pipeline already
    took the bank's wrapper prefix off it. The same stripping runs over either source anyway:
    `imports.canonical.extract_merchant` removes a *prefix*, so an extracted merchant still
    carries the embedded date and card sequence the bank rewrites every month, and grouping on
    it verbatim would file each occurrence of a subscription under a key of its own.
    """
    source = (transaction.merchant or "").strip() or transaction.description_clean
    return normalize_label(source)


def normalize_label(label: str) -> str:
    """Case-fold ``label``, collapse its whitespace, and drop the parts that vary per occurrence.

    Falls back to the merely case-folded and collapsed label when nothing survives the strip: a
    label made entirely of noise says little, but an empty key would file every such row in the
    same group and invent a series out of unrelated charges.
    """
    collapsed = _WHITESPACE_RE.sub(" ", label).strip().casefold()
    kept = [token for token in collapsed.split(" ") if token and not _is_variable(token)]
    return " ".join(kept) if kept else collapsed


def _is_variable(token: str) -> bool:
    """True for wrapper words, embedded dates, card sequences, and reference numbers."""
    stripped = _EDGE_PUNCTUATION_RE.sub("", token)
    if not stripped:
        return True
    # Both forms are tested because the punctuation is part of some wrapper words (« N° ») and
    # mere separator noise around others (« CB, »).
    if token in _NOISE_WORDS or stripped in _NOISE_WORDS:
        return True
    if not _LETTER_RE.search(stripped):
        # No letters at all: « 14/05/2026 », « 4979 », « 12,50 ».
        return True
    return len(_DIGIT_RE.findall(stripped)) >= _IDENTIFIER_DIGIT_COUNT
