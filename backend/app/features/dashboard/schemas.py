"""Response schemas for the dashboard summary endpoint."""

from pydantic import BaseModel


class CategoryBreakdown(BaseModel):
    """One category's slice of the month's expense total.

    `name` is an i18n key for system categories and free text for user categories, same as
    `CategoryRead.name` — the frontend resolves system keys via its own ARB entries.
    """

    category_id: str | None
    name: str
    amount_minor: int
    pct: float


class DashboardSummary(BaseModel):
    """The monthly dashboard summary: totals, MoM deltas, and the expense breakdown."""

    income_minor: int
    expense_minor: int
    net_minor: int
    savings_rate: float
    income_delta_pct: float
    expense_delta_pct: float
    net_delta_pct: float

    #: MoM change in savings rate, in percentage *points* (e.g. `0.223` → `0.204` is `-1.9`, not
    #: `-8.5`), so the frontend can show it directly beside the ratio without rescaling.
    savings_rate_delta_pct: float
    by_category: list[CategoryBreakdown]
    currency: str


class MonthlyTotals(BaseModel):
    """One month's income and expense, for the income-vs-expense bars."""

    #: `YYYY-MM`.
    month: str
    income_minor: int

    #: Positive magnitude, matching `DashboardSummary.expense_minor`.
    expense_minor: int
    net_minor: int


class SavingsPoint(BaseModel):
    """One point on the cumulative-savings line."""

    #: `YYYY-MM`.
    month: str

    #: Running total of net across every month up to and including this one — including months
    #: before the returned window, so the line starts where the user's savings actually stand
    #: rather than at zero.
    cumulative_minor: int


class DashboardTrends(BaseModel):
    """The dashboard's two trend series.

    Both windows are anchored on *today*, not on the month the user has selected in the picker:
    they answer "how am I trending lately", which doesn't change when the user pages back to
    look at an older month. That is why this is a separate endpoint from the summary rather
    than more fields on it — there is no `month` parameter for it to honour.
    """

    #: The last 4 months ending with the current one, oldest first.
    monthly_series: list[MonthlyTotals]

    #: The last 6 months ending with the current one, oldest first.
    savings_series: list[SavingsPoint]
    currency: str
