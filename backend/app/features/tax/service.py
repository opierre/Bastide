"""Business logic for tax profiles and the ledger prefill.

Two rules shape everything here. A profile is **created lazily and never guessed at**: the row
appears with defaults on first read, and every figure in it got there because the user put it
there. The prefill is the other half of that promise — it reads the ledger, reports how much of
the year it actually saw, and returns a suggestion the user accepts field by field (§5c). It
writes nothing, which is why it lives beside the profile rather than inside it: a figure the app
wrote would be indistinguishable, later, from one the user declared.
"""

from collections.abc import Sequence
from datetime import date

from app.core.errors import ValidationError
from app.features.auth.models import User
from app.features.mortgages.models import Mortgage
from app.features.mortgages.service import median_minor, schedule_for
from app.features.properties.models import Property
from app.features.tax import engine
from app.features.tax.models import TaxProfile
from app.features.tax.parameters import resolve
from app.features.tax.repository import TaxRepository
from app.features.tax.schemas import (
    BreakdownEntryRead,
    Confidence,
    IfiComponentRead,
    IfiRead,
    PfuRead,
    PrefillConfidence,
    PrefillRead,
    PropertyIncomeRead,
    TaxEstimateRead,
    TaxProfileRead,
    TaxProfileUpdate,
)

#: The profile field each prefilled figure lands in, and the system category it is summed from.
#: `categories.name` holds the i18n key for system rows (`app/core/seed.py`), so the key is the
#: join: a user's own category never feeds a suggestion, because nothing says what it means.
PREFILL_CATEGORY_KEYS: dict[str, str] = {
    "salaries_minor": "category.income.salary",
    "pensions_minor": "category.income.pension",
    "dividends_minor": "category.income.dividends",
    "interest_minor": "category.finance.interest",
}

#: A full year of statements. Anything short of it is a partial import, and saying so is the
#: difference between a suggestion and a trap.
_MONTHS_IN_YEAR = 12

#: A month is "stable" while it sits within 20 % of the median month. A 13th-month bonus breaks
#: it — deliberately: twelve months whose total is not twelve times a typical one is a figure the
#: user should look at before accepting, which is exactly what `medium` says.
_STABILITY_NUMERATOR = 5


class TaxYearOutOfRangeError(ValidationError):
    """Raised when a `tax_year` path segment is outside the range the app can estimate.

    Next year's income cannot be estimated, and offering it would imply otherwise; a year older
    than the seeded parameter set has no barème to run against.
    """

    code = "TAX_YEAR_OUT_OF_RANGE"


def confidence_for(monthly_totals: Sequence[int]) -> Confidence:
    """How far a prefilled figure can be trusted, from the months behind it.

    `high` needs both a complete year and monthly figures that hold steady; twelve uneven
    months earn `medium`, and a partly imported year is `low` however even it looks — four
    months of statements are not an annual income.
    """
    if len(monthly_totals) < _MONTHS_IN_YEAR:
        return "low"
    median = median_minor(monthly_totals)
    stable = all(abs(total - median) * _STABILITY_NUMERATOR <= median for total in monthly_totals)
    return "high" if stable else "medium"


def ifi_valuation_date(tax_year: int) -> date:
    """The date the IFI base reads a loan's outstanding principal at.

    The IFI is assessed on 1 January of the year, so the base nets the capital still owed on
    that day. Deriving the date from the year rather than from `today` is what makes an
    estimate for a past year answer the same way every time it is asked.
    """
    return date(tax_year, 1, 1)


def to_read(profile: TaxProfile, currency: str) -> TaxProfileRead:
    """The stored profile on the wire. Nothing here is derived — that is §16's job."""
    return TaxProfileRead(
        id=profile.id,
        tax_year=profile.tax_year,
        # ty: ignore[invalid-argument-type] — the column is a plain str; the Literal is enforced
        # by the update schema, which is the only writer of this field.
        household=profile.household,
        dependents_count=profile.dependents_count,
        single_parent=profile.single_parent,
        salaries_minor=profile.salaries_minor,
        pensions_minor=profile.pensions_minor,
        dividends_minor=profile.dividends_minor,
        interest_minor=profile.interest_minor,
        capital_gains_minor=profile.capital_gains_minor,
        pfu_opt_out=profile.pfu_opt_out,
        deductions_minor=profile.deductions_minor,
        credits_minor=profile.credits_minor,
        currency=currency,
        created_at=profile.created_at,
        updated_at=profile.updated_at,
    )


class TaxService:
    """Tax profile read/patch and the ledger prefill, scoped to a user."""

    def __init__(self, repository: TaxRepository) -> None:
        self._repository = repository

    def list_profiles(self, user: User) -> list[TaxProfileRead]:
        """The user's declared years, newest first. Creates nothing — a list is a list."""
        return [
            to_read(profile, user.currency) for profile in self._repository.list_profiles(user.id)
        ]

    def get_or_create(self, user: User, tax_year: int, today: date) -> TaxProfileRead:
        """Return the year's profile, creating it with the §4c defaults if absent.

        Idempotent: a second call — including one racing the first — returns the existing row
        rather than creating a second.

        Raises:
            TaxYearOutOfRangeError: the year is in the future or predates the seeded set.
        """
        return to_read(self._owned(user.id, tax_year, today), user.currency)

    def update(
        self, user: User, tax_year: int, data: TaxProfileUpdate, today: date
    ) -> TaxProfileRead:
        """Patch the supplied fields; omitted ones keep their stored value.

        The row is created first if the year has none, so the panel can declare a salary for a
        year the user has never opened without a separate call to bring it into being.

        Raises:
            TaxYearOutOfRangeError: the year is in the future or predates the seeded set.
        """
        profile = self._owned(user.id, tax_year, today)
        for field, value in data.model_dump(exclude_unset=True).items():
            if value is None:
                continue  # No column here is nullable: absent and null both mean "leave alone".
            setattr(profile, field, value)
        return to_read(self._repository.save(profile), user.currency)

    def prefill(self, user: User, tax_year: int, today: date) -> PrefillRead:
        """What the ledger suggests for one year — a read, and only a read (§5c).

        A year with nothing imported is not an error: it returns zeros with `months_covered`
        at 0, because "nothing imported for 2024" is an answer.

        Raises:
            TaxYearOutOfRangeError: the year is in the future or predates the seeded set.
        """
        self._check_year(tax_year, today)
        totals = self._repository.monthly_totals_by_category_key(
            user.id,
            tuple(PREFILL_CATEGORY_KEYS.values()),
            date(tax_year, 1, 1),
            date(tax_year + 1, 1, 1),
        )
        # Floored at 0: a category whose year nets out negative (a reversed payment, a
        # clawback) has no annual income to suggest, and the profile refuses negatives.
        months = {field: totals.get(key, []) for field, key in PREFILL_CATEGORY_KEYS.items()}
        amounts = {field: max(sum(monthly), 0) for field, monthly in months.items()}
        return PrefillRead(
            tax_year=tax_year,
            salaries_minor=amounts["salaries_minor"],
            pensions_minor=amounts["pensions_minor"],
            dividends_minor=amounts["dividends_minor"],
            interest_minor=amounts["interest_minor"],
            # The year's own coverage, not a field's: the widest month count any prefilled
            # category reached, so a headline « N mois » never overstates a thin import.
            months_covered=max((len(monthly) for monthly in months.values()), default=0),
            per_field_confidence=PrefillConfidence(
                salaries_minor=confidence_for(months["salaries_minor"]),
                pensions_minor=confidence_for(months["pensions_minor"]),
                dividends_minor=confidence_for(months["dividends_minor"]),
                interest_minor=confidence_for(months["interest_minor"]),
            ),
            currency=user.currency,
        )

    def estimate(self, user: User, tax_year: int, today: date) -> TaxEstimateRead:
        """Estimate one year: assemble the inputs, resolve the parameters, run §16's pipeline.

        The profile is created with defaults if the year has none, so a year the user has
        never opened estimates at zero rather than 404-ing — zero income is a valid
        estimate, not a missing one. Nothing is written beyond that lazy row: the result is
        a pure function of the profile, the resolved set and the user's properties,
        recomputed on every read (§4c).

        Raises:
            TaxYearOutOfRangeError: the year is in the future or predates the seeded set.
            TaxParameterMissingError: the resolved set lacks a key the pipeline needs.
            TaxBracketsMissingError: the year holds no `ir` or `ifi` barème.
        """
        profile = self._owned(user.id, tax_year, today)
        parameters = resolve(
            tax_year,
            self._repository.list_parameters(user.id, tax_year),
            self._repository.list_brackets(user.id, tax_year),
        )
        properties = self._repository.list_active_properties(user.id)
        loans = self._repository.list_active_property_loans(user.id)
        on = ifi_valuation_date(tax_year)
        result = engine.estimate(
            tax_year=tax_year,
            profile=engine.ProfileInput(
                household=profile.household,
                dependents_count=profile.dependents_count,
                single_parent=profile.single_parent,
                salaries_minor=profile.salaries_minor,
                pensions_minor=profile.pensions_minor,
                dividends_minor=profile.dividends_minor,
                interest_minor=profile.interest_minor,
                capital_gains_minor=profile.capital_gains_minor,
                pfu_opt_out=profile.pfu_opt_out,
                deductions_minor=profile.deductions_minor,
                credits_minor=profile.credits_minor,
            ),
            parameters=parameters,
            properties=tuple(_property_input(prop) for prop in properties),
            mortgages=tuple(_mortgage_input(loan, on) for loan in loans),
        )
        return _to_estimate_read(result, parameters.source, user.currency)

    def _owned(self, user_id: str, tax_year: int, today: date) -> TaxProfile:
        """The user's profile for the year, created with defaults on first read.

        There is no cross-user read to guard here: the path carries a year, not an id, so a
        request is answered from the caller's own row or creates one.
        """
        self._check_year(tax_year, today)
        existing = self._repository.get_profile(user_id, tax_year)
        if existing is not None:
            return existing
        return self._repository.add_or_get_existing(
            TaxProfile(
                user_id=user_id,
                tax_year=tax_year,
                household="single",
                dependents_count=0,
                single_parent=False,
                salaries_minor=0,
                pensions_minor=0,
                dividends_minor=0,
                interest_minor=0,
                capital_gains_minor=0,
                pfu_opt_out=False,
                deductions_minor=0,
                credits_minor=0,
            )
        )

    def _check_year(self, tax_year: int, today: date) -> None:
        """Refuse a year the app cannot estimate, at either end.

        The floor is the oldest year the system parameter set covers: without a barème there is
        nothing to run. An install whose parameters have not been seeded at all has no floor to
        enforce — only the future check applies, rather than refusing every year on a database
        that simply has not been seeded yet.

        Raises:
            TaxYearOutOfRangeError: the year is ahead of `today` or below the seeded floor.
        """
        earliest = self._repository.earliest_seeded_tax_year()
        if tax_year > today.year or (earliest is not None and tax_year < earliest):
            raise TaxYearOutOfRangeError(
                "The tax year is outside the range this app can estimate.",
                details={"tax_year": tax_year, "earliest": earliest, "latest": today.year},
            )


def _property_input(prop: Property) -> engine.PropertyInput:
    """A declared property as the engine needs it — plain integers, no ORM past this line."""
    return engine.PropertyInput(
        property_id=prop.id,
        label=prop.label,
        kind=prop.kind,
        market_value_minor=prop.market_value_minor,
        ownership_bps=prop.ownership_bps,
        annual_rent_minor=prop.annual_rent_minor,
        annual_charges_minor=prop.annual_charges_minor,
        property_regime=prop.property_regime,
    )


def _mortgage_input(loan: Mortgage, on: date) -> engine.MortgageInput:
    """A loan with its outstanding principal already derived by §15's schedule engine.

    One implementation, so the capital the IFI base nets off and the capital the Crédits
    panel prints can never disagree about the same loan.
    """
    return engine.MortgageInput(
        mortgage_id=loan.id,
        label=loan.label,
        # Narrowed by the query: only loans carrying a `property_id` net off the base.
        property_id=str(loan.property_id),
        outstanding_principal_minor=schedule_for(loan).outstanding_at(on),
    )


def _to_estimate_read(
    result: engine.Estimate, parameter_source: str, currency: str
) -> TaxEstimateRead:
    """The estimate on the wire. `parts` is the one non-integer, and it is not money."""
    return TaxEstimateRead(
        tax_year=result.tax_year,
        parts=float(result.parts),
        salary_pension_gross_minor=result.salary_pension_gross_minor,
        salary_pension_allowance_minor=result.salary_pension_allowance_minor,
        taxable_income_minor=result.taxable_income_minor,
        ir_before_decote_minor=result.ir_before_decote_minor,
        decote_minor=result.decote_minor,
        credits_applied_minor=result.credits_applied_minor,
        ir_minor=result.ir_minor,
        quotient_capped=result.quotient_capped,
        average_rate_bps=result.average_rate_bps,
        marginal_rate_bps=result.marginal_rate_bps,
        pfu=(
            PfuRead(
                base_minor=result.pfu.base_minor,
                income_tax_minor=result.pfu.income_tax_minor,
                social_charges_minor=result.pfu.social_charges_minor,
            )
            if result.pfu is not None
            else None
        ),
        bareme_capital_minor=(
            result.bareme_capital.taxable_minor if result.bareme_capital is not None else None
        ),
        property_income=PropertyIncomeRead(
            # ty: ignore[invalid-argument-type] — the engine returns a plain str; the Literal
            # lists the engine's own three constants, the only values it can produce.
            regime=result.property_income.regime,
            gross_minor=result.property_income.gross_minor,
            allowance_minor=result.property_income.allowance_minor,
            net_minor=result.property_income.net_minor,
            social_charges_minor=result.property_income.social_charges_minor,
        ),
        ifi=IfiRead(
            base_minor=result.ifi.base_minor,
            threshold_minor=result.ifi.threshold_minor,
            liable=result.ifi.liable,
            gross_minor=result.ifi.gross_minor,
            decote_minor=result.ifi.decote_minor,
            due_minor=result.ifi.due_minor,
            components=[
                IfiComponentRead(
                    # ty: ignore[invalid-argument-type] — see `regime`; the engine emits
                    # exactly the three component keys the Literal lists.
                    key=component.key,
                    reference_id=component.reference_id,
                    label=component.label,
                    amount_minor=component.amount_minor,
                )
                for component in result.ifi.components
            ],
        ),
        total_due_minor=result.total_due_minor,
        breakdown=[
            BreakdownEntryRead(key=entry.key, amount_minor=entry.amount_minor)
            for entry in result.breakdown
        ],
        # ty: ignore[invalid-argument-type] — `ResolvedParameters.source` is the same Literal.
        parameter_source=parameter_source,
        ignored_keys=list(result.ignored_keys),
        currency=currency,
    )
