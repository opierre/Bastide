"""Response schemas for the banks feature."""

from pydantic import BaseModel


class BankRead(BaseModel):
    """A bank code resolved to the bank it belongs to."""

    bank_code: str
    name: str
