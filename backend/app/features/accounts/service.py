"""Business logic for account creation, updates, and archive-on-delete."""

from sqlalchemy.orm import Session

from app.core.errors import ConflictError, NotFoundError
from app.features.accounts.balance import shift_opening_balance
from app.features.accounts.models import Account
from app.features.accounts.repository import AccountRepository
from app.features.accounts.schemas import AccountCreate, AccountUpdate
from app.features.auth.models import User


class AccountNotFoundError(NotFoundError):
    """Raised when an account doesn't exist or doesn't belong to the caller."""

    code = "ACCOUNT_NOT_FOUND"


class OfxAccountIdTakenError(ConflictError):
    """Raised when another of the user's accounts already carries that bank account id."""

    code = "ACCOUNT_OFX_ID_TAKEN"


def _normalize_ofx_account_id(value: str | None) -> str | None:
    """Trim, and treat a blank id as absent — an empty string identifies nothing."""
    if value is None:
        return None
    trimmed = value.strip()
    return trimmed or None


class AccountService:
    """Account CRUD, scoped to a user, plus archive-on-delete."""

    def __init__(self, repository: AccountRepository, db: Session) -> None:
        self._repository = repository
        # Needed only for `update`'s opening-balance correction (cache + snapshot shift);
        # every other method here goes through the repository alone.
        self._db = db

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

    def find_by_ofx_account_id(self, user_id: str, ofx_account_id: str) -> Account | None:
        """The user's account carrying this bank account id, or None.

        This is the exact answer to "does this statement's account already
        exist" — the id comes from the file itself, so unlike a bank name it
        needs no guessing.
        """
        normalized = _normalize_ofx_account_id(ofx_account_id)
        if normalized is None:
            return None
        return self._repository.get_by_ofx_account_id(normalized, user_id)

    def create(self, user: User, data: AccountCreate) -> Account:
        """Create an account with the cache seeded from its opening balance.

        Currency falls back to the user's, which is the Phase 1 answer for every
        account the user types by hand (one currency per user — see the
        multi-currency skill). A declared one wins over it: an account proposed by
        an OFX statement is denominated by that file's `CURDEF`, and storing the
        profile currency instead would relabel — not convert — every figure the
        import goes on to write.

        Raises:
            OfxAccountIdTakenError: another account of this user already carries
                the given `ofx_account_id`.
        """
        ofx_account_id = self._claim_ofx_account_id(user.id, data.ofx_account_id)
        account = Account(
            user_id=user.id,
            name=data.name,
            type=data.type,
            institution=data.institution,
            currency=(data.currency or user.currency).upper(),
            ofx_account_id=ofx_account_id,
            opening_balance_minor=data.opening_balance_minor,
            cached_balance_minor=data.opening_balance_minor,
        )
        return self._repository.add(account)

    def update(self, user_id: str, account_id: str, data: AccountUpdate) -> Account:
        """Patch mutable fields (name, type, institution, ofx_account_id, opening_balance_minor).

        `opening_balance_minor` is the manual escape hatch: imports derive it from a
        statement automatically (see the imports service), but a statement without a
        `LEDGERBAL` never yields one, and a bad first derivation needs a way back. Shifting
        it keeps the cache and every existing snapshot consistent rather than just patching
        the field.

        Raises:
            AccountNotFoundError: no such account, or it belongs to another user.
            OfxAccountIdTakenError: another account of this user already carries
                the given `ofx_account_id`.
        """
        account = self.get(user_id, account_id)
        if data.name is not None:
            account.name = data.name
        if data.type is not None:
            account.type = data.type
        if data.institution is not None:
            account.institution = data.institution
        if data.ofx_account_id is not None:
            account.ofx_account_id = self._claim_ofx_account_id(
                user_id, data.ofx_account_id, allow_account_id=account.id
            )
        if data.opening_balance_minor is not None:
            shift_opening_balance(self._db, account, data.opening_balance_minor)
        return self._repository.update(account)

    def _claim_ofx_account_id(
        self, user_id: str, value: str | None, allow_account_id: str | None = None
    ) -> str | None:
        """Normalize a bank account id and check no other account of the user holds it.

        Enforced here rather than left to the unique constraint so the caller
        gets the error envelope with a usable code instead of an integrity error.

        Raises:
            OfxAccountIdTakenError: the id belongs to another of the user's accounts.
        """
        normalized = _normalize_ofx_account_id(value)
        if normalized is None:
            return None
        existing = self._repository.get_by_ofx_account_id(normalized, user_id)
        if existing is not None and existing.id != allow_account_id:
            raise OfxAccountIdTakenError(
                "Another account already uses this bank account id.",
                details={"account_id": existing.id},
            )
        return normalized

    def archive(self, user_id: str, account_id: str) -> None:
        """Archive an account. Never hard-deletes.

        Raises:
            AccountNotFoundError: no such account, or it belongs to another user.
        """
        account = self.get(user_id, account_id)
        account.archived = True
        self._repository.update(account)
