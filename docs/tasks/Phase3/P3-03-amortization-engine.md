# P3-03 — Amortisation & TAEG engine
Scope: backend
Depends on: P3-01
Skills: fastapi-backend, testing
PROJECT.md: §15, §4c

## Objective
A pure, dependency-free module turning the declared loan inputs into a full instalment schedule
with its cost totals and an indicative TAEG. No ORM, no HTTP, no I/O — this is the one function
both the Crédits panel and the Simulateur compute against, so it must be callable with plain
integers.

## Files
- `backend/app/features/mortgages/engine.py`
- `backend/tests/features/mortgages/test_engine.py`

## Steps
1. Signature takes integers and a date only: `principal_minor`, `annual_rate_bps`, `term_months`,
   `insurance_monthly_minor`, `repayment_type`, `first_payment_date`, `upfront_fees_minor`.
   Rows carry `ordinal, due_on, instalment_minor, interest_minor, principal_minor,
   insurance_minor, outstanding_after_minor`, plus totals.
2. Arithmetic per §15: `i = annual_rate_bps / (12 x 10_000)` as an exact `Decimal` — **never a
   float anywhere in this module**. `constant_payment`: `payment = P x i / (1 - (1 + i)^-n)`,
   rounded half-up to minor units **once**, then held constant. Per period
   `interest_k = round_half_up(outstanding x i)` and `principal_k = payment - interest_k`.
3. **The final instalment absorbs the residue**: `principal_n = outstanding_{n-1}` and
   `payment_n = principal_n + interest_n`. A schedule ending a few cents short draws a loan that
   was never repaid, which is worse than an uneven last row.
4. `interest_only`: every instalment is `round_half_up(P x i)`; the principal is repaid whole in
   the final row.
5. Insurance rides on top and is never amortised: `instalment = payment + insurance`. It is not
   interest and it does not reduce the principal.
6. A zero rate is a real case (a family loan, a PTZ-shaped input): `i = 0` must yield
   `payment = round_half_up(P / n)` with the residue in the last row, not a division by zero.
7. Raise a dedicated exception — which P3-04 maps to 422 — for a loan whose first instalment does
   not cover its first interest. The closed form has no answer for a balance that grows, and the
   panel has nothing to draw.
8. `taeg_bps`: the internal rate of return of the actual flows — advance `principal -
   upfront_fees` against instalments **including insurance** — by bisection on the monthly rate to
   a tolerance stable at bps resolution, annualised as `(1 + m)^12 - 1`. Return an int in bps and
   name it indicative in the docstring (§15: a real TAEG includes fees we never see).
9. `outstanding_at(date)` and the `year` aggregation derive from the same generated rows — one
   generator, two views, so a yearly total can never disagree with the months it sums.

## Acceptance
- `sum(principal_k) == principal_minor` exactly and `outstanding_after_n == 0` for every tested
  loan, including awkward ones: odd rates, 1-month terms, 360-month terms, zero rate.
- No `principal_k <= 0` in any produced schedule; the degenerate loan raises instead.
- No `float` appears in the module (grep-able), and no result depends on `Decimal` context leaking
  in from the caller.
- Yearly aggregation equals the sum of its months, to the cent.
- A reference loan matches a hand-computed table held in the test as data.
- `ruff` + `ty` clean.

## Tests
- `test_engine.py`: the reference loan row for row; both invariants over a matrix of rates, terms
  and principals; zero rate; 1-month term; `interest_only` shape; insurance absent from interest
  and principal; degenerate loan raises; TAEG of a fee-free, insurance-free loan equals the nominal
  rate's annual equivalent within 1 bps, and rises when fees or insurance are added.

## Commits
- `feat(mortgages): add the amortisation schedule engine`
- `feat(mortgages): add indicative TAEG computation`
