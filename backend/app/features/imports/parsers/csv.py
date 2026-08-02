"""Template-driven CSV parser for French bank exports.

CSV has no standard shape, so every bank needs a saved `csv_template` (delimiter, encoding,
date format, decimal separator, amount layout, column mapping) created once and reused. This
module only turns `(bytes, template)` into `RawTransaction`s; dedup/normalization is shared
with OFX in `canonical.py`.
"""

import csv
from datetime import datetime
from decimal import Decimal, InvalidOperation

from app.features.imports.canonical import RawTransaction

_REQUIRED_SIGNED_COLUMNS = ("booked_date", "description", "amount")
_REQUIRED_DEBIT_CREDIT_COLUMNS = ("booked_date", "description", "debit", "credit")
_THOUSANDS_SEPARATOR_CHARS = "   "  # space, NBSP, narrow no-break space


class CsvParseError(Exception):
    """Raised when a file can't be parsed with the given template."""


class CsvTemplateConfig:
    """The subset of a `csv_template` needed to parse a file — decoupled from the ORM row."""

    def __init__(
        self,
        delimiter: str,
        encoding: str,
        date_format: str,
        decimal_separator: str,
        amount_strategy: str,
        column_map: dict[str, str],
        header_offset: int = 0,
    ) -> None:
        self.delimiter = delimiter
        self.encoding = encoding
        self.date_format = date_format
        self.decimal_separator = decimal_separator
        self.amount_strategy = amount_strategy
        self.column_map = column_map
        self.header_offset = header_offset


def validate_template_config(config: CsvTemplateConfig) -> None:
    """Structural validation that doesn't require a sample file.

    Raises:
        CsvParseError: an unsupported amount strategy, a required canonical field missing from
            `column_map`, or a `date_format` that isn't a usable `strptime` pattern.
    """
    if config.amount_strategy == "signed":
        required = _REQUIRED_SIGNED_COLUMNS
    elif config.amount_strategy == "debit_credit":
        required = _REQUIRED_DEBIT_CREDIT_COLUMNS
    else:
        raise CsvParseError(f"Unknown amount_strategy: {config.amount_strategy!r}")

    missing = [field for field in required if field not in config.column_map]
    if missing:
        raise CsvParseError(f"column_map is missing required field(s): {', '.join(missing)}")

    if len(config.delimiter) != 1:
        raise CsvParseError(f"delimiter must be a single character: {config.delimiter!r}")

    if config.decimal_separator not in (",", "."):
        raise CsvParseError(f"decimal_separator must be ',' or '.': {config.decimal_separator!r}")

    try:
        datetime(2000, 1, 1).strftime(config.date_format)
    except ValueError as exc:
        raise CsvParseError(f"Invalid date_format: {config.date_format!r}") from exc


def _decode(raw_bytes: bytes, encoding: str) -> str:
    try:
        return raw_bytes.decode(encoding)
    except (UnicodeDecodeError, LookupError) as exc:
        raise CsvParseError(f"Could not decode file as {encoding!r}: {exc}") from exc


def _column_index(header: list[str], key: str) -> int:
    if key.isdigit():
        return int(key)
    try:
        return header.index(key)
    except ValueError as exc:
        raise CsvParseError(f"Column {key!r} not found in header {header!r}") from exc


def _parse_date(value: str, date_format: str) -> datetime:
    try:
        return datetime.strptime(value.strip(), date_format)
    except ValueError as exc:
        raise CsvParseError(f"Invalid date {value!r} for format {date_format!r}") from exc


def _parse_decimal(value: str, decimal_separator: str) -> Decimal:
    cleaned = value.strip()
    for char in _THOUSANDS_SEPARATOR_CHARS:
        cleaned = cleaned.replace(char, "")
    if decimal_separator != ".":
        cleaned = cleaned.replace(".", "").replace(decimal_separator, ".")
    try:
        return Decimal(cleaned)
    except InvalidOperation as exc:
        raise CsvParseError(f"Invalid amount {value!r}") from exc


def _amount_minor(decimal_value: Decimal) -> int:
    return int((decimal_value * 100).to_integral_value())


def parse(raw_bytes: bytes, config: CsvTemplateConfig) -> list[RawTransaction]:
    """Parse CSV bytes into raw transactions using a template's column mapping.

    Raises:
        CsvParseError: the template is structurally invalid, or a row can't be parsed against it.
    """
    validate_template_config(config)

    text = _decode(raw_bytes, config.encoding)
    lines = text.splitlines()[config.header_offset :]
    if not lines:
        raise CsvParseError("No rows left after applying header_offset.")

    rows = list(csv.reader(lines, delimiter=config.delimiter))
    header, data_rows = rows[0], rows[1:]

    booked_date_idx = _column_index(header, config.column_map["booked_date"])
    description_idx = _column_index(header, config.column_map["description"])
    value_date_idx = (
        _column_index(header, config.column_map["value_date"])
        if "value_date" in config.column_map
        else None
    )

    if config.amount_strategy == "signed":
        amount_idx = _column_index(header, config.column_map["amount"])
        debit_idx = credit_idx = None
    else:
        amount_idx = None
        debit_idx = _column_index(header, config.column_map["debit"])
        credit_idx = _column_index(header, config.column_map["credit"])

    transactions: list[RawTransaction] = []
    for row in data_rows:
        if not row or all(not cell.strip() for cell in row):
            continue  # skip blank/footer lines

        booked_date = _parse_date(row[booked_date_idx], config.date_format).date()
        value_date = (
            _parse_date(row[value_date_idx], config.date_format).date()
            if value_date_idx is not None and row[value_date_idx].strip()
            else None
        )
        description_raw = row[description_idx].strip()

        if amount_idx is not None:
            decimal_value = _parse_decimal(row[amount_idx], config.decimal_separator)
            amount_minor = _amount_minor(decimal_value)
        else:
            debit_raw = row[debit_idx].strip() if debit_idx is not None else ""
            credit_raw = row[credit_idx].strip() if credit_idx is not None else ""
            separator = config.decimal_separator
            if debit_raw:
                amount_minor = -abs(_amount_minor(_parse_decimal(debit_raw, separator)))
            elif credit_raw:
                amount_minor = abs(_amount_minor(_parse_decimal(credit_raw, separator)))
            else:
                raise CsvParseError(f"Row has neither debit nor credit amount: {row!r}")

        transactions.append(
            RawTransaction(
                booked_date=booked_date,
                amount_minor=amount_minor,
                description_raw=description_raw,
                value_date=value_date,
            )
        )

    return transactions
