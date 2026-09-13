"""Tests for `/tax/parameters/{year}` — resolution, overrides and reset (§4c, §5c, §16).

What is at stake: the set a user reads is the set the estimate runs on; a barème is replaced whole
or not at all; the seeded set defines which keys exist; a reset gives back exactly the seeded
figures; and nothing a user does can reach a system row, another user's overrides, or another year.
"""

import pytest

from app.features.tax.parameters import (
    ResolvedBracket,
    TaxBracketsInvalidError,
    TaxParameterOutOfRangeError,
    TaxParameterUnknownError,
    check_brackets,
    check_parameter,
)


@pytest.mark.parametrize(
    ("bad_set", "reason"),
    [
        ([], "empty"),
        ([ResolvedBracket(100, 0)], "not_from_zero"),
        ([ResolvedBracket(0, 0), ResolvedBracket(0, 1100)], "not_ascending"),
        ([ResolvedBracket(0, 0), ResolvedBracket(10, 0), ResolvedBracket(5, 0)], "not_ascending"),
        ([ResolvedBracket(0, 10_001)], "rate_out_of_range"),
    ],
)
def test_check_brackets_names_the_rule_a_set_breaks(
    bad_set: list[ResolvedBracket], reason: str
) -> None:
    with pytest.raises(TaxBracketsInvalidError) as refused:
        check_brackets("ir", bad_set)

    assert refused.value.details is not None
    assert (refused.value.details["kind"], refused.value.details["reason"]) == ("ir", reason)


def test_check_brackets_accepts_a_single_band_from_zero() -> None:
    check_brackets("ifi", [ResolvedBracket(0, 0)])


@pytest.mark.parametrize(
    ("unit", "value", "refused"),
    [
        ("bps", 10_001, True),
        ("bps", -1, True),
        ("minor", -1, True),
        ("minor", 10**12, False),
        ("count", -1, True),
        ("count", 0, False),
    ],
)
def test_check_parameter_applies_the_range_of_each_unit(
    unit: str, value: int, refused: bool
) -> None:
    """`count` has no seeded key yet, so its rule is held here rather than through the route."""
    units = {"some_key": unit}
    if refused:
        with pytest.raises(TaxParameterOutOfRangeError):
            check_parameter("some_key", value, units)
    else:
        assert check_parameter("some_key", value, units) == unit


def test_check_parameter_refuses_a_key_the_seed_does_not_hold() -> None:
    with pytest.raises(TaxParameterUnknownError):
        check_parameter("unknown_bps", 0, {"pfu_income_tax_bps": "bps"})
