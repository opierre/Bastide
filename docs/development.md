# Development workflow

How to work on Bastide day to day: editor setup, running both halves, the checks CI runs,
regenerating the reference docs, working with coding agents, and committing.

---

## 1. One-time setup

### Workspace
Open `bastide.code-workspace` (**File → Open Workspace from File…**). It is a multi-root
workspace — `backend`, `frontend`, `docs` and the repo root — so each package gets its own
integrated terminal and formatter.

### Extensions
- **Python** (Microsoft) + **Ruff** (Astral) + **ty** (Astral) — backend lint/format/types.
- **Flutter** + **Dart** — frontend.
- **Claude Code** (or run the `claude` CLI in the integrated terminal).
- Optional: **SQLite Viewer** (inspect the local db), **Even Better TOML** (edit `pyproject.toml`).

### Toolchain check (run once per machine)
```bash
# backend
cd backend && uv sync          # creates the env from the lockfile
uv run ruff --version && uv run ty --version
# frontend
cd ../frontend && flutter doctor && flutter pub get
```

---

## 2. Running both halves

Two integrated terminals:

```bash
# Terminal A — backend (from backend/)
uv run alembic upgrade head     # after cloning, and after pulling a new migration
uv run uvicorn app.main:app --host 127.0.0.1 --port 8765 --reload

# Terminal B — frontend (from frontend/)
flutter run -d windows          # or -d macos / -d linux
```

A debug build that finds no packaged backend talks to the one already running at
`http://127.0.0.1:8765`, so both halves keep their hot reload. The packaged app instead starts
its own backend on a free port; see `frontend/CLAUDE.md` § Backend modes for the
`--dart-define`s that switch between the two. The backend binds **loopback
only** — never `0.0.0.0`. With the backend running, the interactive API docs are at
`http://127.0.0.1:8765/docs`.

The datastore lives in the current OS user's local data folder, so each account on a shared
computer keeps its own: `%LOCALAPPDATA%\Bastide\bastide.db` on Windows,
`~/Library/Application Support/Bastide/` on macOS, `~/.local/share/Bastide/` on Linux. Set
`BASTIDE_DB_PATH` (environment or `backend/.env`) to point the sidecar and Alembic elsewhere,
e.g. a throwaway dev database.

For AI categorisation, run a local inference runtime (Ollama or `llama-server`) with a small
model such as Gemma 4 E4B, then enable it in **Paramètres → Données → IA locale**. Without one,
categorisation runs on rules alone.

---

## 3. Checks

The same checks CI runs (`.github/workflows/ci.yml`, required check `ci-ok`):

| Side | Command (from the package folder) |
|------|-----------------------------------|
| Backend lint + format | `uv run ruff check . && uv run ruff format --check .` |
| Backend types | `uv run ty check` |
| Backend tests | `uv run pytest` (parallel by default; `-n 0` runs serially) |
| Frontend lint + format | `flutter analyze && dart format --output=none --set-exit-if-changed lib test` |
| Frontend tests | `flutter test` |

### Generated reference docs
`docs/database.md` and `docs/api.md` are generated from the code, and a backend test fails when
either is stale. Regenerate from `backend/` after touching a migration or a route:

```bash
uv run python -m scripts.schema_doc   # docs/database.md, from a freshly migrated database
uv run python -m scripts.api_doc      # docs/api.md, from the OpenAPI schema
```

### Building the app for users
`uv run tools/package_app.py` (from anywhere) freezes the backend, builds the Flutter release
with the backend inside it, and wraps it into `dist/`: the Inno Setup installer and a portable
zip on Windows, a `.dmg` on macOS, an AppImage on Linux. It builds for the OS it runs on only.
It needs [Inno Setup](https://jrsoftware.org/isinfo.php) on Windows and
[`appimagetool`](https://github.com/AppImage/appimagetool) on Linux. `--skip-backend` reuses
the backend already frozen in `backend/dist/`. The user-facing install guide is
`docs/install.md`.

### Releasing
Releases are built by CI only (`.github/workflows/release.yml`), never on a dev machine. Pushing
a `v*` tag runs `tools/package_app.py` on a Windows, a macOS (Apple Silicon) and a Linux runner
and keeps each OS's packages as a workflow artifact:

```bash
git tag v0.1.0-rc.1 && git push origin v0.1.0-rc.1
```

The committed versions are the source of truth, and CI never rewrites them: the tag must be
`v` + the version that `backend/pyproject.toml` and `frontend/pubspec.yaml` both declare,
optionally followed by a pre-release suffix such as `-rc.1`. Otherwise the run fails before
building anything (`.github/scripts/release_version.py`). To release, bump both files in one
commit, merge it, then tag that commit.

The tag, without its `v`, names the packages; the run number is the build number. Each runner
smoke-tests its frozen backend before packaging, so a missing hidden import fails the release.
When every OS is built, the run opens a **draft** GitHub Release with the packages, a
`SHA256SUMS` file and notes made from the Conventional Commits since the previous tag
(`.github/scripts/release_notes.py`); a tag with a `-` suffix is marked as a pre-release.
Review the draft and publish it by hand. Re-running the workflow on the same tag refreshes the
draft, but never touches a release that has already been published.

The app is not code-signed (see `docs/install.md`), so the release run takes these steps to
keep antivirus warnings down:

- **Compiled bootloader.** Each runner freezes the backend with
  `tools/build_backend.py --bootloader-from-source`, which compiles PyInstaller's bootloader
  instead of using the prebuilt one that antivirus heuristics flag most. It needs a C compiler;
  local builds skip it unless you pass the flag. Both Windows executables carry a version
  resource (company, product, description).
- **macOS signature check.** The app is ad-hoc signed inside out by `tools/package_app.py`; the
  run then mounts the `.dmg` and checks the app in it with `codesign --verify --deep --strict`.
- **VirusTotal.** A `virustotal` job uploads every package and lists the detections in the run
  summary (`.github/scripts/virustotal_scan.py`). A file any engine calls malicious turns the
  run red; don't publish the draft until that is sorted out. It needs a free VirusTotal API key
  in the `VIRUSTOTAL_API_KEY` repository secret, and is skipped with a warning without one.

Before publishing each release, if Windows Defender or SmartScreen flags them, submit the setup
`.exe` and `bastide-backend.exe` (from the portable zip) to Microsoft's
[false-positive submission portal](https://www.microsoft.com/en-us/wdsi/filesubmission) as
software developer. Do the same for any other vendor VirusTotal shows flagging a file.

---

## 4. Working with coding agents

Run **scoped sessions**, not one giant session over the whole repo. The package-level
`CLAUDE.md` files mean an agent started inside a folder automatically inherits root + package
rules.

- **Backend-only change?** Start `claude` from `backend/`. It sees `backend/CLAUDE.md` + root.
- **Frontend-only change?** Start `claude` from `frontend/`.
- **Cross-cutting change** (e.g. an API-contract change touching both sides)? Start from the repo
  root so both folders are in scope.

Narrower context means fewer tokens and far less drift. Point the agent at the skills it should load, ask it to stop when a decision isn't covered by
the skills, and review the diff before committing.

---

## 5. Commit & rollback

The Conventional Commits convention (`git-conventional-commits` skill) is what makes rollback
safe:

- **Inspect history**: `git log --oneline` — each commit is one logical change with a clear
  `type(scope): subject`.
- **Undo a commit but keep history honest**: `git revert <sha>` — preferred on any shared branch.
- **Throw away uncommitted work** on a file: `git restore <path>`.
- **Roll back a whole feature**: commits are scoped to one feature, so a range can be reverted
  without disturbing others.
- Never force-push shared history; fix forward.

---

## 6. Design references

The binding visual spec is [`docs/design/00-shared-design-block.md`](design/00-shared-design-block.md)
plus one file per panel. Once a panel ships, **the Flutter code is the source of truth for its
tokens and behaviour**, and the amendment paragraphs in those files record why the build
diverged from what was drawn (`docs/design/01-tool-wrappers.md`).
