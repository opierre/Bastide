"""Request/response schemas for the imports feature."""

from datetime import date, datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict


class CsvTemplateCreate(BaseModel):
    """A per-bank CSV column mapping, submitted once and reused on every subsequent import."""

    bank_name: str
    delimiter: str
    encoding: str
    date_format: str
    decimal_separator: str
    amount_strategy: Literal["signed", "debit_credit"]
    column_map: dict[str, str]
    header_offset: int = 0


class CsvTemplateRead(BaseModel):
    """A saved CSV template as returned by the API."""

    model_config = ConfigDict(from_attributes=True)

    id: str
    bank_name: str
    delimiter: str
    encoding: str
    date_format: str
    decimal_separator: str
    amount_strategy: str
    column_map: dict[str, str]
    header_offset: int
    created_at: datetime


class CsvPreviewRow(BaseModel):
    """One parsed sample row, returned by the preview endpoint without persisting anything."""

    booked_date: date
    value_date: date | None
    amount_minor: int
    description_raw: str


class ImportBatchRead(BaseModel):
    """An import batch as returned by the API: counts, coverage window, and outcome.

    `balance_mismatch_minor` is set only when this statement declared a balance that
    disagrees with what the ledger implies at `balance_mismatch_as_of` — e.g. a missed
    statement, an un-imported gap, or a bad prior correction. `None` means either there
    was nothing to compare (CSV, or an OFX file without a `LEDGERBAL`) or the two agreed.
    """

    id: str
    account_id: str
    source_format: str
    file_name: str
    file_hash: str
    period_start: date
    period_end: date
    transaction_count: int
    new_count: int
    duplicate_count: int
    status: str
    error_message: str | None
    balance_mismatch_minor: int | None
    balance_mismatch_as_of: date | None
    imported_at: datetime
