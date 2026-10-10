# /// script
# requires-python = ">=3.12"
# dependencies = []
# ///
"""Build the desktop app for this OS and wrap it for delivery, into ``dist/``.

Run from anywhere with ``uv run tools/package_app.py``. CI and local builds both go
through this script, so they run the same steps:

1. freeze the backend (``tools/build_backend.py``), unless ``--skip-backend``;
2. ``flutter build <os> --release``, versioned from ``frontend/pubspec.yaml``;
3. put the frozen backend inside the app, where the supervisor looks for it;
4. wrap the app for this OS:

   - Windows: ``Bastide-Setup-<version>.exe`` (Inno Setup, ``tools/windows/bastide.iss``).

Like the backend freeze, nothing here cross-compiles: each OS packages itself.
"""

import argparse
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FRONTEND = ROOT / "frontend"
BACKEND_DIST = ROOT / "backend" / "dist" / "bastide-backend"
LICENSE = ROOT / "LICENSE"
DIST = ROOT / "dist"


def run(*command: str | Path, cwd: Path = ROOT) -> None:
    """Run a command, echoing it; a failure ends the build."""
    print(f"$ {' '.join(map(str, command))}", flush=True)
    subprocess.run(list(map(str, command)), cwd=cwd, check=True)


def require(tool: str, *fallbacks: Path) -> Path:
    """The path to ``tool``: on the PATH, or the first fallback that exists."""
    found = shutil.which(tool)
    if found is not None:
        return Path(found)
    for path in fallbacks:
        if path.is_file():
            return path
    sys.exit(f"{tool} is not on the PATH")


def pubspec_version() -> tuple[str, str]:
    """The ``(build name, build number)`` declared in ``pubspec.yaml``."""
    text = (FRONTEND / "pubspec.yaml").read_text(encoding="utf-8")
    match = re.search(r"^version:\s*([^\s+]+)(?:\+(\d+))?\s*$", text, re.MULTILINE)
    if match is None:
        sys.exit("frontend/pubspec.yaml declares no version")
    return match[1], match[2] or "1"


def numeric_version(version: str) -> str:
    """``1.2.3`` out of ``1.2.3-rc.1``: Windows version resources take numbers only."""
    match = re.match(r"\d+(\.\d+)*", version)
    if match is None:
        sys.exit(f"{version} doesn't start with a version number")
    return match[0]


def package_windows(version: str) -> None:
    release = FRONTEND / "build" / "windows" / "x64" / "runner" / "Release"
    # The CMake install step copies the backend in (frontend/windows/CMakeLists.txt).
    if not (release / "backend" / "bastide-backend.exe").is_file():
        sys.exit(f"No backend in {release}: the frozen build is missing")
    shutil.copy2(LICENSE, release / "LICENSE.txt")

    iscc = require(
        "iscc",
        Path.home() / "AppData/Local/Programs/Inno Setup 6/ISCC.exe",
        Path("C:/Program Files (x86)/Inno Setup 6/ISCC.exe"),
    )
    run(
        iscc, f"/DAppVersion={version}", f"/DNumericVersion={numeric_version(version)}",
        f"/DSourceDir={release}", f"/DOutputDir={DIST}", "/Q",
        ROOT / "tools" / "windows" / "bastide.iss",
    )  # fmt: skip


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "--skip-backend", action="store_true", help="reuse the backend already in backend/dist/"
    )
    parser.add_argument(
        "--build-number", help="the build number (default: the one in pubspec.yaml)"
    )
    args = parser.parse_args()

    platform = {"win32": "windows", "darwin": "macos"}.get(sys.platform, sys.platform)
    if platform not in {"windows"}:
        sys.exit(f"Packaging is not set up for {sys.platform}")

    if not args.skip_backend:
        run(require("uv"), "run", ROOT / "tools" / "build_backend.py")
    if not BACKEND_DIST.is_dir():
        sys.exit(f"No frozen backend in {BACKEND_DIST}: run tools/build_backend.py")

    version, build_number = pubspec_version()
    build_number = args.build_number or build_number
    run(
        require("flutter"), "build", platform, "--release",
        f"--build-name={version}", f"--build-number={build_number}",
        cwd=FRONTEND,
    )  # fmt: skip

    DIST.mkdir(exist_ok=True)
    package_windows(version)

    print(f"Packaged Bastide {version} into {DIST}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
