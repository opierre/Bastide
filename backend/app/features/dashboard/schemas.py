"""Response schemas for the dashboard summary endpoint."""

from pydantic import BaseModel

from app.features.categories.hues import CategoryHue


class CategoryBreakdown(BaseModel):
    """One top-level category's slice of the month's expense total, its subcategories included.

    `name` is an i18n key for system categories and free text for user categories, same as
    `CategoryRead.name` — the frontend resolves system keys via its own ARB entries.
    """

    category_id: str | None
    name: str

    #: The category's hue slot, resolved to a colour by the app's theme; `cat0` for the
    #: uncategorized bucket.
    hue: CategoryHue
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

    #: The user's savings-rate goal in whole percent (`PATCH /settings`), what the rate's
    #: repère measures against.
    savings_rate_goal_percent: int
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
    """One month on the savings chart."""

    #: `YYYY-MM`.
    month: str

    #: What the month put aside: its own net (income − expense), not a running total, so each
    #: bar answers "how much did I save that month". Negative when the month spent more than
    #: it earned.
    saved_minor: int


class CategoryHabit(BaseModel):
    """One top-level category's spending in the month against its own monthly average.

    The category is bucketed exactly as in `CategoryBreakdown` (subcategories rolled up,
    transfers excluded, one uncategorised bucket), with the same `name` and `hue` rules.
    """

    category_id: str | None
    name: str
    hue: CategoryHue

    #: The month's spending, a positive magnitude like `CategoryBreakdown.amount_minor`.
    amount_minor: int

    #: Mean monthly spending over the months counted (`DashboardHabits.months_counted`),
    #: a positive magnitude rounded to the minor unit, halves away from zero. `null` when the
    #: category had no spending in those months: no history, not a zero average.
    average_minor: int | None

    #: `amount_minor − average_minor`: positive when the month spent more than usual. `null`
    #: with no average.
    gap_minor: int | None


class DashboardHabits(BaseModel):
    """« Par rapport à vos habitudes »: each category's month against its usual spending."""

    #: The selected month, `YYYY-MM`.
    month: str

    #: How many months the averages cover: the 12 before the selected month, fewer for a user
    #: whose first transaction is more recent, `0` when there is no earlier month of data.
    months_counted: int

    #: One row per top-level category with spending in the month. Rows with a gap come first,
    #: by the size of the gap (rises and falls mixed), then the rows without history, by
    #: amount. Not truncated: the panel's row limit is the app's to apply.
    rows: list[CategoryHabit]

    #: The sum of every row's `gap_minor`, the rows without an average left out; `null` when
    #: no row has an average.
    total_gap_minor: int | None
    currency: str


class DashboardTrends(BaseModel):
    """The dashboard's two trend series.

    Both windows are anchored on *today*, not on the month the user has selected in the picker:
    they answer "how am I trending lately", which doesn't change when the user pages back to
    look at an older month. That is why this is a separate endpoint from the summary rather
    than more fields on it — there is no `month` parameter for it to honour.
    """

    #: The last 4 months ending with the current one, oldest first.
    monthly_series: list[MonthlyTotals]

    #: The last 12 months ending with the current one, oldest first.
    savings_series: list[SavingsPoint]
    currency: str
