# P1-12 — Transactions backend
Scope: backend
Depends on: P1-08, P1-11
Skills: fastapi-backend, database, ai-categorization, testing
PROJECT.md: §4, §5, §7

## Objective
List transactions with filtering, pagination, and search; fetch one; and patch a transaction's
category/description/merchant — a user category edit sets `source=user` and `needs_review=false`
and is protected from future rule re-application.

## Files
- `backend/app/features/transactions/{router,schemas,service,repository}.py`
- `backend/tests/features/transactions/test_transactions.py`

## Contract slice
```
GET   /api/v1/transactions ?account_id&from&to&category_id&needs_review&q&page → page<transaction>
GET   /api/v1/transactions/{id} → transaction
PATCH /api/v1/transactions/{id} {category_id?|description_clean?|merchant?}
```
Paged response: `{items, page, page_size, total}`.

## Steps
1. Repository: user-scoped, filtered (account, date range, category, needs_review flag,
   text search `q` over description_clean/merchant), keyset or limit/offset pagination, eager-load
   category to avoid N+1.
2. Service: list/detail/patch. On category patch → `source=user`, `needs_review=false`.
3. Patching another user's transaction → 404. Editing description recomputes nothing destructive
   (dedup_hash stays as imported).
4. Ensure list never returns unbounded results (enforce a max page size).

## Acceptance
- Filters compose correctly; pagination stable; search matches description/merchant.
- Category patch sets `source=user`; subsequent `rules/apply` (P1-11) leaves it untouched.
- All queries user-scoped; cross-user access → 404.
- No N+1 on category in list responses.

## Tests
- `test_transactions.py`: filter combinations; pagination totals; search; patch sets source=user;
  cross-user 404; max page size enforced.

## Commits
- `feat(transactions): add transaction list with filters, search, and pagination`
- `feat(transactions): add transaction detail and user category override`
