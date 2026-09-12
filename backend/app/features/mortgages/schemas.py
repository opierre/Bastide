"""Pydantic I/O for declared loans and every figure derived from their schedule."""

from datetime import date, datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

#: The credit product the panel prints on every card (§4c). A label, never an engine input.
MortgageKind = Literal["mortgage", "works", "consumer", "auto"]

#: The maths the schedule runs on; mirrors the engine's `RepaymentType`.
RepaymentTypeName = Literal["constant_payment", "interest_only"]

#: `repaid` is user intent, never settled from the schedule: a loan whose last instalment has
#: passed simply reports `remaining_months = 0` until the user flips it.
MortgageStatus = Literal["active", "repaid", "archived"]


class MortgageCreate(BaseModel):
    """Payload declaring a loan.

    `currency` is absent: it is the user's, per the Phase 1 one-currency rule (multi-currency
    skill), and a derived figure is absent because nothing derived is stored (§15).
    """

    model_config = ConfigDict(extra="forbid")

    label: str = Field(min_length=1, max_length=255)
    lender: str = Field(min_length=1, max_length=255)
    kind: MortgageKind
    repayment_type: RepaymentTypeName
    principal_minor: int = Field(gt=0)
    annual_rate_bps: int = Field(ge=0)
    insurance_monthly_minor: int = Field(ge=0)
    term_months: int = Field(gt=0)
    first_payment_date: date
    upfront_fees_minor: int = Field(default=0, ge=0)
    property_id: str | None = None


class MortgageUpdate(BaseModel):
    """Patch payload for a loan.

    Omitted fields are left alone; `None` is indistinguishable from absent, as everywhere else in
    this API, so unlinking a property is not expressible here.
    """

    model_config = ConfigDict(extra="forbid")

    label: str | None = Field(default=None, min_length=1, max_length=255)
    lender: str | None = Field(default=None, min_length=1, max_length=255)
    kind: MortgageKind | None = None
    repayment_type: RepaymentTypeName | None = None
    principal_minor: int | None = Field(default=None, gt=0)
    annual_rate_bps: int | None = Field(default=None, ge=0)
    insurance_monthly_minor: int | None = Field(default=None, ge=0)
    term_months: int | None = Field(default=None, gt=0)
    first_payment_date: date | None = None
    upfront_fees_minor: int | None = Field(default=None, ge=0)
    property_id: str | None = None
    status: MortgageStatus | None = None


class MortgageRead(BaseModel):
    """A loan with the figures the list derives from its schedule, as of today."""

    id: str
    label: str
    lender: str
    property_id: str | None
    kind: MortgageKind
    repayment_type: RepaymentTypeName
    principal_minor: int
    annual_rate_bps: int
    insurance_monthly_minor: int
    term_months: int
    first_payment_date: date
    upfront_fees_minor: int
    status: MortgageStatus
    currency: str
    #: The échéance, insurance excluded.
    monthly_payment_minor: int
    #: The échéance plus insurance: what leaves the account each month.
    total_instalment_minor: int
    #: Capital still owed after every instalment due on or before today.
    outstanding_principal_minor: int
    #: Share of the principal repaid, in basis points (10000 = 100 %).
    paid_principal_pct: int
    remaining_months: int
    #: Null once the last instalment has passed.
    next_payment_on: date | None
    created_at: datetime
    updated_at: datetime


class MortgageDetail(MortgageRead):
    """A loan with its cost totals and indicative TAEG on top of the list figures."""

    total_interest_minor: int
    total_insurance_minor: int
    #: Interest, insurance and upfront fees.
    total_cost_minor: int
    #: Indicative (§15): a real TAEG includes fees the app never sees.
    taeg_bps: int
    last_payment_on: date


#: `year` aggregates the engine's month rows; it is never a second formula.
ScheduleGranularity = Literal["month", "year"]


class ScheduleMonthRow(BaseModel):
    """One instalment, exactly as the engine produced it. `instalment_minor` includes insurance."""

    ordinal: int
    due_on: date
    instalment_minor: int
    interest_minor: int
    principal_minor: int
    insurance_minor: int
    outstanding_after_minor: int


class ScheduleYearRow(BaseModel):
    """The instalments of one calendar year inside the requested window, summed."""

    year: int
    instalment_minor: int
    interest_minor: int
    principal_minor: int
    insurance_minor: int
    #: Capital still owed after the year's last instalment in the window.
    outstanding_after_minor: int


class ScheduleTotals(BaseModel):
    """Sums over the rows returned, whatever the granularity."""

    interest_minor: int
    principal_minor: int
    insurance_minor: int


class ScheduleRead(BaseModel):
    """A window of a loan's schedule, derived per request and stored nowhere (§15)."""

    granularity: ScheduleGranularity
    rows: list[ScheduleMonthRow] | list[ScheduleYearRow]
    totals: ScheduleTotals
    currency: str
