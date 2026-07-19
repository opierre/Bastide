"""FastAPI dependency resolving the authenticated user from a bearer token."""

from typing import Annotated

from fastapi import Depends, Header
from sqlalchemy.orm import Session

from app.core.db import get_db
from app.core.errors import AuthError
from app.features.auth.models import User
from app.features.auth.repository import AuthRepository
from app.features.auth.service import AuthService

_BEARER_PREFIX = "Bearer "


def bearer_token(authorization: Annotated[str | None, Header()] = None) -> str:
    """Extract the opaque token from the ``Authorization: Bearer <token>`` header.

    Raises:
        AuthError: the header is missing or not a bearer token.
    """
    if authorization is None or not authorization.startswith(_BEARER_PREFIX):
        raise AuthError("Not authenticated")
    return authorization.removeprefix(_BEARER_PREFIX).strip()


def get_current_user(
    token: Annotated[str, Depends(bearer_token)],
    db: Annotated[Session, Depends(get_db)],
) -> User:
    """Resolve the bearer token to its owning ``User``.

    Raises:
        AuthError: the token is missing, malformed, or doesn't match a live session.
    """
    service = AuthService(AuthRepository(db))
    return service.get_current_user(token)
