"""Recurring-series endpoints: detection and the subscription lifecycle."""

from datetime import date
from typing import Annotated

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

from app.core.db import get_db
from app.features.accounts.repository import AccountRepository
from app.features.accounts.service import AccountService
from app.features.auth.deps import get_current_user
from app.features.auth.models import User
from app.features.recurring.repository import RecurringRepository
from app.features.recurring.schemas import (
    DetectionResultRead,
    DetectRequest,
    OccurrenceRead,
    SeriesCreate,
    SeriesDetailRead,
    SeriesRead,
    SeriesStatus,
    SeriesUpdate,
)
from app.features.recurring.service import RecurringDetectionService, RecurringService
from app.features.transactions.repository import TransactionRepository
from app.features.transactions.schemas import TransactionRead

router = APIRouter(prefix="/api/v1/recurring", tags=["recurring"])


def _detection_service(db: Annotated[Session, Depends(get_db)]) -> RecurringDetectionService:
    return RecurringDetectionService(
        RecurringRepository(db),
        TransactionRepository(db),
        AccountService(AccountRepository(db), db),
        db,
    )


def _service(db: Annotated[Session, Depends(get_db)]) -> RecurringService:
    return RecurringService(
        RecurringRepository(db),
        TransactionRepository(db),
        AccountService(AccountRepository(db), db),
    )


@router.get("", response_model=list[SeriesRead])
async def list_series(
    service: Annotated[RecurringService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
    series_status: Annotated[
        SeriesStatus | None,
        Query(alias="status", description="Return only series in this lifecycle status."),
    ] = None,
    account_id: Annotated[
        str | None, Query(description="Return only series of this account.")
    ] = None,
) -> list[SeriesRead]:
    """List the caller's series, soonest charge first.

    Cancelled and dismissed series are included: the panel dims a cancelled row rather than
    hiding it, and a client that wants one kind asks for it by `status`.
    """
    return [
        SeriesRead.model_validate(series)
        for series in service.list_for_user(user.id, status=series_status, account_id=account_id)
    ]


@router.post("", response_model=SeriesRead, status_code=status.HTTP_201_CREATED)
async def create_series(
    payload: SeriesCreate,
    service: Annotated[RecurringService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
) -> SeriesRead:
    """Declare a subscription the detector has not found (`is_manual = true`)."""
    return SeriesRead.model_validate(service.create(user.id, payload, date.today()))


@router.post("/detect", response_model=DetectionResultRead)
async def detect_recurring(
    payload: DetectRequest,
    service: Annotated[RecurringDetectionService, Depends(_detection_service)],
    user: Annotated[User, Depends(get_current_user)],
) -> DetectionResultRead:
    """Run a detection pass and report what it created and refreshed.

    Synchronous, unlike a categorisation run: this is one indexed scan of the account's rows
    and some arithmetic, with no model in the loop to wait on.
    """
    result = service.detect(user.id, payload.account_id)
    return DetectionResultRead(
        created_count=result.created_count, updated_count=result.updated_count
    )


@router.get("/{series_id}", response_model=SeriesDetailRead)
async def get_series(
    series_id: str,
    service: Annotated[RecurringService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
) -> SeriesDetailRead:
    """One series with the occurrence history it was deduced from, newest charge first."""
    series, occurrences = service.occurrences(user.id, series_id)
    return SeriesDetailRead(
        **SeriesRead.model_validate(series).model_dump(),
        occurrences=[
            OccurrenceRead(
                id=occurrence.id,
                created_at=occurrence.created_at,
                transaction=TransactionRead.model_validate(transaction),
            )
            for occurrence, transaction in occurrences
        ],
    )


@router.patch("/{series_id}", response_model=SeriesRead)
async def update_series(
    series_id: str,
    payload: SeriesUpdate,
    service: Annotated[RecurringService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
) -> SeriesRead:
    """Patch a series; a `status` outside the lifecycle is a 409, not a write."""
    return SeriesRead.model_validate(service.update(user.id, series_id, payload))


@router.delete("/{series_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_series(
    series_id: str,
    service: Annotated[RecurringService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
) -> None:
    """Delete a declared series; dismiss a detected one."""
    service.delete(user.id, series_id)
