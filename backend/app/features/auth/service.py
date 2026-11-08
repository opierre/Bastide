"""Business logic for registration, login, logout, password recovery, profile and avatar."""

from collections.abc import Callable
from datetime import UTC, datetime

from app.core.errors import AuthError, ConflictError, NotFoundError
from app.core.live_sessions import LiveSessions, get_live_sessions
from app.core.security import (
    generate_recovery_code,
    generate_token,
    hash_password,
    hash_recovery_code,
    verify_password,
    verify_recovery_code,
)
from app.features.auth.avatar import AVATAR_CONTENT_TYPE, normalize_avatar
from app.features.auth.models import AVATAR_IMAGE, AVATAR_MONOGRAM, AuthToken, User, UserAvatar
from app.features.auth.repository import AuthRepository
from app.features.auth.schemas import PasswordReset, ProfileUpdate, UserLogin, UserRegister


class EmailTakenError(ConflictError):
    """Raised when registering with an email that's already in use."""

    code = "EMAIL_TAKEN"


class DisplayNameTakenError(ConflictError):
    """Raised when a display name, which doubles as the username, is already in use."""

    code = "DISPLAY_NAME_TAKEN"


class InvalidCredentialsError(AuthError):
    """Raised when login credentials don't match a known user."""

    code = "INVALID_CREDENTIALS"


class InvalidRecoveryCodeError(AuthError):
    """Raised when a reset's identifier and recovery code don't match a known user.

    The same error covers an unknown identifier, so a reset can't probe which users exist.
    """

    code = "INVALID_RECOVERY_CODE"


class AvatarNotFoundError(NotFoundError):
    """Raised when fetching the picture of a user who hasn't uploaded one."""

    code = "AVATAR_NOT_FOUND"


def _utc_now() -> datetime:
    return datetime.now(UTC)


class AuthService:
    """Registration, login, logout, profile and avatar, and bearer-token resolution."""

    def __init__(
        self,
        repository: AuthRepository,
        clock: Callable[[], datetime] = _utc_now,
        live_sessions: LiveSessions | None = None,
    ) -> None:
        self._repository = repository
        self._clock = clock
        # Told about every revoked session, so connections opened under it are closed too.
        self._live_sessions = live_sessions if live_sessions is not None else get_live_sessions()

    def register(self, data: UserRegister) -> tuple[User, str, str]:
        """Create a user (locale + currency persisted), a session token, and a recovery code.

        Returns:
            The user, the session token, and the plaintext recovery code: the only time it
            exists unhashed, so the caller must show it to the user now.

        Raises:
            EmailTakenError: the email is already registered.
            DisplayNameTakenError: the display name is already registered.
        """
        if self._repository.get_user_by_email(data.email) is not None:
            raise EmailTakenError("A user with this email already exists.")
        if self._repository.get_user_by_display_name(data.display_name) is not None:
            raise DisplayNameTakenError("A user with this display name already exists.")

        recovery_code = generate_recovery_code()
        user = User(
            email=data.email,
            password_hash=hash_password(data.password),
            recovery_code_hash=hash_recovery_code(recovery_code),
            display_name=data.display_name,
            locale=data.locale,
            currency=data.currency,
        )
        self._repository.add_user(user)
        token = self._issue_token(user)
        return user, token, recovery_code

    def login(self, data: UserLogin) -> tuple[User, str]:
        """Verify credentials and issue a new session token.

        Raises:
            InvalidCredentialsError: the identifier or password is wrong.
        """
        user = self._find_user(data.identifier)
        if user is None or not verify_password(data.password, user.password_hash):
            raise InvalidCredentialsError("Incorrect identifier or password.")

        token = self._issue_token(user)
        return user, token

    def reset_password(self, data: PasswordReset) -> tuple[User, str, str]:
        """Set a new password using the recovery code, as the way back in after losing it.

        The used code is spent: a new one replaces it, and every existing session is revoked.

        Returns:
            The user, a new session token, and the replacement plaintext recovery code.

        Raises:
            InvalidRecoveryCodeError: the identifier is unknown, its user has no recovery code,
                or the code doesn't match.
        """
        user = self._find_user(data.identifier)
        if (
            user is None
            or user.recovery_code_hash is None
            or not verify_recovery_code(data.recovery_code, user.recovery_code_hash)
        ):
            raise InvalidRecoveryCodeError("Incorrect identifier or recovery code.")

        recovery_code = generate_recovery_code()
        self._repository.reset_credentials(
            user,
            password_hash=hash_password(data.new_password),
            recovery_code_hash=hash_recovery_code(recovery_code),
        )
        self._live_sessions.revoke_user(user.id)
        token = self._issue_token(user)
        return user, token, recovery_code

    def regenerate_recovery_code(self, user: User, password: str) -> str:
        """Replace the user's recovery code, invalidating the previous one.

        Asks for the password again so an unattended open session can't swap the code.

        Returns:
            The new plaintext recovery code, to show to the user once.

        Raises:
            InvalidCredentialsError: the password is wrong.
        """
        if not verify_password(password, user.password_hash):
            raise InvalidCredentialsError("Incorrect password.")

        recovery_code = generate_recovery_code()
        user.recovery_code_hash = hash_recovery_code(recovery_code)
        self._repository.save_user(user)
        return recovery_code

    def update_profile(self, user: User, data: ProfileUpdate) -> User:
        """Change the user's display name, which is also their username.

        Raises:
            DisplayNameTakenError: another user already has this display name.
        """
        owner = self._repository.get_user_by_display_name(data.display_name)
        if owner is not None and owner.id != user.id:
            raise DisplayNameTakenError("A user with this display name already exists.")

        user.display_name = data.display_name
        return self._repository.save_user(user)

    def get_avatar(self, user: User) -> UserAvatar:
        """The picture the user uploaded as their avatar.

        Raises:
            AvatarNotFoundError: the user's avatar is not a picture.
        """
        avatar = self._repository.get_avatar(user.id)
        if avatar is None or user.avatar != AVATAR_IMAGE:
            raise AvatarNotFoundError("This user has no avatar picture.")
        return avatar

    def upload_avatar(self, user: User, data: bytes) -> User:
        """Make an uploaded picture the user's avatar, re-encoded without its metadata.

        The default it replaces is kept, so removing the picture later brings it back.

        Raises:
            AvatarTooLargeError: the file or its pixel count is over the limit.
            AvatarInvalidImageError: the bytes aren't a PNG, JPEG or WebP picture.
        """
        image = normalize_avatar(data)
        previous = user.avatar if user.avatar != AVATAR_IMAGE else AVATAR_MONOGRAM
        return self._repository.save_avatar(
            user,
            UserAvatar(
                user_id=user.id,
                image=image,
                content_type=AVATAR_CONTENT_TYPE,
                previous_choice=previous,
                updated_at=self._clock(),
            ),
        )

    def remove_avatar(self, user: User) -> User:
        """Drop the user's picture and go back to the default they had before uploading it.

        A no-op for a user without a picture.
        """
        avatar = self._repository.get_avatar(user.id)
        if avatar is None:
            return user
        return self._repository.set_avatar_choice(user, avatar.previous_choice)

    def set_avatar_choice(self, user: User, choice: str) -> User:
        """Make the monogram or a preset the user's avatar, dropping any uploaded picture."""
        return self._repository.set_avatar_choice(user, choice)

    def logout(self, token: str) -> None:
        """Invalidate a session token and close what it opened. A no-op if it is already gone."""
        record = self._repository.get_token(token)
        if record is not None:
            self._repository.delete_token(record)
            self._live_sessions.revoke_session(record.id)

    def get_current_user(self, token: str) -> User:
        """Resolve the user owning a bearer token.

        Raises:
            AuthError: the token is unknown or its user no longer exists.
        """
        return self.get_session(token)[0]

    def get_session(self, token: str) -> tuple[User, str]:
        """Resolve a bearer token to its user and the id of its session.

        The session id is what a long-lived connection registers under, so it can be closed
        when that session is revoked without holding on to the token itself.

        Raises:
            AuthError: the token is unknown or its user no longer exists.
        """
        record = self._repository.get_token(token)
        if record is None:
            raise AuthError("Invalid or expired token.")

        user = self._repository.get_user_by_id(record.user_id)
        if user is None:
            raise AuthError("Invalid or expired token.")

        return user, record.id

    def _find_user(self, identifier: str) -> User | None:
        """Look a user up by email if the identifier has an "@", by display name otherwise."""
        if "@" in identifier:
            return self._repository.get_user_by_email(identifier)
        return self._repository.get_user_by_display_name(identifier.strip().lower())

    def _issue_token(self, user: User) -> str:
        token = generate_token()
        self._repository.add_token(AuthToken(user_id=user.id, token=token))
        return token
