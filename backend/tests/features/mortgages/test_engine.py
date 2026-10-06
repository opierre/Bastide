"""The amortisation engine against its invariants and a hand-computed reference."""

import inspect
from datetime import date
from decimal import ROUND_DOWN, Decimal, localcontext

import pytest

from app.features.mortgages import engine
from app.features.mortgages.engine import (
    NonAmortizingLoanError,
    RepaymentType,
    Schedule,
    build_schedule,
    taeg_bps,
)


def _loan(
    *,
    principal_minor: int = 20_000_000,
    annual_rate_bps: int = 345,
    term_months: int = 240,
    insurance_monthly_minor: int = 0,
    repayment_type: RepaymentType = RepaymentType.CONSTANT_PAYMENT,
    first_payment_date: date = date(2026, 1, 31),
    upfront_fees_minor: int = 0,
) -> Schedule:
    return build_schedule(
        principal_minor=principal_minor,
        annual_rate_bps=annual_rate_bps,
        term_months=term_months,
        insurance_monthly_minor=insurance_monthly_minor,
        repayment_type=repayment_type,
        first_payment_date=first_payment_date,
        upfront_fees_minor=upfront_fees_minor,
    )


def _assert_invariants(schedule: Schedule, principal_minor: int) -> None:
    assert sum(row.principal_minor for row in schedule.rows) == principal_minor
    assert schedule.rows[-1].outstanding_after_minor == 0
    assert all(row.principal_minor > 0 for row in schedule.rows)


# 1 000,00 € at 12 % (1 % a month) over 4 months with 5,00 € insurance, worked by hand:
# payment = 100 000 × 0,01 / (1 − 1,01⁻⁴) = 25 628,11 → 25 628. Row 4 absorbs the residue and its
# interest 253,75 rounds half-up to 254. Columns: due_on, instalment, interest, principal,
# insurance, outstanding_after.
REFERENCE_ROWS = [
    (date(2026, 1, 31), 26_128, 1_000, 24_628, 500, 75_372),
    (date(2026, 2, 28), 26_128, 754, 24_874, 500, 50_498),
    (date(2026, 3, 31), 26_128, 505, 25_123, 500, 25_375),
    (date(2026, 4, 30), 26_129, 254, 25_375, 500, 0),
]


def test_reference_loan_matches_the_hand_computed_table() -> None:
    schedule = _loan(
        principal_minor=100_000,
        annual_rate_bps=1200,
        term_months=4,
        insurance_monthly_minor=500,
        upfront_fees_minor=15_000,
    )

    assert [
        (
            row.due_on,
            row.instalment_minor,
            row.interest_minor,
            row.principal_minor,
            row.insurance_minor,
            row.outstanding_after_minor,
        )
        for row in schedule.rows
    ] == REFERENCE_ROWS
    assert [row.ordinal for row in schedule.rows] == [1, 2, 3, 4]
    assert schedule.total_interest_minor == 2_513
    assert schedule.total_insurance_minor == 2_000
    assert sum(row.instalment_minor for row in schedule.rows) == 104_513
    assert schedule.total_cost_minor == 2_513 + 2_000 + 15_000


@pytest.mark.parametrize("principal_minor", [100, 99_999, 12_345_678, 50_000_000])
@pytest.mark.parametrize("annual_rate_bps", [0, 1, 199, 345, 777, 1999])
@pytest.mark.parametrize("term_months", [1, 7, 180, 360])
def test_constant_payment_invariants_hold(
    principal_minor: int, annual_rate_bps: int, term_months: int
) -> None:
    try:
        schedule = _loan(
            principal_minor=principal_minor,
            annual_rate_bps=annual_rate_bps,
            term_months=term_months,
        )
    except NonAmortizingLoanError:
        # Only a principal too small to spread over the term in whole cents may refuse.
        assert principal_minor < term_months * 2
        return

    assert len(schedule.rows) == term_months
    _assert_invariants(schedule, principal_minor)


def test_zero_rate_spreads_the_principal_with_the_residue_last() -> None:
    schedule = _loan(principal_minor=1_000_000, annual_rate_bps=0, term_months=7)

    assert all(row.interest_minor == 0 for row in schedule.rows)
    # 1 000 000 / 7 = 142 857,14 → 142 857; the last row takes the 6 cents left over.
    assert [row.principal_minor for row in schedule.rows] == [142_857] * 6 + [142_858]
    _assert_invariants(schedule, 1_000_000)


def test_one_month_term_repays_everything_at_once() -> None:
    schedule = _loan(principal_minor=500_000, annual_rate_bps=600, term_months=1)

    (row,) = schedule.rows
    assert row.interest_minor == 2_500
    assert row.principal_minor == 500_000
    assert row.instalment_minor == 502_500
    assert row.outstanding_after_minor == 0


def test_interest_only_pays_interest_then_the_principal_whole() -> None:
    schedule = _loan(
        principal_minor=10_000_000,
        annual_rate_bps=333,
        term_months=12,
        repayment_type=RepaymentType.INTEREST_ONLY,
    )

    # 10 000 000 × 0,0333 / 12 = 27 750.
    assert all(row.interest_minor == 27_750 for row in schedule.rows)
    assert [row.principal_minor for row in schedule.rows] == [0] * 11 + [10_000_000]
    assert [row.outstanding_after_minor for row in schedule.rows] == [10_000_000] * 11 + [0]
    assert schedule.rows[-1].instalment_minor == 10_027_750


def test_insurance_rides_on_top_without_touching_interest_or_principal() -> None:
    bare = _loan()
    insured = _loan(insurance_monthly_minor=4_200)

    for bare_row, insured_row in zip(bare.rows, insured.rows, strict=True):
        assert insured_row.interest_minor == bare_row.interest_minor
        assert insured_row.principal_minor == bare_row.principal_minor
        assert insured_row.outstanding_after_minor == bare_row.outstanding_after_minor
        assert insured_row.insurance_minor == 4_200
        assert insured_row.instalment_minor == bare_row.instalment_minor + 4_200
    assert insured.total_interest_minor == bare.total_interest_minor


def test_loan_whose_first_instalment_does_not_amortise_raises() -> None:
    # 3 cents at 20 %: the payment rounds to 0 and never covers anything.
    with pytest.raises(NonAmortizingLoanError):
        _loan(principal_minor=3, annual_rate_bps=2000, term_months=12)


def test_yearly_aggregation_equals_the_sum_of_its_months() -> None:
    schedule = _loan(insurance_monthly_minor=3_100, first_payment_date=date(2026, 5, 15))
    years = schedule.by_year()

    # 240 months from May 2026 run to April 2046.
    assert [year.year for year in years] == list(range(2026, 2047))
    for totals in years:
        months = [row for row in schedule.rows if row.due_on.year == totals.year]
        assert totals.instalment_minor == sum(row.instalment_minor for row in months)
        assert totals.interest_minor == sum(row.interest_minor for row in months)
        assert totals.principal_minor == sum(row.principal_minor for row in months)
        assert totals.insurance_minor == sum(row.insurance_minor for row in months)
        assert totals.outstanding_end_minor == months[-1].outstanding_after_minor
    assert sum(year.principal_minor for year in years) == 20_000_000
    assert sum(year.instalment_minor for year in years) == sum(
        row.instalment_minor for row in schedule.rows
    )


def test_outstanding_at_reads_the_generated_rows() -> None:
    schedule = _loan(principal_minor=100_000, annual_rate_bps=1200, term_months=4)

    assert schedule.outstanding_at(date(2026, 1, 30)) == 100_000
    assert schedule.outstanding_at(date(2026, 1, 31)) == 75_372
    assert schedule.outstanding_at(date(2026, 3, 15)) == 50_498
    assert schedule.outstanding_at(date(2030, 1, 1)) == 0


def test_payment_day_is_clamped_per_month_without_drifting() -> None:
    schedule = _loan(first_payment_date=date(2027, 12, 31), term_months=3)

    assert [row.due_on for row in schedule.rows] == [
        date(2027, 12, 31),
        date(2028, 1, 31),
        date(2028, 2, 29),
    ]


def test_caller_decimal_context_does_not_leak_in() -> None:
    expected = _loan(annual_rate_bps=417, term_months=300)

    with localcontext() as ctx:
        ctx.prec = 3
        ctx.rounding = ROUND_DOWN
        assert _loan(annual_rate_bps=417, term_months=300) == expected


def test_non_positive_principal_or_term_is_rejected() -> None:
    with pytest.raises(ValueError):
        _loan(principal_minor=0)
    with pytest.raises(ValueError):
        _loan(term_months=0)


@pytest.mark.parametrize(
    ("annual_rate_bps", "term_months"), [(345, 240), (120, 12), (777, 360), (1999, 60)]
)
def test_taeg_of_a_bare_loan_is_the_nominal_rate_annual_equivalent(
    annual_rate_bps: int, term_months: int
) -> None:
    schedule = _loan(annual_rate_bps=annual_rate_bps, term_months=term_months)
    monthly = Decimal(annual_rate_bps) / 120_000
    expected = ((1 + monthly) ** 12 - 1) * 10_000

    assert abs(taeg_bps(schedule) - expected) <= 1


def test_taeg_rises_with_fees_and_with_insurance() -> None:
    bare = taeg_bps(_loan())

    assert taeg_bps(_loan(upfront_fees_minor=150_000)) > bare
    assert taeg_bps(_loan(insurance_monthly_minor=4_200)) > bare


def test_taeg_of_a_free_loan_is_zero() -> None:
    assert taeg_bps(_loan(annual_rate_bps=0)) == 0


def test_taeg_rejects_fees_that_swallow_the_principal() -> None:
    with pytest.raises(ValueError):
        taeg_bps(_loan(principal_minor=100_000, upfront_fees_minor=100_000))


def test_engine_source_never_mentions_float() -> None:
    assert "float" not in inspect.getsource(engine)
