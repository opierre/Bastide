"""Placement endpoints: placements, their movements and declared values, and derived views.

Every derived figure is recomputed per request and never stored.
"""

from datetime import date
from typing import Annotated

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

from app.core.db import get_db
from app.features.auth.deps import get_current_user
from app.features.auth.models import User
from app.features.placements.repository import PlacementRepository
from app.features.placements.schemas import (
    EnvelopeRead,
    InvestmentClose,
    InvestmentCreate,
    InvestmentDetail,
    InvestmentRead,
    InvestmentSeries,
    InvestmentSummary,
    InvestmentUpdate,
    LinkCandidate,
    MovementCreate,
    MovementRead,
    MovementUpdate,
    ValuationCreate,
    ValuationRead,
    ValuationUpdate,
)
from app.features.placements.service import PlacementService, envelope_catalogue

router = APIRouter(prefix="/api/v1/investments", tags=["investments"])


def _service(db: Annotated[Session, Depends(get_db)]) -> PlacementService:
    return PlacementService(PlacementRepository(db))


def get_today() -> date:
    """The date figures are measured at and dates checked against; pinned by tests."""
    return date.today()


CurrentUser = Annotated[User, Depends(get_current_user)]
Today = Annotated[date, Depends(get_today)]
ServiceDep = Annotated[PlacementService, Depends(_service)]


@router.get("/envelopes", response_model=list[EnvelopeRead])
async def list_envelopes(user: CurrentUser) -> list[EnvelopeRead]:
    """The envelope catalogue with its indicative ceilings and age milestones."""
    return envelope_catalogue(user.currency)


@router.get("/summary", response_model=InvestmentSummary)
async def get_summary(service: ServiceDep, user: CurrentUser, today: Today) -> InvestmentSummary:
    """Declared value, net payments and unrealised gain over the open placements."""
    return service.summary(user, today)


@router.get("/series", response_model=InvestmentSeries)
async def get_series(service: ServiceDep, user: CurrentUser, today: Today) -> InvestmentSeries:
    """The placements' value and net payments at each closed month end, as net worth counts."""
    return service.series(user, today)


@router.get("", response_model=list[InvestmentRead])
async def list_investments(
    service: ServiceDep, user: CurrentUser, today: Today
) -> list[InvestmentRead]:
    """The caller's placements with their derived figures, open ones first."""
    return service.list_for_user(user, today)


@router.post("", response_model=InvestmentDetail, status_code=status.HTTP_201_CREATED)
async def create_investment(
    payload: InvestmentCreate, service: ServiceDep, user: CurrentUser, today: Today
) -> InvestmentDetail:
    """Create a placement, with its opening payments and current value when given."""
    return service.create(user, payload, today)


@router.get("/{investment_id}", response_model=InvestmentDetail)
async def get_investment(
    investment_id: str, service: ServiceDep, user: CurrentUser, today: Today
) -> InvestmentDetail:
    """One placement with its movements and declared values, newest first."""
    return service.get(user, investment_id, today)


@router.patch("/{investment_id}", response_model=InvestmentDetail)
async def update_investment(
    investment_id: str,
    payload: InvestmentUpdate,
    service: ServiceDep,
    user: CurrentUser,
    today: Today,
) -> InvestmentDetail:
    """Patch a placement's name, institution, envelope or opening date."""
    return service.update(user, investment_id, payload, today)


@router.delete("/{investment_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_investment(investment_id: str, service: ServiceDep, user: CurrentUser) -> None:
    """Delete a placement and its whole history. Closing is how to keep it."""
    service.delete(user, investment_id)


@router.post("/{investment_id}/close", response_model=InvestmentDetail)
async def close_investment(
    investment_id: str,
    payload: InvestmentClose,
    service: ServiceDep,
    user: CurrentUser,
    today: Today,
) -> InvestmentDetail:
    """Close a placement; a positive final amount is recorded as a withdrawal that day."""
    return service.close(user, investment_id, payload, today)


@router.post("/{investment_id}/reopen", response_model=InvestmentDetail)
async def reopen_investment(
    investment_id: str, service: ServiceDep, user: CurrentUser, today: Today
) -> InvestmentDetail:
    """Undo a closing; the final withdrawal stays as any movement does."""
    return service.reopen(user, investment_id, today)


@router.get("/{investment_id}/link-candidates", response_model=list[LinkCandidate])
async def list_link_candidates(
    investment_id: str,
    service: ServiceDep,
    user: CurrentUser,
    amount_minor: Annotated[int, Query(description="The movement's signed amount.")],
    on: Annotated[date, Query(description="The movement's date.")],
    movement_id: Annotated[
        str | None, Query(description="The movement being edited, whose own link is kept.")
    ] = None,
) -> list[LinkCandidate]:
    """Imported transactions of the opposite amount near that date, not linked elsewhere."""
    return service.link_candidates(user, investment_id, amount_minor, on, movement_id)


@router.post(
    "/{investment_id}/movements",
    response_model=MovementRead,
    status_code=status.HTTP_201_CREATED,
)
async def create_movement(
    investment_id: str,
    payload: MovementCreate,
    service: ServiceDep,
    user: CurrentUser,
    today: Today,
) -> MovementRead:
    """Record a payment in (positive) or a withdrawal (negative)."""
    return service.add_movement(user, investment_id, payload, today)


@router.patch("/{investment_id}/movements/{movement_id}", response_model=MovementRead)
async def update_movement(
    investment_id: str,
    movement_id: str,
    payload: MovementUpdate,
    service: ServiceDep,
    user: CurrentUser,
    today: Today,
) -> MovementRead:
    """Patch a movement; `note` and `transaction_id` sent as null are cleared."""
    return service.update_movement(user, investment_id, movement_id, payload, today)


@router.delete("/{investment_id}/movements/{movement_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_movement(
    investment_id: str, movement_id: str, service: ServiceDep, user: CurrentUser
) -> None:
    """Delete a movement."""
    service.delete_movement(user, investment_id, movement_id)


@router.post(
    "/{investment_id}/valuations",
    response_model=ValuationRead,
    status_code=status.HTTP_201_CREATED,
)
async def create_valuation(
    investment_id: str,
    payload: ValuationCreate,
    service: ServiceDep,
    user: CurrentUser,
    today: Today,
) -> ValuationRead:
    """Record the value copied from a statement; one per date."""
    return service.add_valuation(user, investment_id, payload, today)


@router.patch("/{investment_id}/valuations/{valuation_id}", response_model=ValuationRead)
async def update_valuation(
    investment_id: str,
    valuation_id: str,
    payload: ValuationUpdate,
    service: ServiceDep,
    user: CurrentUser,
    today: Today,
) -> ValuationRead:
    """Patch a declared value; `note` sent as null is cleared."""
    return service.update_valuation(user, investment_id, valuation_id, payload, today)


@router.delete("/{investment_id}/valuations/{valuation_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_valuation(
    investment_id: str, valuation_id: str, service: ServiceDep, user: CurrentUser
) -> None:
    """Delete a declared value."""
    service.delete_valuation(user, investment_id, valuation_id)
