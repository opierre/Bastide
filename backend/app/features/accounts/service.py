"""Business logic for account creation, updates, and archive-on-delete."""

from app.core.errors import NotFoundError
from app.features.accounts.models import Account
from app.features.accounts.repository import AccountRepository
from app.features.accounts.schemas import AccountCreate, AccountUpdate
from app.features.auth.models import User


class AccountNotFoundError(NotFoundError):
    """Raised when an account doesn't exist or doesn't belong to the caller."""

    code = "ACCOUNT_NOT_FOUND"


class AccountService:
    """Account CRUD, scoped to a user, plus archive-on-delete."""

    def __init__(self, repository: AccountRepository) -> None:
        self._repository = repository

    def list_for_user(self, user_id: str) -> list[Account]:
        """List a user's non-archived accounts."""
        return self._repository.list_by_user(user_id)

    def get(self, user_id: str, account_id: str) -> Account:
        """Fetch a single account the user owns.

        Raises:
            AccountNotFoundError: no such account, or it belongs to another user.
        """
        account = self._repository.get_by_id_for_user(account_id, user_id)
        if account is None:
            raise AccountNotFoundError("Account not found.")
        return account

    def create(self, user: User, data: AccountCreate) -> Account:
        """Create an account, currency defaulted to the user's and the cache seeded."""
        account = Account(
            user_id=user.id,
            name=data.name,
            type=data.type,
            institution=data.institution,
            currency=user.currency,
            opening_balance_minor=data.opening_balance_minor,
            cached_balance_minor=data.opening_balance_minor,
        )
        return self._repository.add(account)

    def update(self, user_id: str, account_id: str, data: AccountUpdate) -> Account:
        """Patch mutable fields (name, type, institution).

        Raises:
            AccountNotFoundError: no such account, or it belongs to another user.
        """
        account = self.get(user_id, account_id)
        if data.name is not None:
            account.name = data.name
        if data.type is not None:
            account.type = data.type
        if data.institution is not None:
            account.institution = data.institution
        return self._repository.update(account)

    def archive(self, user_id: str, account_id: str) -> None:
        """Archive an account. Never hard-deletes.

        Raises:
            AccountNotFoundError: no such account, or it belongs to another user.
        """
        account = self.get(user_id, account_id)
        account.archived = True
        self._repository.update(account)
