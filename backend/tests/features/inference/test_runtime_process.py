"""Tests for supervising the downloaded `llama-server`.

Most use a fake process and a scripted readiness client, so no model is ever loaded; one
starts a real child process (a tiny HTTP server standing in for `llama-server`) to check
the launch, the readiness probe and the stop against an actual process.
"""

import asyncio
import json
import subprocess
import sys
import textwrap
from collections.abc import Coroutine, Sequence
from pathlib import Path
from typing import IO, Any

import httpx
import pytest

from app.features.inference.client import (
    HttpInferenceClient,
    InferenceProtocolError,
    InferenceUnavailable,
)
from app.features.inference.runtime_install import RuntimeInstaller
from app.features.inference.runtime_manifest import RuntimeBuild
from app.features.inference.runtime_process import (
    ManagedRuntime,
    ManagedRuntimeClient,
    Process,
)
from tests.features.inference.test_runtime_install import MODEL_FILE, ZIP_BUILD


def _run[T](coro: Coroutine[Any, Any, T]) -> T:
    return asyncio.run(coro)


def _installed(root: Path, build: RuntimeBuild = ZIP_BUILD) -> RuntimeInstaller:
    """An installer whose server and model are already in place."""
    installer = RuntimeInstaller(root, build, model=MODEL_FILE)
    assert installer.server_path is not None
    installer.server_path.parent.mkdir(parents=True)
    installer.server_path.write_bytes(b"server")
    installer.model_path.parent.mkdir(parents=True)
    installer.model_path.write_bytes(b"model")
    return installer


class FakeProcess:
    """A process that runs until told otherwise."""

    def __init__(self, *, exit_code: int | None = None, ignores_terminate: bool = False) -> None:
        self.exit_code = exit_code
        self.ignores_terminate = ignores_terminate
        self.terminated = False
        self.killed = False

    def poll(self) -> int | None:
        return self.exit_code

    def terminate(self) -> None:
        self.terminated = True
        if not self.ignores_terminate:
            self.exit_code = 0

    def kill(self) -> None:
        self.killed = True
        self.exit_code = -9

    def wait(self, timeout: float | None = None) -> int:
        if self.exit_code is None:
            raise subprocess.TimeoutExpired("llama-server", timeout or 0)
        return self.exit_code


class Launches:
    """Records each launch and hands out the next fake process."""

    def __init__(self, *processes: FakeProcess) -> None:
        self._processes = list(processes) or [FakeProcess()]
        self.commands: list[list[str]] = []

    def __call__(self, command: Sequence[str], log: IO[bytes], cwd: Path) -> Process:
        self.commands.append(list(command))
        return self._processes[min(len(self.commands), len(self._processes)) - 1]


class ScriptedClient:
    """Answers `list_models` with a 503 a set number of times, then with the model."""

    def __init__(self, loading_polls: int = 0) -> None:
        self.loading_polls = loading_polls
        self.base_urls: list[str] = []

    def __call__(self, base_url: str) -> ScriptedClient:
        self.base_urls.append(base_url)
        return self

    async def list_models(self) -> list[str]:
        if self.loading_polls > 0:
            self.loading_polls -= 1
            raise InferenceProtocolError("The inference runtime returned HTTP 503.")
        return ["gemma-4-e4b-it"]

    async def complete(self, *args: Any, **kwargs: Any) -> str:  # pragma: no cover
        raise AssertionError("not used")


def _runtime(
    tmp_path: Path,
    launches: Launches,
    client: ScriptedClient | None = None,
    *,
    installer: RuntimeInstaller | None = None,
    ready_timeout: float = 5.0,
) -> ManagedRuntime:
    return ManagedRuntime(
        installer or _installed(tmp_path / "runtime"),
        tmp_path / "logs" / "llama-server.log",
        ready_timeout=ready_timeout,
        launcher=launches,
        client_factory=client or ScriptedClient(),
        port_picker=lambda: 41234,
    )


def test_starts_the_server_on_loopback_and_waits_for_the_model(tmp_path: Path) -> None:
    launches = Launches()
    client = ScriptedClient(loading_polls=2)
    runtime = _runtime(tmp_path, launches, client)

    base_url = _run(runtime.ensure_running())

    assert base_url == "http://127.0.0.1:41234/v1"
    assert runtime.running
    assert client.loading_polls == 0
    [command] = launches.commands
    assert command[command.index("--host") + 1] == "127.0.0.1"
    assert command[command.index("--port") + 1] == "41234"
    assert command[command.index("--alias") + 1] == "gemma-4-e4b-it"
    assert command[command.index("--model") + 1].endswith("model.gguf")
    # Nothing beyond the API, and nothing fetched from the network.
    assert {"--no-webui", "--offline", "--no-mmproj"} <= set(command)
    assert (tmp_path / "logs" / "llama-server.log").exists()


def test_a_running_server_is_reused(tmp_path: Path) -> None:
    launches = Launches()
    runtime = _runtime(tmp_path, launches)

    _run(runtime.ensure_running())
    _run(runtime.ensure_running())

    assert len(launches.commands) == 1


def test_concurrent_callers_share_one_start(tmp_path: Path) -> None:
    launches = Launches()
    runtime = _runtime(tmp_path, launches, ScriptedClient(loading_polls=1))

    async def both() -> tuple[str, str]:
        return await asyncio.gather(runtime.ensure_running(), runtime.ensure_running())

    first, second = _run(both())

    assert first == second
    assert len(launches.commands) == 1


def test_nothing_starts_when_the_runtime_is_not_installed(tmp_path: Path) -> None:
    launches = Launches()
    installer = RuntimeInstaller(tmp_path / "runtime", ZIP_BUILD, model=MODEL_FILE)
    runtime = _runtime(tmp_path, launches, installer=installer)

    with pytest.raises(InferenceUnavailable, match="not installed"):
        _run(runtime.ensure_running())

    assert launches.commands == []


def test_a_server_that_exits_during_startup_is_reported(tmp_path: Path) -> None:
    launches = Launches(FakeProcess(exit_code=1))
    runtime = _runtime(tmp_path, launches)

    with pytest.raises(InferenceUnavailable, match="code 1"):
        _run(runtime.ensure_running())

    assert not runtime.running


def test_a_model_that_never_loads_times_out_and_is_stopped(tmp_path: Path) -> None:
    process = FakeProcess()
    runtime = _runtime(
        tmp_path, Launches(process), ScriptedClient(loading_polls=1000), ready_timeout=0.2
    )

    with pytest.raises(InferenceUnavailable, match="in time"):
        _run(runtime.ensure_running())

    assert process.terminated
    assert not runtime.running


def test_a_server_that_died_is_started_again(tmp_path: Path) -> None:
    first, second = FakeProcess(), FakeProcess()
    launches = Launches(first, second)
    runtime = _runtime(tmp_path, launches)

    _run(runtime.ensure_running())
    first.exit_code = 139
    _run(runtime.ensure_running())

    assert len(launches.commands) == 2
    assert runtime.running


def test_stop_terminates_the_server(tmp_path: Path) -> None:
    process = FakeProcess()
    runtime = _runtime(tmp_path, Launches(process))
    _run(runtime.ensure_running())

    runtime.stop()
    runtime.stop()

    assert process.terminated
    assert not process.killed
    assert not runtime.running


def test_stop_kills_a_server_that_ignores_terminate(tmp_path: Path) -> None:
    process = FakeProcess(ignores_terminate=True)
    runtime = _runtime(tmp_path, Launches(process))
    _run(runtime.ensure_running())

    runtime.stop()

    assert process.killed


def test_stopping_a_runtime_never_started_does_nothing(tmp_path: Path) -> None:
    _runtime(tmp_path, Launches()).stop()


def test_the_client_starts_the_runtime_and_asks_for_its_own_model(tmp_path: Path) -> None:
    runtime = _runtime(tmp_path, Launches())
    sent: list[dict[str, Any]] = []

    def handle(request: httpx.Request) -> httpx.Response:
        if request.url.path.endswith("/models"):
            return httpx.Response(200, json={"data": [{"id": "gemma-4-e4b-it"}]})
        sent.append(json.loads(request.content))
        return httpx.Response(200, json={"choices": [{"message": {"content": "{}"}}]})

    client = ManagedRuntimeClient(
        runtime,
        client_factory=lambda url: HttpInferenceClient(url, transport=httpx.MockTransport(handle)),
    )

    assert _run(client.list_models()) == ["gemma-4-e4b-it"]
    reply = _run(client.complete([{"role": "user", "content": "hi"}], model="whatever:tag"))

    assert reply == "{}"
    assert sent[0]["model"] == "gemma-4-e4b-it"


def test_the_client_reports_an_absent_runtime_as_unavailable(tmp_path: Path) -> None:
    installer = RuntimeInstaller(tmp_path / "runtime", ZIP_BUILD, model=MODEL_FILE)
    client = ManagedRuntimeClient(_runtime(tmp_path, Launches(), installer=installer))

    with pytest.raises(InferenceUnavailable):
        _run(client.list_models())


# A stand-in for `llama-server`: serves `/v1/models` on the `--port` it is given, and
# answers 503 for its first request the way the real one does while the model loads.
_FAKE_SERVER = textwrap.dedent(
    """
    import json, sys
    from http.server import BaseHTTPRequestHandler, HTTPServer

    port = int(sys.argv[sys.argv.index("--port") + 1])
    alias = sys.argv[sys.argv.index("--alias") + 1]
    state = {"requests": 0}

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            state["requests"] += 1
            loading = state["requests"] == 1
            body = json.dumps({"data": [] if loading else [{"id": alias}]}).encode()
            self.send_response(503 if loading else 200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, *args):
            print("request", flush=True)

    HTTPServer(("127.0.0.1", port), Handler).serve_forever()
    """
)


def test_a_real_child_process_is_started_probed_and_stopped(tmp_path: Path) -> None:
    script = tmp_path / "fake_llama_server.py"
    script.write_text(_FAKE_SERVER)
    started: list[subprocess.Popen[bytes]] = []

    def launch(command: Sequence[str], log: IO[bytes], cwd: Path) -> Process:
        # The installed "server" is a placeholder file; run the stand-in script in its
        # place with the arguments the supervisor built.
        process = subprocess.Popen(
            [sys.executable, str(script), *command[1:]],
            stdin=subprocess.DEVNULL,
            stdout=log,
            stderr=subprocess.STDOUT,
            cwd=cwd,
        )
        started.append(process)
        return process

    runtime = ManagedRuntime(
        _installed(tmp_path / "runtime"),
        tmp_path / "logs" / "llama-server.log",
        ready_timeout=20.0,
        launcher=launch,
    )
    try:
        base_url = _run(runtime.ensure_running())
        assert _run(HttpInferenceClient(base_url).list_models()) == ["gemma-4-e4b-it"]
    finally:
        runtime.stop()

    [process] = started
    assert process.poll() is not None
    assert "request" in (tmp_path / "logs" / "llama-server.log").read_text()
