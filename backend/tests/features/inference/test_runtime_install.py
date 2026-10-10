"""Tests for downloading and installing the local runtime, with HTTP mocked throughout.

The pinned files here are small stand-ins built by each test, with their real hashes: what
is under test is the download, resume and verification logic, not the published artifacts.
"""

import hashlib
import io
import tarfile
import threading
import zipfile
from collections.abc import Callable, Iterator
from pathlib import Path
from unittest.mock import patch

import httpx
import pytest
from fastapi.testclient import TestClient

from app.features.inference.router import get_runtime_installer
from app.features.inference.runtime_install import (
    RuntimeBusyError,
    RuntimeInstaller,
    RuntimeUnsupportedError,
)
from app.features.inference.runtime_manifest import (
    LLAMA_CPP_BUILD,
    MODEL,
    RUNTIME_BUILDS,
    PinnedFile,
    RuntimeBuild,
    platform_key,
)
from tests.api import register as _register

ARCHIVE_URL = "https://example.test/llama.zip"
MODEL_URL = "https://example.test/model.gguf"
MODEL_BYTES = b"GGUF" + bytes(range(256)) * 64

type Handler = Callable[[httpx.Request], httpx.Response]


def _pinned(url: str, filename: str, content: bytes) -> PinnedFile:
    return PinnedFile(
        url=url, filename=filename, size=len(content), sha256=hashlib.sha256(content).hexdigest()
    )


def _zip(members: dict[str, bytes]) -> bytes:
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w") as bundle:
        for name, data in members.items():
            bundle.writestr(name, data)
    return buffer.getvalue()


def _tar(members: dict[str, bytes]) -> bytes:
    buffer = io.BytesIO()
    with tarfile.open(fileobj=buffer, mode="w:gz") as bundle:
        for name, data in members.items():
            info = tarfile.TarInfo(name)
            info.size = len(data)
            info.mode = 0o755
            bundle.addfile(info, io.BytesIO(data))
    return buffer.getvalue()


ZIP_BYTES = _zip({"llama-server.exe": b"MZ server", "ggml.dll": b"MZ lib"})
ZIP_BUILD = RuntimeBuild(
    archive=_pinned(ARCHIVE_URL, "llama.zip", ZIP_BYTES), kind="zip", server="llama-server.exe"
)
MODEL_FILE = _pinned(MODEL_URL, "model.gguf", MODEL_BYTES)


def _serve(files: dict[str, bytes]) -> tuple[Handler, list[httpx.Request]]:
    """A handler serving `files` by URL, honouring `Range`, and the requests it saw."""
    seen: list[httpx.Request] = []

    def handle(request: httpx.Request) -> httpx.Response:
        seen.append(request)
        body = files[str(request.url)]
        if (header := request.headers.get("Range")) is not None:
            start = int(header.removeprefix("bytes=").removesuffix("-"))
            return httpx.Response(206, content=body[start:])
        return httpx.Response(200, content=body)

    return handle, seen


def _installer(
    root: Path,
    handler: Handler,
    *,
    build: RuntimeBuild | None = ZIP_BUILD,
    model: PinnedFile = MODEL_FILE,
) -> RuntimeInstaller:
    return RuntimeInstaller(root, build, model=model, transport=httpx.MockTransport(handler))


def _install(installer: RuntimeInstaller) -> None:
    installer.start()
    installer.wait(5)


def test_nothing_on_disk_reports_the_full_size_to_download(tmp_path: Path) -> None:
    handler, seen = _serve({})
    status = _installer(tmp_path, handler).status()

    assert status.state == "absent"
    assert status.total_bytes == len(ZIP_BYTES) + len(MODEL_BYTES)
    assert status.downloaded_bytes == 0
    # Reporting the size is local: nothing is fetched until the user asks.
    assert seen == []


def test_a_verified_download_installs_the_server_and_the_model(tmp_path: Path) -> None:
    handler, _ = _serve({ARCHIVE_URL: ZIP_BYTES, MODEL_URL: MODEL_BYTES})
    installer = _installer(tmp_path, handler)

    _install(installer)

    assert installer.status().state == "installed"
    assert installer.is_installed()
    assert installer.server_path is not None
    assert installer.server_path.read_bytes() == b"MZ server"
    assert installer.model_path.read_bytes() == MODEL_BYTES
    # Neither the archive nor a `.part` is left behind.
    assert list((tmp_path / "downloads").iterdir()) == []


def test_a_tar_build_is_extracted_with_its_folder(tmp_path: Path) -> None:
    server = f"llama-{LLAMA_CPP_BUILD}/llama-server"
    archive = _tar({server: b"\x7fELF server", f"llama-{LLAMA_CPP_BUILD}/libllama.so": b"lib"})
    build = RuntimeBuild(
        archive=_pinned(ARCHIVE_URL, "llama.tar.gz", archive), kind="tar.gz", server=server
    )
    handler, _ = _serve({ARCHIVE_URL: archive, MODEL_URL: MODEL_BYTES})
    installer = _installer(tmp_path, handler, build=build)

    _install(installer)

    assert installer.is_installed()
    assert installer.server_path is not None
    assert installer.server_path.read_bytes() == b"\x7fELF server"


def test_a_file_that_does_not_match_its_hash_is_refused(tmp_path: Path) -> None:
    tampered = MODEL_BYTES[:-1] + b"!"
    handler, _ = _serve({ARCHIVE_URL: ZIP_BYTES, MODEL_URL: tampered})
    installer = _installer(tmp_path, handler)

    _install(installer)

    status = installer.status()
    assert status.state == "failed"
    assert status.error == "hash_mismatch"
    assert not installer.model_path.exists()
    # The refused bytes are deleted, not kept to resume from.
    assert not (tmp_path / "downloads" / "model.gguf.part").exists()
    assert status.downloaded_bytes == 0


def test_a_file_of_the_wrong_size_is_refused(tmp_path: Path) -> None:
    handler, _ = _serve({ARCHIVE_URL: ZIP_BYTES, MODEL_URL: MODEL_BYTES + b"extra"})
    installer = _installer(tmp_path, handler)

    _install(installer)

    assert installer.status().error == "hash_mismatch"
    assert not installer.model_path.exists()


def test_an_interrupted_download_resumes_where_it_stopped(tmp_path: Path) -> None:
    half = len(MODEL_BYTES) // 2
    part = tmp_path / "downloads" / "model.gguf.part"
    part.parent.mkdir(parents=True)
    part.write_bytes(MODEL_BYTES[:half])
    handler, seen = _serve({ARCHIVE_URL: ZIP_BYTES, MODEL_URL: MODEL_BYTES})
    installer = _installer(tmp_path, handler)

    assert installer.status().downloaded_bytes == half
    _install(installer)

    assert installer.model_path.read_bytes() == MODEL_BYTES
    model_requests = [request for request in seen if str(request.url) == MODEL_URL]
    assert [request.headers.get("Range") for request in model_requests] == [f"bytes={half}-"]


def test_a_server_that_ignores_the_range_restarts_the_file(tmp_path: Path) -> None:
    part = tmp_path / "downloads" / "model.gguf.part"
    part.parent.mkdir(parents=True)
    part.write_bytes(MODEL_BYTES[:100])
    files = {ARCHIVE_URL: ZIP_BYTES, MODEL_URL: MODEL_BYTES}

    def no_ranges(request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, content=files[str(request.url)])

    installer = _installer(tmp_path, no_ranges)

    _install(installer)

    assert installer.model_path.read_bytes() == MODEL_BYTES


def test_cancelling_keeps_what_was_fetched_for_the_next_download(tmp_path: Path) -> None:
    release = threading.Event()

    def stream() -> Iterator[bytes]:
        yield MODEL_BYTES[:1000]
        release.wait(5)
        yield MODEL_BYTES[1000:]

    def handle(request: httpx.Request) -> httpx.Response:
        if str(request.url) == ARCHIVE_URL:
            return httpx.Response(200, content=ZIP_BYTES)
        return httpx.Response(200, content=stream())

    installer = _installer(tmp_path, handle)
    installer.start()
    _wait_for(lambda: installer.status().downloaded_bytes >= len(ZIP_BYTES) + 1000)

    # The stream is held mid-file; let it go only once the cancel has been asked for.
    threading.Timer(0.2, release.set).start()
    status = installer.cancel()

    assert status.state == "absent"
    assert status.error is None
    assert status.downloaded_bytes > 0
    assert (tmp_path / "downloads" / "model.gguf.part").is_file()
    assert not installer.model_path.exists()
    # The archive, finished before the cancel, stays installed.
    assert installer.server_path is not None and installer.server_path.is_file()


def test_a_network_failure_is_reported_and_can_be_retried(tmp_path: Path) -> None:
    online = threading.Event()
    serve, _ = _serve({ARCHIVE_URL: ZIP_BYTES, MODEL_URL: MODEL_BYTES})

    def flaky(request: httpx.Request) -> httpx.Response:
        if not online.is_set():
            raise httpx.ConnectError("offline", request=request)
        return serve(request)

    installer = _installer(tmp_path, flaky)
    _install(installer)

    assert installer.status().state == "failed"
    assert installer.status().error == "network"

    online.set()
    _install(installer)

    assert installer.status().state == "installed"
    assert installer.status().error is None


def test_an_error_status_is_a_network_failure(tmp_path: Path) -> None:
    installer = _installer(tmp_path, lambda request: httpx.Response(404))
    _install(installer)

    assert installer.status().error == "network"


def test_a_disk_too_small_is_refused_before_downloading(tmp_path: Path) -> None:
    handler, seen = _serve({ARCHIVE_URL: ZIP_BYTES, MODEL_URL: MODEL_BYTES})
    installer = _installer(tmp_path, handler)

    with patch(
        "app.features.inference.runtime_install.shutil.disk_usage",
        return_value=type("Usage", (), {"free": 10})(),
    ):
        _install(installer)

    assert installer.status().error == "disk_full"
    assert seen == []


def test_an_archive_writing_outside_its_folder_is_refused(tmp_path: Path) -> None:
    evil = _zip({"llama-server.exe": b"MZ", "../../escaped.txt": b"gotcha"})
    build = RuntimeBuild(
        archive=_pinned(ARCHIVE_URL, "llama.zip", evil), kind="zip", server="llama-server.exe"
    )
    handler, _ = _serve({ARCHIVE_URL: evil, MODEL_URL: MODEL_BYTES})
    installer = _installer(tmp_path / "runtime", handler, build=build)

    _install(installer)

    assert installer.status().error == "extract"
    assert not (tmp_path / "escaped.txt").exists()
    assert not installer.is_installed()


def test_starting_twice_runs_one_download(tmp_path: Path) -> None:
    handler, seen = _serve({ARCHIVE_URL: ZIP_BYTES, MODEL_URL: MODEL_BYTES})
    installer = _installer(tmp_path, handler)

    installer.start()
    installer.start()
    installer.wait(5)
    installer.start()  # Installed: nothing left to fetch.
    installer.wait(5)

    assert len(seen) == 2


def test_removing_deletes_everything(tmp_path: Path) -> None:
    handler, _ = _serve({ARCHIVE_URL: ZIP_BYTES, MODEL_URL: MODEL_BYTES})
    installer = _installer(tmp_path / "runtime", handler)
    _install(installer)

    status = installer.remove()

    assert status.state == "absent"
    assert not (tmp_path / "runtime").exists()


def test_removing_during_a_download_is_refused(tmp_path: Path) -> None:
    release = threading.Event()

    def handle(request: httpx.Request) -> httpx.Response:
        release.wait(5)
        return httpx.Response(200, content=ZIP_BYTES)

    installer = _installer(tmp_path, handle)
    installer.start()
    try:
        with pytest.raises(RuntimeBusyError):
            installer.remove()
    finally:
        release.set()
        installer.wait(5)


def test_an_unsupported_platform_cannot_download(tmp_path: Path) -> None:
    handler, _ = _serve({})
    installer = _installer(tmp_path, handler, build=None)

    assert installer.status().state == "unsupported"
    with pytest.raises(RuntimeUnsupportedError):
        installer.start()


@pytest.mark.parametrize(
    ("system", "machine", "key"),
    [
        ("win32", "AMD64", "windows-x64"),
        ("darwin", "arm64", "macos-arm64"),
        ("linux", "x86_64", "linux-x64"),
        ("darwin", "x86_64", None),
        ("win32", "ARM64", None),
    ],
)
def test_the_platform_picks_its_pinned_build(system: str, machine: str, key: str | None) -> None:
    assert platform_key(system, machine) == key


def test_every_pinned_file_carries_a_sha256() -> None:
    for pinned in [MODEL, *(build.archive for build in RUNTIME_BUILDS.values())]:
        assert len(pinned.sha256) == 64
        int(pinned.sha256, 16)
        assert pinned.url.startswith("https://")
        assert pinned.size > 0


def _wait_for(condition: Callable[[], bool], timeout: float = 5.0) -> None:
    done = threading.Event()
    deadline = threading.Timer(timeout, done.set)
    deadline.start()
    try:
        while not condition():
            if done.wait(0.01):
                raise AssertionError("condition not met in time")
    finally:
        deadline.cancel()


# --- API ---------------------------------------------------------------------------------


@pytest.fixture
def api_installer(client: TestClient, tmp_path: Path) -> RuntimeInstaller:
    handler, _ = _serve({ARCHIVE_URL: ZIP_BYTES, MODEL_URL: MODEL_BYTES})
    installer = _installer(tmp_path, handler)
    client.app.dependency_overrides[get_runtime_installer] = lambda: installer
    return installer


def test_the_status_endpoint_reports_the_size_to_download(
    client: TestClient, api_installer: RuntimeInstaller
) -> None:
    headers = _register(client)

    response = client.get("/api/v1/settings/inference/runtime", headers=headers)

    assert response.status_code == 200
    assert response.json() == {
        "state": "absent",
        "downloaded_bytes": 0,
        "total_bytes": len(ZIP_BYTES) + len(MODEL_BYTES),
        "error": None,
        "model_tag": "gemma-4-e4b-it",
    }


def test_downloading_through_the_api_installs_the_runtime(
    client: TestClient, api_installer: RuntimeInstaller
) -> None:
    headers = _register(client)

    response = client.post("/api/v1/settings/inference/runtime/download", headers=headers)
    assert response.status_code == 202
    api_installer.wait(5)

    status = client.get("/api/v1/settings/inference/runtime", headers=headers).json()
    assert status["state"] == "installed"
    assert status["total_bytes"] == 0

    removed = client.delete("/api/v1/settings/inference/runtime", headers=headers)
    assert removed.status_code == 200
    assert removed.json()["state"] == "absent"


def test_cancel_through_the_api_answers_with_the_status(
    client: TestClient, api_installer: RuntimeInstaller
) -> None:
    headers = _register(client)

    response = client.post("/api/v1/settings/inference/runtime/cancel", headers=headers)

    assert response.status_code == 200
    assert response.json()["state"] == "absent"


def test_an_unsupported_platform_is_a_409_with_its_code(client: TestClient, tmp_path: Path) -> None:
    handler, _ = _serve({})
    client.app.dependency_overrides[get_runtime_installer] = lambda: _installer(
        tmp_path, handler, build=None
    )
    headers = _register(client)

    response = client.post("/api/v1/settings/inference/runtime/download", headers=headers)

    assert response.status_code == 409
    assert response.json()["error"]["code"] == "RUNTIME_UNSUPPORTED"


@pytest.mark.parametrize(
    ("method", "path"),
    [
        ("GET", "/runtime"),
        ("POST", "/runtime/download"),
        ("POST", "/runtime/cancel"),
        ("DELETE", "/runtime"),
    ],
)
def test_runtime_endpoints_require_authentication(
    client: TestClient, method: str, path: str
) -> None:
    response = client.request(method, f"/api/v1/settings/inference{path}")
    assert response.status_code == 401
