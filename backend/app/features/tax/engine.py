"""The French tax estimation engine (PROJECT.md §16).

A pure function of plain data: household facts, the resolved parameter set, the user's properties
and the loans secured on them go in; IR, PFU, social charges and IFI come out with a per-component
breakdown. No session, no HTTP, no ORM — the whole point is that the pipeline can be checked
against hand-computed cases, which is the only way anyone can ever verify a tax figure.

The pipeline runs in §16's stated order and the order is load-bearing: the abattements feed the
RNI, the RNI feeds the quotient, and the quotient feeds the décote. Every intermediate is an exact
``Decimal`` under a private context and every returned amount is an integer in minor units; the IR
alone is rounded to the whole currency unit, once, at the end, as French practice requires.

**Estimation-first, and loudly so.** ``IGNORED_KEYS`` is part of the output, not a disclaimer
bolted on: an estimator that silently omits a regime invites trust in a total that was never
trying to be complete.
"""

from dataclasses import dataclass
from decimal import ROUND_HALF_EVEN, ROUND_HALF_UP, Context, Decimal, localcontext

from app.features.tax.parameters import IFI, IR, ResolvedBracket, ResolvedParameters

# Fixed so no result depends on the caller's decimal context; far beyond what a barème needs.
_CONTEXT = Context(prec=50, rounding=ROUND_HALF_EVEN)
_BPS_PER_UNIT = Decimal(10_000)
#: Minor units in one whole currency unit — what "rounded to the euro" means in cents.
_MINOR_PER_UNIT = Decimal(100)
_HALF = Decimal("0.5")

#: The nature that carries the primary-residence abattement in the IFI base (§4c).
PRIMARY_RESIDENCE = "primary_residence"
#: The nature that may carry rent, and so the only one that produces property income (§4c).
RENTAL = "rental"

MICRO_FONCIER = "micro_foncier"
REEL = "reel"
#: Reported when the rented properties did not all land on the same regime.
MIXED = "mixed"

COUPLE = "couple"

#: Half-parts granted per dependent: 0,5 for each of the first two, 1 from the third (§16).
_FIRST_DEPENDENTS = 2

#: What §16 knowingly does not model, as machine keys. The frontend owns the wording in fr and
#: en; a response carrying prose would be a translation bug waiting to happen — and naming the
#: gaps is part of the feature, because an estimate that hides its own is worse than none.
IGNORED_KEYS: tuple[str, ...] = (
    "withholding_reconciliation",
    "retirement_savings_beyond_deductions",
    "property_deficits_carry_forward",
    "csg_deductible_on_bareme_capital",
    "holding_duration_allowances",
    "property_sale_taxation",
    "micro_bic_bnc_lmnp",
    "local_property_taxes",
    "ifi_liabilities_other_than_mortgages",
    "foreign_income_and_treaties",
    "invalidity_and_veteran_parts",
)


@dataclass(frozen=True)
class ProfileInput:
    """The declared household facts and income one estimate runs on (`tax_profiles`)."""

    household: str
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


@dataclass(frozen=True)
class PropertyInput:
    """One non-archived declared property, as the estimate needs it (`properties`)."""

    property_id: str
    label: str
    kind: str
    market_value_minor: int
    ownership_bps: int
    annual_rent_minor: int | None
    annual_charges_minor: int | None
    property_regime: str | None


@dataclass(frozen=True)
class MortgageInput:
    """One active loan secured on a counted property, with its principal already derived.

    The outstanding figure comes from §15's schedule engine: this module never builds a schedule,
    so a loan and its IFI deduction can never disagree about the same row.
    """

    mortgage_id: str
    label: str
    property_id: str
    outstanding_principal_minor: int


@dataclass(frozen=True)
class BreakdownEntry:
    """One component of the total, so the total is never a number without a derivation."""

    key: str
    amount_minor: int


@dataclass(frozen=True)
class PfuResult:
    """The flat road for capital income: 12,8 % IR plus social charges, outside the barème."""

    base_minor: int
    income_tax_minor: int
    social_charges_minor: int


@dataclass(frozen=True)
class BaremeCapitalResult:
    """The barème road for capital income: the dividend abattement, then into the RNI."""

    base_minor: int
    allowance_minor: int
    taxable_minor: int
    social_charges_minor: int


@dataclass(frozen=True)
class PropertyResult:
    """Property income as §16 derives it — from `properties`, never declared twice."""

    #: `micro_foncier` | `reel` | `mixed`; `None` when no property produced rent.
    regime: str | None
    gross_minor: int
    allowance_minor: int
    net_minor: int
    social_charges_minor: int


@dataclass(frozen=True)
class IfiComponent:
    """One line of the IFI base build-up, at the amount it contributes (negative if it nets off).

    `key` is `property`, `primary_residence_allowance` or `mortgage`; `reference_id` points at the
    row it came from. Synthèse draws this build-up rather than re-deriving a base from
    `/properties`, which is the duplication §16 exists to prevent.
    """

    key: str
    reference_id: str
    label: str
    amount_minor: int


@dataclass(frozen=True)
class IfiResult:
    """The IFI, always present. « Non redevable » is a state with a base and a threshold."""

    base_minor: int
    threshold_minor: int
    liable: bool
    gross_minor: int
    decote_minor: int
    due_minor: int
    components: tuple[IfiComponent, ...]


@dataclass(frozen=True)
class Estimate:
    """A whole estimate. Nothing here is stored: it is a pure function of its inputs (§4c)."""

    tax_year: int
    parts: Decimal
    salary_pension_gross_minor: int
    salary_pension_allowance_minor: int
    taxable_income_minor: int
    ir_before_decote_minor: int
    decote_minor: int
    credits_applied_minor: int
    ir_minor: int
    quotient_capped: bool
    average_rate_bps: int
    marginal_rate_bps: int
    pfu: PfuResult | None
    bareme_capital: BaremeCapitalResult | None
    property_income: PropertyResult
    ifi: IfiResult
    total_due_minor: int
    breakdown: tuple[BreakdownEntry, ...]
    ignored_keys: tuple[str, ...]


def estimate(
    *,
    tax_year: int,
    profile: ProfileInput,
    parameters: ResolvedParameters,
    properties: tuple[PropertyInput, ...],
    mortgages: tuple[MortgageInput, ...],
) -> Estimate:
    """Run §16's pipeline over one profile and return every component of its result.

    Zero income is a valid estimate, not a special case: it falls out as all zeros with
    `average_rate_bps` at 0 rather than a division by zero.

    Raises:
        TaxParameterMissingError: the resolved set lacks a key the pipeline needs.
        TaxBracketsMissingError: the year holds no `ir` or `ifi` barème.
    """
    with localcontext(_CONTEXT):
        return _estimate(tax_year, profile, parameters, properties, mortgages)


def _estimate(
    tax_year: int,
    profile: ProfileInput,
    parameters: ResolvedParameters,
    properties: tuple[PropertyInput, ...],
    mortgages: tuple[MortgageInput, ...],
) -> Estimate:
    couple = profile.household == COUPLE
    base_parts = Decimal(2) if couple else Decimal(1)

    # 1. Salaries and pensions: 10 % abattement, its floor and ceiling scaled by the declarants
    #    the household holds, since the profile stores one figure for the two of them.
    gross_activity = profile.salaries_minor + profile.pensions_minor
    allowance = _salary_allowance(gross_activity, int(base_parts), parameters)
    activity_net = gross_activity - allowance

    # 2. Property income, derived from `properties` — never declared in the profile (§4c).
    property_income = _property_income(properties, parameters)

    # 3. Capital income down exactly one of two roads, chosen by `pfu_opt_out`.
    pfu, bareme_capital = _capital_income(profile, parameters)
    bareme_capital_minor = bareme_capital.taxable_minor if bareme_capital is not None else 0

    # 4. Revenu net imposable: the barème-taxed categories less the deductions, floored at 0.
    taxable_income = max(
        activity_net + property_income.net_minor + bareme_capital_minor - profile.deductions_minor,
        0,
    )

    # 5. Parts, then 6. the IR brut under the plafonnement du quotient familial.
    parts = _parts(profile, base_parts)
    bands = parameters.bands(IR)
    ir_full = _bareme(Decimal(taxable_income) / parts, bands) * parts
    ir_base = _bareme(Decimal(taxable_income) / base_parts, bands) * base_parts
    cap = (parts - base_parts) / _HALF * parameters.value("quotient_half_part_cap_minor")
    ir_capped = max(ir_base - cap, Decimal(0))
    # The capped figure wins when it is higher: the advantage is trimmed, never granted twice.
    quotient_capped = ir_capped > ir_full
    ir_before_decote = _to_minor(max(ir_full, ir_capped))

    # 7. Décote, then the credits, then the one rounding to the whole currency unit.
    decote = _decote(ir_before_decote, couple, parameters)
    after_decote = ir_before_decote - decote
    credits_applied = min(profile.credits_minor, after_decote)
    ir_minor = _to_whole_unit(after_decote - credits_applied)

    # 8. IFI over the same properties, netting the loans secured on them.
    ifi = _ifi(properties, mortgages, parameters)

    # 9. The total, with one breakdown entry per component that fed it.
    breakdown = _breakdown(ir_minor, pfu, bareme_capital, property_income, ifi)
    quotient = Decimal(taxable_income) / parts
    return Estimate(
        tax_year=tax_year,
        parts=parts,
        salary_pension_gross_minor=gross_activity,
        salary_pension_allowance_minor=allowance,
        taxable_income_minor=taxable_income,
        ir_before_decote_minor=ir_before_decote,
        decote_minor=decote,
        credits_applied_minor=credits_applied,
        ir_minor=ir_minor,
        quotient_capped=quotient_capped,
        # The taux moyen is read on the base the marginal rate is read on, so the two agree by
        # construction. No income is 0 %, not a division by zero.
        average_rate_bps=(
            _round_half_up(Decimal(ir_minor) * _BPS_PER_UNIT / taxable_income)
            if taxable_income > 0
            else 0
        ),
        marginal_rate_bps=_marginal_rate_bps(quotient, bands),
        pfu=pfu,
        bareme_capital=bareme_capital,
        property_income=property_income,
        ifi=ifi,
        total_due_minor=sum(entry.amount_minor for entry in breakdown),
        breakdown=breakdown,
        ignored_keys=IGNORED_KEYS,
    )


def _salary_allowance(gross_minor: int, persons: int, parameters: ResolvedParameters) -> int:
    """The 10 % abattement on salaries and pensions, floored and capped per declarant (§16).

    The floor and the ceiling are scaled by the declarants the household holds — one for a
    single, two for a couple — because the profile stores the household's salaries and pensions
    as a single figure and there is no split to apply them to individually. The abattement never
    exceeds the gross it applies to, which is what makes a zero income return zero rather than
    the floor.
    """
    floor = parameters.value("salary_allowance_floor_minor") * persons
    ceiling = parameters.value("salary_allowance_ceiling_minor") * persons
    rated = _apply_bps(gross_minor, parameters.value("salary_allowance_bps"))
    return min(max(rated, floor), ceiling, gross_minor)


def _property_income(
    properties: tuple[PropertyInput, ...], parameters: ResolvedParameters
) -> PropertyResult:
    """Property income summed over the rented properties, each under its own regime (§16).

    `micro_foncier` takes the 30 % abattement while the property's own gross rent stays under the
    ceiling; above it, and under `reel`, the estimate deducts the declared charges and floors the
    result at 0. The response names the regime it used, and `mixed` when the properties did not
    all land on the same one — reporting a single regime for two different ones would misdescribe
    half the figure.
    """
    ceiling = parameters.value("micro_foncier_ceiling_minor")
    allowance_bps = parameters.value("micro_foncier_allowance_bps")

    regimes: set[str] = set()
    gross = allowance = net = 0
    for prop in properties:
        if prop.kind != RENTAL or not prop.annual_rent_minor:
            continue
        rent = prop.annual_rent_minor
        gross += rent
        if prop.property_regime == MICRO_FONCIER and rent <= ceiling:
            abattement = _apply_bps(rent, allowance_bps)
            regimes.add(MICRO_FONCIER)
            allowance += abattement
            net += rent - abattement
        else:
            # `reel`, and a micro-foncier whose rent outgrew its ceiling: real charges, floored.
            regimes.add(REEL)
            net += max(rent - (prop.annual_charges_minor or 0), 0)

    return PropertyResult(
        regime=(next(iter(regimes)) if len(regimes) == 1 else MIXED) if regimes else None,
        gross_minor=gross,
        allowance_minor=allowance,
        net_minor=net,
        social_charges_minor=_apply_bps(net, parameters.value("property_social_charges_bps")),
    )


def _capital_income(
    profile: ProfileInput, parameters: ResolvedParameters
) -> tuple[PfuResult | None, BaremeCapitalResult | None]:
    """Capital income down exactly one road, never both and never a blend (§16).

    `pfu_opt_out` picks it: the PFU is flat and stays outside the barème, while the barème road
    grants the dividends their 40 % abattement and sends the rest into the RNI. Social charges
    ride on the gross either way, at the capital rate.
    """
    base = profile.dividends_minor + profile.interest_minor + profile.capital_gains_minor
    social = _apply_bps(base, parameters.value("capital_social_charges_bps"))
    if not profile.pfu_opt_out:
        return (
            PfuResult(
                base_minor=base,
                income_tax_minor=_apply_bps(base, parameters.value("pfu_income_tax_bps")),
                social_charges_minor=social,
            ),
            None,
        )
    allowance = _apply_bps(profile.dividends_minor, parameters.value("dividend_allowance_bps"))
    return (
        None,
        BaremeCapitalResult(
            base_minor=base,
            allowance_minor=allowance,
            taxable_minor=base - allowance,
            social_charges_minor=social,
        ),
    )


def _parts(profile: ProfileInput, base_parts: Decimal) -> Decimal:
    """Parts: the base household, plus the dependents, plus the parent isolé half-part (§16)."""
    dependents = profile.dependents_count
    parts = base_parts + _HALF * min(dependents, _FIRST_DEPENDENTS)
    parts += max(dependents - _FIRST_DEPENDENTS, 0)
    if profile.single_parent:
        parts += _HALF
    return parts


def _decote(ir_before_decote_minor: int, couple: bool, parameters: ResolvedParameters) -> int:
    """The décote: its threshold less a share of the IR, never more than the IR itself."""
    threshold = parameters.value(
        "decote_threshold_couple_minor" if couple else "decote_threshold_single_minor"
    )
    rate = parameters.value("decote_rate_bps")
    raw = Decimal(threshold) - Decimal(ir_before_decote_minor) * rate / _BPS_PER_UNIT
    return min(max(_to_minor(raw), 0), ir_before_decote_minor)


def _ifi(
    properties: tuple[PropertyInput, ...],
    mortgages: tuple[MortgageInput, ...],
    parameters: ResolvedParameters,
) -> IfiResult:
    """The IFI and, above all, the build-up of its base (§16).

    Every counted property contributes its held share, each primary residence its 30 % abattement
    as a negative line, and every loan secured on a counted property its outstanding principal as
    another. The components sum to the base, so a user can see why the figure is what it is — and
    the whole block is returned even when the base falls short of the threshold, because « non
    redevable » is an answer with a base and a threshold behind it, not a missing row.
    """
    counted = {prop.property_id for prop in properties}
    residence_allowance_bps = parameters.value("ifi_primary_residence_allowance_bps")

    components: list[IfiComponent] = []
    for prop in properties:
        share = _apply_bps(prop.market_value_minor, prop.ownership_bps)
        components.append(
            IfiComponent(
                key="property",
                reference_id=prop.property_id,
                label=prop.label,
                amount_minor=share,
            )
        )
        if prop.kind == PRIMARY_RESIDENCE:
            components.append(
                IfiComponent(
                    key="primary_residence_allowance",
                    reference_id=prop.property_id,
                    label=prop.label,
                    amount_minor=-_apply_bps(share, residence_allowance_bps),
                )
            )
    components.extend(
        IfiComponent(
            key="mortgage",
            reference_id=loan.mortgage_id,
            label=loan.label,
            amount_minor=-loan.outstanding_principal_minor,
        )
        for loan in mortgages
        if loan.property_id in counted
    )

    base = max(sum(component.amount_minor for component in components), 0)
    threshold = parameters.value("ifi_threshold_minor")
    if base < threshold:
        return IfiResult(
            base_minor=base,
            threshold_minor=threshold,
            liable=False,
            gross_minor=0,
            decote_minor=0,
            due_minor=0,
            components=tuple(components),
        )

    gross = _to_minor(_bareme(Decimal(base), parameters.bands(IFI)))
    decote_rate = parameters.value("ifi_decote_rate_bps")
    decote_raw = (
        Decimal(parameters.value("ifi_decote_base_minor"))
        - Decimal(base) * decote_rate / _BPS_PER_UNIT
    )
    decote = min(max(_to_minor(decote_raw), 0), gross)
    return IfiResult(
        base_minor=base,
        threshold_minor=threshold,
        liable=True,
        gross_minor=gross,
        decote_minor=decote,
        due_minor=gross - decote,
        components=tuple(components),
    )


def _breakdown(
    ir_minor: int,
    pfu: PfuResult | None,
    bareme_capital: BaremeCapitalResult | None,
    property_income: PropertyResult,
    ifi: IfiResult,
) -> tuple[BreakdownEntry, ...]:
    """One entry per component of the total, in pipeline order; the entries sum to it exactly.

    The capital entries are the one road taken, which is where the mutual exclusivity of §16's
    two roads shows up in the total itself rather than only in the fields above it.
    """
    entries = [BreakdownEntry(key="income_tax", amount_minor=ir_minor)]
    if pfu is not None:
        entries.append(BreakdownEntry(key="pfu_income_tax", amount_minor=pfu.income_tax_minor))
        entries.append(
            BreakdownEntry(key="pfu_social_charges", amount_minor=pfu.social_charges_minor)
        )
    if bareme_capital is not None:
        entries.append(
            BreakdownEntry(
                key="capital_social_charges", amount_minor=bareme_capital.social_charges_minor
            )
        )
    entries.append(
        BreakdownEntry(
            key="property_social_charges", amount_minor=property_income.social_charges_minor
        )
    )
    entries.append(BreakdownEntry(key="ifi", amount_minor=ifi.due_minor))
    return tuple(entries)


def _bareme(income: Decimal, bands: tuple[ResolvedBracket, ...]) -> Decimal:
    """A progressive barème applied slice by slice; exact, so the caller rounds once.

    Each band taxes only the part of `income` that falls inside it, which is what keeps the
    marginal rate marginal: the top band's rate never reaches the euros below its floor.
    """
    total = Decimal(0)
    for index, band in enumerate(bands):
        if income <= band.lower_bound_minor:
            break
        ceiling = bands[index + 1].lower_bound_minor if index + 1 < len(bands) else None
        top = income if ceiling is None else min(income, Decimal(ceiling))
        total += (top - band.lower_bound_minor) * band.rate_bps / _BPS_PER_UNIT
    return total


def _marginal_rate_bps(quotient: Decimal, bands: tuple[ResolvedBracket, ...]) -> int:
    """The rate of the band the quotient familial lands in — the next euro's rate."""
    rate = 0
    for band in bands:
        if quotient > band.lower_bound_minor:
            rate = band.rate_bps
    return rate


def _apply_bps(amount_minor: int, bps: int) -> int:
    """`amount_minor × bps / 10000`, rounded half-up to minor units."""
    return _round_half_up(Decimal(amount_minor) * bps / _BPS_PER_UNIT)


def _to_minor(value: Decimal) -> int:
    """An exact intermediate settled into minor units, half-up."""
    return _round_half_up(value)


def _to_whole_unit(amount_minor: int) -> int:
    """`amount_minor` rounded to the whole currency unit — the IR's one rounding (§16)."""
    units = (Decimal(amount_minor) / _MINOR_PER_UNIT).quantize(Decimal(1), rounding=ROUND_HALF_UP)
    return int(units * _MINOR_PER_UNIT)


def _round_half_up(value: Decimal) -> int:
    return int(value.quantize(Decimal(1), rounding=ROUND_HALF_UP))
