"""Data access for `Transaction` rows. The only place that queries this table."""

from datetime import date

from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session, selectinload

from app.features.accounts.models import Account
from app.features.transactions.models import Transaction


class TransactionRepository:
    """Queries and writes for transactions, always scoped to a user via the owning account."""

    def __init__(self, db: Session) -> None:
        self._db = db

    def list_for_user(
        self,
        user_id: str,
        *,
        account_id: str | None,
        date_from: date | None,
        date_to: date | None,
        category_id: str | None,
        needs_review: bool | None,
        q: str | None,
        page: int,
        page_size: int,
    ) -> tuple[list[Transaction], int]:
        """Filtered, paginated transactions for a user, newest first.

        Eager-loads `category` (`selectinload`) so rendering a page never triggers one query
        per row.
        """
        query = (
            select(Transaction)
            .join(Account, Account.id == Transaction.account_id)
            .where(Account.user_id == user_id)
        )
        if account_id is not None:
            query = query.where(Transaction.account_id == account_id)
        if date_from is not None:
            query = query.where(Transaction.booked_date >= date_from)
        if date_to is not None:
            query = query.where(Transaction.booked_date <= date_to)
        if category_id is not None:
            query = query.where(Transaction.category_id == category_id)
        if needs_review is not None:
            query = query.where(Transaction.needs_review == needs_review)
        if q:
            pattern = f"%{q}%"
            query = query.where(
                or_(
                    Transaction.description_clean.ilike(pattern),
                    Transaction.merchant.ilike(pattern),
                )
            )

        total = self._db.scalar(select(func.count()).select_from(query.subquery())) or 0

        rows = list(
            self._db.scalars(
                query.options(selectinload(Transaction.category))
                .order_by(Transaction.booked_date.desc(), Transaction.id.desc())
                .offset((page - 1) * page_size)
                .limit(page_size)
            )
        )
        return rows, total

    def get_by_id_for_user(self, transaction_id: str, user_id: str) -> Transaction | None:
        return self._db.scalar(
            select(Transaction)
            .join(Account, Account.id == Transaction.account_id)
            .where(Transaction.id == transaction_id, Account.user_id == user_id)
            .options(selectinload(Transaction.category))
        )

    def update(self, transaction: Transaction) -> Transaction:
        self._db.commit()
        self._db.refresh(transaction)
        return transaction
