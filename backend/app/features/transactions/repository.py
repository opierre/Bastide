"""Data access for `Transaction` rows. The only place that queries this table."""

from datetime import date

from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session, selectinload, with_expression

from app.features.accounts.linked_cards import in_account
from app.features.accounts.models import Account
from app.features.categories.models import Category
from app.features.recurring.models import RecurringOccurrence
from app.features.transactions.models import Transaction

# The series each row belongs to, read alongside it: a transaction is an occurrence of at most
# one series (a unique constraint), so the correlated lookup yields one id or none. The row
# screens need it to tell an already-recurring charge from one that could still be marked.
_SERIES_ID = with_expression(
    Transaction.recurring_series_id,
    select(RecurringOccurrence.series_id)
    .where(RecurringOccurrence.transaction_id == Transaction.id)
    .correlate(Transaction)
    .scalar_subquery(),
)


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
        include_linked_cards: bool = False,
    ) -> tuple[list[Transaction], int]:
        """Filtered, paginated transactions for a user, newest first.

        With `include_linked_cards`, an `account_id` filter also takes in the rows of the
        deferred cards settled on that account (not archived), so the account reads with the
        card purchases its monthly debit pays.

        A `category_id` filter also takes in the rows filed under that category's
        sub-categories, so picking a main category shows everything beneath it.

        Eager-loads `category` (`selectinload`) so rendering a page never triggers one query
        per row.
        """
        query = (
            select(Transaction)
            .join(Account, Account.id == Transaction.account_id)
            .where(Account.user_id == user_id)
        )
        if account_id is not None:
            query = query.where(
                in_account(user_id, account_id, include_linked_cards=include_linked_cards)
            )
        if date_from is not None:
            query = query.where(Transaction.booked_date >= date_from)
        if date_to is not None:
            query = query.where(Transaction.booked_date <= date_to)
        if category_id is not None:
            subcategory_ids = select(Category.id).where(Category.parent_id == category_id)
            query = query.where(
                or_(
                    Transaction.category_id == category_id,
                    Transaction.category_id.in_(subcategory_ids),
                )
            )
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
                query.options(selectinload(Transaction.category), _SERIES_ID)
                .order_by(Transaction.booked_date.desc(), Transaction.id.desc())
                .offset((page - 1) * page_size)
                .limit(page_size)
            )
        )
        return rows, total

    def list_uncategorized_for_user(self, user_id: str) -> list[Transaction]:
        """The user's transactions carrying no category, newest first.

        The population a rule pack preview measures itself against: rows nothing has managed to
        categorise yet are exactly the ones a new pack could help with.
        """
        return list(
            self._db.scalars(
                select(Transaction)
                .join(Account, Account.id == Transaction.account_id)
                .where(Account.user_id == user_id, Transaction.category_id.is_(None))
                .options(selectinload(Transaction.category))
                .order_by(Transaction.booked_date.desc(), Transaction.id.desc())
            )
        )

    def list_all_for_user(
        self, user_id: str, *, account_id: str | None = None
    ) -> list[Transaction]:
        """The user's whole history, oldest first, optionally narrowed to one account.

        Deliberately unpaginated and unfiltered: the recurring detector re-reads every row
        rather than only the new ones, because a third occurrence promotes a group that has
        been sitting below the threshold since long before this import.
        The scan is one pass over an account's rows at a scale of thousands.
        """
        query = (
            select(Transaction)
            .join(Account, Account.id == Transaction.account_id)
            .where(Account.user_id == user_id)
        )
        if account_id is not None:
            query = query.where(Transaction.account_id == account_id)
        return list(self._db.scalars(query.order_by(Transaction.booked_date, Transaction.id)))

    def get_by_id_for_user(self, transaction_id: str, user_id: str) -> Transaction | None:
        return self._db.scalar(
            select(Transaction)
            .join(Account, Account.id == Transaction.account_id)
            .where(Transaction.id == transaction_id, Account.user_id == user_id)
            .options(selectinload(Transaction.category), _SERIES_ID)
            # The row may already sit in the session without its series id (a refresh drops
            # it), and an identity-map hit would otherwise skip the expression.
            .execution_options(populate_existing=True)
        )

    def update(self, transaction: Transaction) -> Transaction:
        self._db.commit()
        self._db.refresh(transaction)
        return transaction
