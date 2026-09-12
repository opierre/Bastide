# P3-02 — Tax parameter & barème seeding
Scope: backend
Depends on: P3-01
Skills: database, testing
PROJECT.md: §16

## Objective
The system (null-`user_id`) rows of `tax_brackets` and `tax_parameters` for one tax year, seeded by
migration, **with the official figures verified and the verification recorded**. This is the card
where one wrong number silently becomes every user's tax estimate, so the verification is part of
the deliverable, not diligence around it.

## Files
- `backend/app/features/tax/seed.py` — the parameter set as data, one module-level structure
- `backend/migrations/versions/*_seed_tax_parameters.py`
- `backend/tests/features/tax/test_seed.py`

## Steps
1. Transcribe the seeded set from `PROJECT.md` §16 into `seed.py`: the `ir` and `ifi` bracket sets
   and every scalar key, as **integers in minor units or bps** — never a float, never a percentage
   written as `0.30`.
2. **Verify every figure against the official source** (impots.gouv.fr, BOFiP, or the Code général
   des impôts) before committing. Record in the migration docstring, for the set as a whole: the
   source, the tax year the figures apply to, and the date of the check. §16 requires this because
   a barème changes annually without anyone touching the code, and an unsourced number in a
   migration is unauditable a year later.
3. If a verified figure **differs** from §16's table, the official value wins — change `seed.py`
   *and* `PROJECT.md` §16 in the same commit, and say so in the PR. Never leave the spec and the
   seed disagreeing.
4. Seed idempotently: insert only where the system row is absent, so re-running the migration
   chain on a populated database is safe.
5. `downgrade()` deletes **only** the system rows for that year. A user's overrides are their data
   and a downgrade must not touch them.
6. Bracket `lower_bound_minor` ascending from 0 with `ordinal` matching; the top band has no
   ceiling, which is expressed by being the last ordinal, not by a sentinel value.
7. No user-facing strings here. Bracket and parameter labels are ARB keys on the frontend (P3-14);
   this table stores numbers and machine keys only.

## Acceptance
- After `upgrade head` the year's `ir` bands are contiguous and ascending by ordinal and bound, the
  `ifi` bands likewise, and every scalar key from §16 exists with the correct `unit`.
- Every seeded value is an integer; no column holds a rate as a fraction.
- Re-running the seed migration inserts nothing the second time.
- `downgrade` removes the system rows and leaves a planted user override untouched.
- The migration docstring names source, tax year, and verification date.
- `ruff` + `ty` clean.

## Tests
- `test_seed.py`: the seeded rows match `seed.py` exactly after migration; bands contiguous and
  ascending with no gap or overlap; idempotent re-seed; a planted user override survives
  `downgrade`; every `unit` is one of `bps|minor|count` and agrees with its key's suffix.

## Commits
- `feat(tax): seed the system barème and tax parameters`
