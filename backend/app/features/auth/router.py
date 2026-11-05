"""Auth endpoints: register, login, logout, me, profile, avatar, and password recovery."""

from typing import Annotated

from fastapi import APIRouter, Depends, File, Header, Response, UploadFile, status
from sqlalchemy.orm import Session

from app.core.db import get_db
from app.features.auth.avatar import MAX_UPLOAD_BYTES
from app.features.auth.deps import bearer_token, get_current_user
from app.features.auth.models import User
from app.features.auth.repository import AuthRepository
from app.features.auth.schemas import (
    AvatarChoiceUpdate,
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


@router.get(
    "/me/avatar",
    response_class=Response,
    responses={200: {"content": {"image/png": {}}}, 304: {"description": "Not modified"}},
)
async def get_avatar(
    service: Annotated[AuthService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
    if_none_match: Annotated[str | None, Header()] = None,
) -> Response:
    """Return the caller's avatar picture, or 304 when their cached copy is still current."""
    avatar = service.get_avatar(user)
    etag = f'"{int(avatar.updated_at.timestamp() * 1_000_000)}"'
    # The app revalidates every time, so a new picture shows at once.
    headers = {"ETag": etag, "Cache-Control": "no-cache"}
    if if_none_match == etag:
        return Response(status_code=status.HTTP_304_NOT_MODIFIED, headers=headers)
    return Response(content=avatar.image, media_type=avatar.content_type, headers=headers)


@router.put("/me/avatar", response_model=MeResponse)
async def upload_avatar(
    file: Annotated[UploadFile, File()],
    service: Annotated[AuthService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
) -> MeResponse:
    """Make an uploaded PNG, JPEG or WebP picture the caller's avatar."""
    # One byte over the cap is enough to know the file is too large, without reading it all.
    data = await file.read(MAX_UPLOAD_BYTES + 1)
    return MeResponse(user=UserRead.model_validate(service.upload_avatar(user, data)))


@router.delete("/me/avatar", response_model=MeResponse)
async def remove_avatar(
    service: Annotated[AuthService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
) -> MeResponse:
    """Drop the caller's picture and bring back the default avatar they had before it."""
    return MeResponse(user=UserRead.model_validate(service.remove_avatar(user)))


@router.put("/me/avatar-choice", response_model=MeResponse)
async def set_avatar_choice(
    payload: AvatarChoiceUpdate,
    service: Annotated[AuthService, Depends(_service)],
    user: Annotated[User, Depends(get_current_user)],
) -> MeResponse:
    """Make the monogram or a preset the caller's avatar, replacing any picture."""
    return MeResponse(user=UserRead.model_validate(service.set_avatar_choice(user, payload.avatar)))
