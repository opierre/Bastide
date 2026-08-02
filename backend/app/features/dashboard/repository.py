"""Data access for the dashboard summary: monthly income/expense aggregation."""

from datetime import date

from sqlalchemy import case, func, or_, select
from sqlalchemy.orm import Session

from app.features.accounts.models import Account
from app.features.categories.models import Category
from app.features.transactions.models import Transaction

# Bucket key for expense transactions with no category (`category_id IS NULL`). Mirrors the
# system category's i18n key so the frontend resolves it exactly like a real category would.
UNCATEGORIZED_KEY = "category.other.uncategorized"


class DashboardRepository:
    """Aggregates a user's transactions for the dashboard summary.

    A transaction counts toward income/expense unless its category's `kind` is `transfer`;
    transactions with no category (`category_id IS NULL`) are still counted, by amount sign.
    """

    def __init__(self, db: Session) -> None:
        self._db = db

    def monthly_totals(self, user_id: str, month_start: date, month_end: date) -> tuple[int, int]:
        """Sum income (positive amounts) and expense (positive magnitude of negative amounts).

        Both are minor-unit integers over `[month_start, month_end)`, excluding `kind=transfer`
        rows.
        """
        income_expr = func.sum(
            case((Transaction.amount_minor > 0, Transaction.amount_minor), else_=0)
        )
        expense_expr = func.sum(
            case((Transaction.amount_minor < 0, -Transaction.amount_minor), else_=0)
        )
        income, expense = self._db.execute(
            select(income_expr, expense_expr)
            .select_from(Transaction)
            .join(Account, Account.id == Transaction.account_id)
            .outerjoin(Category, Category.id == Transaction.category_id)
            .where(
                Account.user_id == user_id,
                Transaction.booked_date >= month_start,
                Transaction.booked_date < month_end,
                or_(Category.kind.is_(None), Category.kind != "transfer"),
            )
        ).one()
        return income or 0, expense or 0

    def expense_breakdown(
        self, user_id: str, month_start: date, month_end: date
    ) -> list[tuple[str | None, str, int]]:
        """`(category_id, name, amount_minor)` rows for the month's expenses, excluding transfers.

        Expense transactions with no category are grouped into a single `None`/`UNCATEGORIZED_KEY`
        bucket. `amount_minor` is the positive magnitude of the (negative) expense.
        """
        amount_expr = func.sum(-Transaction.amount_minor)
        rows = self._db.execute(
            select(Transaction.category_id, Category.name, amount_expr)
            .select_from(Transaction)
            .join(Account, Account.id == Transaction.account_id)
            .outerjoin(Category, Category.id == Transaction.category_id)
            .where(
                Account.user_id == user_id,
                Transaction.booked_date >= month_start,
                Transaction.booked_date < month_end,
                Transaction.amount_minor < 0,
                or_(Category.kind.is_(None), Category.kind != "transfer"),
            )
            .group_by(Transaction.category_id, Category.name)
        ).all()
        return [
            (category_id, name if category_id is not None else UNCATEGORIZED_KEY, amount)
            for category_id, name, amount in rows
        ]
