"""Pydantic I/O for the recurring feature, and the vocabularies the column values come from."""

from datetime import date, datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

from app.features.transactions.schemas import TransactionRead

#: Every value `recurring_series.cadence` may carry. `irregular` exists for user-declared series
#: only: the detector emits a series when it recognises a rhythm and nothing otherwise, so it
#: never produces one (`PROJECT.md` §12).
Cadence = Literal["weekly", "monthly", "quarterly", "yearly", "irregular"]

#: The subset detection can conclude — the four bands a median gap is classified into.
DetectedCadence = Literal["weekly", "monthly", "quarterly", "yearly"]

#: Lifecycle of a series. `dismissed` and `cancelled` are the user's word on it, which is why
#: re-detection leaves both alone.
SeriesStatus = Literal["detected", "confirmed", "dismissed", "cancelled"]


class DetectRequest(BaseModel):
    """Ask for a detection pass, over one account or over all of them."""

    account_id: str | None = None


class DetectionResultRead(BaseModel):
    """What a detection pass did. Series it deliberately left alone count in neither number."""

    created_count: int
    updated_count: int


class SeriesRead(BaseModel):
    """A recurring series as returned by the API.

    `merchant_key` is deliberately absent: it is a machine key the detector groups on, not
    something the panel shows or the client may edit.
    """

    model_config = ConfigDict(from_attributes=True)

    id: str
    account_id: str
    label: str
    category_id: str | None
    cadence: Cadence
    median_interval_days: int
    #: Signed, so negative — a subscription is an outflow (`PROJECT.md` §8).
    expected_amount_minor: int
    currency: str
    first_seen_date: date
    last_seen_date: date
    next_expected_date: date
    occurrence_count: int
    status: SeriesStatus
    is_manual: bool
    #: Signed step in `expected_amount_minor`; a price *rise* on an outflow is negative.
    price_change_minor: int | None
    price_changed_at: date | None
    created_at: datetime
    updated_at: datetime


class OccurrenceRead(BaseModel):
    """One occurrence of a series, carrying the transaction it was deduced from.

    The transaction is embedded rather than referenced by id: the detail screen exists to show
    the user the evidence behind a deduction, and a second round trip per occurrence would make
    that evidence optional in practice.
    """

    id: str
    created_at: datetime
    transaction: TransactionRead


class SeriesDetailRead(SeriesRead):
    """A series plus the occurrence history it was built from, newest first."""

    occurrences: list[OccurrenceRead]


class SeriesCreate(BaseModel):
    """Payload declaring a subscription the detector has not found.

    No `status`: a declared series starts in the same `detected` state as any other, so the
    whole lifecycle matrix applies to it uniformly.
    """

    label: str = Field(min_length=1, max_length=255)
    account_id: str
    expected_amount_minor: int = Field(
        description=(
            "Signed minor units, so negative for the ordinary case of a subscription "
            "(`PROJECT.md` §8). Not constrained to negatives: the sign is the client's "
            "statement about the charge, not something this endpoint may overrule."
        )
    )
    cadence: Cadence
    category_id: str | None = None
