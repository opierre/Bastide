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
    by_category: list[CategoryBreakdown]
    currency: str
