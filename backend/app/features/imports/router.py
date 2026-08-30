"""Import endpoints: upload an OFX/QFX statement, list the history, fetch a single batch."""

from typing import Annotated

from fastapi import APIRouter, Depends, File, Form, UploadFile, status
from sqlalchemy.orm import Session

from app.core.db import SessionFactory, get_db, get_session_factory
from app.features.accounts.repository import AccountRepository
from app.features.accounts.service import AccountService
from app.features.auth.deps import get_current_user
from app.features.auth.models import User
from app.features.categorization.repository import CategorizationRunRepository
from app.features.categorization.runner import (
    CategorizationRunService,
    ClientFactory,
    ImportRunEnqueuer,
    RunLauncher,
    get_client_factory,
    get_run_launcher,
)
from app.features.imports.models import ImportBatch
from app.features.imports.repository import ImportRepository
from app.features.imports.schemas import ImportBatchRead
from app.features.imports.service import ImportService
from app.features.settings.repository import SettingsRepository
from app.features.settings.service import SettingsService

router = APIRouter(prefix="/api/v1", tags=["imports"])


def _import_service(
    db: Annotated[Session, Depends(get_db)],
    session_factory: Annotated[SessionFactory, Depends(get_session_factory)],
    launcher: Annotated[RunLauncher, Depends(get_run_launcher)],
    client_factory: Annotated[ClientFactory, Depends(get_client_factory)],
) -> ImportService:
    account_service = AccountService(AccountRepository(db), db)
    settings_service = SettingsService(SettingsRepository(db))
    return ImportService(
        ImportRepository(db),
        account_service,
        db,
        run_enqueuer=ImportRunEnqueuer(
            settings_service,
            CategorizationRunService(
                CategorizationRunRepository(db),
                account_service,
                settings_service,
                session_factory,
                launcher,
                client_factory,
            ),
        ),
    )


def _to_read(batch: ImportBatch) -> ImportBatchRead:
    return ImportBatchRead(
        id=batch.id,
        account_id=batch.account_id,
        source_format=batch.source_format,
        file_name=batch.file_name,
        file_hash=batch.file_hash,
        period_start=batch.period_start,
        period_end=batch.period_end,
        transaction_count=batch.transaction_count,
        new_count=batch.new_count,
        duplicate_count=batch.duplicate_count,
        status=batch.status,
        error_message=batch.error_message,
        balance_mismatch_minor=batch.balance_mismatch_minor,
        balance_mismatch_as_of=batch.balance_mismatch_as_of,
        imported_at=batch.imported_at,
    )


@router.post("/imports", response_model=ImportBatchRead, status_code=status.HTTP_201_CREATED)
async def create_import(
    service: Annotated[ImportService, Depends(_import_service)],
    user: Annotated[User, Depends(get_current_user)],
    file: Annotated[UploadFile, File()],
    account_id: Annotated[str, Form()],
) -> ImportBatchRead:
    """Upload an OFX/QFX statement for an account; re-uploading the same file changes nothing."""
    content = await file.read()
    return _to_read(service.import_file(user, account_id, file.filename or "import", content))


@router.get("/imports", response_model=list[ImportBatchRead])
async def list_imports(
    service: Annotated[ImportService, Depends(_import_service)],
    user: Annotated[User, Depends(get_current_user)],
) -> list[ImportBatchRead]:
    """The caller's import history, most recent first."""
    return [_to_read(batch) for batch in service.list_for_user(user.id)]


@router.get("/imports/{batch_id}", response_model=ImportBatchRead)
async def get_import(
    batch_id: str,
    service: Annotated[ImportService, Depends(_import_service)],
    user: Annotated[User, Depends(get_current_user)],
) -> ImportBatchRead:
    """Fetch a single import batch."""
    return _to_read(service.get(user.id, batch_id))
