# CLAUDE.md — Backend (Python / FastAPI)

> Stack-specific conventions for `backend/`. Inherits the root `CLAUDE.md`.

## Load before working

- **fastapi-backend** — all Python backend work: endpoints, Pydantic schemas, services, dependency injection, error handling, auth wiring, running the sidecar.
- **database** — DB models, Alembic migrations, queries, money/currency handling, balance strategy, SQLite WAL, account balance snapshots.
- **testing** — pytest conventions, mocking external deps, integration tests, money/dedup/i18n assertions.
- **git-conventional-commits** — when committing.

## Tools

- **uv** — environment + dependency management. Run `uv sync` to install; `uv run` to execute scripts.
- **ruff** — lint + format. Run `ruff check --fix` to lint and fix, `ruff format` to format.
- **ty** — type checking (Astral, primary in CI + editor). Run `ty check` to typecheck. Pydantic inference is still maturing; `mypy --strict` is an optional per-file escape hatch, not part of the normal loop.
- **pytest** — testing. Run `pytest` to run all tests.

## Frozen build

`uv run tools/build_backend.py` (from the repo root) freezes the sidecar with PyInstaller into `backend/dist/bastide-backend/`, from `bastide-backend.spec`. `--smoke` then runs `pytest -m frozen`, the smoke test of that build, which the default run skips. A module loaded by name or a file read by path at runtime must be added to the spec, or it is missing from the build.

## Structure

- `app/core/` — config, db session, security, errors (the foundational types and services).
- `app/features/` — one folder per feature (accounts, imports, transactions, rules, categorization, recurring, goals, mortgages, …). Each feature owns its routes, models, and services.
- `migrations/` — Alembic schema migrations.
- `scripts/` — generators for `docs/database.md` (`python -m scripts.schema_doc`) and `docs/api.md` (`python -m scripts.api_doc`); rerun after changing a migration or a route.
- `tests/` — pytest, mocking.
- `main.py` — entry point.
- `pyproject.toml` — dependencies and build config.

## Key rules

- **Thin routes, pure services.** Routes handle input/output and HTTP ceremony; services do the work and are unit-testable without mocking the DB.
- **Pydantic v2.** Request/response schemas, no v1 syntax.
- **Type hints everywhere.** Full coverage; `ty` checks it in CI.
- **Error envelope.** All errors return `{error: {code, message, details?}}` with proper HTTP status.
- **Sidecar is loopback-only.** Never bind `0.0.0.0`; always `127.0.0.1`.

## See also

- Root `CLAUDE.md` for global conventions.
- `docs/database.md` and `docs/api.md` for the generated schema and endpoint references.
