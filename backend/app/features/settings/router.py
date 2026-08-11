"""User settings endpoints: read (lazily created) and partial patch."""

from typing import Annotated

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.db import get_db
from app.features.auth.deps import get_current_user
from app.features.auth.models import User
from app.features.settings.models import UserSettings
from app.features.settings.repository import SettingsRepository
from app.features.settings.schemas import SettingsRead, SettingsUpdate
from app.features.settings.service import SettingsService

router = APIRouter(prefix="/api/v1/settings", tags=["settings"])


def _service(db: Annotated[Session, Depends(get_db)]) -> SettingsService:
    return SettingsService(SettingsRepository(db))


def _to_read(settings: UserSettings) -> SettingsRead:
    return SettingsRead(
        ai_enabled=settings.ai_enabled,
        inference_base_url=settings.inference_base_url,
        model_tag=settings.model_tag,
        confidence_threshold=settings.confidence_threshold,
    )


@router.get("", response_model=SettingsRead)
async def read_settings(
    service: Annotated[SettingsService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
) -> SettingsRead:
    """Return the caller's settings, creating them with defaults on first read."""
    return _to_read(service.get_or_create(user.id))


@router.patch("", response_model=SettingsRead)
async def update_settings(
    payload: SettingsUpdate,
    service: Annotated[SettingsService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
) -> SettingsRead:
    """Patch the supplied settings fields, leaving omitted ones untouched."""
    return _to_read(service.update(user.id, payload))
