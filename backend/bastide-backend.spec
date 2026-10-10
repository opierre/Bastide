# PyInstaller spec for the frozen sidecar: `uv run --group build pyinstaller bastide-backend.spec`.
#
# One folder (`dist/bastide-backend/`), not one file: `--onefile` unpacks itself to a temp dir on
# every launch, which starts slowly and is what antivirus heuristics flag most.
#
# PyInstaller only follows `import` statements it can see. Everything below is something the
# backend loads by path or by name at runtime, so the analysis would miss it.

import re
import sys
from importlib.metadata import version
from pathlib import Path

from PyInstaller.utils.hooks import collect_submodules, copy_metadata

# `SPECPATH` (set by PyInstaller) is `backend/`, so the build works from any working directory.
BACKEND = Path(SPECPATH)

hiddenimports = [
    # The migration scripts are data files, loaded by path, and import feature models; collect
    # the whole package so a migration never reaches a module the app itself doesn't import.
    # uvicorn's loops and protocols, the SQLAlchemy dialects and argon2's cffi binding are
    # covered by the hooks shipped with PyInstaller and pyinstaller-hooks-contrib.
    *collect_submodules("app"),
]

datas = [
    # Alembic reads the migration scripts from disk; `app.core.schema` looks for them beside the
    # `app` package, which is `_internal/` once frozen.
    *(
        (str(path), str(path.parent.relative_to(BACKEND)))
        for path in (BACKEND / "migrations").rglob("*")
        if path.is_file() and "__pycache__" not in path.parts
    ),
    # Rule packs shipped with the app, read from beside their service module.
    (str(BACKEND / "app/features/rules/packs/builtin"), "app/features/rules/packs/builtin"),
    # `app.__version__` comes from the installed package's metadata.
    *copy_metadata("bastide-backend"),
]


def windows_version_info():
    """The Windows version resource: an executable without one is an antivirus red flag."""
    from PyInstaller.utils.win32.versioninfo import (
        FixedFileInfo,
        StringFileInfo,
        StringStruct,
        StringTable,
        VarFileInfo,
        VarStruct,
        VSVersionInfo,
    )

    product_version = version("bastide-backend")
    # The fixed part takes four numbers: `0.1.0-rc.1` becomes 0.1.0.0.
    numbers = [int(part) for part in re.match(r"\d+(\.\d+)*", product_version)[0].split(".")]
    numbers = tuple((numbers + [0, 0, 0, 0])[:4])
    strings = {
        # Same identity as the Flutter shell's resource (frontend/windows/runner/Runner.rc).
        "CompanyName": "Bastide",
        "FileDescription": "Bastide backend",
        "FileVersion": product_version,
        "InternalName": "bastide-backend",
        "LegalCopyright": "Copyright (C) 2026 Bastide contributors. AGPL-3.0.",
        "OriginalFilename": "bastide-backend.exe",
        "ProductName": "Bastide",
        "ProductVersion": product_version,
    }
    return VSVersionInfo(
        ffi=FixedFileInfo(filevers=numbers, prodvers=numbers),
        kids=[
            # US English, code page 1252: the same translation as Runner.rc.
            StringFileInfo(
                [StringTable("040904E4", [StringStruct(k, v) for k, v in strings.items()])]
            ),
            VarFileInfo([VarStruct("Translation", [0x0409, 1252])]),
        ],
    )


a = Analysis(
    [str(BACKEND / "app" / "__main__.py")],
    pathex=[str(BACKEND)],
    hiddenimports=hiddenimports,
    datas=datas,
    # Development and build tools that happen to be importable from the build environment.
    excludes=["pytest", "_pytest", "coverage", "pygments", "setuptools", "tkinter"],
)
pyz = PYZ(a.pure)
exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name="bastide-backend",
    # A console program: the desktop app reads the `READY` line on stdout and watches stdin.
    console=True,
    # UPX-packed executables are a classic antivirus trigger, and it saves little here.
    upx=False,
    version=windows_version_info() if sys.platform == "win32" else None,
)
coll = COLLECT(exe, a.binaries, a.datas, name="bastide-backend", upx=False)
