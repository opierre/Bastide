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


class SchemaTooNewError(Exception):
    """The database carries a revision this build doesn't know: a newer build migrated it.

    Running on it would break in unpredictable places, and downgrading it would need the
    newer build's migrations, so the only safe move is to refuse to start.
    """

    def __init__(self, revisions: set[str]) -> None:
        self.revisions = revisions
        super().__init__(f"Unknown database revision(s): {', '.join(sorted(revisions))}")


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
        SchemaTooNewError: The database was migrated by a newer build; it is left untouched.
    """
    config = alembic_config(db_path)
    script = ScriptDirectory.from_config(config)
    heads = set(script.get_heads())
    current = current_revisions(db_path)
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
