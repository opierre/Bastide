# P3-06 — Tax profiles API & ledger prefill
Scope: backend
Depends on: P3-01
Skills: fastapi-backend, database, testing
PROJECT.md: §5c, §4c, §16

## Objective
One tax profile per user per year, created lazily with defaults, patchable field by field — plus
the ledger-derived prefill the user may accept. The prefill **suggests**; it never writes.

## Files
- `backend/app/features/tax/router.py`, `schemas.py`, `service.py`, `repository.py`
- `backend/tests/features/tax/test_profiles.py`, `test_prefill.py`

## Contract slice
```
GET   /api/v1/tax/profiles          -> [profile]           (one per declared year, newest first)
GET   /api/v1/tax/profiles/{year}   -> profile             (created lazily with defaults)
PATCH /api/v1/tax/profiles/{year}
GET   /api/v1/tax/prefill           ?year -> ledger-derived suggestion
```

## Steps
1. `get_or_create(user_id, tax_year)` — the same lazy-creation pattern as `user_settings` (P2-01),
   idempotent under concurrent first reads, defaults per §4c: `household='single'`, zero
   everywhere, `pfu_opt_out=false`.
2. `tax_year` is a path segment, not a body field, and is validated as a plausible year (not in the
   future, not before the app could hold data). A profile for next year's income cannot be
   estimated, and offering it would imply otherwise.
3. Partial patch semantics with `model_dump(exclude_unset=True)`: omitted fields keep their stored
   value. All money fields must be `>= 0`; `dependents_count >= 0`; `household` one of the two
   values.
4. **No property income field** — it is derived from `properties` (§4c) so the two panels cannot
   disagree about the same rent. Reject the field if a client sends it rather than accepting and
   ignoring it.
5. `/tax/prefill` reads the ledger for the requested year: salaries and pensions from income-kind
   categories, dividends and interest from their categories where the user has them. Return
   `months_covered` and a per-field confidence — `high` when 12 months are covered and the monthly
   figures are stable, `low` when the year is partly imported. A figure derived from four months of
   statements is not an annual income, and saying so is the difference between a suggestion and a
   trap.
6. The prefill is a **read**. It writes nothing, and the response carries `source='ledger'` so the
   UI can label every prefilled field as such before the user accepts it (§5c rationale).
7. A year with no ledger data returns zeros with `months_covered=0`, not a 404 — "nothing imported
   for 2024" is an answer.

## Acceptance
- `GET` on a fresh year returns defaults and creates exactly one row; calling it twice creates no
  second row.
- `PATCH` updates only supplied fields; negative money or an unknown `household` is a 422; a
  `property_income_minor` field in the payload is a 422.
- A future `tax_year` is refused.
- The prefill never writes: the profile is byte-identical before and after calling it.
- Prefill confidence reflects coverage, and an empty year returns zeros with `months_covered=0`.
- Profiles are user-scoped; another user's year is a 404.
- `ruff` + `ty` clean.

## Tests
- `test_profiles.py`: lazy creation idempotent; partial patch; validation matrix; rejected property
  income field; future year refused; user scoping.
- `test_prefill.py`: sums over seeded transactions; `months_covered` and confidence for a full year
  versus a four-month year; empty year returns zeros; no write occurs (assert the profile row is
  unchanged).

## Commits
- `feat(tax): add tax profile lazy creation and patch endpoints`
- `feat(tax): add the ledger prefill suggestion endpoint`
