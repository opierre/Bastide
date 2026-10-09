"""Smoke test of the frozen build: the PyInstaller output, run the way the desktop app runs it.

PyInstaller only bundles what it can see imported, so a module loaded by name or a data file read
by path can be missing from a build that the source tests never notice. This walks the paths
that load such things: startup migrations, password hashing, an OFX import, shutdown.

Not part of the default run (`-m "not frozen"` in pyproject). Build first, then:

    uv run --group build pyinstaller bastide-backend.spec --noconfirm
    uv run pytest -m frozen

`BASTIDE_FROZEN_BACKEND` points it at an executable elsewhere than `dist/`.
"""

import http.client
import json
import os
import subprocess
import sys
import uuid
from pathlib import Path
from typing import Any

import pytest

from app.core.session import SESSION_TOKEN_HEADER
from tests import backend_process

pytestmark = pytest.mark.frozen

FIXTURES = Path(__file__).resolve().parent / "fixtures" / "imports"

SESSION_TOKEN = "frozen-smoke-token"


def _frozen_executable() -> Path:
    if override := os.environ.get("BASTIDE_FROZEN_BACKEND"):
        return Path(override)
    name = "bastide-backend.exe" if sys.platform == "win32" else "bastide-backend"
    return backend_process.BACKEND_DIR / "dist" / "bastide-backend" / name


class _Client:
    """Just enough HTTP for this test, on `http.client` like `test_backend_process`."""

    def __init__(self, port: int) -> None:
        self.port = port
        self.headers = {SESSION_TOKEN_HEADER: SESSION_TOKEN}

    def request(
        self, method: str, path: str, body: bytes | None = None, content_type: str | None = None
    ) -> tuple[int, Any]:
        headers = dict(self.headers)
        if content_type is not None:
            headers["Content-Type"] = content_type
        connection = http.client.HTTPConnection("127.0.0.1", self.port, timeout=30)
        try:
            connection.request(method, f"/api/v1{path}", body=body, headers=headers)
            response = connection.getresponse()
            return response.status, json.loads(response.read())
        finally:
            connection.close()

    def post_json(self, path: str, payload: dict[str, Any]) -> tuple[int, Any]:
        return self.request("POST", path, json.dumps(payload).encode(), "application/json")

    def post_file(self, path: str, fields: dict[str, str], file: Path) -> tuple[int, Any]:
        boundary = uuid.uuid4().hex
        parts = [
            f'--{boundary}\r\nContent-Disposition: form-data; name="{name}"\r\n\r\n'.encode()
            + f"{value}\r\n".encode()
            for name, value in fields.items()
        ]
        parts.append(
            f'--{boundary}\r\nContent-Disposition: form-data; name="file"; '
            f'filename="{file.name}"\r\nContent-Type: application/octet-stream\r\n\r\n'.encode()
            + file.read_bytes()
            + b"\r\n"
        )
        body = b"".join(parts) + f"--{boundary}--\r\n".encode()
        return self.request("POST", path, body, f"multipart/form-data; boundary={boundary}")


def test_frozen_backend_migrates_registers_imports_and_shuts_down(tmp_path: Path) -> None:
    executable = _frozen_executable()
    assert executable.is_file(), f"no frozen build at {executable}; build it first"
    data_dir = tmp_path / "data"
    # Run from an empty folder: the build must not lean on files in the source tree.
    work_dir = tmp_path / "cwd"
    work_dir.mkdir()

    process = backend_process.start(
        data_dir,
        "--exit-on-stdin-close",
        env={"BASTIDE_SESSION_TOKEN": SESSION_TOKEN},
        command=[str(executable)],
        cwd=work_dir,
    )
    try:
        assert process.stdout is not None and process.stdin is not None
        line = backend_process.read_line(process.stdout)
        assert line is not None and line.startswith("READY "), (
            f"not a READY line: {line!r}; stderr: "
            + backend_process.stderr_log(data_dir).read_text(encoding="utf-8")
        )
        client = _Client(int(line.split()[1]))

        status, _ = client.request("GET", "/health")
        assert status == 200

        status, registered = client.post_json(
            "/auth/register",
            {
                "email": "amelie@example.com",
                "password": "correct-horse-battery-staple",
                "display_name": "amelie",
                "locale": "fr",
                "currency": "EUR",
            },
        )
        assert status == 201, registered
        client.headers["Authorization"] = f"Bearer {registered['token']}"

        status, account = client.post_json(
            "/accounts",
            {
                "name": "Compte courant",
                "type": "checking",
                "institution": "BNP Paribas",
                "opening_balance_minor": 100_000,
            },
        )
        assert status == 201, account

        status, batch = client.post_file(
            "/imports", {"account_id": account["id"]}, FIXTURES / "sample_sgml.ofx"
        )
        assert status == 201, batch
        assert batch["status"] == "success"
        assert batch["new_count"] == 2

        status, packs = client.request("GET", "/rules/packs/builtin")
        assert status == 200
        assert packs, "the built-in rule packs were not bundled"

        process.stdin.close()
        process.wait(timeout=10)
        assert process.returncode == 0
    finally:
        backend_process.stop(process)

    assert (data_dir / "bastide.db").is_file()
    assert (data_dir / "logs" / "backend.log").is_file()


def test_frozen_backend_does_not_need_python_on_the_path(tmp_path: Path) -> None:
    executable = _frozen_executable()
    assert executable.is_file(), f"no frozen build at {executable}; build it first"
    # Only the OS's own folders, so no Python install can be found.
    system_path = os.pathsep.join(
        [os.path.join(os.environ.get("SYSTEMROOT", r"C:\Windows"), "System32")]
        if sys.platform == "win32"
        else ["/usr/bin", "/bin"]
    )

    env = {k: v for k, v in os.environ.items() if not k.startswith("PYTHON")}

    result = subprocess.run(
        [str(executable), "--help"],
        env={**env, "PATH": system_path},
        cwd=tmp_path,
        capture_output=True,
        text=True,
        timeout=60,
    )

    assert result.returncode == 0, result.stderr
    assert "bastide-backend" in result.stdout
