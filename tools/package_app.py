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

   - Windows: ``Bastide-Setup-<version>.exe`` (Inno Setup, ``tools/windows/bastide.iss``)
     and the portable ``Bastide-<version>-windows.zip``.
   - macOS: ``Bastide.app``, ad-hoc signed (unsigned code doesn't run on Apple Silicon),
     in ``Bastide-<version>-macos.dmg``.
   - Linux: ``Bastide-<version>-<arch>.AppImage``, with ``appimagetool`` on the PATH or
     in ``$APPIMAGETOOL``.

Like the backend freeze, nothing here cross-compiles: each OS packages itself.
"""

import argparse
import os
import platform as host
import re
import shutil
import subprocess
import sys
import zipfile
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


def zip_folder(folder: Path, archive: Path, top: str) -> None:
    """Zip ``folder``'s contents under one ``top`` folder, so unzipping makes no mess."""
    archive.unlink(missing_ok=True)
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as zf:
        for path in sorted(folder.rglob("*")):
            zf.write(path, Path(top) / path.relative_to(folder))
    print(f"Wrote {archive}")


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
    zip_folder(release, DIST / f"Bastide-{version}-windows.zip", "Bastide")


MACH_O_MAGICS = {
    bytes.fromhex(magic)
    for magic in ("feedface", "feedfacf", "cefaedfe", "cffaedfe", "cafebabe", "bebafeca")
}


def is_mach_o(path: Path) -> bool:
    """Whether ``path`` is compiled code (an executable, ``.dylib`` or ``.so``)."""
    if path.is_symlink() or not path.is_file():
        return False
    with path.open("rb") as file:
        return file.read(4) in MACH_O_MAGICS


def bundle_macos() -> Path:
    """Put the backend in ``Bastide.app/Contents/Resources/backend/`` and ad-hoc sign the app."""
    app = FRONTEND / "build" / "macos" / "Build" / "Products" / "Release" / "Bastide.app"
    resources = app / "Contents" / "Resources"
    backend = resources / "backend"
    shutil.rmtree(backend, ignore_errors=True)
    # PyInstaller's macOS output links its Python framework through symlinks: keep them.
    shutil.copytree(BACKEND_DIST, backend, symlinks=True)
    shutil.copy2(LICENSE, resources / "LICENSE.txt")

    # Inside out: each backend binary first, deepest first, then the app, which seals them.
    # Flutter's build already signed the frameworks in Contents/Frameworks.
    codesign = require("codesign")
    binaries = sorted(
        (path for path in backend.rglob("*") if is_mach_o(path)),
        key=lambda path: len(path.parts),
        reverse=True,
    )
    for path in binaries:
        run(codesign, "--force", "--sign", "-", "--timestamp=none", path)
    entitlements = FRONTEND / "macos" / "Runner" / "Release.entitlements"
    run(codesign, "--force", "--sign", "-", "--entitlements", entitlements, app)
    run(codesign, "--verify", "--deep", "--strict", "--verbose=2", app)
    return app


def dmg_macos(app: Path, version: str) -> None:
    """Wrap ``app`` in a disk image with an Applications shortcut to drag it onto."""
    staging = DIST / "dmg"
    shutil.rmtree(staging, ignore_errors=True)
    staging.mkdir()
    shutil.copytree(app, staging / app.name, symlinks=True)
    (staging / "Applications").symlink_to("/Applications")
    dmg = DIST / f"Bastide-{version}-macos.dmg"
    run(
        require("hdiutil"), "create", "-volname", "Bastide", "-srcfolder", staging,
        "-fs", "HFS+", "-format", "UDZO", "-ov", dmg,
    )  # fmt: skip
    shutil.rmtree(staging)


DESKTOP_ENTRY = """[Desktop Entry]
Type=Application
Name=Bastide
Comment=Local-first personal finance
Exec=bastide
Icon=bastide
Categories=Office;Finance;
Terminal=false
"""

APP_RUN = """#!/bin/sh
HERE="$(dirname "$(readlink -f "$0")")"
exec "$HERE/bastide" "$@"
"""


def appimage_linux(version: str) -> None:
    """Turn the Flutter bundle, backend included, into one AppImage."""
    arch = {"x86_64": "x64", "aarch64": "arm64"}[host.machine()]
    bundle = FRONTEND / "build" / "linux" / arch / "release" / "bundle"
    # The CMake install step copies the backend in (frontend/linux/CMakeLists.txt).
    if not (bundle / "backend" / "bastide-backend").is_file():
        sys.exit(f"No backend in {bundle}: the frozen build is missing")

    appdir = DIST / "Bastide.AppDir"
    shutil.rmtree(appdir, ignore_errors=True)
    shutil.copytree(bundle, appdir, symlinks=True)
    shutil.copy2(LICENSE, appdir / "LICENSE.txt")
    (appdir / "bastide.desktop").write_text(DESKTOP_ENTRY, encoding="utf-8")
    shutil.copy2(FRONTEND / "assets" / "brand" / "bastide-mark-256.png", appdir / "bastide.png")
    (appdir / ".DirIcon").symlink_to("bastide.png")
    app_run = appdir / "AppRun"
    app_run.write_text(APP_RUN, encoding="utf-8")
    app_run.chmod(0o755)

    tool = os.environ.get("APPIMAGETOOL") or require("appimagetool")
    image = DIST / f"Bastide-{version}-{host.machine()}.AppImage"
    print(f"$ {tool} {appdir} {image}", flush=True)
    subprocess.run(
        [str(tool), str(appdir), str(image)],
        env={**os.environ, "ARCH": host.machine()},
        check=True,
    )
    shutil.rmtree(appdir)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "--skip-backend", action="store_true", help="reuse the backend already in backend/dist/"
    )
    parser.add_argument(
        "--build-number", help="the build number (default: the one in pubspec.yaml)"
    )
    parser.add_argument(
        "--version-label",
        help="the version that names the packages, e.g. 0.1.0-rc.1 for a release candidate"
        " (default: the one in pubspec.yaml)",
    )
    args = parser.parse_args()

    platform = {"win32": "windows", "darwin": "macos"}.get(sys.platform, sys.platform)
    if platform not in {"windows", "macos", "linux"}:
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

    # The app itself keeps the pubspec version: it must match the backend's on startup.
    label = args.version_label or version
    DIST.mkdir(exist_ok=True)
    if platform == "windows":
        package_windows(label)
    elif platform == "macos":
        dmg_macos(bundle_macos(), label)
    else:
        appimage_linux(label)

    print(f"Packaged Bastide {label} into {DIST}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
