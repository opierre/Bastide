"""Balance helpers: cache delta application, point-in-time lookup, and opening-balance shifts.

The ledger (`transactions`) is the source of truth; `Account.cached_balance_minor` is a
maintained-by-delta cache so normal reads are O(1). See the database skill for the full
balance strategy this module implements.
"""

from datetime import date

from sqlalchemy import func, select, update
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


def shift_opening_balance(db: Session, account: Account, new_opening_balance_minor: int) -> None:
    """Change the account's opening balance, keeping the cache and every snapshot consistent.

    The ledger itself is untouched by this, so every figure derived from the opening
    balance — the cache and each monthly snapshot — must move by exactly the delta the
    opening balance moves by, rather than being recomputed independently of it. A cache-only
    fix (or none at all) would leave existing snapshots silently wrong: still offset by the
    old opening balance, so `point_in_time_balance` would answer differently before and after
    a snapshot boundary for a balance that never actually changed on the given date.

    Used both when an import derives the opening balance from a statement's first `LEDGERBAL`
    and when a user corrects it by hand — the two are the same operation with a different
    source for the new value.
    """
    delta = new_opening_balance_minor - account.opening_balance_minor
    if delta == 0:
        return
    account.opening_balance_minor = new_opening_balance_minor
    account.cached_balance_minor += delta
    db.execute(
        update(AccountBalanceSnapshot)
        .where(AccountBalanceSnapshot.account_id == account.id)
        .values(balance_minor=AccountBalanceSnapshot.balance_minor + delta)
    )
