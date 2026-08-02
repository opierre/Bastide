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
    """An import batch as returned by the API: counts, coverage window, and outcome."""

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
    imported_at: datetime
