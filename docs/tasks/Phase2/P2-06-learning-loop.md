# P2-06 — Learning loop: correction → rule
Scope: backend
Depends on: P2-04
Skills: ai-categorization, fastapi-backend, testing
PROJECT.md: §5b, §7
Design: `docs/design/07-transactions.md` (Phase 2 amendment, rule modal),
`docs/design/08-categories-rules.md` (rule editor)

## Objective
Turn a user correction into a deterministic rule, so the next occurrence is handled by stage 1
with no model call. One endpoint that creates the rule, optionally applies it, and reports what
it changed — plus the match preview both drawn rule editors show before the user commits.

## Files
- `backend/app/features/rules/{router,schemas,service}.py` — edit
- `backend/app/features/rules/suggest.py` — pattern suggestion from a transaction
- `backend/tests/features/rules/{test_from_transaction,test_suggest,test_preview}.py`

## Contract slice
```
POST /api/v1/rules/preview
  {match_field, match_type, pattern, account_id?} → {match_count, samples: [transaction]}
POST /api/v1/rules/from-transaction
  {transaction_id, match_field, match_type, pattern, category_id, apply_now}
  → {rule, recategorized_count}
```

## Steps
1. `suggest.py` — given a transaction, propose a `(match_field, match_type, pattern)` the UI can
   pre-fill: prefer `merchant` + `equals` when a merchant was extracted, else `description_clean`
   + `contains` with the most distinctive token run, stripped of dates, card-sequence digits, and
   reference numbers. Pure function, no DB. The client may override every field — the suggestion
   is a default, not a constraint.
2. Endpoint: validate the transaction and category belong to the caller, create the rule
   (enabled, user-scoped) and set the source transaction to `category_id` + `source='user'` +
   `needs_review=false` in the **same DB transaction** — the correction and the rule it justifies
   must not be able to half-apply.
3. Priority for the new rule: append at the end of the user's rules (`max(priority) + 1`) so a
   learned rule never silently preempts one the user ordered deliberately.
4. Reject a `regex` pattern that fails to compile with a 422 carrying the compile error in
   `details` — the user is writing it in a modal and needs to see why.
5. `apply_now=true` → run the existing P1 apply path over the user's transactions, honouring its
   invariant: rows with `source='user'` are never overridden. Return the count changed
   (0 when `apply_now=false`).
6. Reuse the P1 rule engine and apply service. Do **not** fork a second code path — the whole
   value of the learning loop is that it lands in stage 1.
7. `POST /rules/preview` — count the user's transactions an unsaved rule would match, and return
   up to 3 sample rows. Both drawn editors show it before the user commits: « Correspond à 7
   transactions existantes. » in the 07 rule modal, and the same with an example row in the 08
   editor. Evaluate with the **P1 rule engine itself**, not a `LIKE`/search query — a `regex` or
   `range` rule can't be approximated by text search, and a preview that disagrees with what the
   rule then does is worse than no preview. An uncompilable regex here is a 422, same as step 4.
   The endpoint writes nothing.

## Acceptance
- The rule is created, the source transaction is corrected, and both roll back together on error.
- A learned rule lands last in priority order.
- `apply_now=true` recategorizes matching rows and reports an accurate count; `false` changes
  nothing beyond the source row.
- Rows with `source='user'` are never overridden by the apply step.
- Invalid regex → 422 with the compile error; cross-user transaction or category → 404.
- `preview` returns the same count the rule then actually changes, for every match type, and
  writes nothing.
- `ruff` + `ty` clean.

## Tests
- `test_suggest.py`: merchant present → equals-on-merchant; merchant absent → contains on a
  cleaned token run; noisy French bank labels (dates, card digits, refs) are stripped.
- `test_from_transaction.py`: rule created + transaction corrected atomically (assert rollback on
  an induced failure); priority appended; `apply_now` count correct; `source=user` rows skipped;
  bad regex 422; cross-user 404.
- `test_preview.py`: count matches what a subsequent real apply changes, for `contains`,
  `equals`, `regex`, and `range`; at most 3 samples; bad regex 422; nothing persisted;
  user-scoped.

## Commits
- `feat(rules): add pattern suggestion from a transaction`
- `feat(rules): add rule match preview endpoint`
- `feat(rules): add rule creation from a user correction with optional re-apply`
