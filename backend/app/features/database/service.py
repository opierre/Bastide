"""Resetting one profile's data to an empty install (`docs/design/09-settings.md` §Zone de danger).

Deliberately *not* part of the backup feature even though both wipe the same rows: a backup
replaces them with an archive's and reports what the file held, a reset leaves nothing and
reports what it removed. Sharing the delete would mean one service with two blast radii.
"""

from collections.abc import Callable

from sqlalchemy.orm import Session

from app import __version__
from app.core.seed import ensure_system_categories
from app.features.auth.models import User
from app.features.database.errors import ResetRunActiveError
from app.features.database.repository import DatabaseRepository
from app.features.database.schemas import DatabaseCounts, DatabaseSummary


class DatabaseService:
    """Reports what a profile holds, and empties it."""

    def __init__(
        self,
        repository: DatabaseRepository,
        reseed: Callable[[Session], object] = ensure_system_categories,
    ) -> None:
        self._repository = repository
        self._reseed = reseed

    def summary(self, user: User) -> DatabaseSummary:
        """The live data the confirmations show — read at the moment they are shown."""
        return self._summary(user, DatabaseCounts(**self._repository.count_rows(user.id)))

    def reset(self, user: User, db: Session) -> DatabaseSummary:
        """Delete everything the user owns, atomically, and report what went.

        The counts are read before the delete and returned after it: the user is told what a
        confirmation they already read actually removed, not an empty profile's zeroes.

        Raises:
            ResetRunActiveError: a categorisation run is still writing to this data.
        """
        if self._repository.has_active_run(user.id):
            raise ResetRunActiveError("A categorisation run is in progress.")
        before = self.summary(user)

        try:
            self._repository.delete_user_data(user.id)
            # System categories are global, so the delete above never reaches them — but an
            # empty profile has to be able to categorise, and re-seeding says so out loud
            # (and restores the catalog if an earlier release's rows are missing).
            self._reseed(db)
            self._repository.commit()
        except BaseException:
            self._repository.rollback()
            raise
        return before

    def _summary(self, user: User, counts: DatabaseCounts) -> DatabaseSummary:
        return DatabaseSummary(
            app_version=__version__,
            last_import_at=self._repository.latest_import_at(user.id),
            counts=counts,
        )
