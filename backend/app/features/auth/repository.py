"""Data access for `User` and `AuthToken` rows. The only place that queries these tables."""

from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from app.features.auth.models import AVATAR_IMAGE, AuthToken, User, UserAvatar


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

    def get_avatar(self, user_id: str) -> UserAvatar | None:
        return self._db.get(UserAvatar, user_id)

    def save_avatar(self, user: User, avatar: UserAvatar) -> User:
        """Store the user's picture, replacing any earlier one, and point the user at it."""
        existing = self._db.get(UserAvatar, user.id)
        if existing is None:
            self._db.add(avatar)
        else:
            existing.image = avatar.image
            existing.content_type = avatar.content_type
            existing.updated_at = avatar.updated_at
        user.avatar = AVATAR_IMAGE
        return self.save_user(user)

    def set_avatar_choice(self, user: User, choice: str) -> User:
        """Set the user's avatar to a default, dropping their picture in the same transaction."""
        self._db.execute(delete(UserAvatar).where(UserAvatar.user_id == user.id))
        user.avatar = choice
        return self.save_user(user)
