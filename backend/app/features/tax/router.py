"""Tax endpoints: the per-year profile, created lazily and patched field by field."""

from datetime import date
from typing import Annotated

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.db import get_db
from app.features.auth.deps import get_current_user
from app.features.auth.models import User
from app.features.tax.repository import TaxRepository
from app.features.tax.schemas import TaxProfileRead, TaxProfileUpdate
from app.features.tax.service import TaxService

router = APIRouter(prefix="/api/v1/tax", tags=["tax"])


def _service(db: Annotated[Session, Depends(get_db)]) -> TaxService:
    return TaxService(TaxRepository(db))


def get_today() -> date:
    """The date a tax year is checked against; a dependency so tests can pin it."""
    return date.today()


@router.get("/profiles", response_model=list[TaxProfileRead])
async def list_profiles(
    service: Annotated[TaxService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
) -> list[TaxProfileRead]:
    """The caller's declared years, newest first. Listing creates nothing."""
    return service.list_profiles(user)


@router.get("/profiles/{tax_year}", response_model=TaxProfileRead)
async def read_profile(
    tax_year: int,
    service: Annotated[TaxService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
    today: Annotated[date, Depends(get_today)],
) -> TaxProfileRead:
    """One year's profile, created with defaults on first read."""
    return service.get_or_create(user, tax_year, today)


@router.patch("/profiles/{tax_year}", response_model=TaxProfileRead)
async def update_profile(
    tax_year: int,
    payload: TaxProfileUpdate,
    service: Annotated[TaxService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
    today: Annotated[date, Depends(get_today)],
) -> TaxProfileRead:
    """Patch the supplied fields, leaving omitted ones untouched."""
    return service.update(user, tax_year, payload, today)
