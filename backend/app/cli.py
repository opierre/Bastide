"""Command-line entry point: how the desktop app (or a developer) starts the sidecar.

Runs uvicorn programmatically rather than through its CLI, so a frozen build needs no
`uvicorn` executable and the startup sequence stays in one place the app controls.
"""

import argparse
import ipaddress
import logging
import os
import socket
import sys
import threading
from collections.abc import Sequence
from pathlib import Path
from typing import IO

import uvicorn

from app import __version__
from app.core.logs import configure_logging

logger = logging.getLogger(__name__)

DEFAULT_PORT = 8765

#: Exit code when the database is newer than this build. Distinct from uvicorn's own (3) and
#: from argparse's (2), so the desktop app can tell the user what happened.
EXIT_SCHEMA_TOO_NEW = 10


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
    parser.add_argument(
        "--exit-on-stdin-close",
        action="store_true",
        help="Shut down when stdin closes, i.e. when the app that started the backend exits.",
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


class _Server(uvicorn.Server):
    """A uvicorn server that announces itself on stdout once it accepts requests."""

    async def startup(self, sockets: list[socket.socket] | None = None) -> None:
        await super().startup(sockets=sockets)
        if self.started and sockets:
            announce_ready(sockets[0].getsockname()[1])


def announce_ready(port: int) -> None:
    """Print the handshake line the desktop app waits for: `READY <port> <version>`.

    Flushed at once: stdout is a pipe there, which Python buffers until it fills.
    """
    print(f"READY {port} {__version__}", flush=True)


def watch_stdin(server: uvicorn.Server, stdin: IO[bytes]) -> threading.Thread:
    """Shut the server down gracefully once `stdin` reaches end of file.

    The desktop app holds the write end of the pipe and never writes to it. When the app exits
    or crashes, the OS closes that end, and the read here returns. Opt-in, because a backend
    started from an IDE or a script may have no stdin at all.
    """

    def _watch() -> None:
        while stdin.read(4096):
            pass
        server.should_exit = True
        logger.info("Stdin closed: the parent process is gone, shutting down.")

    thread = threading.Thread(target=_watch, name="stdin-watcher", daemon=True)
    thread.start()
    return thread


def report_fatal(code: str) -> None:
    """Print `FATAL <code>` on stderr: a line the desktop app parses and shows translated."""
    print(f"FATAL {code}", file=sys.stderr, flush=True)


def main(argv: Sequence[str] | None = None) -> int:
    """Start the sidecar and serve until stopped; returns the process exit code."""
    args = parse_args(argv)
    configure_logging()
    if args.data_dir is not None:
        # Settings are read from the environment, and the database engine is built when
        # `app.core.db` is first imported, so this must happen before importing the app.
        os.environ["BASTIDE_DB_PATH"] = str(args.data_dir / "bastide.db")

    from app.core.config import get_settings
    from app.core.schema import SchemaTooNewError, migrate
    from app.main import create_app

    try:
        migrate(Path(get_settings().db_path))
    except SchemaTooNewError as error:
        logger.error("%s", error)
        report_fatal("DATABASE_SCHEMA_TOO_NEW")
        return EXIT_SCHEMA_TOO_NEW
    sock = bind(args.host, args.port)
    # No uvicorn log config: its records reach the root logger's stderr handler. No access
    # log either, since request paths carry record ids.
    server = _Server(uvicorn.Config(create_app(), log_config=None, access_log=False))
    if args.exit_on_stdin_close:
        watch_stdin(server, sys.stdin.buffer)
    server.run(sockets=[sock])
    return 0
