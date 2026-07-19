"""Shared FastAPI dependencies used across features."""

from app.core.db import get_db
from app.core.errors import AuthError

__all__ = ["get_current_user", "get_db"]


def get_current_user() -> None:
    """Resolve the authenticated user.

    Stub until P1-04 implements real token validation; always rejects.
    """
    raise AuthError("Not authenticated")
