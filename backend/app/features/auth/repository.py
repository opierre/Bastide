"""Data access for `User` and `AuthToken` rows. The only place that queries these tables."""

from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from app.features.auth.models import AuthToken, User


class AuthRepository:
    """Queries and writes for users and their session tokens."""

    def __init__(self, db: Session) -> None:
        self._db = db

    def get_user_by_email(self, email: str) -> User | None:
        return self._db.scalar(select(User).where(User.email == email))

    def get_user_by_display_name(self, display_name: str) -> User | None:
        return self._db.scalar(select(User).where(User.display_name == display_name))

    def get_user_by_id(self, user_id: str) -> User | None:
        return self._db.get(User, user_id)

    def add_user(self, user: User) -> User:
        self._db.add(user)
        self._db.commit()
        self._db.refresh(user)
        return user

    def add_token(self, token: AuthToken) -> AuthToken:
        self._db.add(token)
        self._db.commit()
        self._db.refresh(token)
        return token

    def get_token(self, token: str) -> AuthToken | None:
        return self._db.scalar(select(AuthToken).where(AuthToken.token == token))

    def delete_token(self, token: AuthToken) -> None:
        self._db.delete(token)
        self._db.commit()

    def save_user(self, user: User) -> User:
        self._db.commit()
        self._db.refresh(user)
        return user

    def reset_credentials(self, user: User, password_hash: str, recovery_code_hash: str) -> None:
        """Replace both secrets and drop every session of the user, in one transaction."""
        user.password_hash = password_hash
        user.recovery_code_hash = recovery_code_hash
        self._db.execute(delete(AuthToken).where(AuthToken.user_id == user.id))
        self._db.commit()
