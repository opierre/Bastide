"""Request/response schemas for the imports feature."""

from datetime import date, datetime

from pydantic import BaseModel


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
