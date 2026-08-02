"""Business logic for the monthly dashboard summary."""

from datetime import date

from app.core.errors import ValidationError
from app.features.dashboard.repository import DashboardRepository
from app.features.dashboard.schemas import CategoryBreakdown, DashboardSummary


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
    """MoM percentage change; `0.0` when there's no previous baseline to compare against."""
    if previous == 0:
        return 0.0
    return (current - previous) / previous * 100


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
