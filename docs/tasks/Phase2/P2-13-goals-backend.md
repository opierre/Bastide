# P2-13 — Goals & allocations backend
Scope: backend
Depends on: P2-02
Skills: fastapi-backend, database, multi-currency, testing
PROJECT.md: §4b, §5b, §13
Design: `docs/design/11-goals.md` — normative, and note its binding "Concept" section: a goal is
**not linked to an account**

## Objective
Savings goals as virtual envelopes: CRUD over goals, an append-only signed allocation ledger, and
derived progress. Nothing here writes a transaction or moves an account balance.

## Files
- `backend/app/features/goals/{router,schemas,service,repository}.py`
- `backend/tests/features/goals/{test_goals,test_allocations}.py`

## Contract slice
```
GET    /api/v1/goals                          ?status → [goal + {progress_minor, progress_pct}]
POST   /api/v1/goals                          {name, target_minor, target_date?, icon, color}
PATCH  /api/v1/goals/{id}                     (incl. {status} — archive and restore)
DELETE /api/v1/goals/{id}                     (archive)
GET    /api/v1/goals/{id}/allocations         → [allocation]
POST   /api/v1/goals/{id}/allocations         {amount_minor, allocated_on, note?} → allocation
DELETE /api/v1/goals/{id}/allocations/{allocation_id}
```

## Steps
1. Goal CRUD, user-scoped. `target_minor` must be positive. `currency` is copied from the user
   (Phase 1's one-currency rule — see the multi-currency skill; do not add a currency selector).
   **No `account_id`**: the drawn design shows no account on a goal anywhere, so the column is
   not built (`PROJECT.md` §13). Reject the field if a client sends it rather than accepting and
   ignoring it.
2. `progress_minor = sum(allocations.amount_minor)`, computed in the repository as a single
   aggregate — do not load allocations to sum them in Python.
   `progress_pct = progress_minor / target_minor`, reported **unclamped** so the API can express
   an over-funded goal; clamping is the UI's business (§13).
3. Allocations are signed: a negative amount is money taken back out. The list is append-only
   history — `DELETE` exists to undo a mistyped entry, and there is no PATCH. Correcting an
   allocation means adding an offsetting one, which is what an honest ledger looks like.
4. Status: a goal flips to `reached` when progress ≥ target, and back to `active` if a negative
   allocation drops it below. Recompute on every allocation write and delete. Do **not**
   auto-archive a reached goal (§13 — reaching it is the moment the UI is built around).
5. `DELETE /goals/{id}` archives (`status='archived'`), consistent with accounts in Phase 1;
   allocations are history and survive. Archiving is **reversible**: `PATCH {status: 'active'}`
   restores a goal, and the restore must recompute `reached` from its allocations rather than
   trusting the status it carried when archived — the target may have been edited since.
   `GET /goals?status=archived` backs the panel's « Afficher les objectifs archivés (2) » link,
   so the default list must exclude archived goals and the filtered one must return them.
6. Over-allocation across goals is **allowed** (§13). The API accepts it silently; the UI warns.
   Do not compare allocations against any account balance here — the backend has no basis for
   deciding which money is "savings".
7. All arithmetic in integer minor units; `progress_pct` is a derived ratio, never a money value.

## Acceptance
- Progress is the exact sum of signed allocations; a negative allocation reduces it.
- `progress_pct` is unclamped and correct; a goal past its target reports over 1.0.
- Status flips to `reached` at exactly target and back to `active` below it, on both write and
  delete of an allocation.
- Deleting a goal archives it and preserves allocations; archived goals are excluded from the
  default list and returned by `?status=archived`; restoring recomputes `reached`.
- Target ≤ 0 → 422; an `account_id` in the payload → 422; cross-user access → 404.
- No transaction row or account balance is ever written by this feature.
- `ruff` + `ty` clean.

## Tests
- `test_goals.py`: CRUD; validation (target, rejected `account_id`); archive and restore
  semantics incl. `reached` recomputed on restore; `?status=archived` filtering; status
  transitions at the boundary; user scoping; currency copied from the user.
- `test_allocations.py`: signed sum; negative allocation flips `reached` back to `active`;
  delete recomputes; over-allocation accepted; progress computed by aggregate (assert no
  ledger/transaction writes occurred).

## Commits
- `feat(goals): add savings goal CRUD with derived progress`
- `feat(goals): add signed allocation ledger and reached-status handling`
