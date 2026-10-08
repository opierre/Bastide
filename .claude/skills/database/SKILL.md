---
name: database
description: Use for any database work in Bastide — defining or changing SQLAlchemy models, writing Alembic migrations, querying, handling money/currency, account balances, or anything touching persistence. Encodes the integer-minor-units money rule, UUID keys, the keep-Postgres-open constraints, the balance cache/snapshot strategy, and SQLite WAL specifics. Consult before writing any model, migration, or query.
---

# Database

Persistence rules for the local SQLite datastore, written so a future switch to PostgreSQL
is a dialect/connection change, not a rewrite. The schema is in `docs/database.md`, generated
from the migrations.

## The stack

- **SQLAlchemy 2.x** (typed, `Mapped[...]` style) is the *only* way code touches the database.
  No raw SQL strings in feature code; no other DB driver.
- **Alembic** for every schema change. The schema is never altered by hand or by
  `create_all` in anything but throwaway tests.
- **SQLite in WAL mode** locally (`PRAGMA journal_mode=WAL;`). One writer + concurrent readers,
  which is plenty for a single-user sidecar.

## Money — the rule that has no exceptions

- Store money as **signed integer minor units** (`*_minor`, e.g. cents). Negative = outflow,
  positive = inflow. **Floats for money are forbidden anywhere** — models, schemas, services,
  tests, fixtures.
- Every monetary column travels with an **ISO-4217 `currency`** code (string). All of a
  user's accounts share `users.currency`; the per-row/per-account `currency` column still exists
  and is populated, reserved for multi-currency. Never drop it.
- Convert to display units only at the very edge (formatting layer / frontend), never in storage
  or business logic.

## Keys, types, timestamps — Postgres-compat constraints

- **Primary keys: UUID stored as string** (`str`, UUIDv4 generated app-side). Uniform across
  SQLite and Postgres; no reliance on autoincrement semantics.
- **Timestamps: UTC, timezone-aware**, stored ISO-8601. Convert to local only for display.
- **Dates** (`booked_date`, etc.): date type, no time component.
- Avoid SQLite-only behaviour: no dynamic-typing tricks, no `rowid` reliance, no SQLite-specific
  functions in queries. Stick to portable SQLAlchemy constructs. Booleans as real `Boolean`.
- Define **explicit constraints and indexes** in models (FKs, unique, not-null) — don't lean on
  SQLite's laxness. They must hold on Postgres too.

## Dedup constraints (imports)

- `transactions`: unique on `(account_id, fitid)` when `fitid` is present; otherwise unique on
  `(account_id, dedup_hash)`. Implement as a partial/conditional uniqueness check in the import
  service (SQLite partial-index support is limited) plus an index on both keys.
- `import_batches.file_hash`: reject re-import of a byte-identical file for the same account.

## Balances — authoritative ledger, fast reads

The ledger is the source of truth; the balance is derived but **not** summed over all rows on
every read:

1. `accounts.cached_balance_minor` is updated by **delta** on every transaction insert / edit /
   delete (`new = old ± Δamount`), inside the same DB transaction as the change. O(1) reads.
2. **Monthly balance snapshots** per account: any point-in-time balance =
   `nearest snapshot ≤ date` + sum of rows after it. Bounds every historical query to a small
   row count.
3. A **full recompute** (opening balance + ordered sum of all rows) exists only as a
   reconciliation/repair routine — run after an import batch and on demand. If it disagrees with
   the cache, that's a logged bug to fix, not a silent correction.

Never write code paths that compute a live balance with an unbounded `SUM` over the full table.

## Migrations discipline

- One migration per logical schema change; reversible (`upgrade`/`downgrade` both implemented).
- Migration message mirrors the Conventional Commit subject.
- Seed data (system categories, localised fr/en — the rich ~25+ set) goes in a dedicated seed
  migration or an idempotent seed routine, never ad hoc.
- Test migrations apply cleanly on an empty DB in CI.
- After any migration, regenerate the schema reference: `uv run python -m scripts.schema_doc`
  from `backend/`. A test fails while `docs/database.md` is stale.

## Querying

- All queries live in **repositories** (see architecture skill). Services and routes never query.
- Every query is **user-scoped** — filter by `user_id` (directly or via the owning account).
  A query that could return another user's rows is a security bug.
- Paginate list endpoints (keyset or limit/offset); never return unbounded result sets.
- Watch N+1: use eager loading (`selectinload`) for known-needed relations.

## Testing the data layer

- Unit tests mock the repository or use an in-memory/temp SQLite with the real schema via Alembic.
- Never hit a real Postgres in unit tests. Integration tests may spin a temp SQLite file.
- Assert money stays integer end-to-end (a float anywhere in a fixture is a test smell).
