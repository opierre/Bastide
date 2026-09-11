"""Database endpoints: what this profile holds, and the reset that empties it."""

from typing import Annotated

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.db import get_db
from app.features.auth.deps import get_current_user
from app.features.auth.models import User
from app.features.database.repository import DatabaseRepository
from app.features.database.schemas import DatabaseSummary
from app.features.database.service import DatabaseService

router = APIRouter(prefix="/api/v1/database", tags=["database"])


def _service(db: Annotated[Session, Depends(get_db)]) -> DatabaseService:
    return DatabaseService(DatabaseRepository(db))


@router.get("/summary", response_model=DatabaseSummary)
async def read_summary(
    service: Annotated[DatabaseService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
) -> DatabaseSummary:
    """How many rows the caller owns, as the reset confirmation lists them."""
    return service.summary(user)


@router.post("/reset", response_model=DatabaseSummary)
async def reset_database(
    service: Annotated[DatabaseService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
) -> DatabaseSummary:
    """Delete all of the caller's data, and report what was deleted."""
    return service.reset(user, db)
