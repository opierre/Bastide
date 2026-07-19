"""Domain exceptions and the handler mapping them to the API error envelope."""

from typing import Any

from fastapi import FastAPI, Request, status
from fastapi.responses import JSONResponse


class DomainError(Exception):
    """Base class for exceptions the global handler maps to the error envelope.

    Services raise these instead of ``HTTPException`` so business logic stays
    decoupled from the web layer.
    """

    code: str = "ERROR"
    status_code: int = status.HTTP_500_INTERNAL_SERVER_ERROR

    def __init__(self, message: str, details: dict[str, Any] | None = None) -> None:
        self.message = message
        self.details = details
        super().__init__(message)


class NotFoundError(DomainError):
    """Raised when a requested resource does not exist (or isn't user-scoped in)."""

    code = "NOT_FOUND"
    status_code = status.HTTP_404_NOT_FOUND


class ConflictError(DomainError):
    """Raised when an operation would violate a uniqueness or state constraint."""

    code = "CONFLICT"
    status_code = status.HTTP_409_CONFLICT


class ValidationError(DomainError):
    """Raised for domain-level validation failures beyond schema validation."""

    code = "VALIDATION_ERROR"
    status_code = status.HTTP_422_UNPROCESSABLE_CONTENT


class AuthError(DomainError):
    """Raised when authentication is missing or invalid."""

    code = "AUTH_ERROR"
    status_code = status.HTTP_401_UNAUTHORIZED


def register_exception_handlers(app: FastAPI) -> None:
    """Map ``DomainError`` subclasses to ``{error: {code, message, details?}}`` responses."""

    @app.exception_handler(DomainError)
    async def handle_domain_error(request: Request, exc: DomainError) -> JSONResponse:
        error: dict[str, Any] = {"code": exc.code, "message": exc.message}
        if exc.details is not None:
            error["details"] = exc.details
        return JSONResponse(status_code=exc.status_code, content={"error": error})
