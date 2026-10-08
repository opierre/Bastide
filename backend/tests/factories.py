"""Persisted parent rows for tests that build data straight on a session.

The test engines enforce foreign keys like the app's, so a row can only point at a user, account
or import batch that exists — a random uuid in its place now fails the insert.
"""

from datetime import date
from uuid import uuid4

from sqlalchemy.orm import Session

from app.features.accounts.models import Account
from app.features.auth.models import User
from app.features.imports.models import ImportBatch


def make_user(db: Session) -> User:
    """Persist a user with a unique email."""
    user = User(
        email=f"{uuid4()}@example.test",
        password_hash="hash",
        display_name="Camille",
        locale="fr",
        currency="EUR",
    )
    db.add(user)
    db.flush()
    return user


def make_account(db: Session, **overrides: object) -> Account:
    """Persist an account, owned by a fresh user unless `user_id` is given."""
    kwargs: dict[str, object] = {
        "name": "Compte courant",
        "type": "checking",
        "institution": "BNP Paribas",
        "currency": "EUR",
        "opening_balance_minor": 0,
        "cached_balance_minor": 0,
        "archived": False,
    }
    kwargs.update(overrides)
    if "user_id" not in kwargs:
        kwargs["user_id"] = make_user(db).id
    account = Account(**kwargs)
    db.add(account)
    db.flush()
    return account


def make_import_batch(db: Session, account: Account, **overrides: object) -> ImportBatch:
    """Persist a successful import batch into `account`."""
    kwargs: dict[str, object] = {
        "user_id": account.user_id,
        "account_id": account.id,
        "source_format": "ofx",
        "file_name": "jan.ofx",
        "file_hash": str(uuid4()),
        "period_start": date(2026, 1, 1),
        "period_end": date(2026, 1, 31),
        "transaction_count": 0,
        "new_count": 0,
        "duplicate_count": 0,
        "status": "success",
    }
    kwargs.update(overrides)
    batch = ImportBatch(**kwargs)
    db.add(batch)
    db.flush()
    return batch
