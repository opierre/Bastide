# /// script
# requires-python = ">=3.12"
# dependencies = []
# ///
"""Freeze the backend into ``backend/dist/bastide-backend/`` with PyInstaller.

Run from anywhere with ``uv run tools/build_backend.py``; add ``--smoke`` to run the
frozen-build smoke test on the result. CI and local builds both go through this
script, so they run the same steps on every OS:

1. sync the backend environment from the lockfile, with the ``build`` group;
2. delete the previous build, so nothing stale survives into the new one;
3. run PyInstaller on ``backend/bastide-backend.spec``.

PyInstaller can't cross-compile: the output runs only on the OS and CPU
architecture it was built on. On Linux it needs ``objdump`` (``binutils``).
"""

import argparse
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BACKEND = ROOT / "backend"
SPEC = BACKEND / "bastide-backend.spec"
DIST = BACKEND / "dist"
WORK = BACKEND / "build"
OUTPUT = DIST / "bastide-backend"


def run(*command: str) -> None:
    """Run a command in ``backend/``, echoing it; a failure ends the build."""
    print(f"$ {' '.join(command)}", flush=True)
    subprocess.run(command, cwd=BACKEND, check=True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "--smoke", action="store_true", help="run the frozen-build smoke test afterwards"
    )
    args = parser.parse_args()

    uv = shutil.which("uv")
    if uv is None:
        print("uv is not on the PATH: https://docs.astral.sh/uv/", file=sys.stderr)
        return 1

    run(uv, "sync", "--locked", "--group", "build")
    shutil.rmtree(OUTPUT, ignore_errors=True)
    shutil.rmtree(WORK / SPEC.stem, ignore_errors=True)
    run(
        uv, "run", "--locked", "--group", "build", "pyinstaller", str(SPEC),
        "--noconfirm", "--distpath", str(DIST), "--workpath", str(WORK),
    )  # fmt: skip
    if args.smoke:
        run(uv, "run", "--locked", "pytest", "-m", "frozen", "-n", "0")

    print(f"Built {OUTPUT}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
