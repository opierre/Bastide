"""Request/response schemas for the transactions feature."""

from datetime import date, datetime

from pydantic import BaseModel, ConfigDict, Field


class TransactionCategory(BaseModel):
    """The embedded category summary on a transaction."""

    model_config = ConfigDict(from_attributes=True)

    id: str
    name: str
    kind: str
    icon: str
    color: str


class TransactionRead(BaseModel):
    """A transaction as returned by the API."""

    model_config = ConfigDict(from_attributes=True)

    id: str
    account_id: str
    booked_date: date
    value_date: date | None
    amount_minor: int
    currency: str
    description_raw: str
    description_clean: str
    merchant: str | None
    category: TransactionCategory | None
    categorization_source: str
    categorization_confidence: float | None
    needs_review: bool
    fitid: str | None
    dedup_hash: str
    created_at: datetime
    updated_at: datetime


class TransactionPage(BaseModel):
    """A page of transactions."""

    items: list[TransactionRead]
    page: int
    page_size: int
    total: int


class TransactionUpdate(BaseModel):
    """Patch payload for a transaction. A `category_id` edit sets `source=user`."""

    category_id: str | None = None
    description_clean: str | None = Field(default=None, min_length=1)
    merchant: str | None = None
