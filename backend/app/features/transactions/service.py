"""Business logic for listing, fetching, and patching transactions."""

from dataclasses import dataclass
from datetime import date

from app.core.errors import NotFoundError
from app.features.categories.repository import CategoryRepository
from app.features.categories.service import CategoryInvalidError
from app.features.recurring.models import RecurringSeries
from app.features.rules.engine import matches
from app.features.rules.models import CategorizationRule
from app.features.rules.repository import RuleRepository
from app.features.transactions.models import Transaction
from app.features.transactions.repository import TransactionRepository
from app.features.transactions.schemas import TransactionUpdate

PAGE_SIZE = 50

#: How many earlier operations of the same merchant the inspector lists.
SAME_MERCHANT_LIMIT = 5


@dataclass(frozen=True)
class TransactionContext:
    """What surrounds a transaction: its import, the rule that filed it, its series, and the
    merchant's earlier operations."""

    import_batch_id: str
    import_file_name: str | None
    rule: CategorizationRule | None
    series: RecurringSeries | None
    same_merchant: list[Transaction]


class TransactionNotFoundError(NotFoundError):
    """Raised when a transaction doesn't exist or doesn't belong to the caller."""

    code = "TRANSACTION_NOT_FOUND"


class TransactionService:
    """Transaction listing/detail (user-scoped) and the user category/description override."""

    def __init__(
        self,
        repository: TransactionRepository,
        categories: CategoryRepository,
        rules: RuleRepository,
    ) -> None:
        self._repository = repository
        self._categories = categories
        self._rules = rules

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
        include_linked_cards: bool = False,
        import_batch_id: str | None = None,
    ) -> tuple[list[Transaction], int, int]:
        """A filtered, paginated page of the user's transactions, the match count and the net.

        Page size is fixed. The net sums every matching row, rows excluded from totals aside.

        `include_linked_cards` adds, to an account filter, the rows of the deferred cards
        settled on that account. `import_batch_id` keeps only the rows that import added.
        """
        return self._repository.list_for_user(
            user_id,
            account_id=account_id,
            date_from=date_from,
            date_to=date_to,
            category_id=category_id,
            needs_review=needs_review,
            q=q,
            page=max(page, 1),
            page_size=PAGE_SIZE,
            include_linked_cards=include_linked_cards,
            import_batch_id=import_batch_id,
        )

    def get(self, user_id: str, transaction_id: str) -> Transaction:
        """Fetch a single transaction the user owns (via its account).

        Raises:
            TransactionNotFoundError: no such transaction, or it belongs to another user.
        """
        transaction = self._repository.get_by_id_for_user(transaction_id, user_id)
        if transaction is None:
            raise TransactionNotFoundError("Transaction not found.")
        return transaction

    def update(self, user_id: str, transaction_id: str, data: TransactionUpdate) -> Transaction:
        """Patch category/description/merchant.

        A `category_id` edit is a user categorization: it sets `categorization_source=user` and
        `needs_review=False`, which protects the row from future `rules/apply` runs.

        Raises:
            TransactionNotFoundError: no such transaction, or it belongs to another user.
            CategoryInvalidError: no such category, or it is another user's.
        """
        transaction = self.get(user_id, transaction_id)
        if data.category_id is not None:
            # The foreign key proves the category row exists, not that this user may see it —
            # without the visibility check a caller could stamp another user's private category
            # onto their own ledger, and its label and colour would render there.
            if self._categories.get_visible_by_id_for_user(data.category_id, user_id) is None:
                raise CategoryInvalidError(
                    "Category not found.",
                    {"field": "category_id", "category_id": data.category_id},
                )
            transaction.category_id = data.category_id
            transaction.categorization_source = "user"
            transaction.needs_review = False
        if data.description_clean is not None:
            transaction.description_clean = data.description_clean
        if data.merchant is not None:
            transaction.merchant = data.merchant
        if data.excluded_from_totals is not None:
            transaction.excluded_from_totals = data.excluded_from_totals
        self._repository.update(transaction)
        # Read back rather than returning the refreshed row: a refresh reloads the columns but
        # not the series id, which the response carries.
        return self.get(user_id, transaction_id)

    def context(self, user_id: str, transaction_id: str) -> TransactionContext:
        """What the inspector shows around a transaction the user owns.

        The rule is resolved when read, as the logo is: a transaction does not record which rule
        filed it. It is the first enabled rule, by priority, that matches the row and targets its
        category, and only for a row a rule filed.

        Raises:
            TransactionNotFoundError: no such transaction, or it belongs to another user.
        """
        transaction = self.get(user_id, transaction_id)
        series_id = transaction.recurring_series_id
        return TransactionContext(
            import_batch_id=transaction.import_batch_id,
            import_file_name=self._repository.import_file_name(transaction.import_batch_id),
            rule=self._filing_rule(user_id, transaction),
            series=self._repository.get_series(series_id) if series_id is not None else None,
            same_merchant=self._repository.list_same_merchant_for_user(
                user_id, transaction, limit=SAME_MERCHANT_LIMIT
            ),
        )

    def _filing_rule(self, user_id: str, transaction: Transaction) -> CategorizationRule | None:
        if transaction.categorization_source != "rule" or transaction.category_id is None:
            return None
        for rule in self._rules.list_enabled_by_user(user_id):
            if rule.category_id == transaction.category_id and matches(transaction, rule):
                return rule
        return None
