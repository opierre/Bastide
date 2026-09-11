"""Categorisation run endpoints: start a run, poll its progress, cancel it, read the history."""

from typing import Annotated

from fastapi import APIRouter, Depends, Query, status
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
    RunLauncher,
    get_client_factory,
    get_run_launcher,
)
from app.features.categorization.schemas import CategorizationRunRead, RunCreate
from app.features.settings.repository import SettingsRepository
from app.features.settings.service import SettingsService

router = APIRouter(prefix="/api/v1/categorization/runs", tags=["categorization"])

DEFAULT_HISTORY_LIMIT = 20
MAX_HISTORY_LIMIT = 100


def _service(
    db: Annotated[Session, Depends(get_db)],
    session_factory: Annotated[SessionFactory, Depends(get_session_factory)],
    launcher: Annotated[RunLauncher, Depends(get_run_launcher)],
    client_factory: Annotated[ClientFactory, Depends(get_client_factory)],
) -> CategorizationRunService:
    return CategorizationRunService(
        CategorizationRunRepository(db),
        AccountService(AccountRepository(db), db),
        SettingsService(SettingsRepository(db)),
        session_factory,
        launcher,
        client_factory,
    )


@router.post("", response_model=CategorizationRunRead, status_code=status.HTTP_202_ACCEPTED)
async def create_run(
    payload: RunCreate,
    service: Annotated[CategorizationRunService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
) -> CategorizationRunRead:
    """Start a categorisation run and return it immediately.

    202, not 201: the run is accepted, not finished — a few hundred rows through a local
    model is minutes of work. Poll `GET /runs/{id}` for progress. Asking again while a run is
    in flight returns that run instead of starting a second over the same rows.
    """
    run = service.request(user, payload)
    return CategorizationRunRead.model_validate(run)


@router.get("", response_model=list[CategorizationRunRead])
async def list_runs(
    service: Annotated[CategorizationRunService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
    limit: Annotated[int, Query(ge=1, le=MAX_HISTORY_LIMIT)] = DEFAULT_HISTORY_LIMIT,
) -> list[CategorizationRunRead]:
    """The caller's run history, newest first."""
    return [
        CategorizationRunRead.model_validate(run) for run in service.list_for_user(user.id, limit)
    ]


@router.get("/{run_id}", response_model=CategorizationRunRead)
async def get_run(
    run_id: str,
    service: Annotated[CategorizationRunService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
) -> CategorizationRunRead:
    """Fetch one run — the progress poll."""
    return CategorizationRunRead.model_validate(service.get(user.id, run_id))


@router.post("/{run_id}/cancel", response_model=CategorizationRunRead)
async def cancel_run(
    run_id: str,
    service: Annotated[CategorizationRunService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
) -> CategorizationRunRead:
    """Cancel an in-flight run; the executor stops after the batch it is on."""
    return CategorizationRunRead.model_validate(service.cancel(user.id, run_id))
