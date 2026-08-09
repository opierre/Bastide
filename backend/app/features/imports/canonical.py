"""The canonical transaction shape every import-format parser normalizes into.

No downstream code (dedup, persistence, categorisation) knows or cares which parser produced a
row. Format-specific parsers (``parsers/ofx.py``) only need to produce a `RawTransaction`; this
module owns cleaning the description, guessing a merchant, and computing the dedup hash.
"""

import hashlib
import re
from dataclasses import dataclass
from datetime import date

_WHITESPACE_RE = re.compile(r"\s+")
# Any letter or digit, in any script — a memo made of nothing but punctuation says nothing.
_ALPHANUMERIC_RE = re.compile(r"[^\W_]")
_NOISE_PREFIX_RE = re.compile(
    r"^(CB|CARTE|PAIEMENT CB|ACHAT CB|VIR(?:EMENT)?|PRLV(?:EMENT)?)\s+",
    re.IGNORECASE,
)


@dataclass(frozen=True, slots=True)
class RawTransaction:
    """A transaction as extracted by a format-specific parser, before normalization."""

    booked_date: date
    amount_minor: int
    description_raw: str

    #: Bank free-text detail alongside the label (OFX `MEMO`), when the format carries one and
    #: it says something the description doesn't. Display-only: nothing derives from it.
    memo: str | None = None
    fitid: str | None = None
    value_date: date | None = None


@dataclass(frozen=True, slots=True)
class CanonicalTransaction:
    """A transaction normalized to the shape shared by every import source."""

    booked_date: date
    value_date: date | None
    amount_minor: int
    currency: str
    description_raw: str
    description_clean: str
    memo: str | None
    merchant: str | None
    fitid: str | None
    dedup_hash: str


def clean_description(raw: str) -> str:
    """Collapse whitespace runs and trim, for both matching and display."""
    return _WHITESPACE_RE.sub(" ", raw).strip()


def clean_memo(raw: str | None) -> str | None:
    """The memo as it should be displayed, or `None` when it carries nothing to display.

    Banks emit a placeholder instead of omitting the tag — Crédit Agricole ships
    ``<MEMO>.`` on every row that has no real detail — so a memo without a single letter
    or digit is treated as absent. Kept here rather than in the OFX parser because it is
    a property of the value, not of the format that carried it.
    """
    if raw is None:
        return None
    cleaned = clean_description(raw)
    return cleaned if _ALPHANUMERIC_RE.search(cleaned) else None


def extract_merchant(description_clean: str) -> str | None:
    """Best-effort merchant guess: the cleaned description with bank-noise prefixes stripped."""
    if not description_clean:
        return None
    stripped = _NOISE_PREFIX_RE.sub("", description_clean).strip()
    return stripped or None


def compute_dedup_hash(
    account_id: str, booked_date: date, amount_minor: int, description_clean: str
) -> str:
    """Stable hash used to dedup rows that lack a bank-issued `fitid` (see the database skill)."""
    payload = "|".join(
        [account_id, booked_date.isoformat(), str(amount_minor), description_clean.upper()]
    )
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def normalize(raw: RawTransaction, account_id: str, currency: str) -> CanonicalTransaction:
    """Normalize a parser's raw output into the canonical shape for the given account."""
    description_clean = clean_description(raw.description_raw)
    dedup_hash = compute_dedup_hash(
        account_id, raw.booked_date, raw.amount_minor, description_clean
    )
    return CanonicalTransaction(
        booked_date=raw.booked_date,
        value_date=raw.value_date,
        amount_minor=raw.amount_minor,
        currency=currency,
        description_raw=raw.description_raw,
        description_clean=description_clean,
        memo=clean_memo(raw.memo),
        merchant=extract_merchant(description_clean),
        fitid=raw.fitid,
        dedup_hash=dedup_hash,
    )
