"""Pydantic I/O for tax profiles and the ledger prefill suggestion.

Two things this module enforces by shape rather than by code. `extra="forbid"` on the patch
payload is what makes a `property_income_minor` field a 422 instead of a silently dropped key —
property income is derived from `properties` (§4c), and a client that thinks it can declare it
here needs to be told, not humoured. And every money field is a non-negative integer in minor
units: a negative salary is not an outflow, it is a typo.
"""

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

#: The two household shapes an estimate runs on (§4c). `couple` is marié/pacsé — one joint
#: estimate; anything finer is a filing status the estimate does not model (§16).
Household = Literal["single", "couple"]

#: How far a prefilled figure can be trusted, always shown next to its coverage (§5c).
Confidence = Literal["low", "medium", "high"]


class TaxProfileUpdate(BaseModel):
    """Patch payload for a tax profile.

    `tax_year` is absent: it is the path segment that identifies the row, not a field a patch
    may move. Omitted fields keep their stored value; `None` is indistinguishable from absent,
    as everywhere else in this API, and no column here is nullable anyway.
    """

    model_config = ConfigDict(extra="forbid")

    household: Household | None = None
    dependents_count: int | None = Field(default=None, ge=0)
    single_parent: bool | None = None
    salaries_minor: int | None = Field(default=None, ge=0)
    pensions_minor: int | None = Field(default=None, ge=0)
    dividends_minor: int | None = Field(default=None, ge=0)
    interest_minor: int | None = Field(default=None, ge=0)
    capital_gains_minor: int | None = Field(default=None, ge=0)
    pfu_opt_out: bool | None = None
    deductions_minor: int | None = Field(default=None, ge=0)
    credits_minor: int | None = Field(default=None, ge=0)


class TaxProfileRead(BaseModel):
    """One year's declared household facts and income.

    No estimate and no property income: the first is a pure function computed on read (§4c),
    the second is derived from `properties` so the two panels cannot disagree about one rent.
    """

    id: str
    tax_year: int
    household: Household
    dependents_count: int
    single_parent: bool
    salaries_minor: int
    pensions_minor: int
    dividends_minor: int
    interest_minor: int
    capital_gains_minor: int
    pfu_opt_out: bool
    deductions_minor: int
    credits_minor: int
    currency: str
    created_at: datetime
    updated_at: datetime


class PrefillConfidence(BaseModel):
    """Per-field confidence, keyed the way the profile fields are so the UI can pair them."""

    salaries_minor: Confidence
    pensions_minor: Confidence
    dividends_minor: Confidence
    interest_minor: Confidence


class PrefillRead(BaseModel):
    """A suggestion the ledger offers for one year — never a write (§5c).

    `source` is `ledger` and nothing else, because the point of the field is that every
    prefilled figure can be labelled as derived before the user accepts it.
    """

    tax_year: int
    salaries_minor: int
    pensions_minor: int
    dividends_minor: int
    interest_minor: int
    source: Literal["ledger"] = "ledger"
    #: Distinct months of the year holding at least one matching transaction, 0 to 12.
    months_covered: int
    per_field_confidence: PrefillConfidence
    currency: str
