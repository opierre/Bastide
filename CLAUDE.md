# CLAUDE.md — FinStride Agent Conventions

> Global conventions for the monorepo. Backend and frontend have their own `CLAUDE.md` files; those inherit and extend this one.

## Stack

- **Python 3.14** · FastAPI · Pydantic v2 · SQLAlchemy 2.x · Alembic
- **Dart** · Flutter (latest stable) · Riverpod
- **uv** (environment and dependency management)
- **Tooling:** ruff (lint + format), ty (type checker), pytest, flutter_test
- **SQLite (WAL)** — kept PostgreSQL-ready
- **Local inference runtime** (optional; `llama-server` or Ollama, default Gemma 4 E4B)

## Core principles

1. **Load the relevant skill before working.** Work on the backend? Load `fastapi-backend` + `database` + `testing`. Frontend? Load `flutter-frontend` + `design-system` + `i18n-l10n` + `testing`. Making structural changes? Load `architecture`. Committing? Load `git-conventional-commits`. If unsure, ask.

2. **Stop and ask if a decision isn't covered.** This monorepo spec and the skill docs answer most questions. If something—architecture choice, tech debt, a UI decision—falls outside them, stop and ask the user instead of guessing.

3. **Conventional Commits.** Every commit must follow the Conventional Commits format: `type(scope): subject` where type ∈ `{feat, fix, docs, refactor, test, chore, build, ci, perf}` and scope is the feature name. One logical change per commit.

4. **Dark-first design.** All UI starts in dark mode. The palette is coherent and readable in dark.

5. **i18n day one.** No hard-coded user-facing strings. French first, English second. Locale chosen at registration, switchable in settings. Dates, numbers, currency formatted per locale.

6. **Money is always signed integer minor units.** E.g. cents. Never floats. Negative = outflow/expense, positive = inflow/income.

7. **Local-first, privacy-first.** All data and AI run on the user's machine. The sidecar is loopback-only; an optional cloud tier, if ever built, reuses the same architecture.

## See also

- `PROJECT.md` for the vision, scope, decisions and their rationale.
- `docs/database.md` and `docs/api.md` for the schema and endpoints — generated from the code, never edited by hand.
- `backend/CLAUDE.md` for Python/FastAPI rules.
- `frontend/CLAUDE.md` for Flutter/Dart rules.
- Skills in `.claude/skills/` for deep guidance on a topic.
