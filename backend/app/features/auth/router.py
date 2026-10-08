"""Auth endpoints: register, login, logout, me, profile, and password recovery."""

from typing import Annotated

from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.core.db import get_db
from app.features.auth.deps import bearer_token, get_current_user
from app.features.auth.models import User
from app.features.auth.repository import AuthRepository
from app.features.auth.schemas import (
    MeResponse,
    PasswordReset,
    PasswordResetResponse,
    ProfileUpdate,
    RecoveryCodeRegenerate,
    RecoveryCodeResponse,
    RegisterResponse,
    TokenResponse,
    UserLogin,
    UserRead,
    UserRegister,
)
from app.features.auth.service import AuthService

router = APIRouter(prefix="/api/v1/auth", tags=["auth"])


def _service(db: Annotated[Session, Depends(get_db)]) -> AuthService:
    return AuthService(AuthRepository(db))


@router.post("/register", response_model=RegisterResponse, status_code=status.HTTP_201_CREATED)
async def register(
    payload: UserRegister, service: Annotated[AuthService, Depends(_service)]
) -> RegisterResponse:
    """Create a new user and return an initial session token and their recovery code."""
    user, token, recovery_code = service.register(payload)
    return RegisterResponse(
        token=token, user=UserRead.model_validate(user), recovery_code=recovery_code
    )


@router.post("/login", response_model=TokenResponse)
async def login(
    payload: UserLogin, service: Annotated[AuthService, Depends(_service)]
) -> TokenResponse:
    """Verify credentials and issue a session token."""
    user, token = service.login(payload)
    return TokenResponse(token=token, user=UserRead.model_validate(user))


@router.post("/password-reset", response_model=PasswordResetResponse)
async def reset_password(
    payload: PasswordReset, service: Annotated[AuthService, Depends(_service)]
) -> PasswordResetResponse:
    """Set a new password with the recovery code; returns a session and a new code."""
    user, token, recovery_code = service.reset_password(payload)
    return PasswordResetResponse(
        token=token, user=UserRead.model_validate(user), recovery_code=recovery_code
    )


@router.post("/recovery-code", response_model=RecoveryCodeResponse)
async def regenerate_recovery_code(
    payload: RecoveryCodeRegenerate,
    service: Annotated[AuthService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
) -> RecoveryCodeResponse:
    """Replace the caller's recovery code after re-checking their password."""
    recovery_code = service.regenerate_recovery_code(user, payload.password)
    return RecoveryCodeResponse(recovery_code=recovery_code)


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


@router.patch("/me", response_model=MeResponse)
async def update_me(
    payload: ProfileUpdate,
    service: Annotated[AuthService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
) -> MeResponse:
    """Change the authenticated user's profile."""
    return MeResponse(user=UserRead.model_validate(service.update_profile(user, payload)))
