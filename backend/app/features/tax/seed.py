"""The system barème and tax parameters for one tax year, as data (§16).

Every figure is an integer: amounts in minor units (cents), rates in basis points. The seed
migration inserts exactly this set as `user_id = NULL` rows, and records in its docstring the
source, tax year and date of the check each figure passed. No labels live here: they are ARB keys
on the frontend.
"""

from dataclasses import dataclass


@dataclass(frozen=True)
class Bracket:
    """One band of a barème; its position in the tuple is its ordinal."""

    #: Inclusive floor of the band.
    lower_bound_minor: int
    rate_bps: int


@dataclass(frozen=True)
class Parameter:
    """One scalar tax parameter."""

    int_value: int
    #: `bps` | `minor` | `count`, agreeing with the key's suffix.
    unit: str


@dataclass(frozen=True)
class TaxSeed:
    """The whole system parameter set for one tax year."""

    #: The year the income was earned.
    tax_year: int
    #: Per kind (`ir`, `ifi`), bands ascending from 0; the last has no ceiling.
    brackets: dict[str, tuple[Bracket, ...]]
    parameters: dict[str, Parameter]


SYSTEM_TAX_SEED = TaxSeed(
    tax_year=2025,
    brackets={
        "ir": (
            Bracket(lower_bound_minor=0, rate_bps=0),
            Bracket(lower_bound_minor=1_160_000, rate_bps=1100),
            Bracket(lower_bound_minor=2_957_900, rate_bps=3000),
            Bracket(lower_bound_minor=8_457_700, rate_bps=4100),
            Bracket(lower_bound_minor=18_191_700, rate_bps=4500),
        ),
        "ifi": (
            Bracket(lower_bound_minor=0, rate_bps=0),
            Bracket(lower_bound_minor=80_000_000, rate_bps=50),
            Bracket(lower_bound_minor=130_000_000, rate_bps=70),
            Bracket(lower_bound_minor=257_000_000, rate_bps=100),
            Bracket(lower_bound_minor=500_000_000, rate_bps=125),
            Bracket(lower_bound_minor=1_000_000_000, rate_bps=150),
        ),
    },
    parameters={
        "salary_allowance_bps": Parameter(int_value=1000, unit="bps"),
        "salary_allowance_floor_minor": Parameter(int_value=50_900, unit="minor"),
        "salary_allowance_ceiling_minor": Parameter(int_value=1_455_500, unit="minor"),
        "quotient_half_part_cap_minor": Parameter(int_value=180_700, unit="minor"),
        "decote_threshold_single_minor": Parameter(int_value=89_700, unit="minor"),
        "decote_threshold_couple_minor": Parameter(int_value=148_300, unit="minor"),
        "decote_rate_bps": Parameter(int_value=4525, unit="bps"),
        "pfu_income_tax_bps": Parameter(int_value=1280, unit="bps"),
        # Since LFSS 2026 capital income and rents carry different prélèvements sociaux.
        "capital_social_charges_bps": Parameter(int_value=1860, unit="bps"),
        "property_social_charges_bps": Parameter(int_value=1720, unit="bps"),
        "dividend_allowance_bps": Parameter(int_value=4000, unit="bps"),
        "micro_foncier_allowance_bps": Parameter(int_value=3000, unit="bps"),
        "micro_foncier_ceiling_minor": Parameter(int_value=1_500_000, unit="minor"),
        "ifi_threshold_minor": Parameter(int_value=130_000_000, unit="minor"),
        "ifi_primary_residence_allowance_bps": Parameter(int_value=3000, unit="bps"),
        "ifi_decote_base_minor": Parameter(int_value=1_750_000, unit="minor"),
        "ifi_decote_rate_bps": Parameter(int_value=125, unit="bps"),
    },
)

#: The HCSF debt-ratio reference of §15, seeded for the same year. Lending guidance rather than
#: tax law, but held in the same parameter table so it is data a user can override, never
#: law-in-code — and a reading, never a refusal.
SYSTEM_LENDING_PARAMETERS: dict[str, Parameter] = {
    "hcsf_limit_bps": Parameter(int_value=3500, unit="bps"),
}
