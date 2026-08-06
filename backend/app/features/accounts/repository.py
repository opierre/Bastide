"""Data access for `Account` rows. The only place that queries this table."""

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.features.accounts.models import Account


class AccountRepository:
    """Queries and writes for accounts, always scoped to a user."""

    def __init__(self, db: Session) -> None:
        self._db = db

    def list_by_user(self, user_id: str) -> list[Account]:
        return list(
            self._db.scalars(
                select(Account)
                .where(Account.user_id == user_id, Account.archived.is_(False))
                .order_by(Account.created_at)
            )
        )

    def get_by_id_for_user(self, account_id: str, user_id: str) -> Account | None:
        return self._db.scalar(
            select(Account).where(Account.id == account_id, Account.user_id == user_id)
        )

    def get_by_ofx_account_id(self, ofx_account_id: str, user_id: str) -> Account | None:
        """The user's account carrying this bank account id, archived or not.

        Archived rows count: they still hold the id, so leaving them out would
        report an id as free and then fail on the unique constraint.
        """
        return self._db.scalar(
            select(Account).where(
                Account.ofx_account_id == ofx_account_id,
                Account.user_id == user_id,
            )
        )

    def add(self, account: Account) -> Account:
        self._db.add(account)
        self._db.commit()
        self._db.refresh(account)
        return account

    def update(self, account: Account) -> Account:
        self._db.commit()
        self._db.refresh(account)
        return account
