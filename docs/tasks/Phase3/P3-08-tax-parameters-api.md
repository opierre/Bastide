# P3-08 — Tax parameters API & override resolution
Scope: backend
Depends on: P3-02
Skills: fastapi-backend, database, testing
PROJECT.md: §16, §5c, §4c

## Objective
Read the resolved parameter set for a year, override any of it per user, and reset back to the
seeded values. One resolution function, shared with the estimate (P3-07), so the numbers the user
sees are literally the numbers the estimate ran on.

## Files
- `backend/app/features/tax/parameters.py` — resolution
- `backend/app/features/tax/router.py`, `schemas.py` — edit
- `backend/tests/features/tax/test_parameters.py`

## Contract slice
```
GET    /api/v1/tax/parameters/{year}  -> brackets, parameters, overridden
PATCH  /api/v1/tax/parameters/{year}  parameters and/or brackets -> the resolved set
DELETE /api/v1/tax/parameters/{year}  ?key&kind -> the resolved set
```

## Steps
1. Resolution per §4c: for each key a user row shadows the system row; for brackets a user set
   shadows the system set **per year and kind, as a whole**. A half-replaced barème is not a
   barème — resolving band by band would let a user create a set with a gap and never see it.
2. `GET` returns the resolved set plus `overridden`, naming the keys and bracket kinds that came
   from user rows. That list is what the panel's « ajusté » markers are drawn from (§16).
3. `PATCH` writes user-owned rows: scalar keys individually; a bracket kind as a full replacement
   (drop that kind's user rows, insert the new set). Validate a submitted set **before** writing:
   ascending, contiguous from 0, no overlap, integer bps, at least one band. An invalid set is
   refused whole with 422 — a partially applied barème is worse than a rejected one.
4. Scalar validation by `unit`: `bps` within 0..10000 unless the key documents a wider range,
   `minor` >= 0, `count` >= 0. An unknown key is a 422, never a silently created row — the seeded
   set defines what exists.
5. `DELETE` with no filter drops **all** the caller's overrides for that year; with `key` or `kind`
   it drops that one. It never touches system rows.
6. Overrides are per year: a 2025 override says nothing about 2026, which is exactly the axis a
   barème changes on.
7. Every write returns the newly resolved set, so the client never guesses what resolution produced
   and never needs a second round trip to find out.
8. Overrides are the user's data: include the two tables' user-owned rows in the backup scope
   (§14). A user who tuned their parameters and then restored a backup must not silently get the
   seeded set back.

## Acceptance
- Resolution returns system values with no overrides, user values where they exist, and reports
  both in `overridden`.
- A bracket kind is replaced wholesale; a descending, gapped, overlapping or empty set is refused
  with 422 and nothing is written.
- An unknown scalar key is a 422; out-of-range values by unit are 422.
- `DELETE` restores the seeded set exactly, both whole-year and per-key.
- Overrides for one year do not affect another.
- P3-07's estimate reflects an override immediately and reports `parameter_source='overridden'`.
- User-owned parameter and bracket rows survive a backup and restore round trip.
- Cross-user access is a 404, and a user can never write a system row.
- `ruff` + `ty` clean.

## Tests
- `test_parameters.py`: resolution with none, some and all keys overridden; wholesale bracket
  replacement; the invalid-set matrix; unknown key; unit ranges; whole-year and targeted reset;
  per-year isolation; the estimate changing under an override; the backup round trip; a user
  attempting to mutate a NULL-`user_id` row.

## Commits
- `feat(tax): add parameter resolution with per-user overrides`
- `feat(tax): add the tax parameters endpoints`
- `feat(backup): include tax parameter overrides in the archive`
