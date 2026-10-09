"""Tests for the sidecar's log destinations."""

import logging
from collections.abc import Generator
from pathlib import Path

import pytest

from app.core import db
from app.core.logs import LOG_FILE_BACKUPS, configure_logging


@pytest.fixture(autouse=True)
def _restore_root_logger() -> Generator[None]:
    root = logging.getLogger()
    handlers, level = root.handlers[:], root.level
    yield
    for handler in root.handlers[:]:
        root.removeHandler(handler)
        handler.close()
    for handler in handlers:
        root.addHandler(handler)
    root.setLevel(level)


def test_records_go_to_backend_log_in_the_given_folder(tmp_path: Path) -> None:
    log_dir = tmp_path / "logs"

    configure_logging(log_dir)
    logging.getLogger("app.test").info("Seeded %d system categories.", 40)

    assert "Seeded 40 system categories." in (log_dir / "backend.log").read_text("utf-8")


def test_the_file_rotates_and_keeps_a_bounded_history(tmp_path: Path) -> None:
    log_dir = tmp_path / "logs"

    configure_logging(log_dir, max_bytes=200)
    for index in range(50):
        logging.getLogger("app.test").info("line %d", index)

    files = sorted(path.name for path in log_dir.iterdir())
    assert files == ["backend.log", *(f"backend.log.{n}" for n in range(1, LOG_FILE_BACKUPS + 1))]
    assert all(path.stat().st_size <= 200 for path in log_dir.iterdir())


def test_without_a_folder_only_stderr_is_used() -> None:
    configure_logging()

    [handler] = logging.getLogger().handlers
    assert type(handler) is logging.StreamHandler


def test_sql_errors_leave_parameter_values_out_of_their_message() -> None:
    assert db.engine.hide_parameters is True
