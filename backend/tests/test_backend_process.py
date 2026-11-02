"""Tests that start the sidecar as a process and talk to it as the desktop app will."""

import http.client
import json
import re
import shutil
import sqlite3
import subprocess
import time
from collections.abc import Generator
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import pytest

from app import __version__
from app.cli import EXIT_SCHEMA_TOO_NEW
from app.core.session import SESSION_TOKEN_HEADER
from tests import backend_process

READY = re.compile(r"^READY (\d+) (\S+)$")


def get_json(port: int, path: str, headers: dict[str, str] | None = None) -> tuple[int, Any]:
    """GET a loopback URL; returns the status and the decoded body.

    `http.client` rather than httpx or urllib: those build an SSL context even for plain
    HTTP, and OpenSSL aborts the process when `SSLKEYLOGFILE` names a path it can't open.
    """
    connection = http.client.HTTPConnection("127.0.0.1", port, timeout=10)
    try:
        connection.request("GET", path, headers=headers or {})
        response = connection.getresponse()
        return response.status, json.loads(response.read())
    finally:
        connection.close()


def _ready_port(process: subprocess.Popen[str]) -> int:
    assert process.stdout is not None
    line = backend_process.read_line(process.stdout)
    assert line is not None and line.startswith("READY "), f"not a READY line: {line!r}"
    return int(line.split()[1])


TOKEN = "launch-token"


@dataclass(frozen=True)
class Sidecar:
    """A sidecar shared by the read-only checks of this module, and what it printed first."""

    data_dir: Path
    first_line: str | None


@pytest.fixture(scope="module")
def sidecar(
    tmp_path_factory: pytest.TempPathFactory, migrated_template: Path
) -> Generator[Sidecar]:
    """One sidecar for the module, started with a session token on an up-to-date database.

    Each process costs seconds to start; the checks below only look at it, so they share one,
    grouped on one worker so xdist does not start one per worker. A test that ends its process
    starts its own.
    """
    data_dir = tmp_path_factory.mktemp("sidecar")
    _copy_database(migrated_template, data_dir)
    process = backend_process.start(data_dir, env={"BASTIDE_SESSION_TOKEN": TOKEN})
    try:
        assert process.stdout is not None
        yield Sidecar(data_dir, backend_process.read_line(process.stdout))
    finally:
        backend_process.stop(process)


def _copy_database(migrated_template: Path, data_dir: Path) -> Path:
    """Put an up-to-date database where the sidecar looks, so startup has nothing to migrate."""
    db_path = data_dir / "bastide.db"
    shutil.copyfile(migrated_template, db_path)
    return db_path


def _ready(sidecar: Sidecar) -> re.Match[str]:
    """The shared sidecar's READY line, which every check below needs before it can look."""
    assert sidecar.first_line is not None, "the backend never printed a line"
    match = READY.match(sidecar.first_line.strip())
    assert match is not None, f"not a READY line: {sidecar.first_line!r}"
    return match


def _port(sidecar: Sidecar) -> int:
    return int(_ready(sidecar).group(1))


@pytest.mark.xdist_group("shared_sidecar")
def test_prints_ready_with_its_port_and_version_then_serves(sidecar: Sidecar) -> None:
    ready = _ready(sidecar)
    port, version = int(ready.group(1)), ready.group(2)
    assert port > 0
    assert version == __version__

    status, health = get_json(port, "/api/v1/health", {SESSION_TOKEN_HEADER: TOKEN})
    assert status == 200
    assert health == {"status": "ok", "version": __version__}


@pytest.mark.xdist_group("shared_sidecar")
def test_requires_the_session_token_it_was_started_with(sidecar: Sidecar) -> None:
    port = _port(sidecar)

    rejected, _ = get_json(port, "/api/v1/health")
    wrong, _ = get_json(port, "/api/v1/health", {SESSION_TOKEN_HEADER: "another-token"})
    accepted, _ = get_json(port, "/api/v1/health", {SESSION_TOKEN_HEADER: TOKEN})

    assert rejected == 401
    assert wrong == 401
    assert accepted == 200


@pytest.mark.xdist_group("shared_sidecar")
def test_writes_its_log_file_in_the_data_dir(sidecar: Sidecar) -> None:
    _ready(sidecar)

    log = (sidecar.data_dir / "logs" / "backend.log").read_text(encoding="utf-8")
    assert "Application startup complete." in log


def test_exits_with_a_dedicated_code_on_a_newer_database(
    tmp_path: Path, migrated_template: Path
) -> None:
    db_path = _copy_database(migrated_template, tmp_path)
    with sqlite3.connect(db_path) as connection:
        connection.execute("UPDATE alembic_version SET version_num = 'f0f0f0f0f0f0'")
    connection.close()

    process = backend_process.start(tmp_path)
    try:
        process.wait(timeout=backend_process.STARTUP_TIMEOUT)
    finally:
        backend_process.stop(process)

    assert process.returncode == EXIT_SCHEMA_TOO_NEW
    stderr = backend_process.stderr_log(tmp_path).read_text(encoding="utf-8")
    assert "FATAL DATABASE_SCHEMA_TOO_NEW" in stderr.splitlines()


def test_exits_within_two_seconds_once_its_stdin_closes(
    tmp_path: Path, migrated_template: Path
) -> None:
    _copy_database(migrated_template, tmp_path)
    process = backend_process.start(tmp_path, "--exit-on-stdin-close")
    try:
        _ready_port(process)
        assert process.stdin is not None

        closed_at = time.monotonic()
        process.stdin.close()
        process.wait(timeout=10)

        assert time.monotonic() - closed_at < 2
        assert process.returncode == 0
    finally:
        backend_process.stop(process)
