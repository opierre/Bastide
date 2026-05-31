---
name: architecture
description: Use whenever creating or moving files, adding a feature, wiring the Flutter frontend to the Python backend, or making any structural/layering decision in the finstride monorepo. Defines the monorepo layout, feature-first boundaries, the localhost sidecar coupling, and the dependency rules every other skill assumes. Consult before scaffolding anything new.
---

# Architecture

Authoritative source for *where code goes* and *what may depend on what* in this monorepo.
Read `PROJECT.md` §3 for the canonical layout; this skill is the enforceable rule set.

## Non-negotiables

- **Monorepo, two packages.** `backend/` (Python/FastAPI) and `frontend/` (Flutter). Shared
  docs/skills live at the root. Never create a third top-level code package without updating
  `PROJECT.md` first.
- **Local sidecar coupling.** The Flutter app launches and supervises the FastAPI process,
  which listens on `127.0.0.1` only. **Never bind `0.0.0.0`.** No code assumes a remote server.
- **Feature-first, vertical slices.** A feature owns everything it needs. Cross-feature reach-in
  is forbidden — features talk through well-defined service interfaces or the API, never by
  importing each other's internals.
- **Local-first.** No network calls except (Phase 2) the local Ollama endpoint and (opt-in)
  ECB FX later. No telemetry, no cloud calls in Phase 1–3.

## Backend layering (strict, one direction)

```
routes  →  services  →  repositories  →  models (SQLAlchemy)
  │           │              │
schemas    (pure logic)   (all DB access)
(Pydantic)
```

- **routes/** — thin. Parse/validate via Pydantic schemas, call one service, map result to a
  response schema. No business logic, no direct DB/session access.
- **services/** — business logic. Pure-ish and unit-testable; dependencies (repos, clock,
  Ollama client) injected so tests can mock them. Services never touch FastAPI request objects.
- **repositories/** — the *only* place that touches the SQLAlchemy session/queries. Return
  domain objects, not ORM rows leaking upward where avoidable.
- **models/** — SQLAlchemy ORM. No business logic.
- **schemas/** — Pydantic v2 I/O models. Distinct from ORM models. Never expose ORM models
  directly over the API.

A layer may depend only on the layer to its right. Routes never import repositories; services
never import FastAPI. Violations are bugs.

### Backend feature folder shape

```
backend/app/features/<feature>/
├── router.py        # APIRouter, thin endpoints
├── schemas.py       # Pydantic request/response
├── service.py       # business logic
├── repository.py    # DB access
├── models.py        # SQLAlchemy models for this feature
└── __init__.py
```

`core/` holds cross-cutting infrastructure only: `config.py`, `db.py` (engine/session), 
`security.py`, `errors.py`, `deps.py` (FastAPI dependencies). Feature code imports from `core`,
never the reverse.

## Frontend layering (Flutter, Riverpod)

```
UI (screens/widgets)  →  controllers/providers (Riverpod)  →  repositories  →  api client
```

- **Widgets contain no business logic.** They read state from providers and call controller
  methods. No HTTP, no parsing, no formatting logic inline.
- **controllers/providers** — state + orchestration (Riverpod `Notifier`/`AsyncNotifier`).
- **repositories** — call the API client, map JSON ↔ immutable Dart models.
- **api client** — single typed HTTP client (base URL = the sidecar). One place owns
  auth-header injection and error mapping.

### Frontend feature folder shape

```
frontend/lib/features/<feature>/
├── presentation/    # screens + widgets
├── application/     # Riverpod controllers/providers
├── data/            # repository + DTO mapping
└── domain/          # immutable models for this feature
```

`core/` holds `theme/`, `router/`, `api/` (client), `l10n/`. Shared widgets (the fixed
navbar/top bar/bottom bar — see design-system skill) live in `core/` because they are app-wide
invariants, not feature-owned.

## API contract is the boundary

The REST contract in `PROJECT.md` §5 is the single source of truth shared by both packages.
When it changes: update `PROJECT.md` first, then backend schema, then frontend DTO — ideally in
one commit (`feat(api): ...`) so the two sides never drift. Generate the frontend client from
the backend's OpenAPI where practical rather than hand-maintaining two copies.

## When you (the agent) are unsure

- New cross-cutting concern? It goes in `core/`, not a feature.
- Logic needed by two features? Extract a service; do not import one feature from another.
- Tempted to call the DB from a route or an HTTP client from a widget? Stop — that violates
  layering. Route the call through the proper layer.
- A decision not covered here or in `PROJECT.md`? Surface it to the user instead of guessing.
