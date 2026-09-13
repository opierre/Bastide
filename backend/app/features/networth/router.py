"""Net-worth endpoint: one derived summary, recomputed per request and never cached."""

from datetime import date
from typing import Annotated

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.db import get_db
from app.features.auth.deps import get_current_user
from app.features.auth.models import User
from app.features.networth.repository import NetWorthRepository
from app.features.networth.schemas import NetWorthSummary
from app.features.networth.service import NetWorthService

router = APIRouter(prefix="/api/v1/networth", tags=["networth"])


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
