"""Health check endpoint."""

from fastapi import APIRouter

from app import __version__
from app.features.health.schemas import HealthRead

router = APIRouter(prefix="/api/v1", tags=["health"])


@router.get("/health", response_model=HealthRead)
async def health() -> HealthRead:
    """Report that the sidecar is up, with the product version it was built as."""
    return HealthRead(status="ok", version=__version__)
