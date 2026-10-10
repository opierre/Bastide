"""Inference endpoints, mounted under the settings prefix so the frontend has one surface."""

from functools import lru_cache
from typing import Annotated

from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.core.db import get_db
from app.features.auth.deps import get_current_user
from app.features.auth.models import User
from app.features.inference.client import InferenceClient, client_from_settings
from app.features.inference.ollama import ollama_client
from app.features.inference.runtime_install import InstallStatus, RuntimeInstaller
from app.features.inference.runtime_manifest import MODEL_ALIAS, runtime_build
from app.features.inference.schemas import InferenceHealth, OllamaDetection, RuntimeStatus
from app.features.inference.service import InferenceService, detect_ollama
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


def get_ollama_client() -> InferenceClient:
    """The client pointed at Ollama's default address. Overridden in tests."""
    return ollama_client()


@lru_cache
def get_runtime_installer() -> RuntimeInstaller:
    """The process-wide installer: one data dir, one download at a time. Overridden in tests."""
    return RuntimeInstaller(get_settings().data_dir / "runtime", runtime_build())


def _service(client: Annotated[InferenceClient, Depends(get_inference_client)]) -> InferenceService:
    return InferenceService(client)


@router.get("/health", response_model=InferenceHealth)
async def read_inference_health(
    service: Annotated[InferenceService, Depends(_service)],
) -> InferenceHealth:
    """Report whether the configured runtime answers, and which models it offers."""
    return await service.health()


@router.get("/ollama", response_model=OllamaDetection, dependencies=[Depends(get_current_user)])
async def read_ollama_detection(
    client: Annotated[InferenceClient, Depends(get_ollama_client)],
) -> OllamaDetection:
    """Report whether Ollama answers on its default loopback address, and its models."""
    return await detect_ollama(client)


def _runtime_status(install: InstallStatus) -> RuntimeStatus:
    return RuntimeStatus(
        state=install.state,
        downloaded_bytes=install.downloaded_bytes,
        total_bytes=install.total_bytes,
        error=install.error,
        model_tag=MODEL_ALIAS,
    )


# The runtime endpoints are plain `def`: cancelling and removing wait on the download thread
# and the disk, which FastAPI then runs off the event loop.


@router.get("/runtime", response_model=RuntimeStatus, dependencies=[Depends(get_current_user)])
def read_runtime(
    installer: Annotated[RuntimeInstaller, Depends(get_runtime_installer)],
) -> RuntimeStatus:
    """Report whether the local runtime is installed, and the size still to download."""
    return _runtime_status(installer.status())


@router.post(
    "/runtime/download",
    response_model=RuntimeStatus,
    status_code=status.HTTP_202_ACCEPTED,
    dependencies=[Depends(get_current_user)],
)
def start_runtime_download(
    installer: Annotated[RuntimeInstaller, Depends(get_runtime_installer)],
) -> RuntimeStatus:
    """Start downloading the pinned runtime and model; poll `GET /runtime` for progress.

    Resumes a download that was cancelled or interrupted. Asking again while one runs
    changes nothing.
    """
    return _runtime_status(installer.start())


@router.post(
    "/runtime/cancel", response_model=RuntimeStatus, dependencies=[Depends(get_current_user)]
)
def cancel_runtime_download(
    installer: Annotated[RuntimeInstaller, Depends(get_runtime_installer)],
) -> RuntimeStatus:
    """Stop the download, keeping what it fetched so the next one resumes."""
    return _runtime_status(installer.cancel())


@router.delete("/runtime", response_model=RuntimeStatus, dependencies=[Depends(get_current_user)])
def remove_runtime(
    installer: Annotated[RuntimeInstaller, Depends(get_runtime_installer)],
) -> RuntimeStatus:
    """Delete the downloaded runtime and model to free the disk space."""
    return _runtime_status(installer.remove())
