---
name: testing
description: Use whenever writing or changing tests, or deciding what to mock, in Bastide. Defines the backend (pytest) and frontend (flutter_test + mocktail) conventions, the mock-everything-external rule, what to use real vs mock, the money/dedup/i18n assertions every feature needs, and the per-slice definition of done. Consult before finishing any feature slice.
---

# Testing

Every feature slice ships with tests; external dependencies are mocked. Tests are part of the
Definition of Done, not an afterthought.

## Principles

- **Mock everything external and non-deterministic**: the Ollama model, network, the system
  clock, the filesystem (for parsers), and randomness (UUIDs/tokens) where assertions need
  determinism. A unit test that depends on a live external thing is not a unit test.
- **Use real where it's cheap and central**: the DB *schema* (via a temp/in-memory SQLite built
  from Alembic) in integration tests, and pure domain logic. Don't mock the thing under test.
- Tests are fast, isolated, and order-independent. No shared mutable global state between tests.

## Backend (pytest)

- Layout mirrors `app/`: `backend/tests/features/<feature>/...`, plus `tests/fixtures/`.
- **Unit tests**: services with mocked repositories and mocked clients (Ollama, clock). Assert
  business rules and the domain exceptions raised. No DB, no FastAPI app.
- **Repository/integration tests**: real schema on a temp SQLite (applied via Alembic), exercise
  queries and constraints (unique/dedup/user-scoping). No Postgres.
- **API tests**: FastAPI `TestClient`/httpx with dependencies overridden (mock services or a
  temp DB). Assert status codes, the **error envelope** shape, auth gating, and user-scoping
  (a user cannot read another user's rows).
- Use fixtures/factories for data; **no float money in any fixture** (lint your own fixtures).
- Tooling: `uv run pytest`; coverage reported. `ruff` + `ty` must pass on test code too.

## Frontend (flutter_test + mocktail)

- **Controller/repository unit tests**: mock the api client (`mocktail`); assert `AsyncValue`
  transitions (loading → data / error) and mapping of the error envelope to typed failures.
- **Widget tests**: pump screens with mocked controllers; assert all three states render
  (loading, error+retry, data). Run key screens under **both fr and en** locales (i18n skill) to
  catch hardcoded strings and French-length overflow.
- No widget test hits a real network or sidecar.

## Assertions every feature should cover

- **Money**: values stay integer minor units end-to-end; signs correct (expense negative); 
  display formatting matches locale.
- **Imports**: dedup catches re-imports; re-importing an identical file inserts zero rows;
  encodings/decimal/date variants parse (use real fixture files).
- **Categorization**: rule priority + first-match-wins; `source=user` never overridden;
  confidence threshold routes to assign vs review; Ollama-absent path still succeeds.
- **Security**: every list/detail query is user-scoped; unauthenticated requests are rejected.
- **i18n**: ARB key parity (fr ↔ en) enforced by a test/CI check.

## Coverage & CI

- Aim for meaningful coverage of services, parsers, repositories, and controllers (the logic),
  not 100% of trivial getters. Don't write assertion-free tests to inflate numbers.
- CI runs: backend `ruff` + `ty` + `pytest`; frontend `flutter analyze` + `flutter test`; the ARB
  parity check; migrations apply on an empty DB. A red CI blocks merge.

## Commit hygiene

Test-only changes commit as `test(scope): ...`. A feature commit may include its tests; a slice
is not "done" (and shouldn't be committed as `feat`) without them.
