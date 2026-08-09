# P2-10 — Recurring detector
Scope: backend
Depends on: P2-02
Skills: database, fastapi-backend, testing
PROJECT.md: §12, §4b

## Objective
The detection algorithm: group a user's outflows into candidate recurring series by merchant and
cadence, with amount tolerance, price-change detection, and idempotent re-runs. Pure logic in one
module, persisted by a thin service. Lifecycle endpoints are P2-11.

## Files
- `backend/app/features/recurring/{detector,normalize}.py` — pure, no DB
- `backend/app/features/recurring/{repository,service}.py`
- `backend/tests/features/recurring/{test_normalize,test_detector,test_detect_service}.py`

## Contract slice
```
POST /api/v1/recurring/detect {account_id?} → {created_count, updated_count}
```

## Steps
1. `normalize.py` — `merchant_key(transaction) -> str`: prefer `merchant`; else
   `description_clean` stripped of the parts banks vary per occurrence (embedded dates,
   card-sequence digits, trailing reference numbers), case-folded, whitespace-collapsed. Pure and
   heavily tested — every downstream grouping decision rests on it.
2. `detector.py` — `detect(transactions) -> list[SeriesCandidate]`, implementing §12 exactly:
   outflows only; ≥ 3 occurrences; median gap classifies cadence (weekly 5–9 d, monthly 26–35 d,
   quarterly 85–95 d, yearly 350–380 d); **every** gap within ±25 % of the median (floor ±3 days);
   every amount within ±10 % or ±200 minor units of the median, whichever is larger.
   Groups failing either regularity test yield no series — do not emit `irregular` candidates
   from detection; that cadence exists only for user-declared series (P2-11).
3. Price change: the newest occurrence outside the amount tolerance of the median of the earlier
   ones, cadence still holding → record `price_change_minor` (signed) and `price_changed_at`, and
   re-baseline `expected_amount_minor` on the newer amount. A series whose price changed must not
   thereby fail its own amount test — compute regularity on the pre-change occurrences.
4. `next_expected_date = last_seen_date + median_interval_days`. Do **not** persist a "missed"
   flag — §12: it stops being true the moment the charge lands. It is derived at read time
   (P2-11).
5. Service: run the detector over the user's transactions (optionally one account), then upsert
   on `(account_id, merchant_key)`. On update it **must not** touch: a series with
   `is_manual=true`, one with `status` in `dismissed`/`cancelled`, or a user-edited `label` or
   `category_id`. Refresh only the observed fields (amounts, dates, counts, cadence).
   Replace the occurrence links for the series in the same transaction.
6. Detection is O(n log n) over the account's rows; it re-reads the whole history rather than
   only new rows, because a third occurrence can promote a group detected long ago. Fine at this
   scale (§4's scale note).

## Acceptance
- Three regular monthly charges of the same amount → one monthly series with the right
  `expected_amount_minor` and `next_expected_date`.
- Two occurrences → no series. Irregular gaps → no series. Wildly varying amounts → no series.
- A €9.99 → €12.99 increase on an otherwise regular series → series kept, `price_change_minor`
  and `price_changed_at` set, expected amount re-baselined.
- A small subscription varying by a couple of cents still qualifies (the minor-unit floor).
- Re-running detection creates no duplicates and preserves user edits, dismissals, cancellations,
  and manual series.
- Inflows are never detected as subscriptions.
- `ruff` + `ty` clean.

## Tests
- `test_normalize.py`: real French bank label shapes (embedded dates, `CB` prefixes, card
  sequence digits, reference numbers) collapse to one key; genuinely different merchants do not.
- `test_detector.py`: table-driven over each rule in step 2 — qualifying and each failing case;
  weekly/monthly/quarterly/yearly classification; price-change re-baselining; boundary values of
  both tolerances.
- `test_detect_service.py`: idempotent re-run (counts and rows); user edits/dismissals/manual
  series preserved; occurrence links replaced not duplicated; user- and account-scoping.

## Commits
- `feat(recurring): add merchant key normalization`
- `feat(recurring): add cadence and amount detection algorithm`
- `feat(recurring): add idempotent detection service and endpoint`
