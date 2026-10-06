---
name: fastapi-backend
description: Use for any Python backend work in the finstride — adding endpoints, Pydantic schemas, services, dependency injection, error handling, auth wiring, or running the sidecar. Encodes the thin-route pattern, the error envelope, Pydantic v2 conventions, the uv/ruff/ty toolchain, and the ty-beta escape-hatch rule. Pairs with the architecture and database skills.
---

# FastAPI Backend

How to build the Python sidecar. Obey the layering in the **architecture** skill and the
persistence rules in the **database** skill; this skill covers FastAPI/Python specifics.

## Toolchain (no exceptions)

- **uv** manages the env and dependencies. `uv add <pkg>`, `uv run ...`. Never `pip install`
  into the system env. Lockfile is committed.
- **ruff** does both lint and format (`ruff check`, `ruff format`). **No black.**
- **ty** (Astral) is the type checker, run in CI and the editor. **No mypy in the normal loop.**
- Target **Python 3.14**, full type hints everywhere.

### The ty-beta rule (saves tokens)

`ty` is beta and its Pydantic v2 inference is still maturing. If `ty check` reports a false
positive on Pydantic models or validators, the fix is a **targeted ignore with a one-line
comment** explaining why — e.g. `# ty: ignore[<rule>] — false positive on Pydantic v2 validator`.
**Do not** restructure correct, working code to satisfy the checker, and do not silence whole
files.

## Endpoint pattern (thin routes)

```python
@router.post("/accounts", response_model=AccountRead, status_code=201)
async def create_account(
    payload: AccountCreate,                 # Pydantic schema validates input
    service: AccountService = Depends(get_account_service),
    user: User = Depends(get_current_user), # auth dependency
) -> AccountRead:
    account = await service.create(user_id=user.id, data=payload)
    return AccountRead.model_validate(account)
```

- Route does: validate (via schema) → call **one** service method → map to a response schema.
- No business logic, no DB session, no `try/except` for domain rules in routes — services raise
  typed domain errors; a global handler maps them to the error envelope.
- All authenticated routes depend on `get_current_user`; that dependency also scopes data access.

## Schemas (Pydantic v2)

- Separate `*Create`, `*Update`, `*Read` schemas. Never expose ORM models directly.
- Money fields are `int` (minor units) named `*_minor`, plus a `currency: str` (ISO-4217).
  No `float`, no `Decimal` over the wire.
- Use `model_config = ConfigDict(from_attributes=True)` for read schemas mapping from ORM.
- Validate at the edge: currency is a known ISO code, dates parse, enums are real enums.

## Services & dependencies

- Services receive their dependencies (repositories, clock, later the Ollama client) via
  constructor/DI so unit tests inject mocks. No global singletons reached into.
- Services raise **domain exceptions** (`NotFoundError`, `ConflictError`, `ValidationError`,
  `AuthError`) defined in `core/errors.py`. They never raise `HTTPException` (that couples logic
  to the web layer).

## Error envelope (consistent)

A global exception handler maps domain exceptions to:

```json
{ "error": { "code": "ACCOUNT_NOT_FOUND", "message": "…", "details": { } } }
```

with the right HTTP status (404, 409, 422, 401, 500). `message` is i18n-key-friendly /
user-safe; never leak stack traces or SQL.

## Auth (local-first)

- Passwords hashed with **Argon2id** (`argon2-cffi` or passlib's argon2 backend).
- Login returns an opaque bearer token stored in `auth_tokens`; `get_current_user` validates it.
- Bind the server to `127.0.0.1` only. CORS locked to the local frontend origin.

## Config & startup

- `core/config.py` via Pydantic Settings, env-overridable. No secrets in code.
- App factory pattern (`create_app()`), routers included per feature.
- After adding or changing a route, regenerate the endpoint reference:
  `uv run python -m scripts.api_doc` from `backend/`. A test fails while `docs/api.md` is stale.
- DB session is a FastAPI dependency yielding per-request sessions (see database skill).
- Run in dev: `uv run uvicorn app.main:app --host 127.0.0.1 --port <p>`. Packaged: launched and
  supervised by the Flutter app.

## Docstrings & comments

Google-style docstrings on services and non-trivial functions. Comments explain *why*. Public
service methods document what domain errors they may raise.
