"""Data access for `UserSettings` rows. The only place that queries this table."""

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.features.settings.models import UserSettings


class SettingsRepository:
    """Queries and writes for user settings, always scoped to a user."""

    def __init__(self, db: Session) -> None:
        self._db = db

    def get_by_user(self, user_id: str) -> UserSettings | None:
        return self._db.scalar(select(UserSettings).where(UserSettings.user_id == user_id))

    def add_or_get_existing(self, settings: UserSettings) -> UserSettings:
        """Insert the row, or return the one a concurrent first read inserted first.

        Two simultaneous `GET /settings` calls both find no row and both try to create
        one; the unique constraint on `user_id` makes the loser fail rather than write a
        duplicate, and it simply adopts the winner's row.
        """
        try:
            self._db.add(settings)
            self._db.commit()
        except IntegrityError:
            self._db.rollback()
            existing = self.get_by_user(settings.user_id)
            if existing is None:
                raise  # Not the uniqueness race — a real constraint failure.
            return existing
        self._db.refresh(settings)
        return settings

    def update(self, settings: UserSettings) -> UserSettings:
        self._db.commit()
        self._db.refresh(settings)
        return settings
