"""Simulator endpoints: the stateless compute and saved scenarios (§17)."""

from datetime import date
from typing import Annotated

from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.core.db import get_db
from app.features.auth.deps import get_current_user
from app.features.auth.models import User
from app.features.mortgages.repository import MortgageRepository, SimulationRepository
from app.features.mortgages.router import get_today
from app.features.mortgages.schemas import (
    SimulationCompute,
    SimulationCreate,
    SimulationRead,
    SimulationResult,
    SimulationUpdate,
)
from app.features.mortgages.simulations_service import SimulationService

router = APIRouter(prefix="/api/v1/simulations", tags=["simulations"])


def _service(db: Annotated[Session, Depends(get_db)]) -> SimulationService:
    return SimulationService(MortgageRepository(db), SimulationRepository(db))


@router.get("", response_model=list[SimulationRead])
async def list_simulations(
    service: Annotated[SimulationService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
) -> list[SimulationRead]:
    """List the caller's saved scenarios, oldest first."""
    return service.list_for_user(user)


@router.post("", response_model=SimulationRead, status_code=status.HTTP_201_CREATED)
async def create_simulation(
    payload: SimulationCreate,
    service: Annotated[SimulationService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
) -> SimulationRead:
    """Save a scenario's inputs; no result is stored."""
    return service.create(user, payload)


@router.post("/compute", response_model=SimulationResult)
async def compute_simulation(
    payload: SimulationCompute,
    service: Annotated[SimulationService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
    today: Annotated[date, Depends(get_today)],
) -> SimulationResult:
    """Compute a simulated loan. Persists nothing; a POST only because the inputs are a body."""
    return service.compute(user, payload, today)


@router.patch("/{simulation_id}", response_model=SimulationRead)
async def update_simulation(
    simulation_id: str,
    payload: SimulationUpdate,
    service: Annotated[SimulationService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
) -> SimulationRead:
    """Patch a scenario's inputs or label."""
    return service.update(user, simulation_id, payload)


@router.delete("/{simulation_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_simulation(
    simulation_id: str,
    service: Annotated[SimulationService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
) -> None:
    """Hard-delete a scenario."""
    service.delete(user.id, simulation_id)
