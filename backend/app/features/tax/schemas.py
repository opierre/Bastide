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


#: The regime the estimate taxed property income under (§16). `mixed` when the user's rented
#: properties did not all land on the same one; `None` when none of them produced rent.
PropertyRegimeUsed = Literal["micro_foncier", "reel", "mixed"]

#: What an IFI base line is: a property at its held share, a primary-residence abattement, or a
#: loan secured on a counted property. Negative amounts net off the base.
IfiComponentKey = Literal["property", "primary_residence_allowance", "mortgage"]

#: Whether any figure behind the estimate came from a user-owned parameter row (§16).
ParameterSourceRead = Literal["seeded", "overridden"]


class BreakdownEntryRead(BaseModel):
    """One component of the total. `key` is a machine key; the frontend owns the wording."""

    key: str
    amount_minor: int


class PfuRead(BaseModel):
    """The flat road for capital income. Null whenever the barème road was taken instead."""

    base_minor: int
    income_tax_minor: int
    social_charges_minor: int


class PropertyIncomeRead(BaseModel):
    """Property income, derived from `properties` and never declared in the profile (§4c)."""

    regime: PropertyRegimeUsed | None
    gross_minor: int
    allowance_minor: int
    net_minor: int
    social_charges_minor: int


class IfiComponentRead(BaseModel):
    """One line of the IFI base build-up, at the amount it contributes.

    `reference_id` is the property or mortgage it came from, so Synthèse can draw the build-up
    without re-deriving a base from `/properties` — the duplication §16 exists to prevent.
    """

    key: IfiComponentKey
    reference_id: str
    label: str
    amount_minor: int


class IfiRead(BaseModel):
    """The IFI block, always present.

    « Non redevable » is a state with a base and a threshold behind it, not an absent component,
    so a user under the threshold gets `liable: false` and a zero amount rather than a null.
    """

    base_minor: int
    threshold_minor: int
    liable: bool
    gross_minor: int
    decote_minor: int
    due_minor: int
    components: list[IfiComponentRead]


class TaxEstimateRead(BaseModel):
    """One year's estimate: every component, and an explicit list of what it did not model.

    Nothing here is stored (§4c) — it is a pure function of the profile, the resolved parameter
    set and the user's properties, recomputed on every read.
    """

    model_config = ConfigDict(populate_by_name=True)

    tax_year: int
    #: Always an exact multiple of 0,5, so no binary approximation is possible. Not money: the
    #: integer-minor-units rule governs amounts, and a part is a count of half-shares.
    parts: float
    salary_pension_gross_minor: int
    salary_pension_allowance_minor: int
    taxable_income_minor: int
    ir_before_decote_minor: int
    decote_minor: int
    credits_applied_minor: int
    #: The IR after décote and credits, rounded to the whole currency unit (French practice).
    ir_minor: int
    quotient_capped: bool
    average_rate_bps: int
    marginal_rate_bps: int
    #: Exactly one of these two is non-null: §16's roads are exclusive, never blended.
    pfu: PfuRead | None
    bareme_capital_minor: int | None = Field(
        default=None, serialization_alias="barème_capital_minor"
    )
    property_income: PropertyIncomeRead = Field(serialization_alias="property")
    ifi: IfiRead
    total_due_minor: int
    breakdown: list[BreakdownEntryRead]
    parameter_source: ParameterSourceRead
    #: §16's knowingly-not-modelled regimes, as machine keys — the frontend owns the wording.
    ignored_keys: list[str]
    currency: str
