"""Data access for `User` and `AuthToken` rows. The only place that queries these tables."""

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.features.auth.models import AuthToken, User


class AuthRepository:
    """Queries and writes for users and their session tokens."""

    def __init__(self, db: Session) -> None:
        self._db = db

    def get_user_by_email(self, email: str) -> User | None:
        return self._db.scalar(select(User).where(User.email == email))

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
