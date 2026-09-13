"""Reference cases for the tax estimation engine (§16), computed by hand and asserted per part.

Every case below was worked out on paper against the seeded 2025 barème before it was written
down here, and each asserts its **component** amounts rather than only its total — a total that
is right for two wrong reasons is exactly the failure this table exists to catch.

The engine is pure, so these tests need no session, no app and no fixtures beyond the seeded
parameter set: the pipeline is checkable, which is the only way anyone can ever verify a tax
figure.
"""

from dataclasses import dataclass, field, replace
from decimal import Decimal
from typing import Any

import pytest

from app.features.tax import engine
from app.features.tax.parameters import ResolvedBracket, ResolvedParameter, ResolvedParameters
from app.features.tax.seed import SYSTEM_TAX_SEED

YEAR = SYSTEM_TAX_SEED.tax_year


def seeded_parameters(**overrides: int) -> ResolvedParameters:
    """The system set as `resolve` would hand it over, optionally with a key overridden."""
    return ResolvedParameters(
        tax_year=YEAR,
        brackets={
            kind: tuple(
                ResolvedBracket(lower_bound_minor=band.lower_bound_minor, rate_bps=band.rate_bps)
                for band in bands
            )
            for kind, bands in SYSTEM_TAX_SEED.brackets.items()
        },
        parameters={
            key: ResolvedParameter(
                int_value=overrides.get(key, parameter.int_value), unit=parameter.unit
            )
            for key, parameter in SYSTEM_TAX_SEED.parameters.items()
        },
        overridden_keys=tuple(sorted(overrides)),
        overridden_bracket_kinds=(),
    )


PARAMETERS = seeded_parameters()


#: The profile a lazily created row holds (§4c): every figure zero until the user declares one.
ZERO_PROFILE = engine.ProfileInput(
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


def profile(**changes: Any) -> engine.ProfileInput:
    """The zero profile with the case's own figures declared on top of it."""
    return replace(ZERO_PROFILE, **changes)


def rental(
    property_id: str,
    regime: str,
    annual_rent_minor: int,
    annual_charges_minor: int | None = None,
    market_value_minor: int = 20_000_000,
) -> engine.PropertyInput:
    return engine.PropertyInput(
        property_id=property_id,
        label=property_id,
        kind="rental",
        market_value_minor=market_value_minor,
        ownership_bps=10_000,
        annual_rent_minor=annual_rent_minor,
        annual_charges_minor=annual_charges_minor,
        property_regime=regime,
    )


def held(
    property_id: str, kind: str, market_value_minor: int, ownership_bps: int = 10_000
) -> engine.PropertyInput:
    return engine.PropertyInput(
        property_id=property_id,
        label=property_id,
        kind=kind,
        market_value_minor=market_value_minor,
        ownership_bps=ownership_bps,
        annual_rent_minor=None,
        annual_charges_minor=None,
        property_regime=None,
    )


@dataclass(frozen=True)
class Case:
    """One reference case: its inputs, and the components its answer must show."""

    name: str
    profile: engine.ProfileInput
    #: The engine fields to assert, by dotted path — components, never only the total.
    expected: dict[str, Any]
    properties: tuple[engine.PropertyInput, ...] = ()
    mortgages: tuple[engine.MortgageInput, ...] = ()
    parameters: ResolvedParameters = field(default=PARAMETERS)


CASES: tuple[Case, ...] = (
    # 40 000 € of salary: 10 % abattement = 4 000 €, RNI 36 000 €. Barème at 1 part:
    # (29 579 − 11 600) × 11 % = 1 977,69 € and (36 000 − 29 579) × 30 % = 1 926,30 €,
    # so 3 903,99 € brut, no décote, rounded to 3 904 €. Taux moyen 3 904 / 36 000 = 10,84 %.
    Case(
        name="single-salary-only",
        profile=profile(salaries_minor=4_000_000),
        expected={
            "parts": Decimal(1),
            "salary_pension_allowance_minor": 400_000,
            "taxable_income_minor": 3_600_000,
            "ir_before_decote_minor": 390_399,
            "decote_minor": 0,
            "ir_minor": 390_400,
            "quotient_capped": False,
            "average_rate_bps": 1084,
            "marginal_rate_bps": 3000,
            "total_due_minor": 390_400,
        },
    ),
    # A pension is abated like a salary and on the same figure: 20 000 € of salary and 20 000 €
    # of pension reach exactly the case above.
    Case(
        name="single-salary-and-pension",
        profile=profile(salaries_minor=2_000_000, pensions_minor=2_000_000),
        expected={
            "salary_pension_gross_minor": 4_000_000,
            "salary_pension_allowance_minor": 400_000,
            "taxable_income_minor": 3_600_000,
            "ir_minor": 390_400,
        },
    ),
    # The abattement floor: on 3 000 € the 10 % rate gives 300 €, under the 509 € floor.
    Case(
        name="single-allowance-floored",
        profile=profile(salaries_minor=300_000),
        expected={
            "salary_pension_allowance_minor": 50_900,
            "taxable_income_minor": 249_100,
            "ir_minor": 0,
        },
    ),
    # And its ceiling, which a couple carries twice over (2 × 14 555 €) on 400 000 €.
    Case(
        name="couple-allowance-ceiling-per-person",
        profile=profile(household="couple", salaries_minor=40_000_000),
        expected={
            "salary_pension_allowance_minor": 2_911_000,
            "taxable_income_minor": 37_089_000,
        },
    ),
    # Couple, two children, 120 000 € of salary. RNI 108 000 €, parts 3 → IR à 3 parts
    # 3 × 3 903,99 = 11 711,97 €. At the base 2 parts: 2 × 9 303,99 = 18 607,98 €, less the cap
    # of 2 × 1 807 € = 3 614 € → 14 993,98 €. The capped figure is higher, so it wins and
    # `quotient_capped` says so.
    Case(
        name="couple-two-children-quotient-capped",
        profile=profile(household="couple", dependents_count=2, salaries_minor=12_000_000),
        expected={
            "parts": Decimal(3),
            "taxable_income_minor": 10_800_000,
            "ir_before_decote_minor": 1_499_398,
            "quotient_capped": True,
            "ir_minor": 1_499_400,
            "marginal_rate_bps": 3000,
            "total_due_minor": 1_499_400,
        },
    ),
    # The same household at a low enough income that the half-parts are worth less than the cap:
    # RNI 45 000 €, IR à 3 parts 3 × 374 = 1 122 € against 2 × 1 199 − 3 614 = 0 € capped, so the
    # advantage stands whole and `quotient_capped` is false.
    Case(
        name="couple-two-children-quotient-not-capped",
        profile=profile(household="couple", dependents_count=2, salaries_minor=5_000_000),
        expected={
            "parts": Decimal(3),
            "taxable_income_minor": 4_500_000,
            "ir_before_decote_minor": 112_200,
            "quotient_capped": False,
            # The couple's décote threshold, not the single's:
            # 1 483 − 45,25 % × 1 122 = 975,295 €, arrondi à 975,30 €.
            "decote_minor": 97_530,
            "ir_minor": 14_700,
        },
    ),
    # 22 000 € of salary: RNI 19 800 €, IR brut (19 800 − 11 600) × 11 % = 902 €. The décote is
    # 897 − 45,25 % × 902 = 488,85 €, leaving 413,15 € rounded to 413 €.
    Case(
        name="single-decote",
        profile=profile(salaries_minor=2_200_000),
        expected={
            "ir_before_decote_minor": 90_200,
            "decote_minor": 48_885,
            "ir_minor": 41_300,
            "marginal_rate_bps": 1100,
            "average_rate_bps": 209,
        },
    ),
    # A décote larger than the IR wipes it out rather than turning it into a refund.
    Case(
        name="single-decote-absorbs-whole-ir",
        profile=profile(salaries_minor=1_800_000),
        expected={
            "ir_before_decote_minor": 50_600,
            "decote_minor": 50_600,
            "ir_minor": 0,
            "total_due_minor": 0,
        },
    ),
    # Credits come last and never go below zero: 5 000 € of credits against 3 903,99 € of IR.
    Case(
        name="credits-floored-at-zero",
        profile=profile(salaries_minor=4_000_000, credits_minor=500_000),
        expected={
            "ir_before_decote_minor": 390_399,
            "credits_applied_minor": 390_399,
            "ir_minor": 0,
            "total_due_minor": 0,
        },
    ),
    # Deductions come off the RNI before the barème, floored at 0.
    Case(
        name="deductions-floor-the-rni",
        profile=profile(salaries_minor=2_000_000, deductions_minor=9_000_000),
        expected={"taxable_income_minor": 0, "ir_minor": 0, "average_rate_bps": 0},
    ),
    # 10 000 € of dividends on the PFU road: 1 280 € of IR and 1 860 € of social charges, both
    # outside the barème — the RNI is the salary case's, untouched.
    Case(
        name="capital-pfu",
        profile=profile(salaries_minor=4_000_000, dividends_minor=1_000_000),
        expected={
            "taxable_income_minor": 3_600_000,
            "ir_minor": 390_400,
            "pfu.base_minor": 1_000_000,
            "pfu.income_tax_minor": 128_000,
            "pfu.social_charges_minor": 186_000,
            "bareme_capital": None,
            "total_due_minor": 704_400,
        },
    ),
    # The same 10 000 € on the barème road: the 40 % abattement leaves 6 000 € in the RNI, taxed
    # at 30 %, and the social charges still ride on the whole 10 000 €.
    Case(
        name="capital-bareme",
        profile=profile(salaries_minor=4_000_000, dividends_minor=1_000_000, pfu_opt_out=True),
        expected={
            "taxable_income_minor": 4_200_000,
            "ir_before_decote_minor": 570_399,
            "ir_minor": 570_400,
            "pfu": None,
            "bareme_capital.allowance_minor": 400_000,
            "bareme_capital.taxable_minor": 600_000,
            "bareme_capital.social_charges_minor": 186_000,
            "total_due_minor": 756_400,
        },
    ),
    # Interest and capital gains take no abattement on the barème road; only dividends do.
    Case(
        name="capital-bareme-interest-and-gains-in-full",
        profile=profile(interest_minor=200_000, capital_gains_minor=300_000, pfu_opt_out=True),
        expected={
            "bareme_capital.base_minor": 500_000,
            "bareme_capital.allowance_minor": 0,
            "bareme_capital.taxable_minor": 500_000,
        },
    ),
    # 12 000 € of rent under micro-foncier: 30 % abattement, 8 400 € net, 17,2 % of social
    # charges on the net figure, and the net joins the RNI.
    Case(
        name="property-micro-foncier",
        profile=profile(salaries_minor=4_000_000),
        properties=(rental("studio", "micro_foncier", 1_200_000),),
        expected={
            "property_income.regime": "micro_foncier",
            "property_income.gross_minor": 1_200_000,
            "property_income.allowance_minor": 360_000,
            "property_income.net_minor": 840_000,
            "property_income.social_charges_minor": 144_480,
            "taxable_income_minor": 4_440_000,
        },
    ),
    # 20 000 € of rent under réel, less 5 000 € of charges.
    Case(
        name="property-reel",
        profile=profile(salaries_minor=4_000_000),
        properties=(rental("duplex", "reel", 2_000_000, 500_000),),
        expected={
            "property_income.regime": "reel",
            "property_income.gross_minor": 2_000_000,
            "property_income.allowance_minor": 0,
            "property_income.net_minor": 1_500_000,
            "property_income.social_charges_minor": 258_000,
            "taxable_income_minor": 5_100_000,
        },
    ),
    # Charges above the rent are a déficit foncier, which §16 does not model: the net floors at
    # 0 rather than sheltering the salary.
    Case(
        name="property-reel-floored-at-zero",
        profile=profile(salaries_minor=4_000_000),
        properties=(rental("duplex", "reel", 500_000, 900_000),),
        expected={
            "property_income.net_minor": 0,
            "property_income.social_charges_minor": 0,
            "taxable_income_minor": 3_600_000,
        },
    ),
    # A micro-foncier whose rent outgrew the 15 000 € ceiling is estimated under réel, and the
    # response says `reel` rather than claiming an abattement it did not grant.
    Case(
        name="property-micro-foncier-over-ceiling-falls-to-reel",
        profile=profile(),
        properties=(rental("immeuble", "micro_foncier", 1_800_000),),
        expected={
            "property_income.regime": "reel",
            "property_income.allowance_minor": 0,
            "property_income.net_minor": 1_800_000,
        },
    ),
    # Two properties on different regimes: each is taxed under its own, and the reported regime
    # is `mixed` rather than a single name that would misdescribe half the figure.
    Case(
        name="property-mixed-regimes",
        profile=profile(),
        properties=(
            rental("studio", "micro_foncier", 1_200_000),
            rental("duplex", "reel", 2_000_000, 500_000),
        ),
        expected={
            "property_income.regime": "mixed",
            "property_income.gross_minor": 3_200_000,
            "property_income.allowance_minor": 360_000,
            "property_income.net_minor": 2_340_000,
        },
    ),
    # A property that produces no rent produces no property income — and no regime to name.
    Case(
        name="property-no-rent",
        profile=profile(),
        properties=(held("maison", "secondary", 30_000_000),),
        expected={
            "property_income.regime": None,
            "property_income.gross_minor": 0,
            "property_income.net_minor": 0,
        },
    ),
    # An IFI base of 1 350 000 €, just over the 1 300 000 € threshold and inside the décote band:
    # 50 000 € × 0,5 % + 5 000 € × 0,7 % = 285 €, less a décote of 17 500 − 1,25 % × 1 350 000 =
    # 625 €… capped at the 285 € it applies to? No — 1 687,50 € exceeds 17 500 €? It does not:
    # the décote is 625 €, leaving 2 225 € — read the figures, not this arithmetic, from below.
    Case(
        name="ifi-just-over-threshold-in-decote-band",
        profile=profile(),
        properties=(held("maison", "secondary", 135_000_000),),
        expected={
            "ifi.base_minor": 135_000_000,
            "ifi.threshold_minor": 130_000_000,
            "ifi.liable": True,
            "ifi.gross_minor": 285_000,
            "ifi.decote_minor": 62_500,
            "ifi.due_minor": 222_500,
            "total_due_minor": 222_500,
        },
    ),
    # Above the décote band the décote is gone, not negative.
    Case(
        name="ifi-above-decote-band",
        profile=profile(),
        properties=(held("maison", "secondary", 200_000_000),),
        expected={
            "ifi.base_minor": 200_000_000,
            "ifi.gross_minor": 740_000,
            "ifi.decote_minor": 0,
            "ifi.due_minor": 740_000,
        },
    ),
    # Under the threshold the block is still there, with its base and its threshold and a zero
    # amount: « non redevable » is a state, not an absent component.
    Case(
        name="ifi-under-threshold-still-reported",
        profile=profile(),
        properties=(held("maison", "secondary", 50_000_000),),
        expected={
            "ifi.base_minor": 50_000_000,
            "ifi.threshold_minor": 130_000_000,
            "ifi.liable": False,
            "ifi.gross_minor": 0,
            "ifi.due_minor": 0,
        },
    ),
)


@pytest.mark.parametrize("case", CASES, ids=lambda case: case.name)
def test_reference_case(case: Case) -> None:
    """Each hand-computed case matches to the euro, component by component."""
    result = engine.estimate(
        tax_year=YEAR,
        profile=case.profile,
        parameters=case.parameters,
        properties=case.properties,
        mortgages=case.mortgages,
    )
    for path, expected in case.expected.items():
        assert _read(result, path) == expected, path


@pytest.mark.parametrize("case", CASES, ids=lambda case: case.name)
def test_breakdown_sums_to_the_total(case: Case) -> None:
    """The total is never a number without a derivation: its entries add up to it exactly."""
    result = engine.estimate(
        tax_year=YEAR,
        profile=case.profile,
        parameters=case.parameters,
        properties=case.properties,
        mortgages=case.mortgages,
    )
    assert sum(entry.amount_minor for entry in result.breakdown) == result.total_due_minor
    assert len({entry.key for entry in result.breakdown}) == len(result.breakdown)


@pytest.mark.parametrize("case", CASES, ids=lambda case: case.name)
def test_the_two_capital_roads_are_exclusive(case: Case) -> None:
    """Exactly one road is taken in every response — never both, never a blend (§16)."""
    result = engine.estimate(
        tax_year=YEAR,
        profile=case.profile,
        parameters=case.parameters,
        properties=case.properties,
        mortgages=case.mortgages,
    )
    assert (result.pfu is None) != (result.bareme_capital is None)
    keys = {entry.key for entry in result.breakdown}
    assert ("pfu_income_tax" in keys) is (result.pfu is not None)
    assert ("capital_social_charges" in keys) is (result.bareme_capital is not None)


def test_zero_income_is_a_valid_estimate() -> None:
    """All zeros, and an average rate of 0 rather than a division by zero or a NaN."""
    result = engine.estimate(
        tax_year=YEAR, profile=profile(), parameters=PARAMETERS, properties=(), mortgages=()
    )
    assert result.taxable_income_minor == 0
    assert result.ir_minor == 0
    assert result.total_due_minor == 0
    assert result.average_rate_bps == 0
    assert result.marginal_rate_bps == 0
    assert result.ifi.base_minor == 0
    assert result.ifi.liable is False


def test_parts_follow_the_household_and_its_dependents() -> None:
    """0,5 for each of the first two dependents, 1 from the third, 0,5 for a parent isolé."""
    assert _parts(household="single") == Decimal(1)
    assert _parts(household="couple") == Decimal(2)
    assert _parts(household="couple", dependents_count=2) == Decimal(3)
    assert _parts(household="couple", dependents_count=3) == Decimal(4)
    assert _parts(household="couple", dependents_count=4) == Decimal(5)
    assert _parts(household="single", dependents_count=1, single_parent=True) == Decimal(2)


def test_ifi_base_components_sum_to_the_reported_base() -> None:
    """One line per counted property, the residence abattement, each netted loan — and they add up.

    The half-share residence is counted at 500 000 €, less its 30 % abattement of 150 000 €, less
    the 200 000 € still owed on the loan secured on it: a base of 150 000 €.
    """
    result = engine.estimate(
        tax_year=YEAR,
        profile=profile(),
        parameters=PARAMETERS,
        properties=(held("residence", "primary_residence", 100_000_000, ownership_bps=5_000),),
        mortgages=(
            engine.MortgageInput(
                mortgage_id="loan",
                label="Prêt",
                property_id="residence",
                outstanding_principal_minor=20_000_000,
            ),
        ),
    )
    assert [
        (component.key, component.reference_id, component.amount_minor)
        for component in result.ifi.components
    ] == [
        ("property", "residence", 50_000_000),
        ("primary_residence_allowance", "residence", -15_000_000),
        ("mortgage", "loan", -20_000_000),
    ]
    assert sum(component.amount_minor for component in result.ifi.components) == 15_000_000
    assert result.ifi.base_minor == 15_000_000


def test_ifi_nets_only_loans_linked_to_counted_properties() -> None:
    """An unlinked loan finances nothing the base counts, so it never shrinks it."""
    result = engine.estimate(
        tax_year=YEAR,
        profile=profile(),
        parameters=PARAMETERS,
        properties=(held("maison", "secondary", 135_000_000),),
        mortgages=(
            engine.MortgageInput(
                mortgage_id="elsewhere",
                label="Prêt sur un autre bien",
                property_id="archivee",
                outstanding_principal_minor=90_000_000,
            ),
        ),
    )
    assert [component.key for component in result.ifi.components] == ["property"]
    assert result.ifi.base_minor == 135_000_000


def test_ifi_base_floors_at_zero() -> None:
    """A property worth less than the loan on it is not a negative fortune."""
    result = engine.estimate(
        tax_year=YEAR,
        profile=profile(),
        parameters=PARAMETERS,
        properties=(held("maison", "secondary", 20_000_000),),
        mortgages=(
            engine.MortgageInput(
                mortgage_id="loan",
                label="Prêt",
                property_id="maison",
                outstanding_principal_minor=35_000_000,
            ),
        ),
    )
    assert result.ifi.base_minor == 0
    assert result.ifi.liable is False


def test_property_income_follows_a_change_to_a_property() -> None:
    """The rent is read from `properties`, so changing one changes the estimate."""
    before = engine.estimate(
        tax_year=YEAR,
        profile=profile(),
        parameters=PARAMETERS,
        properties=(rental("studio", "micro_foncier", 1_200_000),),
        mortgages=(),
    )
    after = engine.estimate(
        tax_year=YEAR,
        profile=profile(),
        parameters=PARAMETERS,
        properties=(rental("studio", "micro_foncier", 1_800_000),),
        mortgages=(),
    )
    assert before.property_income.gross_minor == 1_200_000
    # Past the ceiling the same property is estimated under réel — regime and net both move.
    assert after.property_income.gross_minor == 1_800_000
    assert after.property_income.regime == "reel"
    assert after.taxable_income_minor != before.taxable_income_minor


def test_an_overridden_parameter_changes_the_estimate() -> None:
    """Resolution feeds the engine, so a user's own figure is the figure the estimate runs on."""
    doubled = seeded_parameters(pfu_income_tax_bps=2560)
    result = engine.estimate(
        tax_year=YEAR,
        profile=profile(dividends_minor=1_000_000),
        parameters=doubled,
        properties=(),
        mortgages=(),
    )
    assert result.pfu is not None
    assert result.pfu.income_tax_minor == 256_000
    assert doubled.source == "overridden"


def test_ignored_keys_are_machine_readable_and_non_empty() -> None:
    """The response names what it did not model, in keys the frontend translates itself."""
    result = engine.estimate(
        tax_year=YEAR, profile=profile(), parameters=PARAMETERS, properties=(), mortgages=()
    )
    assert result.ignored_keys
    assert len(set(result.ignored_keys)) == len(result.ignored_keys)
    for key in result.ignored_keys:
        assert key == key.lower()
        assert key.replace("_", "").isalnum()
        assert " " not in key


def test_no_float_in_the_engine() -> None:
    """`Decimal` for every intermediate: a float in here is a rounding bug waiting to happen."""
    source = (engine.__file__ or "").replace("\\", "/")
    with open(source, encoding="utf-8") as handle:
        text = handle.read()
    assert "float(" not in text
    assert ": float" not in text


def _parts(**changes: Any) -> Decimal:
    return engine.estimate(
        tax_year=YEAR,
        profile=profile(**changes),
        parameters=PARAMETERS,
        properties=(),
        mortgages=(),
    ).parts


def _read(result: engine.Estimate, path: str) -> Any:
    """Read a dotted path off the result, so a case can assert a nested component directly."""
    value: Any = result
    for step in path.split("."):
        if value is None:
            return None
        value = getattr(value, step)
    return value
