"""Request/response schemas for the accounts feature."""

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field

# `deferred_card` is the holding account a deferred-debit card gets: French banks
# post card purchases to it during the month and settle the total against the
# current account on one date. It is a real balance the user watches, so it is an
# account type rather than a flag on `credit`.
AccountType = Literal["checking", "savings", "credit", "deferred_card", "cash", "other"]


class AccountCreate(BaseModel):
    """Payload to open a new account. Currency is not accepted here — it defaults to the user's."""

    name: str = Field(min_length=1, max_length=255)
    type: AccountType
    institution: str = Field(min_length=1, max_length=255)
    opening_balance_minor: int
    ofx_account_id: str | None = Field(
        default=None,
        max_length=255,
        description="The bank's own account id (OFX `ACCTID`). Optional, unique per user.",
    )


class AccountUpdate(BaseModel):
    """Patch payload: name, type, institution, the bank's account id, and the opening
    balance are mutable.

    `ofx_account_id` is patchable so an account created before its first import can be
    bound to the id its statements carry. `opening_balance_minor` is a manual correction —
    imports derive it automatically from a statement's first `LEDGERBAL` where possible,
    but a CSV-only account never gets that, so this is the escape hatch for it (and for
    fixing a bad derivation).
    """

    name: str | None = Field(default=None, min_length=1, max_length=255)
    type: AccountType | None = None
    institution: str | None = Field(default=None, min_length=1, max_length=255)
    ofx_account_id: str | None = Field(default=None, max_length=255)
    opening_balance_minor: int | None = None


class AccountRead(BaseModel):
    """An account as returned by the API, including its derived current balance."""

    id: str
    name: str
    type: str
    institution: str
    currency: str
    ofx_account_id: str | None
    opening_balance_minor: int
    balance_minor: int
    archived: bool
    created_at: datetime
    updated_at: datetime
