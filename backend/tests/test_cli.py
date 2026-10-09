"""Tests for the `bastide-backend` command line."""

import socket
from pathlib import Path
from unittest.mock import patch

import pytest

from app import cli
from app.core.config import get_settings


def test_defaults_to_loopback_on_the_dev_port() -> None:
    args = cli.parse_args([])

    assert args.host == "127.0.0.1"
    assert args.port == cli.DEFAULT_PORT
    assert args.data_dir is None


def test_accepts_port_zero_and_a_data_dir(tmp_path: Path) -> None:
    args = cli.parse_args(["--port", "0", "--data-dir", str(tmp_path)])

    assert args.port == 0
    assert args.data_dir == tmp_path


@pytest.mark.parametrize("host", ["127.0.0.1", "127.0.0.2", "::1", "localhost"])
def test_accepts_loopback_hosts(host: str) -> None:
    assert cli.parse_args(["--host", host]).host == host


@pytest.mark.parametrize("host", ["0.0.0.0", "192.168.1.10", "example.com"])
def test_refuses_to_bind_beyond_loopback(host: str) -> None:
    with pytest.raises(SystemExit):
        cli.parse_args(["--host", host])


@pytest.mark.parametrize("port", ["-1", "65536", "http"])
def test_refuses_a_bad_port(port: str) -> None:
    with pytest.raises(SystemExit):
        cli.parse_args(["--port", port])


def test_binding_port_zero_gets_a_free_port() -> None:
    sock = cli.bind("127.0.0.1", 0)
    try:
        assert sock.getsockname()[1] > 0
        assert sock.type == socket.SOCK_STREAM
    finally:
        sock.close()


def test_main_migrates_the_data_dir_then_serves_on_the_bound_socket(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    # Registered so the variable `main` sets is restored after the test.
    monkeypatch.setenv("BASTIDE_DB_PATH", str(tmp_path / "other.db"))
    get_settings.cache_clear()
    try:
        with (
            patch.object(cli, "configure_logging"),
            patch("app.core.schema.migrate") as migrate,
            patch.object(cli.uvicorn.Server, "run") as run,
        ):
            exit_code = cli.main(["--port", "0", "--data-dir", str(tmp_path)])
    finally:
        get_settings.cache_clear()

    assert exit_code == 0
    migrate.assert_called_once_with(tmp_path / "bastide.db")
    [sock] = run.call_args.kwargs["sockets"]
    assert sock.getsockname()[0] == "127.0.0.1"
    sock.close()
