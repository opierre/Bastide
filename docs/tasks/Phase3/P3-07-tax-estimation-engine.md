# P3-07 — Tax estimation engine & endpoint
Scope: backend
Depends on: P3-02, P3-05, P3-06
Skills: fastapi-backend, database, testing
PROJECT.md: §16, §5c

## Objective
The estimate: a pure function from a tax profile, the resolved parameter set and the user's
properties to IR, PFU, social charges and IFI, with a per-component breakdown and an explicit list
of what it did not model. Estimation-first — being honest about its own limits is part of the job.

## Files
- `backend/app/features/tax/engine.py` — pure, no ORM
- `backend/app/features/tax/service.py` — edit: assemble inputs, resolve parameters
- `backend/app/features/tax/router.py` — edit: the estimate route
- `backend/tests/features/tax/test_engine.py`, `test_estimate_endpoint.py`

## Contract slice
```
GET /api/v1/tax/profiles/{year}/estimate -> parts, taxable_income_minor, ir_minor, decote_minor,
      quotient_capped, average_rate_bps, marginal_rate_bps, pfu, property, ifi,
      total_due_minor, breakdown, parameter_source, ignored_keys, currency
```

## Steps
1. `engine.py` takes plain data — profile values, resolved brackets and parameters, property rows —
   and returns the response shape. No session, no HTTP: the pipeline must be testable against
   hand-computed cases, which is the only way anyone can ever check it.
2. Implement §16's pipeline **in its stated order**; the order is load-bearing, since the
   abattements feed the RNI, the RNI feeds the quotient, and the quotient feeds the décote:
   salaries and pensions abattement, property income, the capital-income route, RNI, parts, IR brut
   and the quotient cap, décote, credits, IFI, total.
3. `Decimal` for every intermediate, integer minor units for every returned amount, rates in bps.
   The IR is rounded to the **whole currency unit** (French practice) and intermediates stay in
   minor units, so the rounding happens once, at the end.
4. The quotient cap: compute the IR at base parts (1 or 2) and at full parts; the advantage the
   extra half-parts confer is capped at `quotient_half_part_cap_minor` per half-part, and
   `quotient_capped` reports when the cap bit. Capping silently makes a household's tax look
   arbitrary.
5. Capital income takes exactly one road, chosen by `pfu_opt_out`: the PFU (flat, outside the
   barème) or the barème with the dividend abattement. Both carry social charges at the parameter
   rate. Never both roads, never a blend.
6. Property income is derived from the caller's non-archived properties (§4c): `micro_foncier`
   under the ceiling takes the abattement; `reel` deducts charges and floors at 0. Gross rent above
   the micro ceiling is estimated under `reel`, and the response names the regime it used.
7. IFI only when the base reaches the threshold: the sum of `user_share_value_minor`, primary
   residence less its abattement, **minus the outstanding principal of the mortgages linked to
   those properties** (via P3-03's engine), then the barème and the décote band. Return the base's
   **components** — one line per counted property at its held share, the residence abattement, each
   netted mortgage — alongside the base and the threshold. `15-synthese.md` §Biens view draws that
   build-up inside Synthèse, and the alternative is the frontend re-deriving an IFI base from
   `/properties`, which is the duplication §16 exists to prevent. `Non redevable` is a state with a
   base and a threshold, not an absent component: emit the row with a zero amount.
8. `breakdown` carries one entry per component, so the total is never a number without a
   derivation. `ignored_keys` lists §16's not-modelled regimes as **machine keys** — the frontend
   owns the wording, in fr and en.
9. `parameter_source` is `overridden` when any resolved key or bracket set came from a user row.
   Call P3-08's resolution rather than re-reading the tables here.
10. Zero income is a valid estimate: all zeros, `total_due_minor = 0`, and `average_rate_bps`
    reports 0 rather than dividing by zero or returning NaN.

## Acceptance
- Hand-computed reference cases match to the euro: single with salary only; couple with two
  children where the quotient cap bites; a décote case; PFU versus barème over the same capital
  income; `micro_foncier` versus `reel`; an IFI case just over the threshold inside the décote
  band; a zero-income profile.
- The two capital roads are mutually exclusive in every response.
- Property income comes from `properties` and follows a change to one.
- The IFI base nets off only mortgages linked to the counted properties, and its components sum to
  the reported base.
- A user under the threshold still gets an IFI component with its base and threshold and a zero
  amount, never a missing entry.
- `average_rate_bps` and `marginal_rate_bps` agree with the bracket that applied.
- `ignored_keys` is non-empty and machine-readable; no user-facing prose in the response.
- No `float` in `engine.py`; no estimate is persisted anywhere.
- `ruff` + `ty` clean.

## Tests
- `test_engine.py`: the reference cases as a data-driven table, each asserting its **component**
  amounts and not only the total — a total that is right for two wrong reasons is the failure this
  catches.
- `test_estimate_endpoint.py`: the endpoint assembles profile, parameters and properties; an
  override shows up in `parameter_source`; user scoping; a year with no profile is created lazily
  and estimated at zero.

## Commits
- `feat(tax): add the income tax and IFI estimation engine`
- `feat(tax): add the estimate endpoint with its component breakdown`
