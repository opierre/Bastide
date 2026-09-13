"""Resolution of one year's tax parameter set: the seeded rows, shadowed by the user's (§4c).

Two different shapes of override, for one reason. A **scalar key** is resolved on its own: a user
who raises the micro-foncier ceiling has said nothing about the PFU rate, so every other key keeps
its seeded value. A **bracket kind** is resolved as a whole set per `(tax_year, kind)`, because a
half-replaced barème is not a barème — resolving band by band would let a user leave a gap between
two bands and never see it.

One resolution, shared by the estimate (§16) and the parameters panel (§5c), so the numbers a user
reads are literally the numbers the estimate ran on.
"""

from collections.abc import Iterable, Sequence
from dataclasses import dataclass
from typing import Literal

from app.core.errors import DomainError, ValidationError
from app.features.tax.models import TaxBracket, TaxParameter

#: Whether any figure behind an estimate came from a user row (§5c).
ParameterSource = Literal["seeded", "overridden"]

#: The two barèmes a year holds (§4c).
IR = "ir"
IFI = "ifi"

#: 100 %, the ceiling of every rate an override or a submitted band may carry.
BPS_MAX = 10_000

#: The inclusive range an override may take, by the unit of the key it shadows. `None` is no
#: ceiling: an amount or a count has no natural upper bound, but a rate above 100 % is a typo.
UNIT_RANGES: dict[str, tuple[int, int | None]] = {
    "bps": (0, BPS_MAX),
    "minor": (0, None),
    "count": (0, None),
}


class TaxParameterMissingError(DomainError):
    """Raised when the resolved set has no value for a key the estimate needs.

    A broken or unseeded install, not a user error: the seeded set defines what exists, and a
    user row can only shadow a key, never remove one.
    """

    code = "TAX_PARAMETER_MISSING"


class TaxBracketsMissingError(DomainError):
    """Raised when a year holds no barème of the requested kind. Same cause as above."""

    code = "TAX_BRACKETS_MISSING"


class TaxParameterUnknownError(ValidationError):
    """Raised when an override names a key the year's seeded set does not hold.

    The seeded set defines what exists: an unknown key is refused rather than created, since a
    row nothing reads would look like a setting the estimate honours.
    """

    code = "TAX_PARAMETER_UNKNOWN"


class TaxParameterOutOfRangeError(ValidationError):
    """Raised when an override's value is outside the range its unit allows."""

    code = "TAX_PARAMETER_OUT_OF_RANGE"


class TaxBracketsInvalidError(ValidationError):
    """Raised when a submitted barème is not a usable set; the whole set is refused."""

    code = "TAX_BRACKETS_INVALID"


@dataclass(frozen=True)
class ResolvedBracket:
    """One band of a resolved barème; its position in the tuple is its ordinal."""

    lower_bound_minor: int
    rate_bps: int


@dataclass(frozen=True)
class ResolvedParameter:
    """One resolved scalar, with the unit that says what its integer means."""

    int_value: int
    #: `bps` | `minor` | `count`.
    unit: str


@dataclass(frozen=True)
class ResolvedParameters:
    """A year's parameter set as the estimate sees it, and what in it the user changed."""

    tax_year: int
    #: Per kind (`ir`, `ifi`), bands ascending by ordinal.
    brackets: dict[str, tuple[ResolvedBracket, ...]]
    parameters: dict[str, ResolvedParameter]
    #: The scalar keys that came from a user row, sorted.
    overridden_keys: tuple[str, ...]
    #: The bracket kinds whose whole set came from user rows, sorted.
    overridden_bracket_kinds: tuple[str, ...]

    @property
    def source(self) -> ParameterSource:
        """`overridden` as soon as any key or bracket set came from a user row (§16)."""
        if self.overridden_keys or self.overridden_bracket_kinds:
            return "overridden"
        return "seeded"

    def value(self, key: str) -> int:
        """The resolved integer for `key`.

        Raises:
            TaxParameterMissingError: neither the user nor the seed holds the key.
        """
        parameter = self.parameters.get(key)
        if parameter is None:
            raise TaxParameterMissingError(
                "A tax parameter this estimate needs is missing.",
                details={"key": key, "tax_year": self.tax_year},
            )
        return parameter.int_value

    def bands(self, kind: str) -> tuple[ResolvedBracket, ...]:
        """The resolved barème of `kind`, ascending.

        Raises:
            TaxBracketsMissingError: the year holds no set of that kind.
        """
        bands = self.brackets.get(kind)
        if not bands:
            raise TaxBracketsMissingError(
                "A tax barème this estimate needs is missing.",
                details={"kind": kind, "tax_year": self.tax_year},
            )
        return bands


def resolve(
    tax_year: int,
    parameter_rows: Iterable[TaxParameter],
    bracket_rows: Iterable[TaxBracket],
) -> ResolvedParameters:
    """Resolve a year's set from the system and user rows of that year.

    Both iterables carry the year's system rows (`user_id IS NULL`) and one user's rows, in any
    order; the caller's query is what scopes them to a single user.
    """
    system_values: dict[str, ResolvedParameter] = {}
    user_values: dict[str, ResolvedParameter] = {}
    for row in parameter_rows:
        target = system_values if row.user_id is None else user_values
        target[row.key] = ResolvedParameter(int_value=row.int_value, unit=row.unit)

    system_bands: dict[str, list[TaxBracket]] = {}
    user_bands: dict[str, list[TaxBracket]] = {}
    for band in bracket_rows:
        target = system_bands if band.user_id is None else user_bands
        target.setdefault(band.kind, []).append(band)

    # A user set replaces its kind whole; a kind the user never touched keeps the seeded set.
    brackets = {kind: _ascending(bands) for kind, bands in ({**system_bands, **user_bands}).items()}
    return ResolvedParameters(
        tax_year=tax_year,
        brackets=brackets,
        parameters={**system_values, **user_values},
        overridden_keys=tuple(sorted(user_values)),
        overridden_bracket_kinds=tuple(sorted(user_bands)),
    )


def check_parameter(key: str, int_value: int, system_units: dict[str, str]) -> str:
    """Check one scalar override against the year's seeded set; return the unit it inherits.

    Raises:
        TaxParameterUnknownError: the year's seeded set holds no such key.
        TaxParameterOutOfRangeError: the value is outside its unit's range.
    """
    unit = system_units.get(key)
    if unit is None:
        raise TaxParameterUnknownError(
            "This tax parameter does not exist for the year.", details={"key": key}
        )
    low, high = UNIT_RANGES[unit]
    if int_value < low or (high is not None and int_value > high):
        raise TaxParameterOutOfRangeError(
            "The tax parameter is outside the range its unit allows.",
            details={"key": key, "unit": unit, "min": low, "max": high, "int_value": int_value},
        )
    return unit


def check_brackets(kind: str, bands: Sequence[ResolvedBracket]) -> None:
    """Check a submitted barème as a whole, before any of it is written.

    A band is a floor and a rate, and its ceiling is the next band's floor, so a set is usable
    exactly when it is non-empty, starts at 0 (no gap below the first band) and has strictly
    ascending floors (neither descending nor two bands on one floor).

    Raises:
        TaxBracketsInvalidError: with `details.reason` naming the first rule the set breaks.
    """

    def refuse(reason: str, **details: int) -> TaxBracketsInvalidError:
        return TaxBracketsInvalidError(
            "The tax barème is not a valid set.",
            details={"kind": kind, "reason": reason, **details},
        )

    if not bands:
        raise refuse("empty")
    if bands[0].lower_bound_minor != 0:
        raise refuse("not_from_zero")
    for ordinal, band in enumerate(bands):
        if ordinal and band.lower_bound_minor <= bands[ordinal - 1].lower_bound_minor:
            raise refuse("not_ascending", ordinal=ordinal)
        if not 0 <= band.rate_bps <= BPS_MAX:
            raise refuse("rate_out_of_range", ordinal=ordinal)


def _ascending(bands: list[TaxBracket]) -> tuple[ResolvedBracket, ...]:
    """The bands by ordinal, so a resolved set is always read floor-first."""
    return tuple(
        ResolvedBracket(lower_bound_minor=band.lower_bound_minor, rate_bps=band.rate_bps)
        for band in sorted(bands, key=lambda band: band.ordinal)
    )
