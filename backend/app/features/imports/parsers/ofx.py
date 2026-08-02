"""Tolerant OFX 1.x SGML / OFX 2.x XML parser. QFX (OFX with Quicken extras) reuses this path.

French banks commonly emit OFX 1.x SGML with unclosed leaf tags (`<NAME>foo` with no
`</NAME>`) and Latin-1 encoding rather than well-formed XML, so this deliberately does not use
an XML parser: it scans for `<STMTTRN>...</STMTTRN>` blocks (always closed, since STMTTRN is a
repeated container) and pulls leaf values with a tag-bounded regex that stops at the next tag
or line end, which works whether or not that leaf tag is itself closed.
"""

import re
from datetime import date
from decimal import ROUND_HALF_UP, Decimal, InvalidOperation

from app.features.imports.canonical import RawTransaction


class OfxParseError(Exception):
    """Raised when a file cannot be parsed as OFX/QFX at all, or a record is malformed."""


_OFX_ROOT_RE = re.compile(r"<OFX[>\s]", re.IGNORECASE)
_STMTTRN_RE = re.compile(r"<STMTTRN>(.*?)</STMTTRN>", re.IGNORECASE | re.DOTALL)


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

        name = _tag(block, "NAME")
        memo = _tag(block, "MEMO")
        description_raw = f"{name} {memo}" if name and memo and name != memo else name or memo or ""

        dtuser = _tag(block, "DTUSER") or _tag(block, "DTAVAIL")

        transactions.append(
            RawTransaction(
                booked_date=_parse_date(dtposted),
                value_date=_parse_date(dtuser) if dtuser else None,
                amount_minor=_parse_amount_minor(trnamt),
                description_raw=description_raw,
                fitid=_tag(block, "FITID"),
            )
        )
    return transactions
