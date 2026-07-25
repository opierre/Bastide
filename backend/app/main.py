"""FastAPI application factory for the FinStride sidecar."""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import get_settings
from app.core.errors import register_exception_handlers
from app.features.accounts.router import router as accounts_router
from app.features.auth.router import router as auth_router
from app.features.health.router import router as health_router


def create_app() -> FastAPI:
    """Build the FastAPI app: error envelope, local-only CORS, feature routers."""
    settings = get_settings()
    app = FastAPI(title="FinStride")

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

    return app


app = create_app()
