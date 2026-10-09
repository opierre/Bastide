"""Tests for the schema upgrade the sidecar runs on startup."""

import shutil
import sqlite3
from datetime import UTC, datetime, timedelta
from pathlib import Path
from unittest.mock import patch

import pytest
from alembic.script import ScriptDirectory

from app.core import schema
from app.core.schema import (
    BACKUPS_KEPT,
    SchemaTooNewError,
    alembic_config,
    backup_database,
    current_revisions,
    migrate,
)
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


NOW = datetime(2026, 10, 9, 8, 30, 15, 123456, tzinfo=UTC)


def _backups(db_path: Path) -> list[Path]:
    return sorted((db_path.parent / "backups").glob("*.db"))


def test_no_pending_revision_means_no_backup(tmp_path: Path, migrated_template: Path) -> None:
    db_path = tmp_path / "bastide.db"
    shutil.copyfile(migrated_template, db_path)

    migrate(db_path, now=lambda: NOW)

    assert _backups(db_path) == []


def test_a_new_database_is_not_backed_up(tmp_path: Path) -> None:
    db_path = tmp_path / "bastide.db"

    migrate(db_path, now=lambda: NOW)

    assert _backups(db_path) == []


def test_pending_revisions_back_up_a_restorable_copy_first(tmp_path: Path) -> None:
    db_path = tmp_path / "bastide.db"
    previous = _previous_revision(db_path)
    upgrade(db_path, previous)
    with sqlite3.connect(db_path) as connection:
        connection.execute("CREATE TABLE marker (note TEXT)")
        connection.execute("INSERT INTO marker VALUES ('before the upgrade')")
    connection.close()

    migrate(db_path, now=lambda: NOW)

    [backup] = _backups(db_path)
    assert backup.name == f"bastide-{previous}-20261009T083015123456Z.db"
    restored = tmp_path / "restored.db"
    shutil.copyfile(backup, restored)
    assert current_revisions(restored) == {previous}
    with sqlite3.connect(restored) as connection:
        assert connection.execute("SELECT note FROM marker").fetchall() == [("before the upgrade",)]
    connection.close()


def test_the_backup_holds_rows_still_in_the_write_ahead_log(tmp_path: Path) -> None:
    db_path = tmp_path / "bastide.db"
    writer = sqlite3.connect(db_path)
    writer.execute("PRAGMA journal_mode=WAL")
    writer.execute("PRAGMA wal_autocheckpoint=0")
    writer.execute("CREATE TABLE marker (note TEXT)")
    writer.execute("INSERT INTO marker VALUES ('only in the wal')")
    writer.commit()
    try:
        backup = backup_database(db_path, "rev", NOW)
    finally:
        writer.close()

    with sqlite3.connect(backup) as connection:
        assert connection.execute("SELECT note FROM marker").fetchall() == [("only in the wal",)]
    connection.close()


def test_only_the_newest_backups_are_kept(tmp_path: Path) -> None:
    db_path = tmp_path / "bastide.db"
    sqlite3.connect(db_path).close()
    made = [backup_database(db_path, "rev", NOW + timedelta(days=day)) for day in range(7)]

    assert _backups(db_path) == sorted(made[-BACKUPS_KEPT:])


def _stamp_future_revision(db_path: Path, migrated_template: Path) -> None:
    shutil.copyfile(migrated_template, db_path)
    with sqlite3.connect(db_path) as connection:
        connection.execute("UPDATE alembic_version SET version_num = 'f0f0f0f0f0f0'")
    connection.close()


def test_a_database_from_a_newer_build_is_refused_untouched(
    tmp_path: Path, migrated_template: Path
) -> None:
    db_path = tmp_path / "bastide.db"
    _stamp_future_revision(db_path, migrated_template)
    before = db_path.read_bytes()

    with pytest.raises(SchemaTooNewError) as raised:
        migrate(db_path, now=lambda: NOW)

    assert raised.value.revisions == {"f0f0f0f0f0f0"}
    assert db_path.read_bytes() == before
    assert _backups(db_path) == []
