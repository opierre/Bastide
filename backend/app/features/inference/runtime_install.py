"""Downloading and installing the opt-in local runtime: `llama-server` and its model.

Everything lands under `<data dir>/runtime/`, never beside the app, so an upgrade or a
reinstall of Bastide keeps a 5 GB model the user already waited for. A file is downloaded to a
`.part` beside its destination, hashed as it arrives, and only moved into place once its size
and SHA-256 match the pinned values in `runtime_manifest`; a mismatch deletes it. That makes
"the file is in place" the same statement as "the file is the one the code pins", so being
installed needs no separate record.

The download runs on a plain daemon thread. It is one long, mostly blocking stream that has
nothing to do with the event loop serving requests, and a daemon thread that dies with the
process leaves only a `.part` file behind, which the next download resumes from.
"""

import hashlib
import logging
import shutil
import tarfile
import threading
import zipfile
from dataclasses import dataclass
from pathlib import Path
from typing import Literal

import httpx

from app.core.errors import ConflictError
from app.core.tls import tls_context
from app.features.inference.runtime_manifest import (
    LLAMA_CPP_BUILD,
    MODEL,
    PinnedFile,
    RuntimeBuild,
)

logger = logging.getLogger(__name__)

type InstallState = Literal["unsupported", "absent", "downloading", "installed", "failed"]

#: Why the runtime is not usable. Stable codes the frontend localizes. All but
#: `server_removed` say why the last download stopped short; `server_removed` says that an
#: install which completed has since lost its executable, which in practice is antivirus
#: quarantining it the first time it runs a model.
type InstallError = Literal["network", "hash_mismatch", "disk_full", "extract", "server_removed"]

_CHUNK_BYTES = 1024 * 1024

# A stalled CDN should fail the download, not hang it: no byte for this long is an error the
# user can retry, and the retry resumes where this one stopped.
_TIMEOUT = httpx.Timeout(30.0, connect=10.0)


class RuntimeUnsupportedError(ConflictError):
    """Raised when asked to download on a platform the manifest pins no build for."""

    code = "RUNTIME_UNSUPPORTED"


class RuntimeBusyError(ConflictError):
    """Raised when removing the runtime while it is still being downloaded."""

    code = "RUNTIME_DOWNLOAD_IN_PROGRESS"


@dataclass(frozen=True, slots=True)
class InstallStatus:
    """A snapshot of the install, as the status endpoint reports it.

    `total_bytes` is what still has to be fetched for the runtime to be complete, so it is
    the size to show before the user starts; `downloaded_bytes` is how much of it is already
    on disk, including a `.part` left by an interrupted download.
    """

    state: InstallState
    downloaded_bytes: int = 0
    total_bytes: int = 0
    error: InstallError | None = None


class _Cancelled(Exception):
    """The user cancelled; the `.part` file stays for the next download to resume."""


class _Failed(Exception):
    """A download or install step failed for a reason the user is told about."""

    def __init__(self, error: InstallError) -> None:
        super().__init__(error)
        self.error: InstallError = error


class RuntimeInstaller:
    """Owns `<data dir>/runtime/`: what is there, and the one download that may fill it."""

    def __init__(
        self,
        root: Path,
        build: RuntimeBuild | None,
        *,
        model: PinnedFile = MODEL,
        transport: httpx.BaseTransport | None = None,
    ) -> None:
        """Build an installer.

        Args:
            root: the folder the runtime lives in, `<data dir>/runtime`.
            build: this platform's pinned `llama-server`; `None` where there is none.
            model: the pinned model file.
            transport: injected in tests so no request ever leaves the process.
        """
        self._root = root
        self._build = build
        self._model = model
        self._transport = transport
        self._lock = threading.Lock()
        self._cancel = threading.Event()
        self._thread: threading.Thread | None = None
        self._received = 0
        self._total = 0
        self._error: InstallError | None = None

    @property
    def server_path(self) -> Path | None:
        """Where `llama-server` sits once installed; `None` on an unsupported platform."""
        if self._build is None:
            return None
        return self._server_dir / self._build.server

    @property
    def model_path(self) -> Path:
        """Where the model sits once installed."""
        return self._root / "models" / self._model.filename

    @property
    def model_size(self) -> int:
        """The pinned model's size in bytes."""
        return self._model.size

    def is_installed(self) -> bool:
        """Whether both the server and the model are in place."""
        server = self.server_path
        return server is not None and server.is_file() and self.model_path.is_file()

    def status(self) -> InstallStatus:
        """Report the install as it stands right now."""
        if self._build is None:
            return InstallStatus(state="unsupported")
        with self._lock:
            downloading = self._downloading()
            error = self._error
            received = self._received
            started_total = self._total
        if downloading:
            # Measured against what was missing when the download started: a file that
            # finishes leaves the missing list, but its bytes stay in what was received.
            return InstallStatus(
                state="downloading", downloaded_bytes=received, total_bytes=started_total
            )
        missing = self._missing()
        total = sum(file.size for file in missing)
        if not missing:
            return InstallStatus(state="installed")
        if error is None and self._server_removed():
            error = "server_removed"
        on_disk = sum(self._part_size(file) for file in missing)
        return InstallStatus(
            state="failed" if error is not None else "absent",
            downloaded_bytes=on_disk,
            total_bytes=total,
            error=error,
        )

    def start(self) -> InstallStatus:
        """Start downloading whatever is missing, and return at once.

        Idempotent: while a download runs, or once everything is installed, this changes
        nothing and reports the current status.

        Raises:
            RuntimeUnsupportedError: no build is pinned for this platform.
        """
        if self._build is None:
            raise RuntimeUnsupportedError("No local runtime is available for this platform.")
        with self._lock:
            if not self._downloading() and self._missing():
                self._cancel.clear()
                self._error = None
                missing = self._missing()
                self._received = sum(self._part_size(file) for file in missing)
                self._total = sum(file.size for file in missing)
                self._thread = threading.Thread(
                    target=self._run, name="runtime-download", daemon=True
                )
                self._thread.start()
        return self.status()

    def cancel(self) -> InstallStatus:
        """Ask the download to stop. What it fetched so far stays on disk to resume from."""
        self._cancel.set()
        self.wait()
        return self.status()

    def remove(self) -> InstallStatus:
        """Delete the downloaded runtime, model and partial files.

        Raises:
            RuntimeBusyError: a download is still running; cancel it first.
        """
        with self._lock:
            if self._downloading():
                raise RuntimeBusyError("The local runtime is still being downloaded.")
            self._error = None
        shutil.rmtree(self._root, ignore_errors=True)
        return self.status()

    def wait(self, timeout: float | None = None) -> None:
        """Block until the running download, if any, has stopped."""
        thread = self._thread
        if thread is not None:
            thread.join(timeout)

    @property
    def _server_dir(self) -> Path:
        return self._root / "llama" / LLAMA_CPP_BUILD

    def _server_removed(self) -> bool:
        """The install completed, then lost its server: the folder is there, the file is not.

        The folder is only ever moved into place whole, after extraction, so its presence
        without the executable is something outside the app deleting it.
        """
        server = self.server_path
        return (
            server is not None
            and self._server_dir.is_dir()
            and not server.is_file()
            and self.model_path.is_file()
        )

    def _downloading(self) -> bool:
        return self._thread is not None and self._thread.is_alive()

    def _missing(self) -> list[PinnedFile]:
        """The pinned files still to fetch, archive first: it is the small one."""
        missing: list[PinnedFile] = []
        server = self.server_path
        if self._build is not None and (server is None or not server.is_file()):
            missing.append(self._build.archive)
        if not self.model_path.is_file():
            missing.append(self._model)
        return missing

    def _part_path(self, file: PinnedFile) -> Path:
        return self._root / "downloads" / f"{file.filename}.part"

    def _part_size(self, file: PinnedFile) -> int:
        part = self._part_path(file)
        return part.stat().st_size if part.is_file() else 0

    def _run(self) -> None:
        """The download thread: fetch, verify and install every missing file."""
        build = self._build
        assert build is not None  # `start` refuses an unsupported platform.
        try:
            missing = self._missing()
            self._check_free_space(missing)
            with httpx.Client(
                transport=self._transport,
                follow_redirects=True,
                timeout=_TIMEOUT,
                verify=tls_context(),
            ) as http:
                for file in missing:
                    verified = self._download(http, file)
                    if file is build.archive:
                        self._extract(verified, build)
                        verified.unlink()
                    else:
                        self.model_path.parent.mkdir(parents=True, exist_ok=True)
                        verified.replace(self.model_path)
        except _Cancelled:
            logger.info("Local runtime download cancelled.")
        except _Failed as exc:
            logger.warning("Local runtime download failed: %s", exc.error)
            with self._lock:
                self._error = exc.error
        except OSError:
            logger.exception("Local runtime download failed on disk.")
            with self._lock:
                self._error = "disk_full"

    def _check_free_space(self, missing: list[PinnedFile]) -> None:
        """Refuse up front a download the disk cannot hold, rather than failing at 4 GB."""
        self._root.mkdir(parents=True, exist_ok=True)
        needed = sum(file.size - self._part_size(file) for file in missing)
        # The archive is extracted beside itself before it is deleted: count it twice.
        needed += sum(file.size for file in missing if file is not self._model)
        if shutil.disk_usage(self._root).free < needed:
            raise _Failed("disk_full")

    def _download(self, http: httpx.Client, file: PinnedFile) -> Path:
        """Fetch `file` into its `.part`, resuming one left behind, and verify it.

        Returns the verified `.part`, for the caller to move into place.
        """
        part = self._part_path(file)
        part.parent.mkdir(parents=True, exist_ok=True)
        if part.is_file() and part.stat().st_size > file.size:
            part.unlink()

        digest = hashlib.sha256()
        offset = 0
        if part.is_file():
            # Resuming means vouching for bytes this process did not receive, so they are
            # hashed again rather than trusted: the final check covers the whole file.
            with part.open("rb") as existing:
                while chunk := existing.read(_CHUNK_BYTES):
                    digest.update(chunk)
                    offset += len(chunk)

        if offset < file.size:
            headers = {"Range": f"bytes={offset}-"} if offset else {}
            try:
                with http.stream("GET", file.url, headers=headers) as response:
                    if response.status_code == 200 and offset:
                        # The server ignored the range: start the file over.
                        self._add_received(-offset)
                        digest = hashlib.sha256()
                        offset = 0
                    elif response.status_code not in (200, 206):
                        raise _Failed("network")
                    with part.open("ab" if offset else "wb") as out:
                        for chunk in response.iter_bytes():
                            if self._cancel.is_set():
                                raise _Cancelled
                            out.write(chunk)
                            digest.update(chunk)
                            offset += len(chunk)
                            self._add_received(len(chunk))
                            if offset > file.size:
                                break
            except httpx.HTTPError as exc:
                raise _Failed("network") from exc

        if offset != file.size or digest.hexdigest() != file.sha256:
            part.unlink(missing_ok=True)
            raise _Failed("hash_mismatch")
        return part

    def _add_received(self, count: int) -> None:
        with self._lock:
            self._received += count

    def _extract(self, archive: Path, build: RuntimeBuild) -> None:
        """Unpack the verified archive next to its final folder, then move it into place."""
        staging = self._server_dir.with_name(f"{LLAMA_CPP_BUILD}.extracting")
        shutil.rmtree(staging, ignore_errors=True)
        try:
            if build.kind == "zip":
                with zipfile.ZipFile(archive) as bundle:
                    for member in bundle.namelist():
                        if not _is_within(staging, staging / member):
                            raise _Failed("extract")
                    bundle.extractall(staging)
            else:
                with tarfile.open(archive, "r:gz") as bundle:
                    # `data` refuses absolute paths, `..`, links leaving the folder and
                    # device files, and drops setuid bits: an archive is never trusted to
                    # write outside where it is put, even one whose hash was checked.
                    bundle.extractall(staging, filter="data")
        except (zipfile.BadZipFile, tarfile.TarError) as exc:
            shutil.rmtree(staging, ignore_errors=True)
            raise _Failed("extract") from exc

        if not (staging / build.server).is_file():
            shutil.rmtree(staging, ignore_errors=True)
            raise _Failed("extract")
        shutil.rmtree(self._server_dir, ignore_errors=True)
        staging.replace(self._server_dir)


def _is_within(root: Path, candidate: Path) -> bool:
    return candidate.resolve().is_relative_to(root.resolve())
