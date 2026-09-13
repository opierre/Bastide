"""The amortisation schedule engine (PROJECT.md §15).

A pure function of the declared loan inputs: plain integers and a date in, a full instalment
schedule and its cost totals out. No ORM, no HTTP, no I/O — the Crédits panel and the Simulateur
both compute against this one module.

All arithmetic is exact ``Decimal`` under a private context, so no result depends on the
caller's context and no binary approximation ever touches an amount or a rate.
"""

import calendar
from dataclasses import dataclass
from datetime import date
from decimal import ROUND_HALF_EVEN, ROUND_HALF_UP, Context, Decimal, localcontext
from enum import StrEnum

# Far beyond what 360 compounding periods at any sane rate need; fixed so every caller gets the
# same digits whatever context they run under.
_CONTEXT = Context(prec=50, rounding=ROUND_HALF_EVEN)
_BPS_PER_UNIT = 10_000
_MONTHS_PER_YEAR = 12
_TAEG_MONTHLY_TOLERANCE = Decimal("1e-15")


class RepaymentType(StrEnum):
    """The maths the schedule runs on (`mortgages.repayment_type`)."""

    CONSTANT_PAYMENT = "constant_payment"
    INTEREST_ONLY = "interest_only"


class NonAmortizingLoanError(Exception):
    """Raised when a loan's instalments do not repay its principal period after period.

    The closed form has no answer for a balance that does not shrink — typically a first
    instalment that does not cover its first interest — and the panel has nothing to draw.
    P3-04 maps it to a 422.
    """


@dataclass(frozen=True)
class ScheduleRow:
    """One instalment. ``instalment_minor`` is payment plus insurance."""

    ordinal: int
    due_on: date
    instalment_minor: int
    interest_minor: int
    principal_minor: int
    insurance_minor: int
    outstanding_after_minor: int


@dataclass(frozen=True)
class YearTotals:
    """The instalments due in one calendar year, summed from the schedule rows."""

    year: int
    instalment_minor: int
    interest_minor: int
    principal_minor: int
    insurance_minor: int
    outstanding_end_minor: int


@dataclass(frozen=True)
class Schedule:
    """A generated schedule and its totals; every view derives from ``rows``."""

    principal_minor: int
    upfront_fees_minor: int
    rows: tuple[ScheduleRow, ...]

    @property
    def total_interest_minor(self) -> int:
        return sum(row.interest_minor for row in self.rows)

    @property
    def total_insurance_minor(self) -> int:
        return sum(row.insurance_minor for row in self.rows)

    @property
    def total_cost_minor(self) -> int:
        """What the loan costs beyond the capital: interest, insurance and upfront fees."""
        return self.total_interest_minor + self.total_insurance_minor + self.upfront_fees_minor

    def outstanding_at(self, on: date) -> int:
        """Capital still owed after every instalment due on or before ``on``."""
        outstanding = self.principal_minor
        for row in self.rows:
            if row.due_on > on:
                break
            outstanding = row.outstanding_after_minor
        return outstanding

    def by_year(self) -> tuple[YearTotals, ...]:
        """Instalments aggregated per calendar year, in ascending order."""
        years: dict[int, list[ScheduleRow]] = {}
        for row in self.rows:
            years.setdefault(row.due_on.year, []).append(row)
        return tuple(
            YearTotals(
                year=year,
                instalment_minor=sum(row.instalment_minor for row in rows),
                interest_minor=sum(row.interest_minor for row in rows),
                principal_minor=sum(row.principal_minor for row in rows),
                insurance_minor=sum(row.insurance_minor for row in rows),
                outstanding_end_minor=rows[-1].outstanding_after_minor,
            )
            for year, rows in years.items()
        )


def build_schedule(
    *,
    principal_minor: int,
    annual_rate_bps: int,
    term_months: int,
    insurance_monthly_minor: int,
    repayment_type: RepaymentType,
    first_payment_date: date,
    upfront_fees_minor: int,
) -> Schedule:
    """Generate the full instalment schedule of a declared loan.

    The payment is rounded half-up to minor units once and held constant; the final instalment
    absorbs the rounding residue so the loan ends exactly repaid. Insurance rides on top of each
    instalment and is never amortised.

    Raises:
        ValueError: If an input is out of range (non-positive principal or term, negative rate,
            insurance or fees).
        NonAmortizingLoanError: If a constant-payment instalment does not repay a positive part
            of the principal before the final row.
    """
    if principal_minor <= 0 or term_months <= 0:
        raise ValueError("principal_minor and term_months must be positive")
    if annual_rate_bps < 0 or insurance_monthly_minor < 0 or upfront_fees_minor < 0:
        raise ValueError("annual_rate_bps, insurance_monthly_minor and fees must not be negative")

    with localcontext(_CONTEXT):
        rate = Decimal(annual_rate_bps) / (_MONTHS_PER_YEAR * _BPS_PER_UNIT)
        if repayment_type is RepaymentType.INTEREST_ONLY:
            rows = _interest_only_rows(principal_minor, rate, term_months)
        else:
            rows = _constant_payment_rows(principal_minor, rate, term_months)

    return Schedule(
        principal_minor=principal_minor,
        upfront_fees_minor=upfront_fees_minor,
        rows=tuple(
            ScheduleRow(
                ordinal=ordinal,
                due_on=_add_months(first_payment_date, ordinal - 1),
                instalment_minor=interest + principal + insurance_monthly_minor,
                interest_minor=interest,
                principal_minor=principal,
                insurance_minor=insurance_monthly_minor,
                outstanding_after_minor=outstanding,
            )
            for ordinal, (interest, principal, outstanding) in enumerate(rows, start=1)
        ),
    )


def taeg_bps(schedule: Schedule) -> int:
    """The loan's indicative TAEG, in basis points.

    The internal rate of return of the actual flows — the advance ``principal − upfront_fees``
    against every instalment including insurance — solved by bisection on the monthly rate and
    annualised as ``(1 + m)^12 − 1``. Indicative only (§15): a real TAEG includes fees we never
    see.

    Raises:
        ValueError: If the upfront fees swallow the whole principal, leaving no advance.
    """
    advance = schedule.principal_minor - schedule.upfront_fees_minor
    if advance <= 0:
        raise ValueError("upfront_fees_minor must be smaller than principal_minor")
    instalments = [row.instalment_minor for row in schedule.rows]

    with localcontext(_CONTEXT):

        def net_present_value(monthly_rate: Decimal) -> Decimal:
            discount = 1 / (1 + monthly_rate)
            factor = Decimal(1)
            present_value = Decimal(0)
            for instalment in instalments:
                factor *= discount
                present_value += instalment * factor
            return advance - present_value

        # Repaying no more than the advance is a zero cost of credit.
        if net_present_value(Decimal(0)) >= 0:
            return 0
        low, high = Decimal(0), Decimal(1)
        while net_present_value(high) < 0:
            high *= 2
        # A monthly-rate bracket this narrow moves the annual rate by far less than 1 bps.
        while high - low > _TAEG_MONTHLY_TOLERANCE:
            middle = (low + high) / 2
            if net_present_value(middle) < 0:
                low = middle
            else:
                high = middle
        monthly = (low + high) / 2
        return _round_half_up(((1 + monthly) ** _MONTHS_PER_YEAR - 1) * _BPS_PER_UNIT)


def _constant_payment_rows(
    principal_minor: int, rate: Decimal, term_months: int
) -> list[tuple[int, int, int]]:
    """``(interest, principal, outstanding_after)`` per period for an échéance constante."""
    if rate == 0:
        payment = _round_half_up(Decimal(principal_minor) / term_months)
    else:
        payment = _round_half_up(principal_minor * rate / (1 - (1 + rate) ** -term_months))

    rows: list[tuple[int, int, int]] = []
    outstanding = principal_minor
    for ordinal in range(1, term_months + 1):
        interest = _round_half_up(outstanding * rate)
        if ordinal == term_months:
            principal = outstanding
        else:
            principal = payment - interest
            # A non-positive principal is a balance that never shrinks; one that reaches the
            # whole outstanding early leaves later rows with nothing to repay.
            if principal <= 0 or principal >= outstanding:
                raise NonAmortizingLoanError(
                    f"instalment {ordinal} does not amortise the loan: "
                    f"payment {payment}, interest {interest}, outstanding {outstanding}"
                )
        outstanding -= principal
        rows.append((interest, principal, outstanding))
    return rows


def _interest_only_rows(
    principal_minor: int, rate: Decimal, term_months: int
) -> list[tuple[int, int, int]]:
    """``(interest, principal, outstanding_after)`` per period for a prêt in fine."""
    interest = _round_half_up(principal_minor * rate)
    rows = [(interest, 0, principal_minor)] * (term_months - 1)
    rows.append((interest, principal_minor, 0))
    return rows


def _round_half_up(value: Decimal) -> int:
    return int(value.quantize(Decimal(1), rounding=ROUND_HALF_UP))


def _add_months(anchor: date, months: int) -> date:
    """``anchor`` shifted by whole months, its day clamped to the target month's length.

    Always computed from the anchor, so a loan paid on the 31st returns to the 31st after a
    short month instead of drifting to the 28th.
    """
    month_index = anchor.month - 1 + months
    year = anchor.year + month_index // _MONTHS_PER_YEAR
    month = month_index % _MONTHS_PER_YEAR + 1
    return date(year, month, min(anchor.day, calendar.monthrange(year, month)[1]))
