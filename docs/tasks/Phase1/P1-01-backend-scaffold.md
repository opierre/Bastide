# P1-01 — Backend scaffold (FastAPI sidecar)
Scope: backend
Depends on: P1-00
Skills: fastapi-backend, architecture, testing
PROJECT.md: §3, §5, §8

## Objective
A runnable FastAPI sidecar with the core infrastructure (config, DB session, error envelope,
DI), a health endpoint, and the uv/ruff/ty/pytest toolchain wired. No features yet.

## Files
- `backend/pyproject.toml` — uv-managed; deps: fastapi, uvicorn, sqlalchemy>=2, alembic,
  pydantic>=2, pydantic-settings, argon2-cffi (or passlib[argon2]); dev: pytest, httpx, ruff, ty.
  Tool config: ruff (lint+format), ty.
- `backend/app/main.py` — `create_app()` factory; include routers; mount global exception
  handler; CORS limited to local frontend origin; bind intent `127.0.0.1`.
- `backend/app/core/config.py` — Pydantic Settings (db path, host/port, token secret), env-overridable.
- `backend/app/core/db.py` — SQLAlchemy engine (SQLite + `PRAGMA journal_mode=WAL`), session
  factory, FastAPI dependency yielding a per-request session.
- `backend/app/core/errors.py` — domain exceptions (`NotFoundError`, `ConflictError`,
  `ValidationError`, `AuthError`) + handler mapping them to the `{error:{code,message,details?}}`
  envelope with correct HTTP status.
- `backend/app/core/deps.py` — shared dependencies (db session; `get_current_user` stub raising
  `AuthError` until P1-04 fills it).
- `backend/app/features/health/router.py` — `GET /api/v1/health` → `{status:"ok"}`.
- `backend/tests/test_health.py`, `backend/tests/conftest.py` (TestClient fixture, temp DB).

## Contract slice
```
GET /api/v1/health → 200 {status:"ok"}
```
Error envelope shape (used by all later cards): `{ "error": { "code", "message", "details"? } }`.

## Steps
1. `uv init` the backend; add deps; configure ruff + ty in `pyproject.toml`.
2. Implement `core/config.py`, `core/db.py` (WAL), `core/errors.py` (+ handler), `core/deps.py`.
3. `create_app()` wiring handler + health router + CORS (local origin only).
4. Health endpoint + test. conftest provides a TestClient on a temp SQLite.
5. Ensure `uv run ruff check`, `uv run ty check`, `uv run pytest` all pass.

## Acceptance
- `uv run uvicorn app.main:app --host 127.0.0.1 --port 8765` serves `/api/v1/health`.
- Exception handler returns the envelope with correct status for each domain exception.
- ruff + ty + pytest clean. Server binds loopback only; CORS not wildcard.

## Tests
- `test_health.py`: 200 + body. A test that a raised domain exception maps to the right envelope
  + status (e.g. `NotFoundError` → 404, `AuthError` → 401).

## Commits
- `chore(core): set up uv project, ruff and ty tooling`
- `feat(core): add app factory, db session, and error envelope`
- `feat(core): add health endpoint`  (+ `test(core): cover health and error envelope`)
