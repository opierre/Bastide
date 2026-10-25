"""Net-worth endpoints: the derived summary, and the month-end totals a user declares.

The summary is recomputed per request and never cached.
"""

from datetime import date
from typing import Annotated

from fastapi import APIRouter, Depends, Path, status
from sqlalchemy.orm import Session

from app.core.db import get_db
from app.features.auth.deps import get_current_user
from app.features.auth.models import User
from app.features.networth.repository import NetWorthRepository
from app.features.networth.schemas import (
    DeclaredBalanceRead,
    DeclaredBalanceWrite,
    NetWorthSummary,
)
from app.features.networth.service import NetWorthService

router = APIRouter(prefix="/api/v1/networth", tags=["networth"])

MonthKey = Annotated[
    str, Path(pattern=r"^\d{4}-(0[1-9]|1[0-2])$", description="The month, as `YYYY-MM`.")
]


def _service(db: Annotated[Session, Depends(get_db)]) -> NetWorthService:
    return NetWorthService(NetWorthRepository(db))


def get_today() -> date:
    """The date net worth is measured at; a dependency so tests can pin it."""
    return date.today()


@router.get("/summary", response_model=NetWorthSummary)
async def get_summary(
    service: Annotated[NetWorthService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
    today: Annotated[date, Depends(get_today)],
) -> NetWorthSummary:
    """Assets, liabilities, net worth, the asset composition and the closed-month series."""
    return service.summary(user, today)


@router.get("/declared", response_model=list[DeclaredBalanceRead])
async def list_declared(
    service: Annotated[NetWorthService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
) -> list[DeclaredBalanceRead]:
    """The month-end totals the caller declared, oldest first."""
    return service.declared(user)


@router.put("/declared/{month}", response_model=DeclaredBalanceRead)
async def put_declared(
    month: MonthKey,
    payload: DeclaredBalanceWrite,
    service: Annotated[NetWorthService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
    today: Annotated[date, Depends(get_today)],
) -> DeclaredBalanceRead:
    """Declare, or replace, what all accounts held together at the end of a closed month."""
    return service.declare(user, month, payload.amount_minor, today)


@router.delete("/declared/{month}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_declared(
    month: MonthKey,
    service: Annotated[NetWorthService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
) -> None:
    """Remove the caller's declared total for a month."""
    service.remove_declared(user, month)
