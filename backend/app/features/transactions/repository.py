"""Data access for `Transaction` rows. The only place that queries this table."""

from datetime import date

from sqlalchemy import Select, func, or_, select
from sqlalchemy.orm import Session, selectinload, with_expression

from app.features.accounts.linked_cards import in_account
from app.features.accounts.models import Account
from app.features.categories.models import Category
from app.features.imports.models import ImportBatch
from app.features.recurring.models import RecurringOccurrence, RecurringSeries
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
        import_batch_id: str | None = None,
    ) -> tuple[list[Transaction], int, int]:
        """Filtered, paginated transactions for a user, newest first, with the count and the net.

        With `include_linked_cards`, an `account_id` filter also takes in the rows of the
        deferred cards settled on that account (not archived), so the account reads with the
        card purchases its monthly debit pays.

        A `category_id` filter also takes in the rows filed under that category's
        sub-categories, so picking a main category shows everything beneath it.

        An `import_batch_id` filter keeps the rows that import added. A batch of another
        user matches nothing, since the account join already scopes rows to `user_id`.

        The net is the signed sum of every row the filters match, across all pages, leaving
        out the rows the user excluded from totals.

        Eager-loads `category` (`selectinload`) so rendering a page never triggers one query
        per row.
        """
        query = self._filtered(
            user_id,
            account_id=account_id,
            date_from=date_from,
            date_to=date_to,
            category_id=category_id,
            needs_review=needs_review,
            q=q,
            include_linked_cards=include_linked_cards,
            import_batch_id=import_batch_id,
        )

        total = self._db.scalar(select(func.count()).select_from(query.subquery())) or 0
        counted = query.where(Transaction.excluded_from_totals.is_(False)).subquery()
        net = self._db.scalar(select(func.coalesce(func.sum(counted.c.amount_minor), 0))) or 0

        rows = list(
            self._db.scalars(
                query.options(selectinload(Transaction.category), _SERIES_ID)
                .order_by(Transaction.booked_date.desc(), Transaction.id.desc())
                .offset((page - 1) * page_size)
                .limit(page_size)
            )
        )
        return rows, total, net

    def _filtered(
        self,
        user_id: str,
        *,
        account_id: str | None,
        date_from: date | None,
        date_to: date | None,
        category_id: str | None,
        needs_review: bool | None,
        q: str | None,
        include_linked_cards: bool,
        import_batch_id: str | None,
    ) -> Select[tuple[Transaction]]:
        """The user's transactions narrowed by the list's filters, unordered and unpaged."""
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
        if import_batch_id is not None:
            query = query.where(Transaction.import_batch_id == import_batch_id)
        if q:
            pattern = f"%{q}%"
            query = query.where(
                or_(
                    Transaction.description_clean.ilike(pattern),
                    Transaction.merchant.ilike(pattern),
                )
            )
        return query

    def list_same_merchant_for_user(
        self, user_id: str, transaction: Transaction, *, limit: int
    ) -> list[Transaction]:
        """Up to `limit` earlier operations of the same merchant as `transaction`, newest first.

        The same merchant is the same `merchant`, case aside; a row without one is matched on
        its cleaned label instead. Any of the user's accounts; `transaction` itself is left out,
        and so is anything booked after it.
        """
        if transaction.merchant:
            same = func.lower(Transaction.merchant) == transaction.merchant.lower()
        else:
            same = Transaction.description_clean == transaction.description_clean
        return list(
            self._db.scalars(
                select(Transaction)
                .join(Account, Account.id == Transaction.account_id)
                .where(
                    Account.user_id == user_id,
                    Transaction.id != transaction.id,
                    Transaction.booked_date <= transaction.booked_date,
                    same,
                )
                .order_by(Transaction.booked_date.desc(), Transaction.id.desc())
                .limit(limit)
            )
        )

    def import_file_name(self, import_batch_id: str) -> str | None:
        """The file name of the import that added a row."""
        return self._db.scalar(
            select(ImportBatch.file_name).where(ImportBatch.id == import_batch_id)
        )

    def get_series(self, series_id: str) -> RecurringSeries | None:
        """The recurring series a row is an occurrence of."""
        return self._db.get(RecurringSeries, series_id)

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
