"""Bring the datastore to this build's schema when the sidecar starts.

An installed app has nobody to run `alembic upgrade head` by hand, so startup does it before
the server accepts a request, after copying the database aside in case the upgrade goes wrong.
"""

import logging
import sqlite3
from collections.abc import Callable
from datetime import UTC, datetime
from pathlib import Path

from alembic import command
from alembic.config import Config
from alembic.runtime.migration import MigrationContext
from alembic.script import ScriptDirectory
from sqlalchemy import create_engine
from sqlalchemy.pool import NullPool

logger = logging.getLogger(__name__)

MIGRATIONS_DIR = Path(__file__).resolve().parents[2] / "migrations"

#: Pre-migration copies kept; the oldest beyond this are deleted.
BACKUPS_KEPT = 5

#: The revisions folded into the `b7e4d1a9c352` baseline (v0.1.0's head). Every release is at or
#: past the baseline; only a database last opened by a pre-release build can carry one of these.
SQUASHED_REVISIONS = frozenset(
    {
        "24ef282f7623",
        "a0343e4ecc95",
        "662ad14df059",
        "b1c7a4e9d820",
        "a83dd88e80a1",
        "c3f5a1d47e92",
        "d7b2e5c91f38",
        "e4a1c6f20b73",
        "69c99438379e",
        "f5c81a930d47",
        "a8d3f2c61e05",
        "9aac42160214",
        "c4e8b1d25a97",
        "d2a7c9e4f613",
        "e9b3f7a2c418",
        "b6d4f0e81a53",
        "c7e2a9d4b150",
        "e2c6b9a14f70",
        "f8a2d5c3e910",
    }
)


class SchemaTooNewError(Exception):
    """The database carries a revision this build doesn't know: a newer build migrated it.

    Running on it would break in unpredictable places, and downgrading it would need the
    newer build's migrations, so the only safe move is to refuse to start.
    """

    def __init__(self, revisions: set[str]) -> None:
        self.revisions = revisions
        super().__init__(f"Unknown database revision(s): {', '.join(sorted(revisions))}")


class SchemaTooOldError(Exception):
    """The database predates the migration baseline: this build can't upgrade it.

    The migrations it would need were squashed into the baseline, so it is refused untouched;
    a release up to v0.1.2 can still bring it to the baseline.
    """

    def __init__(self, revisions: set[str]) -> None:
        self.revisions = revisions
        super().__init__(
            f"Database revision(s) older than the baseline: {', '.join(sorted(revisions))}"
        )


def alembic_config(db_path: Path) -> Config:
    """An Alembic config aimed at `db_path`, built without `alembic.ini`.

    Loading the ini would reconfigure logging for the whole process; `env.py` reads the path
    from the config's attributes instead of from the settings.
    """
    config = Config()
    config.set_main_option("script_location", str(MIGRATIONS_DIR))
    config.attributes["db_path"] = str(db_path)
    return config


def current_revisions(db_path: Path) -> set[str]:
    """The revisions the database is stamped with; empty for a new or never-migrated file."""
    if not db_path.exists():
        return set()
    engine = create_engine(f"sqlite:///{db_path}", poolclass=NullPool)
    try:
        with engine.connect() as connection:
            return set(MigrationContext.configure(connection).get_current_heads())
    finally:
        engine.dispose()


def migrate(db_path: Path, now: Callable[[], datetime] = lambda: datetime.now(UTC)) -> None:
    """Upgrade the database at `db_path` to head; a no-op when it is already there.

    A database that already holds a schema is backed up first, into `backups/` beside it. A
    new one has nothing to lose, so it is migrated straight away.

    Raises:
        SchemaTooOldError: The database predates the migration baseline; it is left untouched.
        SchemaTooNewError: The database was migrated by a newer build; it is left untouched.
    """
    config = alembic_config(db_path)
    script = ScriptDirectory.from_config(config)
    heads = set(script.get_heads())
    current = current_revisions(db_path)
    squashed = current & SQUASHED_REVISIONS
    if squashed:
        raise SchemaTooOldError(squashed)
    unknown = current - {revision.revision for revision in script.walk_revisions()}
    if unknown:
        raise SchemaTooNewError(unknown)
    if current == heads:
        return
    if current:
        backup_database(db_path, "+".join(sorted(current)), now())
    command.upgrade(config, "head")


def backup_database(db_path: Path, revision: str, at: datetime) -> Path:
    """Copy the database to `backups/bastide-<revision>-<timestamp>.db` and prune old copies.

    SQLite's online backup API rather than a file copy: in WAL mode, committed rows can still
    sit in the `-wal` file, which copying `bastide.db` alone would leave behind.
    """
    backups_dir = db_path.parent / "backups"
    backups_dir.mkdir(parents=True, exist_ok=True)
    target = backups_dir / f"bastide-{revision}-{at:%Y%m%dT%H%M%S%fZ}.db"
    source = sqlite3.connect(db_path)
    try:
        destination = sqlite3.connect(target)
        try:
            source.backup(destination)
        finally:
            destination.close()
    finally:
        source.close()
    logger.info("Backed up the database to %s before migrating.", target)
    _prune_backups(backups_dir)
    return target


def _prune_backups(backups_dir: Path) -> None:
    """Delete all but the newest `BACKUPS_KEPT` copies, oldest by the timestamp in the name."""
    backups = sorted(backups_dir.glob("bastide-*-*.db"), key=lambda p: p.stem.rsplit("-", 1)[1])
    for old in backups[:-BACKUPS_KEPT]:
        old.unlink()
