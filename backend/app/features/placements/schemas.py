"""Pydantic I/O for placements, their movements and declared values, and the derived figures.

Every `*_minor` field is signed integer minor units in the user's currency. Nothing derived is
accepted on the way in: net payments, gain and age only ever leave the API.
"""

from datetime import date, datetime
from typing import Annotated, Literal

from pydantic import AfterValidator, BaseModel, ConfigDict, Field, StringConstraints

#: The envelope catalogue keys (`engine.ENVELOPES`); labelled by the frontend from ARB.
Envelope = Literal["pea", "pea_pme", "life_insurance", "per", "pee", "securities_account", "other"]

NOTE_MAX_LENGTH = 255


def _blank_to_none(value: str | None) -> str | None:
    return value or None


def _not_zero(value: int) -> int:
    if value == 0:
        raise ValueError("A movement moves money: its amount cannot be zero.")
    return value


#: Free text, trimmed; a blank note is no note, stored as null rather than "".
Note = Annotated[
    Annotated[str, StringConstraints(strip_whitespace=True, max_length=NOTE_MAX_LENGTH)] | None,
    AfterValidator(_blank_to_none),
]
Name = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=255)]
#: Signed, never zero: positive = paid in, negative = withdrawn.
MovementAmount = Annotated[int, AfterValidator(_not_zero)]


class EnvelopeRead(BaseModel):
    """One entry of the envelope catalogue, with its indicative milestones."""

    key: Envelope
    #: `null` for an envelope without a ceiling, or for a user whose currency is not the euro.
    payment_ceiling_minor: int | None
    milestone_years: int | None


class InvestmentCreate(BaseModel):
    """`POST /investments`: a new placement, optionally with its history so far.

    `initial_payments_minor` becomes one movement at the opening date; `initial_value_minor`
    one declared value at `initial_value_on` (today when omitted).
    """

    model_config = ConfigDict(extra="forbid")

    name: Name
    institution: Name
    envelope: Envelope
    opened_on: date
    initial_payments_minor: int | None = Field(default=None, gt=0)
    initial_value_minor: int | None = Field(default=None, ge=0)
    initial_value_on: date | None = None


class InvestmentUpdate(BaseModel):
    """`PATCH /investments/{id}`: omitted fields are left alone. Closing has its own route."""

    model_config = ConfigDict(extra="forbid")

    name: Name | None = None
    institution: Name | None = None
    envelope: Envelope | None = None
    opened_on: date | None = None


class InvestmentClose(BaseModel):
    """`POST /investments/{id}/close`: the closing date and the final amount received.

    A positive final amount is recorded as a withdrawal on the closing date.
    """

    model_config = ConfigDict(extra="forbid")

    closed_on: date
    final_amount_minor: int = Field(ge=0)


class MovementCreate(BaseModel):
    """`POST /investments/{id}/movements`: a payment (positive) or a withdrawal (negative)."""

    model_config = ConfigDict(extra="forbid")

    occurred_on: date
    amount_minor: MovementAmount
    note: Note = None
    #: An imported transaction of the caller's to reconcile with; reference only.
    transaction_id: str | None = None


class MovementUpdate(BaseModel):
    """Patch a movement. `note` and `transaction_id` sent as null are cleared."""

    model_config = ConfigDict(extra="forbid")

    occurred_on: date | None = None
    amount_minor: MovementAmount | None = None
    note: Note = Field(default=None, description="Null or blank clears the note.")
    transaction_id: str | None = Field(default=None, description="Null clears the link.")


class ValuationCreate(BaseModel):
    """`POST /investments/{id}/valuations`: the total value copied from a statement."""

    model_config = ConfigDict(extra="forbid")

    valued_on: date
    value_minor: int = Field(ge=0)
    note: Note = None


class ValuationUpdate(BaseModel):
    """Patch a declared value. `note` sent as null is cleared."""

    model_config = ConfigDict(extra="forbid")

    valued_on: date | None = None
    value_minor: int | None = Field(default=None, ge=0)
    note: Note = Field(default=None, description="Null or blank clears the note.")


class MovementRead(BaseModel):
    """One payment or withdrawal."""

    model_config = ConfigDict(from_attributes=True)

    id: str
    investment_id: str
    occurred_on: date
    amount_minor: int
    currency: str
    note: str | None
    transaction_id: str | None
    created_at: datetime
    updated_at: datetime


class ValuationRead(BaseModel):
    """One declared value."""

    model_config = ConfigDict(from_attributes=True)

    id: str
    investment_id: str
    valued_on: date
    value_minor: int
    currency: str
    note: str | None
    created_at: datetime
    updated_at: datetime


class InvestmentRead(BaseModel):
    """A placement with every figure the list and the inspector print, all derived here."""

    id: str
    name: str
    institution: str
    envelope: Envelope
    opened_on: date
    closed_on: date | None
    currency: str
    #: Sum of the payments in, ≥ 0.
    paid_in_minor: int
    #: Sum of the withdrawals, ≤ 0 (signed: money out is negative).
    withdrawn_minor: int
    #: `paid_in_minor + withdrawn_minor`.
    net_payments_minor: int
    #: The latest declared value and its date; null before the first declaration.
    last_value_minor: int | None
    last_valued_on: date | None
    #: `last_value_minor − net_payments_minor`, signed. Null without a declared value, and
    #: for a closed placement, where nothing is unrealised any more.
    unrealised_gain_minor: int | None
    #: The gain as a share of net payments, in bps; null when that share means nothing.
    gain_bps: int | None
    #: The latest declared value is older than four months (open placements only).
    value_stale: bool
    #: Whole months since opening, up to today or the closing date.
    age_months: int
    payment_ceiling_minor: int | None
    milestone_years: int | None
    #: The date the age milestone falls on; null for an envelope without one.
    milestone_on: date | None
    milestone_reached: bool
    movement_count: int
    #: Movements reconciled with an imported transaction (« {n} rapprochés »).
    linked_movement_count: int
    created_at: datetime
    updated_at: datetime


class InvestmentDetail(InvestmentRead):
    """A placement with its full history, newest first in both lists."""

    movements: list[MovementRead]
    valuations: list[ValuationRead]


class InvestmentSummary(BaseModel):
    """`GET /investments/summary`: the summary line over the open placements."""

    open_count: int
    closed_count: int
    #: Sum of the latest declared values of the open placements that have one.
    declared_value_minor: int
    #: Sum of the net payments of every open placement.
    net_payments_minor: int
    #: Sum of the gains of the open placements that have a declared value.
    unrealised_gain_minor: int
    #: That gain as a share of the same placements' net payments; null when meaningless.
    gain_bps: int | None
    valued_count: int
    stale_count: int
    #: The most recent date a value was declared on, over the open placements.
    last_valued_on: date | None
    currency: str


class InvestmentSeriesPoint(BaseModel):
    """The placements at one closed month end (`YYYY-MM`), as net worth counts them."""

    month: str
    value_minor: int
    net_payments_minor: int


class InvestmentSeries(BaseModel):
    """`GET /investments/series`: every closed month from the first opening to last month."""

    points: list[InvestmentSeriesPoint]
    currency: str


class LinkCandidate(BaseModel):
    """An imported transaction that may have funded a movement: same amount, opposite sign."""

    transaction_id: str
    account_id: str
    account_name: str
    booked_date: date
    amount_minor: int
    currency: str
    description: str
