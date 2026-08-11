"""FastAPI application factory for the FinStride sidecar."""

from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import get_settings
from app.core.db import get_session_factory
from app.core.errors import register_exception_handlers
from app.features.accounts.router import router as accounts_router
from app.features.auth.router import router as auth_router
from app.features.banks.router import router as banks_router
from app.features.categories.router import router as categories_router
from app.features.categorization.router import router as categorization_router
from app.features.categorization.runner import reconcile_orphaned_runs
from app.features.dashboard.router import router as dashboard_router
from app.features.health.router import router as health_router
from app.features.imports.router import router as imports_router
from app.features.inference.router import router as inference_router
from app.features.rules.router import router as rules_router
from app.features.settings.router import router as settings_router
from app.features.transactions.router import router as transactions_router


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    """Reconcile runs orphaned by the previous process before serving anything.

    A categorisation run executes as an in-process task, so one still `pending`/`running` in
    the database lost its executor when that process stopped (`PROJECT.md` §7). Left alone it
    would show as in flight forever and block every future run behind the one-at-a-time check.

    The session factory is resolved through `dependency_overrides` because startup has no
    request to hang a `Depends` on, and tests must be able to point this at their own database
    exactly as they do for the routes.
    """
    provider = app.dependency_overrides.get(get_session_factory, get_session_factory)
    reconcile_orphaned_runs(provider())
    yield


def create_app() -> FastAPI:
    """Build the FastAPI app: error envelope, local-only CORS, feature routers."""
    settings = get_settings()
    app = FastAPI(title="FinStride", lifespan=lifespan)

    register_exception_handlers(app)

    app.add_middleware(
        CORSMiddleware,
        allow_origin_regex=settings.frontend_origin_regex,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    app.include_router(health_router)
    app.include_router(auth_router)
    app.include_router(accounts_router)
    app.include_router(banks_router)
    app.include_router(imports_router)
    app.include_router(categories_router)
    app.include_router(rules_router)
    app.include_router(transactions_router)
    app.include_router(dashboard_router)
    app.include_router(settings_router)
    app.include_router(inference_router)
    app.include_router(categorization_router)

    return app


app = create_app()
