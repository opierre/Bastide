"""Simulator endpoints: the stateless compute over the mortgages engine (§17)."""

from datetime import date
from typing import Annotated

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.db import get_db
from app.features.auth.deps import get_current_user
from app.features.auth.models import User
from app.features.mortgages.repository import MortgageRepository
from app.features.mortgages.router import get_today
from app.features.mortgages.schemas import SimulationCompute, SimulationResult
from app.features.mortgages.simulations_service import SimulationService

router = APIRouter(prefix="/api/v1/simulations", tags=["simulations"])


def _service(db: Annotated[Session, Depends(get_db)]) -> SimulationService:
    return SimulationService(MortgageRepository(db))


@router.post("/compute", response_model=SimulationResult)
async def compute_simulation(
    payload: SimulationCompute,
    service: Annotated[SimulationService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
    today: Annotated[date, Depends(get_today)],
) -> SimulationResult:
    """Compute a simulated loan. Persists nothing; a POST only because the inputs are a body."""
    return service.compute(user, payload, today)
