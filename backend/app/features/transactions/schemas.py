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
    memo: str | None
    merchant: str | None
    category: TransactionCategory | None
    categorization_source: str
    categorization_confidence: float | None
    needs_review: bool
    fitid: str | None
    dedup_hash: str
    #: The recurring series this transaction is an occurrence of, ``None`` when it is in none.
    recurring_series_id: str | None
    #: The rule whose logo this row shows (`GET /rules/{id}/logo`); ``None`` shows the
    #: monogram. The first enabled rule, by priority, that has a logo and matches.
    logo_rule_id: str | None = None
    #: When that logo last changed, so a client can cache the picture by it.
    logo_updated_at: datetime | None = None
    created_at: datetime
    updated_at: datetime


class TransactionPage(BaseModel):
    """A page of transactions."""

    items: list[TransactionRead]
    page: int
    page_size: int
    total: int
    #: Signed sum of every row the filters match, across all pages. ``None`` on a listing
    #: that does not compute it.
    net_minor: int | None = None


class TransactionUpdate(BaseModel):
    """Patch payload for a transaction. A `category_id` edit sets `source=user`."""

    category_id: str | None = None
    description_clean: str | None = Field(default=None, min_length=1)
    merchant: str | None = None


class TransactionRuleRef(BaseModel):
    """The rule that files a transaction: the first enabled rule, by priority, that matches it
    and targets its category."""

    id: str
    match_field: str
    match_type: str
    pattern: str


class TransactionSeriesRef(BaseModel):
    """The recurring series a transaction belongs to, as far as its inspector shows it."""

    id: str
    #: The series' cadence (`weekly`, `monthly`, `quarterly`, `yearly`, `irregular`).
    cadence: str
    next_expected_date: date


class SameMerchantRead(BaseModel):
    """An earlier operation of the same merchant."""

    id: str
    booked_date: date
    amount_minor: int
    currency: str


class TransactionContextRead(BaseModel):
    """What the inspector shows around a transaction, beyond the row itself."""

    import_batch_id: str
    #: ``None`` only if the import row is gone.
    import_file_name: str | None
    #: Set only when a rule filed the row (`categorization_source = rule`).
    rule: TransactionRuleRef | None
    series: TransactionSeriesRef | None
    #: Up to five earlier operations of the same merchant, newest first.
    same_merchant: list[SameMerchantRead]
