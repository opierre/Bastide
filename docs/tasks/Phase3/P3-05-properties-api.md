# P3-05 — Properties API
Scope: backend
Depends on: P3-01
Skills: fastapi-backend, database, multi-currency, testing
PROJECT.md: §5c, §4c, §16, §18

## Objective
CRUD over declared properties, with the user's share of each value derived. This entity exists
because two features need it — IFI (§16) and net worth (§18) — so it must serve both without
either one keeping its own copy of a valuation.

## Files
- `backend/app/features/properties/router.py`, `schemas.py`, `service.py`, `repository.py`
- `backend/tests/features/properties/test_properties.py`

## Contract slice
```
GET    /api/v1/properties       ?archived -> [property + user_share_value_minor]
POST   /api/v1/properties
GET    /api/v1/properties/{id}  -> property + user_share_value_minor + linked_mortgages
PATCH  /api/v1/properties/{id}
DELETE /api/v1/properties/{id}   (archive)
```

## Steps
1. CRUD, user-scoped, per §4c. `market_value_minor > 0`; `ownership_bps` in 1..10000, default
   10000; `kind` one of the four values; `valued_on` required and **not in the future** — a
   valuation dated tomorrow is a typo, and §18 leans on this date to caveat the net-worth series.
2. `user_share_value_minor = round_half_up(market_value_minor * ownership_bps / 10000)` — derived,
   never stored, and the only place that arithmetic lives.
3. Rent fields are coupled and validated as a set: `property_regime` requires `annual_rent_minor`,
   and `annual_charges_minor` is accepted **only** under `reel`. A `micro_foncier` property
   carrying charges is a contradiction the estimate would silently resolve one way or the other
   (§16), so refuse it with a 422 instead of choosing for the user.
4. `kind='rental'` with no rent fields is allowed — a vacant rental is a real state — but rent
   fields on a non-rental kind are refused.
5. `DELETE` archives. Archived properties leave every aggregate (the §16 IFI base, §18 assets) and
   are returned by `?archived=true`.
6. `linked_mortgages` is read from `mortgages.property_id`: the detail shows what the IFI base will
   net off (§16), so the user can see the link they made.
7. Archiving keeps the loan link intact — the loan still exists. P3-01's `ON DELETE SET NULL`
   covers the hard-delete path that archiving deliberately avoids.
8. `currency` is the user's; no per-property currency, no selector.

## Acceptance
- `user_share_value_minor` is exact at 100 % ownership and correctly rounded below it.
- The rent/regime/charges matrix behaves as specified, with 422 in the error envelope.
- A future `valued_on` is refused.
- Archived properties are absent from the default list and present under `?archived=true`.
- `linked_mortgages` lists exactly the caller's loans pointing at that property.
- Cross-user access is a 404.
- `ruff` + `ty` clean.

## Tests
- `test_properties.py`: CRUD; ownership rounding at 10000, 5000 and an odd share; the full
  rent/regime/charges matrix; future `valued_on` refused; archive filtering; `linked_mortgages`
  content; user scoping; currency copied from the user.

## Commits
- `feat(properties): add property CRUD with derived ownership share`
