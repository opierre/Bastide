# P3-09 — Simulator API
Scope: backend
Depends on: P3-03, P3-04
Skills: fastapi-backend, database, testing
PROJECT.md: §17, §5c, §4c

## Objective
A stateless compute endpoint over the same schedule engine as a real loan, plus saved scenarios
that store **inputs only**. One engine, so a simulated loan and a declared one can never disagree
about identical inputs.

## Files
> The simulator lives **inside the mortgages feature** on the backend, because it computes through
> that feature's engine — a `simulator/` package would either reach across a feature boundary
> (which the architecture skill forbids) or copy the engine (which §17 forbids). On the frontend it
> is its own panel folder, because there it shares no code with Crédits, only an API.

- `backend/app/features/mortgages/simulations_router.py`, `simulations_service.py`
- `backend/tests/features/mortgages/test_simulations.py`, `test_compute.py`

## Contract slice
```
GET    /api/v1/simulations          -> [simulation]
POST   /api/v1/simulations
PATCH  /api/v1/simulations/{id}
DELETE /api/v1/simulations/{id}      (hard delete)
POST   /api/v1/simulations/compute  -> payment, cost totals, taeg_bps, yearly, debt_ratio, hcsf,
                                       max_borrowable_minor
```

## Steps
1. `/compute` is **stateless**: it persists nothing, requires no saved scenario, and is safe to
   call on every keystroke-debounced change in the panel. It is a POST only because its input is a
   body, not because it writes.
2. Reuse P3-03's engine for the payment, cost totals and `taeg_bps`. The response carries a
   **year-by-year** summary rather than 300 rows: month-level detail is what
   `/mortgages/{id}/schedule` is for, once the loan is real.
3. `cost_over_price_bps` = total cost over `property_price_minor` when a price is given, else null.
   It answers the question the user actually has — what the credit adds to the purchase — and is
   meaningless without a price, so it is null rather than 0.
4. `include_existing_loans` adds the caller's **active** mortgages to the charge side of the
   ratio. That is the real question: not "can I afford this loan" but "can I afford this loan
   *too*". Income resolution is P3-04's, shared and unchanged.
5. `max_borrowable_minor` solves the same formula backwards for the principal that lands the ratio
   exactly on `hcsf_limit_bps` at the given rate, term and insurance — null when income is unknown.
   Solve it with the engine, by bisection on the principal, so it can never drift from the forward
   computation.
6. `hcsf` reports `within_ratio`, `within_term`, `limit_bps` and `max_term_months` as data. A
   breach is displayed, never enforced: no 4xx, no refusal to save (§15, §17).
7. Saved scenarios: CRUD, user-scoped, inputs only, with the same validation as a mortgage
   (P3-04 step 1) minus the loan-only fields. `DELETE` is a **hard** delete — a scenario is a
   scratchpad, not history, and archiving it would leave debris the user cannot clear.
8. Cap the saved set at a sane number per user (e.g. 20) with a 422 beyond it; the panel compares
   at most 3 (§17) and an unbounded list is a list nobody curates.

## Acceptance
- `/compute` writes nothing (assert the simulation table is untouched) and returns figures
  identical to a declared loan with the same inputs.
- Yearly rows sum to the engine's month rows, to the cent.
- `cost_over_price_bps` is null without a price and correct with one.
- `include_existing_loans` changes only the ratio, never the payment or the cost.
- `max_borrowable_minor` fed back into `/compute` produces a ratio equal to `hcsf_limit_bps` within
  1 bps, and is null when income is unknown.
- An HCSF breach still returns 2xx from both `/compute` and the scenario writes.
- Scenario CRUD is user-scoped; delete is hard; the cap returns 422.
- No computed result is stored on a scenario row.
- `ruff` + `ty` clean.

## Tests
- `test_compute.py`: parity with a declared loan; yearly aggregation; null and non-null
  `cost_over_price_bps`; existing loans in the ratio; the `max_borrowable` round trip; unknown
  income; a breach returning 2xx; statelessness.
- `test_simulations.py`: CRUD; validation; hard delete; the per-user cap; user scoping.

## Commits
- `feat(mortgages): add the stateless loan simulation endpoint`
- `feat(mortgages): add saved simulation scenarios`
