# P3-04 — Mortgages API & debt ratio
Scope: backend
Depends on: P3-03
Skills: fastapi-backend, database, multi-currency, testing
PROJECT.md: §5c, §15

## Objective
CRUD over declared mortgages, the derived schedule endpoint, and the summary carrying the debt
ratio with its income source. Nothing here writes a transaction, moves an account balance, or
persists a schedule row.

## Files
- `backend/app/features/mortgages/router.py`, `schemas.py`, `service.py`, `repository.py`
- `backend/tests/features/mortgages/test_mortgages.py`, `test_schedule.py`, `test_debt_ratio.py`

## Contract slice
```
GET    /api/v1/mortgages                 ?status -> [mortgage + derived summary fields]
POST   /api/v1/mortgages
GET    /api/v1/mortgages/{id}            -> mortgage + cost totals + taeg_bps
PATCH  /api/v1/mortgages/{id}
DELETE /api/v1/mortgages/{id}             (archive)
GET    /api/v1/mortgages/{id}/schedule   ?from&to&granularity=month|year
GET    /api/v1/mortgages/summary         -> totals + debt_ratio_bps + income_source
                                           + by_lender[] + outstanding_series[]
```

## Steps
1. CRUD, user-scoped. Validation: `principal_minor > 0`, `term_months > 0`, `annual_rate_bps >= 0`,
   `insurance_monthly_minor >= 0`, `repayment_type` one of the two values, and a `property_id` that
   must belong to the caller. `currency` comes from the user (Phase 1 one-currency rule, no
   selector; see the multi-currency skill).
2. Every derived figure comes from the P3-03 engine at read time: `monthly_payment_minor`,
   `total_instalment_minor`, `outstanding_principal_minor`, `paid_principal_pct`,
   `remaining_months`, `next_payment_on`, and on the detail the cost totals and `taeg_bps`.
   **Nothing derived is stored** — compute once per request and reuse inside it.
3. `outstanding_principal_minor` is the schedule outstanding *today*. A loan whose
   `first_payment_date` is in the future reports the full principal and 0 % paid rather than a
   negative row count.
4. `/schedule` pages by date window, not by offset — the natural unit is "the year I am looking
   at". `granularity=year` aggregates the engine's own rows, never a second formula. An unbounded
   request is capped at the loan term; there is nothing beyond it.
5. `DELETE` archives (status `archived`), as accounts and goals do. A loan reaching its last
   instalment does **not** auto-flip to `repaid`: status is user intent, and a schedule that has
   run out already shows `remaining_months = 0`. A PATCH on status does the flip.
6. `/summary`: `monthly_charge_minor` and `total_outstanding_minor` sum over **active** loans only,
   with `total_principal_minor`, `repaid_principal_minor` and `repaid_pct_bps` beside them, plus
   `next_payment_on` and how many instalments fall on it. `by_lender[]` gives the monthly charge
   per lender so the panel can legend it without re-listing loans.
7. Debt ratio per §15: `declared_monthly_income_minor` when set (income source `declared`), else
   the **median** of the last 12 complete months of income-kind category totals across
   non-archived accounts (`ledger`), else `null` with `unknown` when fewer than 3 complete months
   exist. Median, not mean: a 13th-month bonus should not lift a ratio the user will plan around.
   Return `hcsf_limit_bps` and `over_limit` as data and **never refuse a write because of them** —
   the app makes no lending decisions (§15).
8. Archived loans are excluded from every aggregate and from the default list; `?status=archived`
   returns them.
9. `outstanding_series[]`: the **combined** outstanding principal of all active loans, one point per
   month from the earliest first payment to the last instalment of the longest loan, plus a marker
   per loan for the month it ends. `12-credits.md` §3 draws this as the panel's trajectory chart,
   and the frontend is forbidden from summing schedules in Dart (§15: one engine), so the join has
   to happen here. It is aggregated from the same P3-03 rows as `/schedule` — never a second
   formula — and like everything else in this card it is computed per request and stored nowhere.

## Acceptance
- Derived fields match the engine for identical inputs, and no derived figure or schedule row is
  persisted (assert no writes beyond the mortgage row itself).
- A future-dated loan reports full principal, 0 % paid, and `next_payment_on` equal to
  `first_payment_date`.
- Yearly granularity totals equal the month rows they aggregate.
- `outstanding_series` at any month equals the sum of each active loan's outstanding at that month,
  starts at the earliest first payment and reaches 0 at the last instalment; `by_lender` sums to
  `monthly_charge_minor`.
- The ratio uses the declared override when present, the ledger median otherwise, and says which;
  with fewer than 3 complete months it is null and unknown.
- `over_limit` is informative: a 60 % ratio still accepts POST and PATCH with 2xx.
- A degenerate loan (instalment below its first interest) returns 422 in the error envelope.
- A property owned by another user is refused; cross-user access to any route is a 404.
- `ruff` + `ty` clean.

## Tests
- `test_mortgages.py`: CRUD; the validation matrix; archive and restore; `repaid` only via PATCH;
  user scoping; currency copied from the user.
- `test_schedule.py`: window filtering; yearly totals equal their months; cap at term;
  future-dated loan; the summary's `outstanding_series` reconciled against two loans' own schedules
  month by month, including the step a later-starting loan adds and its end marker.
- `test_debt_ratio.py`: declared override wins; ledger median across 12 months with an outlier
  month proving median-not-mean; under 3 months gives null and unknown; archived loans excluded;
  `over_limit` never blocks a write.

## Commits
- `feat(mortgages): add mortgage CRUD with derived schedule figures`
- `feat(mortgages): add the amortisation schedule endpoint`
- `feat(mortgages): add the summary endpoint with the debt ratio`
