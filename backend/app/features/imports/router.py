"""Import endpoints: upload OFX/QFX/CSV, list history, fetch a single batch, CSV templates."""

import json
from typing import Annotated

import pydantic
from fastapi import APIRouter, Depends, File, Form, UploadFile, status
from sqlalchemy.orm import Session

from app.core.db import SessionFactory, get_db, get_session_factory
from app.core.errors import ValidationError
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
from app.features.imports.models import CsvTemplate, ImportBatch
from app.features.imports.repository import CsvTemplateRepository, ImportRepository
from app.features.imports.schemas import (
    CsvPreviewRow,
    CsvTemplateCreate,
    CsvTemplateRead,
    ImportBatchRead,
)
from app.features.imports.service import CsvTemplateService, ImportService
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
        CsvTemplateRepository(db),
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


def _csv_template_service(db: Annotated[Session, Depends(get_db)]) -> CsvTemplateService:
    return CsvTemplateService(CsvTemplateRepository(db))


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


def _template_to_read(template: CsvTemplate) -> CsvTemplateRead:
    return CsvTemplateRead.model_validate(template)


@router.post("/imports", response_model=ImportBatchRead, status_code=status.HTTP_201_CREATED)
async def create_import(
    service: Annotated[ImportService, Depends(_import_service)],
    user: Annotated[User, Depends(get_current_user)],
    file: Annotated[UploadFile, File()],
    account_id: Annotated[str, Form()],
    csv_template_id: Annotated[str | None, Form()] = None,
) -> ImportBatchRead:
    """Upload an OFX/QFX/CSV file for an account; re-uploading the same file changes nothing.

    Pass ``csv_template_id`` to import the file as CSV using that saved template.
    """
    content = await file.read()
    batch = service.import_file(
        user, account_id, file.filename or "import", content, csv_template_id=csv_template_id
    )
    return _to_read(batch)


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


@router.post("/csv-templates", response_model=CsvTemplateRead, status_code=status.HTTP_201_CREATED)
async def create_csv_template(
    payload: CsvTemplateCreate,
    service: Annotated[CsvTemplateService, Depends(_csv_template_service)],
    user: Annotated[User, Depends(get_current_user)],
) -> CsvTemplateRead:
    """Save a per-bank CSV column mapping, reused on every subsequent import from that bank."""
    return _template_to_read(service.create(user, payload))


@router.get("/csv-templates", response_model=list[CsvTemplateRead])
async def list_csv_templates(
    service: Annotated[CsvTemplateService, Depends(_csv_template_service)],
    user: Annotated[User, Depends(get_current_user)],
) -> list[CsvTemplateRead]:
    """The caller's saved CSV templates."""
    return [_template_to_read(template) for template in service.list_for_user(user.id)]


@router.post("/csv-templates/preview", response_model=list[CsvPreviewRow])
async def preview_csv_template(
    service: Annotated[CsvTemplateService, Depends(_csv_template_service)],
    _user: Annotated[User, Depends(get_current_user)],
    file: Annotated[UploadFile, File()],
    bank_name: Annotated[str, Form()],
    delimiter: Annotated[str, Form()],
    encoding: Annotated[str, Form()],
    date_format: Annotated[str, Form()],
    decimal_separator: Annotated[str, Form()],
    amount_strategy: Annotated[str, Form()],
    column_map: Annotated[str, Form()],
    header_offset: Annotated[int, Form()] = 0,
) -> list[CsvPreviewRow]:
    """Parse a sample of an uploaded file against a candidate (not-yet-saved) template.

    ``column_map`` is a JSON-encoded object, since multipart form fields are flat strings.

    Raises:
        ValidationError: `column_map` isn't valid JSON, or a field fails schema validation
            (e.g. an `amount_strategy` outside `signed`/`debit_credit`).
    """
    try:
        candidate = CsvTemplateCreate(
            bank_name=bank_name,
            delimiter=delimiter,
            encoding=encoding,
            date_format=date_format,
            decimal_separator=decimal_separator,
            amount_strategy=amount_strategy,  # ty: ignore[invalid-argument-type] — Form() yields str; pydantic validates the Literal at runtime, caught below
            column_map=json.loads(column_map),
            header_offset=header_offset,
        )
    except (json.JSONDecodeError, pydantic.ValidationError) as exc:
        raise ValidationError(f"Invalid template fields: {exc}") from exc

    content = await file.read()
    rows = service.preview(candidate, content)
    return [
        CsvPreviewRow(
            booked_date=row.booked_date,
            value_date=row.value_date,
            amount_minor=row.amount_minor,
            description_raw=row.description_raw,
        )
        for row in rows
    ]
