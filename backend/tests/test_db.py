"""Tests for the pragmas every app connection opens with."""

from pathlib import Path

from sqlalchemy import create_engine, text

from app.core.db import configure_sqlite


def test_configure_sqlite_enables_wal_and_foreign_keys(tmp_path: Path) -> None:
    engine = configure_sqlite(create_engine(f"sqlite:///{tmp_path / 'pragmas.db'}"))

    with engine.connect() as connection:
        assert connection.scalar(text("PRAGMA journal_mode")) == "wal"
        assert connection.scalar(text("PRAGMA foreign_keys")) == 1

    engine.dispose()
