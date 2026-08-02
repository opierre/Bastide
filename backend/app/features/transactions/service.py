"""Business logic for listing transactions."""

from datetime import date

from app.features.transactions.models import Transaction
from app.features.transactions.repository import TransactionRepository

PAGE_SIZE = 50


class TransactionService:
    """Transaction listing, scoped to a user."""

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
