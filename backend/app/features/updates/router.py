"""Update-check endpoint, mounted under the settings prefix like the inference probes."""

from typing import Annotated

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app import __version__
from app.core.db import get_db
from app.features.auth.deps import get_current_user
from app.features.auth.models import User
from app.features.settings.repository import SettingsRepository
from app.features.settings.service import SettingsService
from app.features.updates.releases import GitHubReleases, ReleaseSource
from app.features.updates.schemas import UpdateStatus
from app.features.updates.service import UpdateService

router = APIRouter(prefix="/api/v1/settings/updates", tags=["updates"])


def get_release_source() -> ReleaseSource:
    """Where the newest release is read from. Overridden in tests so nothing leaves the process."""
    return GitHubReleases()


def get_update_service(
    db: Annotated[Session, Depends(get_db)],
    releases: Annotated[ReleaseSource, Depends(get_release_source)],
) -> UpdateService:
    """Overridden in tests to pin the clock."""
    return UpdateService(SettingsService(SettingsRepository(db)), releases, __version__)


@router.get("", response_model=UpdateStatus)
async def read_update_status(
    service: Annotated[UpdateService, Depends(get_update_service)],
    user: Annotated[User, Depends(get_current_user)],
) -> UpdateStatus:
    """Whether a newer release is published; asks GitHub at most once a day, only if opted in."""
    return await service.status(user.id)
