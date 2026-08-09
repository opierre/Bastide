# P2-01 — User settings backend
Scope: backend
Depends on: P1-04
Skills: fastapi-backend, database, testing
PROJECT.md: §4b, §5b

## Objective
A `user_settings` row per user holding the AI configuration the backend needs, exposed as a
read/patch endpoint. Created lazily so no migration backfill or registration change is required.

## Files
- `backend/app/features/settings/{__init__,models,schemas,service,repository,router}.py`
- `backend/migrations/versions/*_add_user_settings.py`
- `backend/tests/features/settings/test_settings.py`

## Contract slice
```
GET   /api/v1/settings  → {ai_enabled, inference_base_url, model_tag, confidence_threshold}
PATCH /api/v1/settings  {ai_enabled?, inference_base_url?, model_tag?, confidence_threshold?}
```

## Steps
1. Model per `PROJECT.md` §4b: `user_id` unique FK, `ai_enabled` (default false),
   `inference_base_url` (default `http://127.0.0.1:11434/v1`), `model_tag` nullable,
   `confidence_threshold` (default 0.80). Alembic migration; no backfill.
2. `get_or_create(user_id)` in the service — `GET` on a user who has never opened settings
   returns the defaults and persists them. Idempotent under concurrent first reads.
3. Pydantic v2 schemas: `confidence_threshold` constrained to `[0, 1]`;
   `inference_base_url` must be an `http(s)` URL **on a loopback host** — reject anything else
   with a 422. The sidecar is loopback-only (§3/§8); a settings field that can point the backend
   at an arbitrary remote host would quietly undo that, sending transaction descriptions off the
   machine.
4. Thin router, user-scoped via the existing auth dependency. Partial patch semantics: omitted
   fields keep their stored value (use `model_dump(exclude_unset=True)`).
5. Register the router in `main.py` alongside the Phase 1 features.

## Acceptance
- `GET /settings` on a fresh user returns defaults and creates exactly one row; calling it twice
  creates no second row.
- `PATCH` updates only supplied fields.
- Threshold outside `[0,1]` → 422. Non-loopback or non-http base URL → 422.
- Settings are user-scoped: user A cannot read or write user B's row.
- `ruff` + `ty` clean.

## Tests
- `test_settings.py`: lazy creation is idempotent; partial patch; threshold bounds; loopback URL
  validation (accept `127.0.0.1`/`localhost`, reject a public host); user scoping.

## Commits
- `feat(settings): add user settings model and migration`
- `feat(settings): add settings read and patch endpoints`
