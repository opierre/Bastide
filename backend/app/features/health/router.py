"""Health check endpoint."""

from fastapi import APIRouter

router = APIRouter(prefix="/api/v1", tags=["health"])


@router.get("/health")
async def health() -> dict[str, str]:
    """Report that the sidecar is up."""
    return {"status": "ok"}
