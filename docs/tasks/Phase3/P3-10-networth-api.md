# P3-10 — Net-worth API
Scope: backend
Depends on: P3-04, P3-05
Skills: fastapi-backend, database, testing
PROJECT.md: §18, §5c

## Objective
One derived summary: assets, liabilities, net worth, and a 12-month series that is explicit about
the one thing it cannot know. No new stored money anywhere.

## Files
- `backend/app/features/networth/router.py`, `service.py`
- `backend/tests/features/networth/test_networth.py`

## Contract slice
```
GET /api/v1/networth/summary -> assets, liabilities, net_worth_minor, composition[],
      month_delta_minor, series, property_values_held_flat, valued_on_oldest, currency
```

## Steps
1. Assets = derived balances of non-archived accounts (§4) + the sum of `user_share_value_minor`
   over non-archived properties (P3-05's formula, reused — not reimplemented).
   Liabilities = the sum of outstanding principal over **active** mortgages (P3-03's engine).
2. **Goals are excluded.** An allocation labels money already counted inside an account (§13), so
   adding envelopes would count the same euros twice. Assert it in a test rather than trusting
   nobody adds it later.
3. **Subscriptions are excluded.** A future charge is not a debt; treating next
   month's Netflix as one would make net worth a mood rather than a measurement.
4. The 12-month series: account history from the monthly balance snapshots (§4), mortgage history
   from the derived schedules at each month end. A property has exactly one declared value, so past
   points hold property values flat, `property_values_held_flat` is true whenever any property is
   counted, and `valued_on_oldest` gives the UI the date to caveat with. **Never interpolate or
   back-date a valuation the user did not give** — that is a fabrication, not a smoothing.
5. Months before a user's first snapshot are omitted, not zero-filled: a zero net worth in January
   because nothing was imported yet is a false statement about their money.
6. `composition[]` breaks the asset side down the way `15-synthese.md` §Row 2 draws it: one entry
   per account **type** and one per property **kind**, each with its amount and its share in bps of
   total assets, properties counted at the held share only. The panel renders a stacked strip and
   its legend from this list and computes no percentage itself.
7. `month_delta_minor` is this month's net worth minus last month's, from the series — null when
   there is no previous point. It is the pill the hero carries, and deriving it in Dart would mean
   the panel disagreeing with its own chart on a month the series skipped.
8. One round of queries, no N+1 across accounts or loans; the whole summary is a single request's
   work and is not cached (it is cheap, and a stale net worth is worse than a recomputed one).

## Acceptance
- Assets, liabilities and net worth reconcile exactly with their parts, in integer minor units, and
  `composition` sums to the asset total with shares summing to 10000 bps.
- `month_delta_minor` equals the last two series points' difference and is null with fewer than two.
- A user whose loans exceed their assets gets a negative `net_worth_minor`, not a floor at zero.
- Archived accounts, archived properties and non-active loans are excluded.
- Goals and subscriptions never appear in any figure.
- `property_values_held_flat` is true when properties are counted and false when none are.
- The series omits months with no snapshot rather than reporting zero.
- A user with no accounts, properties or loans gets zeros and an empty series, not an error.
- Cross-user isolation holds for every figure.
- `ruff` + `ty` clean.

## Tests
- `test_networth.py`: the reconciliation over a seeded fixture; exclusions one by one (archived
  account, archived property, archived and repaid loans, a funded goal, an active subscription);
  the series across snapshots with a loan amortising; flat-property flag and `valued_on_oldest`;
  the empty user; user scoping.

## Commits
- `feat(networth): add the net-worth summary endpoint`
