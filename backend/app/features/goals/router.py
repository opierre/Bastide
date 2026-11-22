"""Goal endpoints: virtual-envelope CRUD, the banner image and the allocation ledger."""

from datetime import date
from typing import Annotated

from fastapi import APIRouter, Depends, File, Header, Query, Response, UploadFile, status
from sqlalchemy.orm import Session

from app.core.db import get_db
from app.features.auth.deps import get_current_user
from app.features.auth.models import User
from app.features.goals.images import MAX_UPLOAD_BYTES
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


def _to_read(goal: Goal, progress_minor: int, reached_on: date | None) -> GoalRead:
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
        reached_on=reached_on,
        image_updated_at=goal.image.updated_at if goal.image is not None else None,
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
    return [_to_read(*view) for view in service.list_for_user(user.id, status=goal_status)]


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
    """Delete a goal with its allocations and banner image. Archiving is how to keep it."""
    service.delete(user.id, goal_id)


@router.get(
    "/{goal_id}/image",
    response_class=Response,
    responses={200: {"content": {"image/png": {}}}, 304: {"description": "Not modified"}},
)
async def get_goal_image(
    goal_id: str,
    service: Annotated[GoalService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
    if_none_match: Annotated[str | None, Header()] = None,
) -> Response:
    """Return a goal's banner picture, or 304 when the caller's cached copy is still current."""
    image = service.get_image(user.id, goal_id)
    etag = f'"{int(image.updated_at.timestamp() * 1_000_000)}"'
    # The app revalidates every time, so a replaced picture shows at once.
    headers = {"ETag": etag, "Cache-Control": "no-cache"}
    if if_none_match == etag:
        return Response(status_code=status.HTTP_304_NOT_MODIFIED, headers=headers)
    return Response(content=image.image, media_type=image.content_type, headers=headers)


@router.put("/{goal_id}/image", response_model=GoalRead)
async def upload_goal_image(
    goal_id: str,
    file: Annotated[UploadFile, File()],
    service: Annotated[GoalService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
) -> GoalRead:
    """Make an uploaded PNG, JPEG or WebP picture the goal's banner, replacing any earlier one.

    Stored cover-cropped to 44:19, without the picture's metadata.
    """
    # One byte over the cap is enough to know the file is too large, without reading it all.
    data = await file.read(MAX_UPLOAD_BYTES + 1)
    return _to_read(*service.upload_image(user.id, goal_id, data))


@router.delete("/{goal_id}/image", response_model=GoalRead)
async def remove_goal_image(
    goal_id: str,
    service: Annotated[GoalService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
) -> GoalRead:
    """Drop the goal's banner picture; the panel shows its tomettes again."""
    return _to_read(*service.remove_image(user.id, goal_id))


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
