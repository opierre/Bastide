"""Command-line entry point: how the desktop app (or a developer) starts the sidecar.

Runs uvicorn programmatically rather than through its CLI, so a frozen build needs no
`uvicorn` executable and the startup sequence stays in one place the app controls.
"""

import argparse
import ipaddress
import os
import socket
from collections.abc import Sequence
from pathlib import Path

import uvicorn

DEFAULT_PORT = 8765


def parse_args(argv: Sequence[str] | None = None) -> argparse.Namespace:
    """Parse the command line; `--port 0` asks the OS for a free port."""
    parser = argparse.ArgumentParser(prog="bastide-backend", description="Bastide sidecar.")
    parser.add_argument("--host", default="127.0.0.1", type=_loopback_host)
    parser.add_argument("--port", default=DEFAULT_PORT, type=_port)
    parser.add_argument(
        "--data-dir",
        type=Path,
        help="Folder for the database (default: the OS user's local data dir).",
    )
    return parser.parse_args(argv)


def _loopback_host(value: str) -> str:
    """Accept only a loopback address: the sidecar holds finances and has no TLS."""
    if value == "localhost":
        return value
    try:
        if ipaddress.ip_address(value).is_loopback:
            return value
    except ValueError:
        pass
    raise argparse.ArgumentTypeError(f"{value!r} is not a loopback address")


def _port(value: str) -> int:
    port = int(value)
    if not 0 <= port <= 65535:
        raise argparse.ArgumentTypeError(f"{value!r} is not a port number")
    return port


def bind(host: str, port: int) -> socket.socket:
    """Bind the listening socket ourselves, so the port the OS picked for `0` is known."""
    family = socket.AF_INET6 if ":" in host else socket.AF_INET
    sock = socket.socket(family, socket.SOCK_STREAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    sock.bind((host, port))
    sock.set_inheritable(True)
    return sock


def main(argv: Sequence[str] | None = None) -> int:
    """Start the sidecar and serve until stopped; returns the process exit code."""
    args = parse_args(argv)
    if args.data_dir is not None:
        # Settings are read from the environment, and the database engine is built when
        # `app.core.db` is first imported, so this must happen before importing the app.
        os.environ["BASTIDE_DB_PATH"] = str(args.data_dir / "bastide.db")

    from app.core.config import get_settings
    from app.core.schema import migrate
    from app.main import create_app

    migrate(Path(get_settings().db_path))
    sock = bind(args.host, args.port)
    server = uvicorn.Server(uvicorn.Config(create_app(), access_log=False))
    server.run(sockets=[sock])
    return 0
