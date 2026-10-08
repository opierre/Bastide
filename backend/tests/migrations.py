"""Running Alembic from inside the test process."""

import os
from pathlib import Path
from typing import Any

from alembic import command
from alembic.config import Config
from sqlalchemy import Engine, create_engine

from app.core.config import get_settings
from app.core.db import configure_sqlite

BACKEND_DIR = Path(__file__).resolve().parent.parent


def upgrade(db_path: Path, revision: str = "head") -> None:
    """Migrate the SQLite file at ``db_path`` up to ``revision``."""
    _run(command.upgrade, db_path, revision)


def downgrade(db_path: Path, revision: str) -> None:
    """Migrate the SQLite file at ``db_path`` down to ``revision``."""
    _run(command.downgrade, db_path, revision)


def _run(action: Any, db_path: Path, revision: str) -> None:
    """Run one Alembic command in-process, the way the CLI would.

    In-process rather than as a subprocess, which cost a Python start-up per call. `env.py`
    targets `get_settings().db_path`, so the path travels through the same variable the CLI
    reads, with the settings cache cleared on both sides so no later test sees this path. The
    config is built without `alembic.ini` on purpose: loading it would reconfigure logging for
    the rest of the session.
    """
    config = Config()
    config.set_main_option("script_location", str(BACKEND_DIR / "migrations"))
    previous = os.environ.get("BASTIDE_DB_PATH")
    os.environ["BASTIDE_DB_PATH"] = str(db_path)
    get_settings.cache_clear()
    try:
        action(config, revision)
    finally:
        if previous is None:
            del os.environ["BASTIDE_DB_PATH"]
        else:
            os.environ["BASTIDE_DB_PATH"] = previous
        get_settings.cache_clear()


def engine_with_foreign_keys(db_path: Path) -> Engine:
    """An engine configured as the app's — foreign keys enforced, so cascades actually run."""
    return configure_sqlite(
        create_engine(f"sqlite:///{db_path}", connect_args={"check_same_thread": False})
    )
