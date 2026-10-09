"""Where the sidecar's logs go when it runs as a process.

Stdout is reserved for the handshake line the desktop app reads (`READY <port> <version>`),
so every log record goes to stderr instead, uvicorn's included.
"""

import logging
import sys

LOG_FORMAT = "%(asctime)s %(levelname)s %(name)s: %(message)s"


def configure_logging(level: int = logging.INFO) -> None:
    """Send every log record to stderr, replacing whatever handlers the root logger had."""
    root = logging.getLogger()
    for handler in root.handlers[:]:
        root.removeHandler(handler)
    handler = logging.StreamHandler(sys.stderr)
    handler.setFormatter(logging.Formatter(LOG_FORMAT))
    root.addHandler(handler)
    root.setLevel(level)
