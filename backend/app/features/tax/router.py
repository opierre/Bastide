"""Tax endpoints: the per-year profile, created lazily and patched field by field, the ledger
prefill that suggests figures for it without ever writing one, and the estimate — computed on
read, never stored, and reporting both the parameters it ran on and the regimes it skipped.
"""

from datetime import date
from typing import Annotated

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.core.db import get_db
from app.features.auth.deps import get_current_user
from app.features.auth.models import User
from app.features.tax.repository import TaxRepository
from app.features.tax.schemas import (
    PrefillRead,
    TaxEstimateRead,
    TaxProfileRead,
    TaxProfileUpdate,
)
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


@router.get("/prefill", response_model=PrefillRead)
async def read_prefill(
    service: Annotated[TaxService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
    today: Annotated[date, Depends(get_today)],
    year: Annotated[int, Query(description="The tax year to read the ledger for.")],
) -> PrefillRead:
    """What the ledger suggests for a year, with the coverage and confidence behind it.

    Declared before `/profiles/{year}` so the literal path is not swallowed by it.
    """
    return service.prefill(user, year, today)


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


@router.get("/profiles/{tax_year}/estimate", response_model=TaxEstimateRead)
async def read_estimate(
    tax_year: int,
    service: Annotated[TaxService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
    today: Annotated[date, Depends(get_today)],
) -> TaxEstimateRead:
    """One year's estimate with its full component breakdown (§16).

    An order-of-magnitude figure to plan with — not a return, not advice, never a filing.
    Nothing is persisted: the year's profile is created with defaults if it has none, and the
    estimate itself is recomputed on every read.
    """
    return service.estimate(user, tax_year, today)
