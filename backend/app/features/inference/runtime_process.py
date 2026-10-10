"""Starting, watching and stopping the downloaded `llama-server`.

The backend supervises it the way the desktop app supervises the backend: loopback only, a
free port picked per launch, logs to a file rather than a pipe nobody reads, and stopped
with its parent. It starts lazily, on the first request that needs a model, so the 5 GB the
model takes in memory are only spent by someone using AI, and it is stopped when the
backend shuts down.

How it dies with the app when nothing shuts down cleanly:

- Windows: the desktop app puts the backend in a kill-on-close Job Object, and a child
  inherits its parent's job, so killing the app kills `llama-server` too.
- Linux: `PR_SET_PDEATHSIG` has the kernel signal it when the backend dies.
- macOS has no equivalent; a backend killed outright leaves it running until the user
  quits it. A graceful exit, including the parent closing stdin, still stops it.
"""

import asyncio
import contextlib
import ctypes
import logging
import signal
import socket
import subprocess
import sys
import time
from collections.abc import Callable, Sequence
from pathlib import Path
from typing import IO, Any, Protocol

from app.features.inference.client import (
    HttpInferenceClient,
    InferenceClient,
    InferenceError,
    InferenceUnavailable,
    Message,
)
from app.features.inference.runtime_install import RuntimeInstaller
from app.features.inference.runtime_manifest import MODEL_ALIAS

logger = logging.getLogger(__name__)

#: Long enough for a 5 GB model to come off a slow disk into memory on a modest machine.
DEFAULT_READY_TIMEOUT_S = 180.0

# Categorization prompts are one batch of rows plus the category list; 8k tokens holds that
# with room to spare, where the model's own default context would reserve gigabytes of KV
# cache for nothing.
_CONTEXT_TOKENS = 8192
_POLL_INTERVAL_S = 0.5
_STOP_GRACE_S = 5.0


class Process(Protocol):
    """The slice of `subprocess.Popen` the supervisor uses; faked in tests."""

    def poll(self) -> int | None: ...
    def terminate(self) -> None: ...
    def kill(self) -> None: ...
    def wait(self, timeout: float | None = None) -> int: ...


type Launcher = Callable[[Sequence[str], IO[bytes], Path], Process]
type ClientFactory = Callable[[str], InferenceClient]


class ManagedRuntime:
    """One `llama-server`, started on demand from what `RuntimeInstaller` put on disk."""

    def __init__(
        self,
        installer: RuntimeInstaller,
        log_path: Path,
        *,
        ready_timeout: float = DEFAULT_READY_TIMEOUT_S,
        launcher: Launcher | None = None,
        client_factory: ClientFactory = HttpInferenceClient,
        port_picker: Callable[[], int] | None = None,
    ) -> None:
        """Build a supervisor.

        Args:
            installer: where the server and model are, and whether they are there.
            log_path: the file the server's output goes to, rewritten at each start.
            ready_timeout: seconds to wait for the model to load before giving up.
            launcher: starts the process; injected in tests so nothing is spawned.
            client_factory: builds the client the readiness probe speaks through.
            port_picker: chooses the loopback port; injected in tests.
        """
        self._installer = installer
        self._log_path = log_path
        self._ready_timeout = ready_timeout
        self._launcher = launcher or _launch
        self._client_factory = client_factory
        self._port_picker = port_picker or _free_port
        self._lock = asyncio.Lock()
        self._process: Process | None = None
        self._base_url: str | None = None

    @property
    def running(self) -> bool:
        """Whether a server this supervisor started is still alive."""
        return self._process is not None and self._process.poll() is None

    async def ensure_running(self) -> str:
        """Start the server unless it already runs, and return its `/v1` base URL.

        Concurrent callers wait for the same start rather than each launching a server.

        Raises:
            InferenceUnavailable: the runtime is not installed, the server exited during
                startup, or the model did not load within the ready timeout.
        """
        async with self._lock:
            if self.running and self._base_url is not None:
                return self._base_url
            self._reap()

            server = self._installer.server_path
            if server is None or not self._installer.is_installed():
                raise InferenceUnavailable("The local runtime is not installed.")

            port = self._port_picker()
            base_url = f"http://127.0.0.1:{port}/v1"
            self._log_path.parent.mkdir(parents=True, exist_ok=True)
            with self._log_path.open("wb") as log:
                # The child keeps its own handle on the log; ours can close at once.
                process = self._launcher(self._command(server, port), log, server.parent)
            self._process = process
            logger.info("Started the local runtime on port %d.", port)

            try:
                await self._wait_until_ready(process, base_url)
            except InferenceUnavailable:
                self._stop_process()
                raise
            self._base_url = base_url
            return base_url

    def stop(self) -> None:
        """Stop the server if it runs. Safe to call at any time, and more than once."""
        self._stop_process()

    def _command(self, server: Path, port: int) -> list[str]:
        return [
            str(server),
            "--model",
            str(self._installer.model_path),
            "--host",
            "127.0.0.1",
            "--port",
            str(port),
            "--alias",
            MODEL_ALIAS,
            "--ctx-size",
            str(_CONTEXT_TOKENS),
            "--parallel",
            "1",
            # Nothing but the API this app calls: no browser UI on the port, and no model
            # or projector fetched from the network behind the user's back.
            "--no-webui",
            "--offline",
            "--no-mmproj",
        ]

    async def _wait_until_ready(self, process: Process, base_url: str) -> None:
        """Poll `/v1/models` until the model has loaded (the server answers 503 until then)."""
        client = self._client_factory(base_url)
        deadline = time.monotonic() + self._ready_timeout
        while True:
            if (code := process.poll()) is not None:
                raise InferenceUnavailable(
                    f"The local runtime exited during startup (code {code}); "
                    f"see {self._log_path.name}."
                )
            try:
                await client.list_models()
                return
            except InferenceError:
                pass
            if time.monotonic() >= deadline:
                raise InferenceUnavailable("The local runtime did not load its model in time.")
            await asyncio.sleep(_POLL_INTERVAL_S)

    def _reap(self) -> None:
        """Forget a server that has exited on its own, so the next call starts another."""
        if self._process is not None and self._process.poll() is not None:
            logger.warning("The local runtime exited (code %s).", self._process.poll())
            self._process = None
            self._base_url = None

    def _stop_process(self) -> None:
        process, self._process, self._base_url = self._process, None, None
        if process is None or process.poll() is not None:
            return
        process.terminate()
        try:
            process.wait(_STOP_GRACE_S)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(_STOP_GRACE_S)
        logger.info("Stopped the local runtime.")


class ManagedRuntimeClient:
    """`InferenceClient` for the downloaded runtime: starts it, then talks to it over HTTP.

    The model argument is replaced by the alias the server was started with: it serves one
    model, and that is its name whatever tag the caller holds.
    """

    def __init__(
        self, runtime: ManagedRuntime, *, client_factory: ClientFactory = HttpInferenceClient
    ) -> None:
        """Build a client; `client_factory` is injected in tests so nothing leaves."""
        self._runtime = runtime
        self._client_factory = client_factory

    async def list_models(self) -> list[str]:
        """Start the runtime if needed, then list what it serves."""
        base_url = await self._runtime.ensure_running()
        return await self._client_factory(base_url).list_models()

    async def complete(
        self,
        messages: Sequence[Message],
        *,
        model: str,
        response_format: dict[str, Any] | None = None,
        timeout: float | None = None,
    ) -> str:
        """Start the runtime if needed, then run one completion on its model."""
        base_url = await self._runtime.ensure_running()
        return await self._client_factory(base_url).complete(
            messages, model=MODEL_ALIAS, response_format=response_format, timeout=timeout
        )


def _free_port() -> int:
    """A loopback port nothing listens on right now.

    The server binds it a moment later, so another process could take it in between; the
    server then exits at startup, which `ensure_running` reports, and the next call picks
    another port.
    """
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as probe:
        probe.bind(("127.0.0.1", 0))
        return probe.getsockname()[1]


def _launch(command: Sequence[str], log: IO[bytes], cwd: Path) -> Process:
    """Start the server detached from our stdin and console, its output in `log`."""
    options: dict[str, Any] = {}
    if sys.platform == "win32":
        # `llama-server.exe` is a console program: without this, Windows opens a console
        # window for it in front of the app.
        options["creationflags"] = subprocess.CREATE_NO_WINDOW
    elif sys.platform.startswith("linux"):
        options["preexec_fn"] = _die_with_parent
    return subprocess.Popen(
        command,
        stdin=subprocess.DEVNULL,
        stdout=log,
        stderr=subprocess.STDOUT,
        cwd=cwd,
        **options,
    )


def _die_with_parent() -> None:  # pragma: no cover — runs in the forked child, Linux only.
    """Ask the kernel to SIGTERM this child when the backend dies, however it dies."""
    pr_set_pdeathsig = 1
    with contextlib.suppress(OSError, AttributeError):
        ctypes.CDLL("libc.so.6", use_errno=True).prctl(pr_set_pdeathsig, signal.SIGTERM)
