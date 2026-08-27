"""Recurring-series endpoints. Detection only; the lifecycle routes are a separate slice."""

from typing import Annotated

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.db import get_db
from app.features.accounts.repository import AccountRepository
from app.features.accounts.service import AccountService
from app.features.auth.deps import get_current_user
from app.features.auth.models import User
from app.features.recurring.repository import RecurringRepository
from app.features.recurring.schemas import DetectionResultRead, DetectRequest
from app.features.recurring.service import RecurringDetectionService
from app.features.transactions.repository import TransactionRepository

router = APIRouter(prefix="/api/v1/recurring", tags=["recurring"])


def _service(db: Annotated[Session, Depends(get_db)]) -> RecurringDetectionService:
    return RecurringDetectionService(
        RecurringRepository(db),
        TransactionRepository(db),
        AccountService(AccountRepository(db), db),
        db,
    )


@router.post("/detect", response_model=DetectionResultRead)
async def detect_recurring(
    payload: DetectRequest,
    service: Annotated[RecurringDetectionService, Depends(_service)],
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
