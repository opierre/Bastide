"""Bank directory lookup: turn a French bank code into the bank's name."""

from typing import Annotated

from fastapi import APIRouter, Depends, Query

from app.features.auth.deps import get_current_user
from app.features.auth.models import User
from app.features.banks.directory import normalize_bank_code, resolve_bank_name
from app.features.banks.schemas import BankRead

router = APIRouter(prefix="/api/v1/banks", tags=["banks"])


@router.get("", response_model=list[BankRead])
async def lookup_bank(
    _user: Annotated[User, Depends(get_current_user)],
    bank_code: Annotated[
        str,
        Query(description="A French bank code (OFX `BANKID`), or any string starting with one."),
    ],
) -> list[BankRead]:
    """Resolve a French bank code to the bank that carries it.

    Returns zero or one entry rather than 404-ing on a miss: an unknown code is
    an ordinary outcome of a best-effort guess, not a client mistake — the
    caller simply falls back to showing the raw code.
    """
    name = resolve_bank_name(bank_code)
    code = normalize_bank_code(bank_code)
    if name is None or code is None:
        return []
    return [BankRead(bank_code=code, name=name)]
