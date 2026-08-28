"""Goal endpoints: virtual-envelope CRUD and the signed allocation ledger."""

from typing import Annotated

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

from app.core.db import get_db
from app.features.auth.deps import get_current_user
from app.features.auth.models import User
from app.features.goals.models import Goal
from app.features.goals.repository import GoalRepository
from app.features.goals.schemas import (
    AllocationCreate,
    AllocationRead,
    GoalCreate,
    GoalRead,
    GoalStatus,
    GoalUpdate,
)
from app.features.goals.service import GoalService

router = APIRouter(prefix="/api/v1/goals", tags=["goals"])


def _service(db: Annotated[Session, Depends(get_db)]) -> GoalService:
    return GoalService(GoalRepository(db))


def _to_read(goal: Goal, progress_minor: int) -> GoalRead:
    return GoalRead(
        id=goal.id,
        name=goal.name,
        target_minor=goal.target_minor,
        currency=goal.currency,
        target_date=goal.target_date,
        icon=goal.icon,
        color=goal.color,
        # ty: ignore[invalid-argument-type] — column is a plain str; the Literal is
        # enforced by the service, which is the only writer of this field.
        status=goal.status,
        progress_minor=progress_minor,
        # Target is constrained positive on the way in, so this ratio never divides by zero.
        progress_pct=progress_minor / goal.target_minor,
        created_at=goal.created_at,
        updated_at=goal.updated_at,
    )


@router.get("", response_model=list[GoalRead])
async def list_goals(
    service: Annotated[GoalService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
    goal_status: Annotated[
        GoalStatus | None,
        Query(alias="status", description="Return only goals in this status."),
    ] = None,
) -> list[GoalRead]:
    """List the caller's goals with their progress; archived ones only when asked for."""
    return [
        _to_read(goal, progress)
        for goal, progress in service.list_for_user(user.id, status=goal_status)
    ]


@router.post("", response_model=GoalRead, status_code=status.HTTP_201_CREATED)
async def create_goal(
    payload: GoalCreate,
    service: Annotated[GoalService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
) -> GoalRead:
    """Create a savings goal. Writes no transaction and moves no balance."""
    return _to_read(*service.create(user, payload))


@router.patch("/{goal_id}", response_model=GoalRead)
async def update_goal(
    goal_id: str,
    payload: GoalUpdate,
    service: Annotated[GoalService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
) -> GoalRead:
    """Patch a goal, including archiving it and restoring it via `status`."""
    return _to_read(*service.update(user.id, goal_id, payload))


@router.delete("/{goal_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_goal(
    goal_id: str,
    service: Annotated[GoalService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
) -> None:
    """Archive a goal (never hard-deletes â€” the allocations are history)."""
    service.archive(user.id, goal_id)


@router.get("/{goal_id}/allocations", response_model=list[AllocationRead])
async def list_allocations(
    goal_id: str,
    service: Annotated[GoalService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
) -> list[AllocationRead]:
    """One goal's allocation history, newest first."""
    return [
        AllocationRead.model_validate(allocation)
        for allocation in service.list_allocations(user.id, goal_id)
    ]


@router.post(
    "/{goal_id}/allocations", response_model=AllocationRead, status_code=status.HTTP_201_CREATED
)
async def create_allocation(
    goal_id: str,
    payload: AllocationCreate,
    service: Annotated[GoalService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
) -> AllocationRead:
    """Append a signed allocation. A negative amount takes money back out of the envelope."""
    return AllocationRead.model_validate(service.add_allocation(user.id, goal_id, payload))


@router.delete("/{goal_id}/allocations/{allocation_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_allocation(
    goal_id: str,
    allocation_id: str,
    service: Annotated[GoalService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
) -> None:
    """Undo a mistyped ledger line. There is no PATCH: a real correction is an offsetting line."""
    service.delete_allocation(user.id, goal_id, allocation_id)
