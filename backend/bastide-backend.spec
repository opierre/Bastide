# PyInstaller spec for the frozen sidecar: `uv run --group build pyinstaller bastide-backend.spec`.
#
# One folder (`dist/bastide-backend/`), not one file: `--onefile` unpacks itself to a temp dir on
# every launch, which starts slowly and is what antivirus heuristics flag most.
#
# PyInstaller only follows `import` statements it can see. Everything below is something the
# backend loads by path or by name at runtime, so the analysis would miss it.

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
)
coll = COLLECT(exe, a.binaries, a.datas, name="bastide-backend", upx=False)
