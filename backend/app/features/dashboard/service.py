"""Business logic for the monthly dashboard summary."""

from datetime import date

from app.core.errors import ValidationError
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
        month_start, month_end = _month_bounds(month)
        prev_start, prev_end = _previous_month_bounds(month_start)

        income, expense = self._repository.monthly_totals(user_id, month_start, month_end)
        prev_income, prev_expense = self._repository.monthly_totals(user_id, prev_start, prev_end)

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
        current = date(today.year, today.month, 1)
        months = _months_ending_at(current, SAVINGS_MONTHS)
        window_end = _next_month(current)

        buckets = self._repository.monthly_totals_by_month(user_id, months[0], window_end)

        # Everything saved before the window opens, so the line starts at the user's real
        # standing rather than at zero six months ago.
        running = self._repository.net_before(user_id, months[0])
        savings_series: list[SavingsPoint] = []
        monthly_series: list[MonthlyTotals] = []
        bars_from = months[SAVINGS_MONTHS - BARS_MONTHS]

        for month_start in months:
            income, expense = buckets.get((month_start.year, month_start.month), (0, 0))
            running += income - expense
            savings_series.append(
                SavingsPoint(month=_month_key(month_start), cumulative_minor=running)
            )
            if month_start >= bars_from:
                monthly_series.append(
                    MonthlyTotals(
                        month=_month_key(month_start),
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


def _month_key(month_start: date) -> str:
    """`YYYY-MM` for a first-of-month date."""
    return f"{month_start.year:04d}-{month_start.month:02d}"


def _next_month(month_start: date) -> date:
    if month_start.month == 12:
        return date(month_start.year + 1, 1, 1)
    return date(month_start.year, month_start.month + 1, 1)


def _months_ending_at(current: date, count: int) -> list[date]:
    """The `count` first-of-month dates ending with `current`, oldest first."""
    months: list[date] = []
    for offset in range(count - 1, -1, -1):
        total = current.year * 12 + (current.month - 1) - offset
        months.append(date(total // 12, total % 12 + 1, 1))
    return months


def _month_bounds(month: str) -> tuple[date, date]:
    """Parse `YYYY-MM` into `[month_start, month_end)`."""
    parts = month.split("-")
    if len(parts) != 2:
        raise DashboardMonthInvalidError(f"Invalid month '{month}', expected YYYY-MM.")
    try:
        year, mon = int(parts[0]), int(parts[1])
        month_start = date(year, mon, 1)
    except ValueError as exc:
        raise DashboardMonthInvalidError(f"Invalid month '{month}', expected YYYY-MM.") from exc

    month_end = date(year + 1, 1, 1) if mon == 12 else date(year, mon + 1, 1)
    return month_start, month_end


def _previous_month_bounds(month_start: date) -> tuple[date, date]:
    """The `[prev_start, prev_end)` window for the month immediately before `month_start`."""
    if month_start.month == 1:
        prev_start = date(month_start.year - 1, 12, 1)
    else:
        prev_start = date(month_start.year, month_start.month - 1, 1)
    return prev_start, month_start


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
