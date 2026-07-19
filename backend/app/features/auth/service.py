"""Business logic for registration, login, logout, and current-user lookup."""

from app.core.errors import AuthError, ConflictError
from app.core.security import generate_token, hash_password, verify_password
from app.features.auth.models import AuthToken, User
from app.features.auth.repository import AuthRepository
from app.features.auth.schemas import UserLogin, UserRegister


class EmailTakenError(ConflictError):
    """Raised when registering with an email that's already in use."""

    code = "EMAIL_TAKEN"


class InvalidCredentialsError(AuthError):
    """Raised when login credentials don't match a known user."""

    code = "INVALID_CREDENTIALS"


class AuthService:
    """Registration, login, logout, and bearer-token resolution."""

    def __init__(self, repository: AuthRepository) -> None:
        self._repository = repository

    def register(self, data: UserRegister) -> tuple[User, str]:
        """Create a user (locale + currency persisted) and an initial session token.

        Raises:
            EmailTakenError: the email is already registered.
        """
        if self._repository.get_user_by_email(data.email) is not None:
            raise EmailTakenError("A user with this email already exists.")

        user = User(
            email=data.email,
            password_hash=hash_password(data.password),
            display_name=data.display_name,
            locale=data.locale,
            currency=data.currency,
        )
        self._repository.add_user(user)
        token = self._issue_token(user)
        return user, token

    def login(self, data: UserLogin) -> tuple[User, str]:
        """Verify credentials and issue a new session token.

        Raises:
            InvalidCredentialsError: the email or password is wrong.
        """
        user = self._repository.get_user_by_email(data.email)
        if user is None or not verify_password(data.password, user.password_hash):
            raise InvalidCredentialsError("Incorrect email or password.")

        token = self._issue_token(user)
        return user, token

    def logout(self, token: str) -> None:
        """Invalidate a session token. A no-op if the token is already gone."""
        record = self._repository.get_token(token)
        if record is not None:
            self._repository.delete_token(record)

    def get_current_user(self, token: str) -> User:
        """Resolve the user owning a bearer token.

        Raises:
            AuthError: the token is unknown or its user no longer exists.
        """
        record = self._repository.get_token(token)
        if record is None:
            raise AuthError("Invalid or expired token.")

        user = self._repository.get_user_by_id(record.user_id)
        if user is None:
            raise AuthError("Invalid or expired token.")

        return user

    def _issue_token(self, user: User) -> str:
        token = generate_token()
        self._repository.add_token(AuthToken(user_id=user.id, token=token))
        return token
