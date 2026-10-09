"""Where the sidecar's logs go when it runs as a process.

Stdout is reserved for the handshake line the desktop app reads (`READY <port> <version>`),
so every log record goes to stderr instead, uvicorn's included. A packaged app has no
console, so the same records also go to a rotating file the user can attach to a bug report.

Log messages carry counts, ids and paths, never transaction data: no access log (request
lines carry record ids and filters), and SQL parameters are hidden (`app.core.db`).
"""

import logging
import sys
from logging.handlers import RotatingFileHandler
from pathlib import Path

LOG_FORMAT = "%(asctime)s %(levelname)s %(name)s: %(message)s"
LOG_FILE_NAME = "backend.log"
LOG_FILE_MAX_BYTES = 1_000_000
#: Rotated files kept beside the current one: `backend.log.1` … `backend.log.3`.
LOG_FILE_BACKUPS = 3


def configure_logging(
    log_dir: Path | None = None,
    level: int = logging.INFO,
    max_bytes: int = LOG_FILE_MAX_BYTES,
) -> None:
    """Send every log record to stderr and, given `log_dir`, to a rotating file in it.

    Replaces whatever handlers the root logger had.
    """
    root = logging.getLogger()
    for handler in root.handlers[:]:
        root.removeHandler(handler)
        handler.close()
    handlers: list[logging.Handler] = [logging.StreamHandler(sys.stderr)]
    if log_dir is not None:
        log_dir.mkdir(parents=True, exist_ok=True)
        handlers.append(
            RotatingFileHandler(
                log_dir / LOG_FILE_NAME,
                maxBytes=max_bytes,
                backupCount=LOG_FILE_BACKUPS,
                encoding="utf-8",
            )
        )
    formatter = logging.Formatter(LOG_FORMAT)
    for handler in handlers:
        handler.setFormatter(formatter)
        root.addHandler(handler)
    root.setLevel(level)
