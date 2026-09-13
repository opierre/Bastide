# P3-05 — Properties API
Scope: backend
Depends on: P3-01
Skills: fastapi-backend, database, multi-currency, testing
PROJECT.md: §5c, §4c, §18

## Objective
CRUD over declared properties, with the user's share of each value derived. This entity exists
for net worth (§18), which needs one valuation per property rather than a figure duplicated per
panel.

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
   never stored, and the only place that arithmetic lives. Return
   `acquisition_delta_minor` beside it — the held share less the held share of the acquisition
   price, null when no acquisition price was declared — because `15-synthese.md` §Biens view prints
   it on every card and the frontend derives no money.
3. ~~Rent fields~~ — **removed with the tax feature.** `annual_rent_minor`, `annual_charges_minor`
   and `property_regime` and their validation matrix are gone (migration `c7e2a9d4b150`); a
   payload carrying them is refused as unknown.
4. `kind` is a label only; `rental` carries no extra fields.
5. `DELETE` archives. Archived properties leave every aggregate (§18 assets) and are returned by
   `?archived=true`.
6. `linked_mortgages` is read from `mortgages.property_id`, so the user can see the link they made.
7. Archiving keeps the loan link intact — the loan still exists. P3-01's `ON DELETE SET NULL`
   covers the hard-delete path that archiving deliberately avoids.
8. `currency` is the user's; no per-property currency, no selector.
9. « Nouvelle estimation » in the panel (`15-synthese.md`) is a **PATCH of `market_value_minor` and
   `valued_on` together** — there is no valuation history table in §4c, and a property has exactly
   one declared value (the assumption §18's series leans on). If a per-property history is ever
   wanted, that is a data-model decision, not something this endpoint grows quietly: stop and ask.

## Acceptance
- `user_share_value_minor` is exact at 100 % ownership and correctly rounded below it;
  `acquisition_delta_minor` is on the same held-share basis and null without an acquisition price.
- A future `valued_on` is refused.
- Archived properties are absent from the default list and present under `?archived=true`.
- `linked_mortgages` lists exactly the caller's loans pointing at that property.
- Cross-user access is a 404.
- `ruff` + `ty` clean.

## Tests
- `test_properties.py`: CRUD; ownership rounding at 10000, 5000 and an odd share; rent fields refused as
  unknown; future `valued_on` refused; archive filtering; `linked_mortgages`
  content; user scoping; currency copied from the user.

## Commits
- `feat(properties): add property CRUD with derived ownership share`
