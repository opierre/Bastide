"""Every migration's `downgrade`, checked once by taking the whole chain down and back up."""

import shutil
from pathlib import Path

from sqlalchemy import create_engine, inspect

from app.core.schema import current_revisions
from scripts.schema_doc import render
from tests.migrations import downgrade, upgrade


def _schema(db_path: Path) -> str:
    """The schema reference `docs/database.md` would hold for this database."""
    engine = create_engine(f"sqlite:///{db_path}")
    try:
        return render(engine)
    finally:
        engine.dispose()


def test_head_to_base_to_head_rebuilds_the_same_schema(
    tmp_path: Path, migrated_template: Path
) -> None:
    db_path = tmp_path / "roundtrip.db"
    shutil.copyfile(migrated_template, db_path)

    downgrade(db_path, "base")
    engine = create_engine(f"sqlite:///{db_path}")
    leftover = set(inspect(engine).get_table_names()) - {"alembic_version"}
    engine.dispose()
    assert leftover == set()
    assert current_revisions(db_path) == set()

    upgrade(db_path)
    assert _schema(db_path) == _schema(migrated_template)
