"""Mortgage endpoints: declared-loan CRUD with figures derived from the schedule per request."""

from datetime import date
from typing import Annotated

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

from app.core.db import get_db
from app.features.auth.deps import get_current_user
from app.features.auth.models import User
from app.features.mortgages.repository import MortgageRepository
from app.features.mortgages.schemas import (
    MortgageCreate,
    MortgageDetail,
    MortgageRead,
    MortgageStatus,
    MortgageSummary,
    MortgageUpdate,
    ScheduleGranularity,
    ScheduleRead,
)
from app.features.mortgages.service import MortgageService

router = APIRouter(prefix="/api/v1/mortgages", tags=["mortgages"])


def _service(db: Annotated[Session, Depends(get_db)]) -> MortgageService:
    return MortgageService(MortgageRepository(db))


def get_today() -> date:
    """The date every "as of today" figure is computed at; a dependency so tests can pin it."""
    return date.today()


@router.get("", response_model=list[MortgageRead])
async def list_mortgages(
    service: Annotated[MortgageService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
    today: Annotated[date, Depends(get_today)],
    mortgage_status: Annotated[
        MortgageStatus | None,
        Query(alias="status", description="Return only loans in this status."),
    ] = None,
) -> list[MortgageRead]:
    """List the caller's loans with their derived figures; archived ones only when asked for."""
    return service.list_for_user(user, today, status=mortgage_status)


@router.post("", response_model=MortgageDetail, status_code=status.HTTP_201_CREATED)
async def create_mortgage(
    payload: MortgageCreate,
    service: Annotated[MortgageService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
    today: Annotated[date, Depends(get_today)],
) -> MortgageDetail:
    """Declare a loan. Writes no transaction, moves no balance, stores no schedule."""
    return service.create(user, payload, today)


# Declared before `/{mortgage_id}` so "summary" is never read as a loan id.
@router.get("/summary", response_model=MortgageSummary)
async def get_summary(
    service: Annotated[MortgageService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
    today: Annotated[date, Depends(get_today)],
) -> MortgageSummary:
    """Totals over active loans, the debt ratio with its income source, and the trajectory.

    `over_limit` is a reading, never a refusal: the app makes no lending decisions (§15).
    """
    return service.summary(user, today)


@router.get("/{mortgage_id}", response_model=MortgageDetail)
async def get_mortgage(
    mortgage_id: str,
    service: Annotated[MortgageService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
    today: Annotated[date, Depends(get_today)],
) -> MortgageDetail:
    """One loan with its cost totals and indicative TAEG."""
    return service.get(user, mortgage_id, today)


@router.patch("/{mortgage_id}", response_model=MortgageDetail)
async def update_mortgage(
    mortgage_id: str,
    payload: MortgageUpdate,
    service: Annotated[MortgageService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
    today: Annotated[date, Depends(get_today)],
) -> MortgageDetail:
    """Patch a loan, including archiving, restoring and marking it repaid via `status`."""
    return service.update(user, mortgage_id, payload, today)


@router.get("/{mortgage_id}/schedule", response_model=ScheduleRead)
async def get_schedule(
    mortgage_id: str,
    service: Annotated[MortgageService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
    start: Annotated[
        date | None, Query(alias="from", description="First due date included.")
    ] = None,
    end: Annotated[date | None, Query(alias="to", description="Last due date included.")] = None,
    granularity: Annotated[
        ScheduleGranularity, Query(description="`month` rows, or the same rows summed per year.")
    ] = "month",
) -> ScheduleRead:
    """A date window of the loan's amortisation schedule, derived per request."""
    return service.schedule(user, mortgage_id, start=start, end=end, granularity=granularity)


@router.delete("/{mortgage_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_mortgage(
    mortgage_id: str,
    service: Annotated[MortgageService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
) -> None:
    """Archive a loan (never hard-deletes)."""
    service.archive(user.id, mortgage_id)
