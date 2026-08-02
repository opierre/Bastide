"""Business logic for listing, fetching, and patching transactions."""

from datetime import date

from app.core.errors import NotFoundError
from app.features.transactions.models import Transaction
from app.features.transactions.repository import TransactionRepository
from app.features.transactions.schemas import TransactionUpdate

PAGE_SIZE = 50


class TransactionNotFoundError(NotFoundError):
    """Raised when a transaction doesn't exist or doesn't belong to the caller."""

    code = "TRANSACTION_NOT_FOUND"


class TransactionService:
    """Transaction listing/detail (user-scoped) and the user category/description override."""

    def __init__(self, repository: TransactionRepository) -> None:
        self._repository = repository

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
    ) -> tuple[list[Transaction], int]:
        """A filtered, paginated page of the user's transactions. Page size is fixed."""
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
        """
        transaction = self.get(user_id, transaction_id)
        if data.category_id is not None:
            transaction.category_id = data.category_id
            transaction.categorization_source = "user"
            transaction.needs_review = False
        if data.description_clean is not None:
            transaction.description_clean = data.description_clean
        if data.merchant is not None:
            transaction.merchant = data.merchant
        return self._repository.update(transaction)
