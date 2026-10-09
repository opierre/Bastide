"""Bring the datastore to this build's schema when the sidecar starts.

An installed app has nobody to run `alembic upgrade head` by hand, so startup does it before
the server accepts a request.
"""

from pathlib import Path

from alembic import command
from alembic.config import Config
from alembic.runtime.migration import MigrationContext
from alembic.script import ScriptDirectory
from sqlalchemy import create_engine
from sqlalchemy.pool import NullPool

MIGRATIONS_DIR = Path(__file__).resolve().parents[2] / "migrations"


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


def migrate(db_path: Path) -> None:
    """Upgrade the database at `db_path` to head; a no-op when it is already there."""
    config = alembic_config(db_path)
    heads = set(ScriptDirectory.from_config(config).get_heads())
    if current_revisions(db_path) == heads:
        return
    command.upgrade(config, "head")
