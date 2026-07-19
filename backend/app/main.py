"""FastAPI application factory for the FinStride sidecar."""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import get_settings
from app.core.errors import register_exception_handlers


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

    return app


app = create_app()
