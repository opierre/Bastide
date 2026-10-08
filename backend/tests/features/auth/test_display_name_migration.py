"""The migration turning free-text display names into unique usernames."""

from pathlib import Path

import pytest
from sqlalchemy import Connection, create_engine, text
from sqlalchemy.exc import IntegrityError

from tests.migrations import downgrade, upgrade

PRE_MIGRATION_REVISION = "e2c6b9a14f70"


def _insert_user(conn: Connection, user_id: str, display_name: str, created_at: str) -> None:
    conn.execute(
        text(
            "INSERT INTO users (id, email, password_hash, display_name, locale, currency,"
            " created_at, updated_at)"
            " VALUES (:id, :email, 'hash', :name, 'fr', 'EUR', :created_at, :created_at)"
        ),
        {
            "id": user_id,
            "email": f"{user_id}@example.com",
            "name": display_name,
            "created_at": created_at,
        },
    )


def test_existing_names_are_normalized_and_deduplicated(tmp_path: Path) -> None:
    db_path = tmp_path / "app.db"
    upgrade(db_path, PRE_MIGRATION_REVISION)
    engine = create_engine(f"sqlite:///{db_path}")
    with engine.begin() as conn:
        _insert_user(conn, "u1", "Amelie", "2026-01-01 00:00:00")
        _insert_user(conn, "u2", "amelie", "2026-02-01 00:00:00")
        _insert_user(conn, "u3", "Pierre Olivier", "2026-03-01 00:00:00")
        _insert_user(conn, "u4", "Jo", "2026-04-01 00:00:00")
        _insert_user(conn, "u5", "already.ok", "2026-05-01 00:00:00")
    engine.dispose()

    upgrade(db_path)

    engine = create_engine(f"sqlite:///{db_path}")
    with engine.begin() as conn:
        rows = conn.execute(text("SELECT id, display_name FROM users")).all()
        names = {user_id: name for user_id, name in rows}
        assert names == {
            "u1": "amelie",
            "u2": "amelie-2",
            "u3": "pierre.olivier",
            "u4": "user",
            "u5": "already.ok",
        }
        with pytest.raises(IntegrityError):
            _insert_user(conn, "u6", "amelie", "2026-06-01 00:00:00")
    engine.dispose()


def test_downgrade_then_upgrade_is_clean(tmp_path: Path) -> None:
    db_path = tmp_path / "app.db"
    upgrade(db_path)
    downgrade(db_path, PRE_MIGRATION_REVISION)
    upgrade(db_path)
