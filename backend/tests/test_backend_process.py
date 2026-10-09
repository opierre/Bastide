"""Tests that start the sidecar as a process and talk to it as the desktop app will."""

import http.client
import json
import re
import shutil
import sqlite3
import subprocess
from pathlib import Path
from typing import Any

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


def test_prints_ready_with_its_port_and_version_then_serves(tmp_path: Path) -> None:
    process = backend_process.start(tmp_path)
    try:
        assert process.stdout is not None
        line = backend_process.read_line(process.stdout)

        assert line is not None, "the backend never printed a line"
        match = READY.match(line.strip())
        assert match is not None, f"not a READY line: {line!r}"
        port, version = int(match.group(1)), match.group(2)
        assert port > 0
        assert version == __version__

        status, health = get_json(port, "/api/v1/health")
        assert status == 200
        assert health == {"status": "ok", "version": __version__}
    finally:
        backend_process.stop(process)


def test_requires_the_session_token_it_was_started_with(tmp_path: Path) -> None:
    process = backend_process.start(tmp_path, env={"BASTIDE_SESSION_TOKEN": "launch-token"})
    try:
        port = _ready_port(process)

        rejected, _ = get_json(port, "/api/v1/health")
        accepted, _ = get_json(port, "/api/v1/health", {SESSION_TOKEN_HEADER: "launch-token"})

        assert rejected == 401
        assert accepted == 200
    finally:
        backend_process.stop(process)


def test_exits_with_a_dedicated_code_on_a_newer_database(
    tmp_path: Path, migrated_template: Path
) -> None:
    db_path = tmp_path / "bastide.db"
    shutil.copyfile(migrated_template, db_path)
    with sqlite3.connect(db_path) as connection:
        connection.execute("UPDATE alembic_version SET version_num = 'f0f0f0f0f0f0'")
    connection.close()

    process = backend_process.start(tmp_path)
    try:
        _, stderr = process.communicate(timeout=backend_process.STARTUP_TIMEOUT)
    finally:
        backend_process.stop(process)

    assert process.returncode == EXIT_SCHEMA_TOO_NEW
    assert "FATAL DATABASE_SCHEMA_TOO_NEW" in stderr.splitlines()
