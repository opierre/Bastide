"""Business logic for the opt-in update check."""

from collections.abc import Callable
from datetime import UTC, datetime, timedelta

from app.features.settings.service import SettingsService
from app.features.updates.releases import (
    RELEASES_REPO,
    ReleaseCheckFailed,
    ReleaseSource,
    is_newer,
)
from app.features.updates.schemas import UpdateStatus

#: However often the app starts, GitHub is asked at most this often.
CHECK_INTERVAL = timedelta(days=1)


def release_page(version: str) -> str:
    """The GitHub page of the release tagged `v<version>`.

    Built here rather than taken from GitHub's answer, so the link the app opens can only
    ever point at this repository's releases.
    """
    return f"https://github.com/{RELEASES_REPO}/releases/tag/v{version}"


class UpdateService:
    """Reports whether a newer release exists, asking GitHub only when the user opted in."""

    def __init__(
        self,
        settings: SettingsService,
        releases: ReleaseSource,
        current_version: str,
        now: Callable[[], datetime] = lambda: datetime.now(UTC),
    ) -> None:
        self._settings = settings
        self._releases = releases
        self._current_version = current_version
        self._now = now

    async def status(self, user_id: str) -> UpdateStatus:
        """The update status for this user, checking GitHub if the last check is a day old.

        Raises nothing: an unreachable GitHub comes back as `reachable=False`.
        """
        settings = self._settings.get_or_create(user_id)
        if not settings.update_check_enabled:
            return UpdateStatus(enabled=False, current_version=self._current_version)

        now = self._now()
        latest = settings.update_latest_version
        # SQLite hands timestamps back naive; they were written in UTC.
        checked_at = settings.update_checked_at
        if checked_at is not None and checked_at.tzinfo is None:
            checked_at = checked_at.replace(tzinfo=UTC)

        reachable = True
        # A check stamped in the future (the clock was set back) is treated as due.
        if checked_at is None or not checked_at <= now < checked_at + CHECK_INTERVAL:
            try:
                latest = await self._releases.latest_version()
            except ReleaseCheckFailed:
                reachable = False
            else:
                checked_at = now
                self._settings.record_update_check(user_id, now, latest)

        available = latest is not None and is_newer(latest, self._current_version)
        return UpdateStatus(
            enabled=True,
            current_version=self._current_version,
            latest_version=latest,
            update_available=available,
            release_url=release_page(latest) if available and latest is not None else None,
            checked_at=checked_at,
            reachable=reachable,
        )
