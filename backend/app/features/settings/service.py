"""Business logic for reading and patching a user's settings."""

from datetime import datetime

from app.features.settings.models import UserSettings
from app.features.settings.repository import SettingsRepository
from app.features.settings.schemas import SettingsUpdate

# The columns a patch may legitimately set back to null — clearing a declared income is how the
# debt ratio returns to the ledger median (PROJECT.md §15). For the others an explicit `null` is
# not a value the column accepts, so it is treated as "leave alone" rather than writing a null
# the schema forbids.
_NULLABLE_FIELDS = frozenset({"model_tag", "declared_monthly_income_minor"})


class SettingsService:
    """Read/patch of the per-user settings row, created lazily on first read."""

    def __init__(self, repository: SettingsRepository) -> None:
        self._repository = repository

    def get_or_create(self, user_id: str) -> UserSettings:
        """Return the user's settings, creating the row with defaults if absent.

        Idempotent: a second call — including one racing the first — returns the existing
        row rather than creating a second.
        """
        existing = self._repository.get_by_user(user_id)
        if existing is not None:
            return existing
        return self._repository.add_or_get_existing(UserSettings(user_id=user_id))

    def record_backup(self, user_id: str, at: datetime) -> UserSettings:
        """Stamp the time of the user's latest full backup export."""
        settings = self.get_or_create(user_id)
        settings.last_backup_at = at
        return self._repository.update(settings)

    def update(self, user_id: str, data: SettingsUpdate) -> UserSettings:
        """Patch the supplied fields; omitted ones keep their stored value."""
        settings = self.get_or_create(user_id)
        for field, value in data.model_dump(exclude_unset=True).items():
            if value is None and field not in _NULLABLE_FIELDS:
                continue
            setattr(settings, field, value)
        return self._repository.update(settings)
