"""Unit tests for the placement arithmetic: no database, no app."""

from datetime import date

import pytest

from app.features.placements.engine import (
    Holding,
    add_months,
    ceiling_for,
    full_months_between,
    ratio_bps,
)


def _holding(**overrides: object) -> Holding:
    fields: dict[str, object] = {
        "envelope": "pea",
        "opened_on": date(2024, 3, 10),
        "closed_on": None,
        "movements": ((date(2024, 3, 10), 500_000), (date(2025, 1, 5), 200_000)),
        "valuations": ((date(2024, 12, 31), 560_000),),
    }
    fields.update(overrides)
    return Holding(**fields)


@pytest.mark.parametrize(
    ("day", "months", "expected"),
    [
        (date(2024, 3, 10), 60, date(2029, 3, 10)),
        (date(2024, 2, 29), 12, date(2025, 2, 28)),
        (date(2026, 7, 31), -4, date(2026, 3, 31)),
        (date(2026, 6, 30), -4, date(2026, 2, 28)),
    ],
)
def test_add_months_clamps_to_the_month_end(day: date, months: int, expected: date) -> None:
    assert add_months(day, months) == expected


@pytest.mark.parametrize(
    ("start", "end", "expected"),
    [
        (date(2023, 3, 10), date(2026, 5, 15), 38),
        (date(2023, 3, 20), date(2026, 5, 15), 37),
        (date(2026, 5, 15), date(2026, 5, 1), 0),
    ],
)
def test_full_months_between(start: date, end: date, expected: int) -> None:
    assert full_months_between(start, end) == expected


@pytest.mark.parametrize(
    ("numerator", "denominator", "expected"),
    [
        (161, 1_000, 1_610),
        (1, 3, 3_333),
        (-1, 3, -3_333),
        (1, 20_000, 1),  # 0.5 bps rounds away from zero
        (-1, 20_000, -1),
        (100, 0, None),
        (100, -50, None),
    ],
)
def test_ratio_bps_rounds_half_away_from_zero(
    numerator: int, denominator: int, expected: int | None
) -> None:
    assert ratio_bps(numerator, denominator) == expected


def test_ceiling_is_shown_only_in_euros() -> None:
    assert ceiling_for("pea", "EUR") == 15_000_000
    assert ceiling_for("pea", "eur") == 15_000_000
    assert ceiling_for("pea", "CHF") is None
    assert ceiling_for("life_insurance", "EUR") is None


def test_value_counts_net_payments_before_the_first_declaration() -> None:
    assert _holding().value_on(date(2024, 6, 30)) == 500_000


def test_value_holds_the_last_declaration_flat() -> None:
    holding = _holding()
    assert holding.value_on(date(2024, 12, 31)) == 560_000
    # A payment after the last declaration does not move the declared value.
    assert holding.value_on(date(2025, 2, 28)) == 560_000
    assert holding.net_payments_on(date(2025, 2, 28)) == 700_000


def test_value_is_zero_before_opening_and_from_closing() -> None:
    holding = _holding(closed_on=date(2025, 6, 15))
    assert holding.value_on(date(2024, 2, 29)) == 0
    assert holding.value_on(date(2025, 6, 14)) == 560_000
    assert holding.value_on(date(2025, 6, 15)) == 0


def test_values_stay_integers() -> None:
    holding = _holding()
    for day in (date(2024, 6, 30), date(2025, 2, 28)):
        assert type(holding.value_on(day)) is int
        assert type(holding.net_payments_on(day)) is int
