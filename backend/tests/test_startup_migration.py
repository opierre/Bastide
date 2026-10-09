"""Tests for the schema upgrade the sidecar runs on startup."""

import shutil
from pathlib import Path
from unittest.mock import patch

from alembic.script import ScriptDirectory

from app.core import schema
from app.core.schema import alembic_config, current_revisions, migrate
from tests.migrations import upgrade


def _heads(db_path: Path) -> set[str]:
    return set(ScriptDirectory.from_config(alembic_config(db_path)).get_heads())


def _previous_revision(db_path: Path) -> str:
    script = ScriptDirectory.from_config(alembic_config(db_path))
    head = script.get_current_head()
    assert head is not None
    previous = script.get_revision(head).down_revision
    assert isinstance(previous, str)
    return previous


def test_a_new_database_is_created_at_head(tmp_path: Path) -> None:
    db_path = tmp_path / "data" / "bastide.db"

    migrate(db_path)

    assert current_revisions(db_path) == _heads(db_path)


def test_a_database_at_head_is_left_alone(tmp_path: Path, migrated_template: Path) -> None:
    db_path = tmp_path / "bastide.db"
    shutil.copyfile(migrated_template, db_path)

    with patch.object(schema.command, "upgrade") as upgrade_command:
        migrate(db_path)

    upgrade_command.assert_not_called()


def test_an_older_database_is_upgraded_to_head(tmp_path: Path) -> None:
    db_path = tmp_path / "bastide.db"
    previous = _previous_revision(db_path)
    upgrade(db_path, previous)

    migrate(db_path)

    assert current_revisions(db_path) == _heads(db_path)


def test_a_missing_file_has_no_revision(tmp_path: Path) -> None:
    assert current_revisions(tmp_path / "absent.db") == set()
