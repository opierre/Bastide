# P2-11 — Subscriptions API & lifecycle
Scope: backend
Depends on: P2-10
Skills: fastapi-backend, database, i18n-l10n, testing
PROJECT.md: §5b, §12

## Objective
The user-facing surface over detected series: list and inspect them, confirm / dismiss / mark
cancelled, edit them, declare one the detector missed, and a summary carrying the monthly burden
plus the price-increase and missed-charge signals.

## Files
- `backend/app/features/recurring/{router,schemas,service}.py` — extend P2-10's service
- `backend/tests/features/recurring/{test_recurring_api,test_summary}.py`

## Contract slice
```
GET    /api/v1/recurring            ?status&account_id → [series]
GET    /api/v1/recurring/{id}       → series + [occurrence with its transaction]
POST   /api/v1/recurring            {label, account_id, expected_amount_minor, cadence,
                                     category_id?} → series   (is_manual = true)
PATCH  /api/v1/recurring/{id}       {label?|category_id?|cadence?|expected_amount_minor?|status?}
DELETE /api/v1/recurring/{id}
GET    /api/v1/recurring/summary    → {monthly_total_minor, active_count, cancelled_count,
                                       cadence_counts: {monthly, quarterly, yearly, …},
                                       next_charge: {series_id, label, amount_minor, due_on}?,
                                       price_increases: [{series_id, delta_minor, changed_at}],
                                       missed: [{series_id, expected_on, days_late}], currency}
```
The summary is shaped by what the panel's three summary cards actually print (frame ①):
« 212,08 € » with « Canal+ (résilié) exclu », « 7 » with « 6 mensuels · 1 trimestriel ·
1 annuel », and « Netflix — demain · 15,49 € · 15/05/2026 ». Each of those is one field here
rather than something the client re-derives from the full list.

## Steps
1. List with `status` and `account_id` filters, user-scoped, ordered by `next_expected_date`.
   Detail returns the occurrence history joined to its transactions so the UI can show what the
   series was built from.
2. Status transitions: `detected → confirmed | dismissed`, `confirmed → cancelled | dismissed`,
   `cancelled → confirmed` (resubscribed). Reject anything else with a 409 rather than writing a
   nonsense state. `dismissed` and `cancelled` are both terminal as far as the **detector** is
   concerned (P2-10 never revives them), but the user may still move them by hand.
3. Manual creation sets `is_manual=true` and `occurrence_count=0`; the detector must never
   overwrite it. A manual series may use `cadence='irregular'`, which detection never produces.
4. `DELETE`: hard-delete a manual series (it is pure user data); a detected series is set to
   `dismissed` instead — hard-deleting it would just invite the next detection run to recreate
   it, and the user's "no" needs somewhere to live.
5. `monthly_total_minor`: normalise every non-`dismissed` series to a monthly figure
   (weekly ×52/12, quarterly ÷3, yearly ÷12) using **integer minor units** with a documented
   rounding rule — never floats (§8). `cancelled` series are excluded from the burden but still
   listed.
6. Missed charges are computed **at read time** in the summary: `next_expected_date` more than
   the cadence tolerance in the past with no newer occurrence. Never persisted (§12). Report
   `days_late` — the panel prints « 9 jours de retard », and a date alone would make the client
   compute lateness against its own clock.
7. Price increases read `price_change_minor`/`price_changed_at` written by the detector, filtered
   to increases (outflows growing more negative) within a recent window.
8. `next_charge` is the soonest `next_expected_date` among non-dismissed, non-cancelled series;
   null when there is none. `cadence_counts` counts the same set; `cancelled_count` is separate
   because the panel names the exclusion explicitly rather than leaving the totals to disagree
   silently.

## Acceptance
- Every legal transition succeeds; every illegal one 409s.
- A dismissed series stays dismissed across a detection re-run.
- Deleting a manual series removes it; deleting a detected series dismisses it.
- `monthly_total_minor` is correct for a mixed weekly/monthly/quarterly/yearly set and computed
  in integer minor units.
- Missed charges appear once the tolerance is exceeded and disappear when a matching transaction
  is imported — with no write to the series.
- User-scoped throughout; `ruff` + `ty` clean.

## Tests
- `test_recurring_api.py`: filters; detail includes occurrences; transition matrix (legal +
  illegal); manual create and hard delete; detected delete → dismissed; dismissal survives
  re-detection; user scoping.
- `test_summary.py`: monthly normalisation across all cadences with exact integer expectations;
  cancelled excluded from the total but listed and counted; `cadence_counts` and `next_charge`
  against the drawn fixture set (212,08 € / 7 / Netflix 15/05/2026); missed appears/disappears
  without mutating the series and reports `days_late`; price increases filtered to increases only.

## Commits
- `feat(recurring): add subscription listing, detail, and manual creation`
- `feat(recurring): add lifecycle transitions with validation`
- `feat(recurring): add summary with monthly burden and price/missed signals`
