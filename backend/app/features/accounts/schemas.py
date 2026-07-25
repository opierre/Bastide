"""Request/response schemas for the accounts feature."""

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field

AccountType = Literal["checking", "savings", "credit", "cash", "other"]


class AccountCreate(BaseModel):
    """Payload to open a new account. Currency is not accepted here — it defaults to the user's."""

    name: str = Field(min_length=1, max_length=255)
    type: AccountType
    institution: str = Field(min_length=1, max_length=255)
    opening_balance_minor: int


class AccountUpdate(BaseModel):
    """Patch payload: only name, type, and institution are mutable."""

    name: str | None = Field(default=None, min_length=1, max_length=255)
    type: AccountType | None = None
    institution: str | None = Field(default=None, min_length=1, max_length=255)


class AccountRead(BaseModel):
    """An account as returned by the API, including its derived current balance."""

    id: str
    name: str
    type: str
    institution: str
    currency: str
    opening_balance_minor: int
    balance_minor: int
    archived: bool
    created_at: datetime
    updated_at: datetime
