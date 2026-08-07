"""Dashboard endpoint: the monthly summary (income, expense, savings rate, MoM, breakdown)."""

from datetime import date
from typing import Annotated

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.core.db import get_db
from app.features.auth.deps import get_current_user
from app.features.auth.models import User
from app.features.dashboard.repository import DashboardRepository
from app.features.dashboard.schemas import DashboardSummary, DashboardTrends
from app.features.dashboard.service import DashboardService

router = APIRouter(prefix="/api/v1/dashboard", tags=["dashboard"])


def _service(db: Annotated[Session, Depends(get_db)]) -> DashboardService:
    return DashboardService(DashboardRepository(db))


@router.get("/summary", response_model=DashboardSummary)
async def get_summary(
    service: Annotated[DashboardService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
    month: Annotated[str, Query(pattern=r"^\d{4}-\d{2}$")],
) -> DashboardSummary:
    """The caller's monthly summary in their single currency."""
    return service.summary(user.id, user.currency, month)


@router.get("/trends", response_model=DashboardTrends)
async def get_trends(
    service: Annotated[DashboardService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
) -> DashboardTrends:
    """The caller's recent trend series.

    Deliberately takes no `month`: both windows end with the *current* month, so paging the
    dashboard's month picker back doesn't move them.
    """
    return service.trends(user.id, user.currency, date.today())
