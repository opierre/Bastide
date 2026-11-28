"""Data access for the dashboard summary: monthly income/expense aggregation."""

from datetime import date
from typing import Any

from sqlalchemy import ColumnElement, case, extract, func, or_, select
from sqlalchemy.orm import Session, aliased

from app.features.accounts.models import Account
from app.features.categories.hues import CategoryHue, slot_for
from app.features.categories.models import Category
from app.features.settings.models import UserSettings
from app.features.transactions.models import Transaction

# Bucket key for expense transactions with no category (`category_id IS NULL`). Mirrors the
# system category's i18n key so the frontend resolves it exactly like a real category would.
UNCATEGORIZED_KEY = "category.other.uncategorized"

# Hue slot of that bucket: the neutral catch-all, like any category without a hue.
UNCATEGORIZED_HUE: CategoryHue = "cat0"


class DashboardRepository:
    """Aggregates a user's transactions for the dashboard summary.

    A transaction counts toward income/expense unless its category's `kind` is `transfer`;
    transactions with no category (`category_id IS NULL`) are still counted, by amount sign.
    """

    def __init__(self, db: Session) -> None:
        self._db = db

    def savings_rate_goal_percent(self, user_id: str) -> int | None:
        """The user's savings-rate goal in whole percent; `None` with no settings row yet."""
        return self._db.scalar(
            select(UserSettings.savings_rate_goal_percent).where(UserSettings.user_id == user_id)
        )

    def monthly_totals_by_month(
        self, user_id: str, start: date, end: date
    ) -> dict[tuple[int, int], tuple[int, int]]:
        """`(year, month)` → `(income, expense)` for every month in `[start, end)` that has rows.

        Income sums the positive amounts and expense the magnitude of the negative ones, both in
        minor units, excluding `kind=transfer` rows. Grouped per month so a summary and its
        comparison month, or a whole trend series, cost one query. Months with no transactions
        are simply absent from the mapping; the caller decides what a gap means (zero, so far).

        Grouped with `extract()` rather than `strftime()` so the query keeps working on
        PostgreSQL — SQLAlchemy compiles it to each backend's own dialect.
        """
        year = extract("year", Transaction.booked_date)
        month = extract("month", Transaction.booked_date)
        income_expr = func.sum(
            case((Transaction.amount_minor > 0, Transaction.amount_minor), else_=0)
        )
        expense_expr = func.sum(
            case((Transaction.amount_minor < 0, -Transaction.amount_minor), else_=0)
        )
        rows = self._db.execute(
            select(year, month, income_expr, expense_expr)
            .select_from(Transaction)
            .join(Account, Account.id == Transaction.account_id)
            .outerjoin(Category, Category.id == Transaction.category_id)
            .where(
                Account.user_id == user_id,
                Transaction.booked_date >= start,
                Transaction.booked_date < end,
                or_(Category.kind.is_(None), Category.kind != "transfer"),
            )
            .group_by(year, month)
        ).all()
        return {
            (int(row_year), int(row_month)): (income or 0, expense or 0)
            for row_year, row_month, income, expense in rows
        }

    def expense_breakdown(
        self, user_id: str, month_start: date, month_end: date
    ) -> list[tuple[str | None, str, CategoryHue, int]]:
        """`(category_id, name, hue, amount_minor)` per top-level category for the month's expenses.

        A subcategory's spending rolls up to its parent, so each row is a top-level category
        (categories are two levels deep: a parent is always top-level). `hue` is that top-level
        category's slot, so a custom category is drawn in the hue it picked. Transfers are
        excluded by the transaction's own category. Expense transactions with no category are
        grouped into a single `None`/`UNCATEGORIZED_KEY` bucket. `amount_minor` is the positive
        magnitude of the (negative) expense.
        """
        rows = self._expense_by_top_category(user_id, month_start, month_end, by_month=False)
        return [(category_id, name, hue, amount) for category_id, name, hue, _, amount in rows]

    def expense_by_category_and_month(
        self, user_id: str, start: date, end: date
    ) -> list[tuple[str | None, str, CategoryHue, tuple[int, int], int]]:
        """`(category_id, name, hue, (year, month), amount_minor)` for expenses in `[start, end)`.

        The same buckets as `expense_breakdown` (top-level categories with their subcategories,
        transfers excluded, one uncategorised bucket, positive magnitudes), split per month in
        one grouped query. A month without spending in a category is absent.
        """
        return self._expense_by_top_category(user_id, start, end, by_month=True)

    def first_booked_date(self, user_id: str) -> date | None:
        """The booking date of the user's earliest transaction, any kind; `None` with none."""
        return self._db.scalar(
            select(func.min(Transaction.booked_date))
            .select_from(Transaction)
            .join(Account, Account.id == Transaction.account_id)
            .where(Account.user_id == user_id)
        )

    def _expense_by_top_category(
        self, user_id: str, start: date, end: date, *, by_month: bool
    ) -> list[tuple[str | None, str, CategoryHue, tuple[int, int], int]]:
        """Expense magnitudes per top-level category in `[start, end)`, optionally per month.

        Without `by_month` every row carries `(0, 0)` as its month.
        """
        parent = aliased(Category)
        top_id = func.coalesce(parent.id, Category.id)
        top_name = func.coalesce(parent.name, Category.name)
        top_color = func.coalesce(parent.color, Category.color)
        amount_expr = func.sum(-Transaction.amount_minor)
        group_columns: list[ColumnElement[Any]] = [top_id, top_name, top_color]
        if by_month:
            group_columns += [
                extract("year", Transaction.booked_date),
                extract("month", Transaction.booked_date),
            ]
        rows = self._db.execute(
            select(*group_columns, amount_expr)
            .select_from(Transaction)
            .join(Account, Account.id == Transaction.account_id)
            .outerjoin(Category, Category.id == Transaction.category_id)
            .outerjoin(parent, parent.id == Category.parent_id)
            .where(
                Account.user_id == user_id,
                Transaction.booked_date >= start,
                Transaction.booked_date < end,
                Transaction.amount_minor < 0,
                or_(Category.kind.is_(None), Category.kind != "transfer"),
            )
            .group_by(*group_columns)
        ).all()
        result: list[tuple[str | None, str, CategoryHue, tuple[int, int], int]] = []
        for row in rows:
            category_id, name, color = row[0], row[1], row[2]
            month = (int(row[3]), int(row[4])) if by_month else (0, 0)
            amount = int(row[-1])
            if category_id is None:
                result.append((None, UNCATEGORIZED_KEY, UNCATEGORIZED_HUE, month, amount))
            else:
                result.append((category_id, name, slot_for(color), month, amount))
        return result
