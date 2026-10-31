"""Tests for the pragmas every app connection opens with, and the UTC timestamp column."""

from datetime import UTC, datetime, timedelta, timezone
from pathlib import Path

from sqlalchemy import Column, MetaData, Table, create_engine, insert, select, text

from app.core.db import UtcDateTime, configure_sqlite


def test_configure_sqlite_enables_wal_and_foreign_keys(tmp_path: Path) -> None:
    engine = configure_sqlite(create_engine(f"sqlite:///{tmp_path / 'pragmas.db'}"))

    with engine.connect() as connection:
        assert connection.scalar(text("PRAGMA journal_mode")) == "wal"
        assert connection.scalar(text("PRAGMA foreign_keys")) == 1

    engine.dispose()


def _round_trip(tmp_path: Path, value: datetime) -> datetime:
    table = Table("stamps", MetaData(), Column("at", UtcDateTime()))
    engine = create_engine(f"sqlite:///{tmp_path / 'stamps.db'}")
    table.metadata.create_all(engine)
    with engine.begin() as connection:
        connection.execute(insert(table).values(at=value))
        read = connection.scalar(select(table.c.at))
    engine.dispose()
    assert read is not None
    return read


def test_a_timestamp_reads_back_aware_in_utc(tmp_path: Path) -> None:
    read = _round_trip(tmp_path, datetime(2026, 3, 1, 23, 30, tzinfo=UTC))

    assert read == datetime(2026, 3, 1, 23, 30, tzinfo=UTC)
    assert read.tzinfo is UTC


def test_an_offset_timestamp_is_stored_as_the_same_instant_in_utc(tmp_path: Path) -> None:
    paris = timezone(timedelta(hours=1))

    read = _round_trip(tmp_path, datetime(2026, 3, 2, 0, 30, tzinfo=paris))

    assert read == datetime(2026, 3, 1, 23, 30, tzinfo=UTC)
    assert read.tzinfo is UTC


def test_a_naive_timestamp_is_taken_as_utc(tmp_path: Path) -> None:
    # What a backup made before timestamps carried their zone holds.
    read = _round_trip(tmp_path, datetime(2026, 3, 1, 23, 30))

    assert read == datetime(2026, 3, 1, 23, 30, tzinfo=UTC)
