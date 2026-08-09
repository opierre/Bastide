"""Tolerant OFX 1.x SGML / OFX 2.x XML parser. QFX (OFX with Quicken extras) reuses this path.

French banks commonly emit OFX 1.x SGML with unclosed leaf tags (`<NAME>foo` with no
`</NAME>`) and Latin-1 encoding rather than well-formed XML, so this deliberately does not use
an XML parser: it scans for `<STMTTRN>...</STMTTRN>` blocks (always closed, since STMTTRN is a
repeated container) and pulls leaf values with a tag-bounded regex that stops at the next tag
or line end, which works whether or not that leaf tag is itself closed.
"""

import re
from dataclasses import dataclass
from datetime import date
from decimal import ROUND_HALF_UP, Decimal, InvalidOperation

from app.features.imports.canonical import RawTransaction


class OfxParseError(Exception):
    """Raised when a file cannot be parsed as OFX/QFX at all, or a record is malformed."""


@dataclass(frozen=True, slots=True)
class LedgerBalance:
    """The closing balance a statement declares for its account (`LEDGERBAL`).

    This is the one figure in the file that states where the account actually
    stood, as opposed to how it moved — which is what lets an import work out
    the account's opening balance instead of asking the user to know it.
    """

    amount_minor: int

    #: `DTASOF` — the date the balance holds at. Optional: it is mandatory in
    #: the spec but not every exporter emits it, and the statement's last
    #: booked date is a serviceable stand-in.
    as_of: date | None


_OFX_ROOT_RE = re.compile(r"<OFX[>\s]", re.IGNORECASE)
_STMTTRN_RE = re.compile(r"<STMTTRN>(.*?)</STMTTRN>", re.IGNORECASE | re.DOTALL)
# `AVAILBAL` carries a different figure (funds available, including holds), so
# the tag is matched exactly rather than on a `BAL` suffix.
_LEDGERBAL_RE = re.compile(r"<LEDGERBAL>(.*?)(?:</LEDGERBAL>|\Z)", re.IGNORECASE | re.DOTALL)


def _tag(block: str, tag: str) -> str | None:
    match = re.search(rf"<{tag}>\s*([^<\r\n]*)", block, re.IGNORECASE)
    if match is None:
        return None
    value = match.group(1).strip()
    return value or None


def decode(raw_bytes: bytes) -> str:
    """Decode OFX bytes, falling back to Latin-1 (common in French bank exports)."""
    try:
        return raw_bytes.decode("utf-8")
    except UnicodeDecodeError:
        return raw_bytes.decode("latin-1")


def _parse_date(value: str) -> date:
    digits = value[:8]
    try:
        return date(int(digits[0:4]), int(digits[4:6]), int(digits[6:8]))
    except (ValueError, IndexError) as exc:
        raise OfxParseError(f"Invalid OFX date: {value!r}") from exc


def _parse_amount_minor(value: str) -> int:
    try:
        decimal_value = Decimal(value)
    except InvalidOperation as exc:
        raise OfxParseError(f"Invalid OFX amount: {value!r}") from exc
    minor = (decimal_value * 100).quantize(Decimal("1"), rounding=ROUND_HALF_UP)
    return int(minor)


def parse(raw_bytes: bytes) -> list[RawTransaction]:
    """Parse OFX/QFX bytes into raw transactions (no dedup/normalization).

    Raises:
        OfxParseError: the file isn't OFX at all, or a `STMTTRN` is missing `DTPOSTED`/`TRNAMT`.
    """
    text = decode(raw_bytes)
    if _OFX_ROOT_RE.search(text) is None:
        raise OfxParseError("Not an OFX file: missing <OFX> root element.")

    transactions: list[RawTransaction] = []
    for block in _STMTTRN_RE.findall(text):
        dtposted = _tag(block, "DTPOSTED")
        trnamt = _tag(block, "TRNAMT")
        if dtposted is None or trnamt is None:
            raise OfxParseError("STMTTRN missing DTPOSTED or TRNAMT.")

        # `NAME` is the payee/label and `MEMO` the bank's free-text detail. They are kept
        # apart so the description (and everything derived from it — merchant, rules,
        # dedup hash) stays the label alone, with the memo carried as its own field.
        name = _tag(block, "NAME")
        memo = _tag(block, "MEMO")
        description_raw = name or memo or ""
        # A memo echoing the name adds nothing to display, and a memo-only record has
        # already been promoted to the description above.
        memo = memo if memo and memo != name and memo != description_raw else None

        dtuser = _tag(block, "DTUSER") or _tag(block, "DTAVAIL")

        transactions.append(
            RawTransaction(
                booked_date=_parse_date(dtposted),
                value_date=_parse_date(dtuser) if dtuser else None,
                amount_minor=_parse_amount_minor(trnamt),
                description_raw=description_raw,
                memo=memo,
                fitid=_tag(block, "FITID"),
            )
        )
    return transactions


def parse_ledger_balance(raw_bytes: bytes) -> LedgerBalance | None:
    """The closing balance the statement declares, or `None` when it declares none.

    Never raises: the balance is a bonus the file may or may not carry, and a
    statement we can't read one out of must still import its transactions. A
    file holding several statements is read for the first, matching how the
    client picks the account block it routes on.
    """
    text = decode(raw_bytes)
    match = _LEDGERBAL_RE.search(text)
    if match is None:
        return None

    balamt = _tag(match.group(1), "BALAMT")
    if balamt is None:
        return None

    try:
        amount_minor = _parse_amount_minor(balamt)
    except OfxParseError:
        return None

    dtasof = _tag(match.group(1), "DTASOF")
    try:
        as_of = _parse_date(dtasof) if dtasof else None
    except OfxParseError:
        as_of = None

    return LedgerBalance(amount_minor=amount_minor, as_of=as_of)
