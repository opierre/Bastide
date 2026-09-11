"""Backup endpoints: export an archive, inspect one, restore one."""

from typing import Annotated

from fastapi import APIRouter, Depends, File, UploadFile
from fastapi.responses import Response
from sqlalchemy.orm import Session

from app.core.db import get_db
from app.features.auth.deps import get_current_user
from app.features.auth.models import User
from app.features.backup.repository import BackupRepository
from app.features.backup.schemas import BackupSummary
from app.features.backup.service import BackupService
from app.features.settings.repository import SettingsRepository
from app.features.settings.service import SettingsService

router = APIRouter(prefix="/api/v1/backup", tags=["backup"])

#: Carries the export's `BackupSummary` beside the binary body.
SUMMARY_HEADER = "X-Backup-Summary"


def _service(db: Annotated[Session, Depends(get_db)]) -> BackupService:
    return BackupService(BackupRepository(db), SettingsService(SettingsRepository(db)))


@router.post("/export", response_class=Response)
async def export_backup(
    service: Annotated[BackupService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
) -> Response:
    """The caller's data as a `.finstride` archive; its summary rides in a header."""
    content, summary = service.export(user)
    stamp = summary.exported_at.strftime("%Y-%m-%d")
    return Response(
        content=content,
        media_type="application/zip",
        headers={
            "Content-Disposition": f'attachment; filename="finstride-{stamp}.finstride"',
            SUMMARY_HEADER: summary.model_dump_json(),
        },
    )


@router.post("/inspect", response_model=BackupSummary)
async def inspect_backup(
    service: Annotated[BackupService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
    file: Annotated[UploadFile, File()],
) -> BackupSummary:
    """What an archive holds, without touching any data."""
    return service.inspect(user, await file.read())


@router.post("/restore", response_model=BackupSummary)
async def restore_backup(
    service: Annotated[BackupService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
    file: Annotated[UploadFile, File()],
) -> BackupSummary:
    """Replace all of the caller's data with the archive's."""
    return service.restore(user, await file.read())
