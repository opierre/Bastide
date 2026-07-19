"""Auth endpoints: register, login, logout, and me."""

from typing import Annotated

from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.core.db import get_db
from app.features.auth.deps import bearer_token, get_current_user
from app.features.auth.models import User
from app.features.auth.repository import AuthRepository
from app.features.auth.schemas import MeResponse, TokenResponse, UserLogin, UserRead, UserRegister
from app.features.auth.service import AuthService

router = APIRouter(prefix="/api/v1/auth", tags=["auth"])


def _service(db: Annotated[Session, Depends(get_db)]) -> AuthService:
    return AuthService(AuthRepository(db))


@router.post("/register", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
async def register(
    payload: UserRegister, service: Annotated[AuthService, Depends(_service)]
) -> TokenResponse:
    """Create a new user and return an initial session token."""
    user, token = service.register(payload)
    return TokenResponse(token=token, user=UserRead.model_validate(user))


@router.post("/login", response_model=TokenResponse)
async def login(
    payload: UserLogin, service: Annotated[AuthService, Depends(_service)]
) -> TokenResponse:
    """Verify credentials and issue a session token."""
    user, token = service.login(payload)
    return TokenResponse(token=token, user=UserRead.model_validate(user))


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
async def logout(
    service: Annotated[AuthService, Depends(_service)],
    token: Annotated[str, Depends(bearer_token)],
    _user: Annotated[User, Depends(get_current_user)],
) -> None:
    """Invalidate the caller's session token."""
    service.logout(token)


@router.get("/me", response_model=MeResponse)
async def me(user: Annotated[User, Depends(get_current_user)]) -> MeResponse:
    """Return the authenticated user's profile."""
    return MeResponse(user=UserRead.model_validate(user))
