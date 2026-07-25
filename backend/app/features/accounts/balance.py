"""Balance helpers: cache delta application, point-in-time lookup, and full recompute.

The ledger (`transactions`) is the source of truth; `Account.cached_balance_minor` is a
maintained-by-delta cache so normal reads are O(1). See the database skill for the full
balance strategy this module implements.
"""

from datetime import date

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.features.accounts.models import Account, AccountBalanceSnapshot
from app.features.transactions.models import Transaction


def current_balance(account: Account) -> int:
    """The account's current balance, read straight from the cache. O(1) — no query."""
    return account.cached_balance_minor


def apply_delta(account: Account, delta_minor: int) -> None:
    """Adjust ``cached_balance_minor`` by a signed delta.

    Callers must apply this inside the same DB transaction as the ledger insert/edit/delete
    that produced the delta, so the cache never drifts from the ledger it derives from.
    """
    account.cached_balance_minor += delta_minor


def point_in_time_balance(db: Session, account: Account, as_of: date) -> int:
    """Balance as of ``as_of``: nearest snapshot at or before it, plus the rows since.

    Falls back to the account's opening balance plus every row up to ``as_of`` when no
    snapshot exists yet (e.g. a fresh account), bounding the query to a small row count either
    way rather than summing the whole ledger.
    """
    snapshot = db.scalar(
        select(AccountBalanceSnapshot)
        .where(
            AccountBalanceSnapshot.account_id == account.id,
            AccountBalanceSnapshot.period_end <= as_of,
        )
        .order_by(AccountBalanceSnapshot.period_end.desc())
        .limit(1)
    )

    rows_since_query = select(func.coalesce(func.sum(Transaction.amount_minor), 0)).where(
        Transaction.account_id == account.id,
        Transaction.booked_date <= as_of,
    )

    if snapshot is not None:
        base = snapshot.balance_minor
        rows_since_query = rows_since_query.where(Transaction.booked_date > snapshot.period_end)
    else:
        base = account.opening_balance_minor

    rows_since_sum = db.scalar(rows_since_query) or 0
    return base + rows_since_sum


def recompute_balance(db: Session, account: Account) -> int:
    """Full reconciliation: opening balance plus every transaction on the ledger.

    A repair/verification routine only (post-import integrity check, or a manual "recalculate"
    action) — never on the normal read path, which uses `current_balance` instead.
    """
    total = db.scalar(
        select(func.coalesce(func.sum(Transaction.amount_minor), 0)).where(
            Transaction.account_id == account.id
        )
    )
    return account.opening_balance_minor + (total or 0)
