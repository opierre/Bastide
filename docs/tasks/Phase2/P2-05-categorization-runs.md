# P2-05 — Categorization run orchestration
Scope: backend
Depends on: P2-02, P2-04
Skills: ai-categorization, fastapi-backend, database, testing
PROJECT.md: §5b, §7

## Objective
Run stage 2 asynchronously over a user's unmatched transactions, tracked in a
`categorization_run` the frontend can poll and cancel, and enqueued automatically after an
import. An import must never wait on the model.

## Files
- `backend/app/features/categorization/{runner,repository,router}.py`
- `backend/app/features/categorization/schemas.py` — run schemas (extend P2-04's file)
- `backend/app/features/imports/service.py` — edit: enqueue a run after a successful import
- `backend/app/main.py` — edit: startup reconciliation of orphaned runs
- `backend/tests/features/categorization/{test_runner,test_runs_api,test_import_enqueue}.py`

## Contract slice
```
POST /api/v1/categorization/runs         {account_id?, scope: pending|all} → 202 run
GET  /api/v1/categorization/runs         ?limit → [run]   (newest first)
GET  /api/v1/categorization/runs/{id}    → run
POST /api/v1/categorization/runs/{id}/cancel → run
```

## Steps
1. Row selection: `scope=pending` → rows with `needs_review=true` and
   `categorization_source='uncategorized'`; `scope=all` → additionally rows with
   `source='model'` (a re-run after changing model or threshold). **Never** select
   `source='user'` or `source='rule'` — §7, user and deterministic intent both win over the model.
   Optional `account_id` narrows further.
2. Create the run `pending` with `total_count` set, then execute it in the background
   (FastAPI `BackgroundTasks` or an asyncio task — the sidecar is single-process and single-user;
   do not add a broker). Return **202** immediately with the run.
3. **One run at a time per user.** If a `pending`/`running` run exists, return it instead of
   creating a second — two passes over the same rows would race on `category_id`. Enforce this
   in the repository under the same transaction that inserts, not with a check-then-insert.
4. Executor loop, per batch of P2-04's batch size:
   - re-read the run's `status`; if `cancelled`, stop cleanly;
   - call `categorize_batch`;
   - apply assignments (`category_id`, `source='model'`, `categorization_confidence`,
     `needs_review=false`); deferred rows are left untouched;
   - increment `processed_count`/`assigned_count`/`deferred_count`/`failed_count` and
     **commit** — per §7, progress is committed per batch so a crash keeps completed work.
5. Terminal status: `success` (no failures), `partial` (some rows failed), `failed` (the runtime
   was unreachable for the whole run, or an unexpected error — record `error_message`).
   Always set `finished_at`.
6. **Import enqueue**: after an import commits successfully, if `ai_enabled` is true, enqueue a
   run scoped to that account with `trigger='import'` and `import_batch_id` set. If `ai_enabled`
   is false or the runtime is unreachable, **do nothing at all** — no run row, no error. The
   import result must be byte-identical to Phase 1 in that case.
7. **Startup reconciliation** in `main.py`: mark any run still `pending`/`running` as `failed`
   with an explanatory `error_message` — its executor died with the previous process.
8. Cancellation sets `status='cancelled'`; the executor notices between batches. Cancelling a
   finished run is a 409, not a silent no-op.

## Acceptance
- `POST /runs` returns 202 in well under a second regardless of row count.
- A second `POST` while one is in flight returns the existing run, not a new one.
- Rows with `source='user'` or `source='rule'` are never modified by a run.
- Killing the process mid-run leaves the already-processed rows categorized and
  `processed_count` accurate; the next startup marks that run `failed`.
- Cancel stops the run between batches, leaving completed batches applied.
- An import with AI disabled behaves exactly as in Phase 1 and creates no run.
- An import with AI enabled but the runtime down still succeeds; the run ends `failed`.
- User-scoped throughout. `ruff` + `ty` clean.

## Tests
- `test_runner.py` (client mocked): per-batch commit (assert counts after a simulated mid-run
  crash); cancellation between batches; `user`/`rule` rows untouched; status resolution for the
  all-ok / some-failed / runtime-down cases; startup reconciliation.
- `test_runs_api.py`: 202 shape; single-in-flight returns the existing run; history newest-first;
  cancel on a finished run → 409; user scoping.
- `test_import_enqueue.py`: AI off → no run and an unchanged import response; AI on → run created
  with `trigger='import'` and the batch id; runtime down → import still 201.

## Commits
- `feat(categorization): add run repository and background executor`
- `feat(categorization): add run endpoints with progress and cancellation`
- `feat(imports): enqueue a categorization run after import when AI is enabled`
