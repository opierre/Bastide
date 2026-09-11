"""Inference endpoints, mounted under the settings prefix so the frontend has one surface."""

from typing import Annotated

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.db import get_db
from app.features.auth.deps import get_current_user
from app.features.auth.models import User
from app.features.inference.client import InferenceClient, client_from_settings
from app.features.inference.schemas import InferenceHealth
from app.features.inference.service import InferenceService
from app.features.settings.repository import SettingsRepository
from app.features.settings.service import SettingsService

router = APIRouter(prefix="/api/v1/settings/inference", tags=["inference"])


def get_inference_client(
    db: Annotated[Session, Depends(get_db)],
    user: Annotated[User, Depends(get_current_user)],
) -> InferenceClient:
    """Build the client for the runtime this user has configured.

    Overridden in tests so no request leaves the process.
    """
    settings = SettingsService(SettingsRepository(db)).get_or_create(user.id)
    return client_from_settings(settings)


def _service(client: Annotated[InferenceClient, Depends(get_inference_client)]) -> InferenceService:
    return InferenceService(client)


@router.get("/health", response_model=InferenceHealth)
async def read_inference_health(
    service: Annotated[InferenceService, Depends(_service)],
) -> InferenceHealth:
    """Report whether the configured runtime answers, and which models it offers."""
    return await service.health()
