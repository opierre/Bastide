# P1-11 — Categories & rules backend
Scope: backend
Depends on: P1-03, P1-06
Skills: ai-categorization, fastapi-backend, database, i18n-l10n, testing
PROJECT.md: §4, §5, §7

## Objective
Manage categories (system + user) and `categorization_rules`, and implement the deterministic
rule engine: priority-ordered, first-match-wins, never overriding user-set categories, with a
re-apply endpoint.

## Files
- `backend/app/features/categories/{router,schemas,service,repository}.py`
- `backend/app/features/rules/{router,schemas,service,repository}.py`
- `backend/app/features/rules/engine.py` — the rule engine (pure, unit-testable).
- `backend/tests/features/categories/test_categories.py`,
  `backend/tests/features/rules/{test_rules.py,test_engine.py}`

## Contract slice
```
GET/POST/PATCH/DELETE /api/v1/categories      (system are read-only; user can CRUD their own)
GET/POST/PATCH/DELETE /api/v1/rules
POST /api/v1/rules/apply  {account_id?} → {recategorized_count}
```

## Steps
1. Categories service: list system + user categories (localized names resolve via i18n keys for
   system ones); user CRUD on their own; cannot edit/delete system categories.
2. Rules CRUD (user-scoped): `priority`, `match_field`, `match_type` (contains|equals|regex|
   range), `pattern`, `category_id`, `enabled`.
3. `engine.py`: given a transaction + ordered enabled rules, return the first matching
   category (or none). Pure function — no DB inside.
4. `rules/apply`: re-run the engine over the user's transactions (optionally one account); set
   `category_id` + `source=rule` + `needs_review=false` on matches. **Never** touch rows with
   `source=user`. Return count changed.
5. The import pipeline (P1-08/09) calls the engine on insert; unmatched → `uncategorized`,
   `needs_review=true`.

## Acceptance
- System categories are read-only; users manage their own.
- Engine respects priority and first-match-wins; regex/range/contains/equals all work.
- `apply` never overrides `source=user`; returns an accurate count.
- Unmatched transactions remain `uncategorized` / `needs_review=true`.

## Tests
- `test_engine.py`: priority ordering, first-match-wins, each match_type, no-match path.
- `test_rules.py`: apply changes matching rows, skips `source=user`, count correct, user-scoped.
- `test_categories.py`: cannot modify system categories; user CRUD works; localized names present.

## Commits
- `feat(categories): add category CRUD over system and user categories`
- `feat(rules): add categorization rule CRUD`
- `feat(rules): add deterministic rule engine and apply endpoint`
