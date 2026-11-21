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
from app.features.settings.models import DEFAULT_SAVINGS_RATE_GOAL_PERCENT

#: How many months each trend series covers: the bars end with the current month, the savings
#: series with the selected one.
BARS_MONTHS = 4
SAVINGS_MONTHS = 12


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

        # Both months in one grouped query; a month without rows is absent, which means zero.
        buckets = self._repository.monthly_totals_by_month(user_id, prev_start, month_end)
        income, expense = buckets.get((month_start.year, month_start.month), (0, 0))
        prev_income, prev_expense = buckets.get((prev_start.year, prev_start.month), (0, 0))

        savings_rate = _safe_ratio(income - expense, income)
        prev_savings_rate = _safe_ratio(prev_income - prev_expense, prev_income)

        expense_rows = self._repository.expense_breakdown(user_id, month_start, month_end)
        by_category = [
            CategoryBreakdown(
                category_id=category_id,
                name=name,
                hue=hue,
                amount_minor=amount_minor,
                pct=(amount_minor / expense * 100) if expense > 0 else 0.0,
            )
            for category_id, name, hue, amount_minor in expense_rows
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
            savings_rate_goal_percent=self._savings_rate_goal_percent(user_id),
            by_category=by_category,
            currency=currency,
        )

    def _savings_rate_goal_percent(self, user_id: str) -> int:
        """The user's goal, or the default before their settings row exists."""
        goal = self._repository.savings_rate_goal_percent(user_id)
        return DEFAULT_SAVINGS_RATE_GOAL_PERCENT if goal is None else goal

    def trends(
        self, user_id: str, currency: str, today: date, month: str | None = None
    ) -> DashboardTrends:
        """Both trend series: savings over the months ending with `month` (`YYYY-MM`), the
        monthly bars over the months ending with `today`'s.

        The savings window follows the dashboard's selected month (default: `today`'s), so
        paging the month picker back shows the year leading up to that month. The monthly bars
        stay anchored on the calendar whatever `month` is. `today` is a parameter rather than a
        `date.today()` call so the series are testable without freezing the clock.

        Raises:
            DashboardMonthInvalidError: `month` doesn't parse as `YYYY-MM`.
        """
        this_month = month_index(today)
        savings_end = this_month if month is None else _parse_month(month)
        savings_months = range(savings_end - SAVINGS_MONTHS + 1, savings_end + 1)
        bars_months = range(this_month - BARS_MONTHS + 1, this_month + 1)

        # One grouped query spanning both windows; a month without rows is absent, i.e. zero.
        buckets = self._repository.monthly_totals_by_month(
            user_id,
            first_of_month(min(savings_months[0], bars_months[0])),
            first_of_month(max(savings_end, this_month) + 1),
        )

        def totals(index: int) -> tuple[int, int]:
            month_start = first_of_month(index)
            return buckets.get((month_start.year, month_start.month), (0, 0))

        savings_series = [
            SavingsPoint(month=month_key(index), saved_minor=income - expense)
            for index in savings_months
            for income, expense in [totals(index)]
        ]
        monthly_series = [
            MonthlyTotals(
                month=month_key(index),
                income_minor=income,
                expense_minor=expense,
                net_minor=income - expense,
            )
            for index in bars_months
            for income, expense in [totals(index)]
        ]

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
