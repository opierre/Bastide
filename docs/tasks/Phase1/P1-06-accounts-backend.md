# P1-06 — Accounts backend
Scope: backend
Depends on: P1-04
Skills: fastapi-backend, database, multi-currency, testing
PROJECT.md: §4, §5

## Objective
Account CRUD scoped to the user, with currency defaulting to the user's currency, archive-on-
delete, and the balance machinery (cache delta + snapshot-based point-in-time) in the service.

## Files
- `backend/app/features/accounts/{router,schemas,service,repository}.py`
- `backend/app/features/accounts/balance.py` — balance helpers: apply delta to
  `cached_balance_minor`; compute point-in-time via nearest snapshot + rows since; full recompute
  (reconciliation).
- `backend/tests/features/accounts/test_accounts.py`, `test_balance.py`

## Contract slice
```
GET    /api/v1/accounts            → [account]
POST   /api/v1/accounts            {name,type,institution,opening_balance_minor} → 201 account
GET    /api/v1/accounts/{id}       → account (incl. derived current balance)
PATCH  /api/v1/accounts/{id}       {name?,type?,institution?}
DELETE /api/v1/accounts/{id}       → 204 (archive, not hard delete)
```
- On create, `currency = user.currency` (multi-currency skill: do NOT offer a per-account
  currency picker in Phase 1, but DO store the column).
- All queries user-scoped; another user's account → 404 `ACCOUNT_NOT_FOUND`.

## Steps
1. Schemas (`AccountCreate/Update/Read`); `Read` includes derived balance.
2. Service: create (default currency, init cache = opening balance), update, archive; read uses
   the balance helper, not a raw full SUM.
3. `balance.py`: implement delta apply + snapshot point-in-time + full recompute, per database
   skill. These are used here and by the import card (P1-08).
4. Repository: user-scoped queries only.

## Acceptance
- Create defaults currency to the user's; column populated.
- Delete archives (`archived=true`), never hard-deletes; archived excluded from default list.
- Balance read is O(1) via cache; full recompute matches cache on a fresh account.
- Cross-user access returns 404, not another user's data.

## Tests
- `test_accounts.py`: CRUD happy paths; archive behavior; user-scoping (user B cannot see/modify
  user A's account → 404).
- `test_balance.py`: cache delta correctness; point-in-time via snapshot; full recompute equals
  cache after a series of inserts.

## Commits
- `feat(accounts): add account CRUD with user-scoped access`
- `feat(accounts): add balance cache, snapshot, and recompute helpers`
