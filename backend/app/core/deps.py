"""Shared FastAPI dependencies used across features."""

from app.core.db import get_db
from app.features.auth.deps import get_current_user

__all__ = ["get_current_user", "get_db"]
