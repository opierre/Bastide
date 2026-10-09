"""Starting the sidecar as a real process, the way the desktop app does."""

import os
import subprocess
import sys
import threading
from collections.abc import Sequence
from pathlib import Path
from queue import Empty, Queue
from typing import IO

BACKEND_DIR = Path(__file__).resolve().parent.parent

#: Startup migrates a fresh database, which takes a few seconds on a slow CI runner.
STARTUP_TIMEOUT = 60.0


#: The backend run from source, with the interpreter running the tests.
SOURCE_COMMAND = (sys.executable, "-m", "app")


def start(
    data_dir: Path,
    *args: str,
    env: dict[str, str] | None = None,
    command: Sequence[str] = SOURCE_COMMAND,
    cwd: Path = BACKEND_DIR,
) -> subprocess.Popen[str]:
    """Run `<command> --port 0 --data-dir <data_dir>` in `cwd`, with piped stdin and stdout.

    `command` defaults to `python -m app`; a frozen build passes its executable instead.

    Stderr goes to `stderr_log(data_dir)` rather than a pipe: nothing reads it while the test
    runs, and a full pipe would block the backend's next log call. The `BASTIDE_*` variables
    of the test process are dropped, so the child sees only what the test passes.
    """
    child_env = {k: v for k, v in os.environ.items() if not k.startswith("BASTIDE_")}
    child_env.update(env or {})
    # The child gets its own handle on the file, so this one can close right away.
    with stderr_log(data_dir).open("w", encoding="utf-8") as stderr:
        return subprocess.Popen(
            [*command, "--port", "0", "--data-dir", str(data_dir), *args],
            cwd=cwd,
            env=child_env,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=stderr,
            text=True,
            encoding="utf-8",
        )


def stderr_log(data_dir: Path) -> Path:
    """Where `start` writes the backend's stderr."""
    return data_dir.parent / f"{data_dir.name}-stderr.log"


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
