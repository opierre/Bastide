"""Starting the sidecar as a real process, the way the desktop app does."""

import os
import subprocess
import sys
import threading
from pathlib import Path
from queue import Empty, Queue
from typing import IO

BACKEND_DIR = Path(__file__).resolve().parent.parent

#: Startup migrates a fresh database, which takes a few seconds on a slow CI runner.
STARTUP_TIMEOUT = 60.0


def start(data_dir: Path, *args: str, env: dict[str, str] | None = None) -> subprocess.Popen[str]:
    """Run `python -m app --port 0 --data-dir <data_dir>` with piped stdin and stdout.

    The `BASTIDE_*` variables of the test process are dropped, so the child sees only what
    the test passes.
    """
    child_env = {k: v for k, v in os.environ.items() if not k.startswith("BASTIDE_")}
    child_env.update(env or {})
    return subprocess.Popen(
        [sys.executable, "-m", "app", "--port", "0", "--data-dir", str(data_dir), *args],
        cwd=BACKEND_DIR,
        env=child_env,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
    )


def read_line(stream: IO[str], timeout: float = STARTUP_TIMEOUT) -> str | None:
    """The next line of `stream`, or None if none arrives in time or the stream ends.

    Read on a thread because a pipe can't be polled with a timeout on Windows.
    """
    lines: Queue[str] = Queue()
    threading.Thread(target=lambda: lines.put(stream.readline()), daemon=True).start()
    try:
        return lines.get(timeout=timeout) or None
    except Empty:
        return None


def stop(process: subprocess.Popen[str]) -> None:
    """Kill the process if it is still running, and release its pipes."""
    if process.poll() is None:
        process.kill()
    process.communicate(timeout=10)
