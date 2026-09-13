"""Business logic for the monthly dashboard summary."""

from datetime import date

from app.core.errors import ValidationError
from app.core.months import first_of_month, month_index, month_key
from app.features.dashboard.repository import DashboardRepository
from app.features.dashboard.schemas import (
    CategoryBreakdown,
    DashboardSummary,
    DashboardTrends,
    MonthlyTotals,
    SavingsPoint,
)

#: How many months each trend series covers, ending with the current month.
BARS_MONTHS = 4
SAVINGS_MONTHS = 6


class DashboardMonthInvalidError(ValidationError):
    """Raised when `month` isn't a valid `YYYY-MM` value."""

    code = "DASHBOARD_MONTH_INVALID"


class DashboardService:
    """Computes the monthly summary: totals, savings rate, MoM deltas, and category breakdown."""

    def __init__(self, repository: DashboardRepository) -> None:
        self._repository = repository

    def summary(self, user_id: str, currency: str, month: str) -> DashboardSummary:
        """Build the summary for `month` (`YYYY-MM`), comparing against the previous month.

        Raises:
            DashboardMonthInvalidError: `month` doesn't parse as `YYYY-MM`.
        """
        current = _parse_month(month)
        month_start, month_end = first_of_month(current), first_of_month(current + 1)
        prev_start = first_of_month(current - 1)

        income, expense = self._repository.monthly_totals(user_id, month_start, month_end)
        prev_income, prev_expense = self._repository.monthly_totals(
            user_id, prev_start, month_start
        )

        savings_rate = _safe_ratio(income - expense, income)
        prev_savings_rate = _safe_ratio(prev_income - prev_expense, prev_income)

        expense_rows = self._repository.expense_breakdown(user_id, month_start, month_end)
        by_category = [
            CategoryBreakdown(
                category_id=category_id,
                name=name,
                amount_minor=amount_minor,
                pct=(amount_minor / expense * 100) if expense > 0 else 0.0,
            )
            for category_id, name, amount_minor in expense_rows
        ]

        return DashboardSummary(
            income_minor=income,
            expense_minor=expense,
            net_minor=income - expense,
            savings_rate=savings_rate,
            income_delta_pct=_delta_pct(income, prev_income),
            expense_delta_pct=_delta_pct(expense, prev_expense),
            net_delta_pct=_delta_pct(income - expense, prev_income - prev_expense),
            savings_rate_delta_pct=_savings_rate_delta_pct(
                savings_rate, prev_savings_rate, prev_income
            ),
            by_category=by_category,
            currency=currency,
        )

    def trends(self, user_id: str, currency: str, today: date) -> DashboardTrends:
        """Both trend series, over the months ending with `today`'s.

        Anchored on `today` rather than on a requested month: these answer "how am I trending
        lately", a question the month picker doesn't change. `today` is a parameter rather than
        a `date.today()` call so the series are testable without freezing the clock.
        """
        current = month_index(today)
        months = range(current - SAVINGS_MONTHS + 1, current + 1)
        window_start = first_of_month(months[0])

        buckets = self._repository.monthly_totals_by_month(
            user_id, window_start, first_of_month(current + 1)
        )

        # Everything saved before the window opens, so the line starts at the user's real
        # standing rather than at zero six months ago.
        running = self._repository.net_before(user_id, window_start)
        savings_series: list[SavingsPoint] = []
        monthly_series: list[MonthlyTotals] = []
        bars_from = current - BARS_MONTHS + 1

        for index in months:
            month_start = first_of_month(index)
            income, expense = buckets.get((month_start.year, month_start.month), (0, 0))
            running += income - expense
            savings_series.append(SavingsPoint(month=month_key(index), cumulative_minor=running))
            if index >= bars_from:
                monthly_series.append(
                    MonthlyTotals(
                        month=month_key(index),
                        income_minor=income,
                        expense_minor=expense,
                        net_minor=income - expense,
                    )
                )

        return DashboardTrends(
            monthly_series=monthly_series,
            savings_series=savings_series,
            currency=currency,
        )


def _parse_month(month: str) -> int:
    """Parse `YYYY-MM` into a month index.

    Raises:
        DashboardMonthInvalidError: `month` doesn't parse as `YYYY-MM`.
    """
    parts = month.split("-")
    if len(parts) != 2:
        raise DashboardMonthInvalidError(f"Invalid month '{month}', expected YYYY-MM.")
    try:
        return month_index(date(int(parts[0]), int(parts[1]), 1))
    except ValueError as exc:
        raise DashboardMonthInvalidError(f"Invalid month '{month}', expected YYYY-MM.") from exc


def _delta_pct(current: int, previous: int) -> float:
    """MoM percentage change; `0.0` when there's no previous baseline to compare against.

    Divided by the *magnitude* of the baseline, so the sign of the result is always the
    direction of the move. Net can be negative, and a signed divisor inverts it: a month going
    from −200,00 € to +100,00 € is a recovery, but `(100_00 − −200_00) / −200_00` reports
    −150 %, which the dashboard's trend pill paints red and points downwards. Income and expense
    are non-negative totals, so `abs` leaves their deltas unchanged.
    """
    if previous == 0:
        return 0.0
    return (current - previous) / abs(previous) * 100


def _savings_rate_delta_pct(rate: float, prev_rate: float, prev_income: int) -> float:
    """MoM change in savings rate, in points.

    `0.0` when the previous month has no income to rate against.
    """
    if prev_income == 0:
        return 0.0
    return (rate - prev_rate) * 100


def _safe_ratio(numerator: int, denominator: int) -> float:
    """`numerator / denominator`, or `0.0` when `denominator <= 0` (no income to divide by)."""
    if denominator <= 0:
        return 0.0
    return numerator / denominator
