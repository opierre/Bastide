"""Which transactions an account filter covers once its linked cards are taken in.

One definition, shared by every query that widens an account to the deferred cards settled
on it: the transaction list (`include_linked_cards`) and the categorization run started from
the review queue. The queue must be exactly the run's input, so the two may never disagree on
what a linked card is.
"""

from typing import Any

from sqlalchemy import ColumnElement, Select, or_, select

from app.features.accounts.models import Account
from app.features.transactions.models import Transaction


def linked_card_ids(user_id: str, account_id: str) -> Select[Any]:
    """The ids of the user's non-archived deferred cards settled on ``account_id``."""
    return select(Account.id).where(
        Account.user_id == user_id,
        Account.settlement_account_id == account_id,
        Account.type == "deferred_card",
        Account.archived.is_(False),
    )


def in_account(user_id: str, account_id: str, *, include_linked_cards: bool) -> ColumnElement[bool]:
    """A filter on `Transaction` for one account, optionally with its linked cards' rows."""
    if not include_linked_cards:
        return Transaction.account_id == account_id
    return or_(
        Transaction.account_id == account_id,
        Transaction.account_id.in_(linked_card_ids(user_id, account_id)),
    )
