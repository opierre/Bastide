# Development workflow

How to work on FinStride day to day: editor setup, running both halves, the checks CI runs,
regenerating the reference docs, working with coding agents, and committing.

---

## 1. One-time setup

### Workspace
Open `finstride.code-workspace` (**File → Open Workspace from File…**). It is a multi-root
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

The Flutter API client targets `http://127.0.0.1:8765/api/v1`. The backend binds **loopback
only** — never `0.0.0.0`. With the backend running, the interactive API docs are at
`http://127.0.0.1:8765/docs`.

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
