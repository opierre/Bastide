# P1-04 — Auth backend
Scope: backend
Depends on: P1-03
Skills: fastapi-backend, database, i18n-l10n, testing
PROJECT.md: §5, §8

## Objective
User registration (with locale + currency), login, logout, and `me`, with Argon2id password
hashing and a bearer token. `get_current_user` becomes real and scopes all later data access.

## Files
- `backend/app/features/auth/{router,schemas,service,repository}.py`
- `backend/app/core/security.py` — Argon2id hash/verify; token issue/verify (opaque token in a
  local token store table, or JWT with local secret — choose opaque for Phase 1 simplicity).
- Update `backend/app/core/deps.py` — `get_current_user` validates the bearer token → `User`.
- `backend/tests/features/auth/test_auth.py`

## Contract slice
```
POST /api/v1/auth/register {email,password,display_name,locale,currency} → 201 {token,user}
POST /api/v1/auth/login    {email,password} → 200 {token,user}
POST /api/v1/auth/logout   → 204
GET  /api/v1/auth/me       → 200 {user}        (requires bearer)
```
- `locale` ∈ {`fr`,`en`}; `currency` is a valid ISO-4217 code. Validate both.
- Errors via envelope: duplicate email → 409 `EMAIL_TAKEN`; bad creds → 401 `INVALID_CREDENTIALS`.

## Steps
1. `security.py`: Argon2id hash + verify; token generation + verification.
2. Service: `register` (reject duplicate email, hash pw, store locale+currency), `login`
   (verify, issue token), `logout` (invalidate token), `me`.
3. Router: thin endpoints; `register`/`login` public, `me`/`logout` require `get_current_user`.
4. Wire real `get_current_user` in `core/deps.py`.
5. Validate locale + ISO currency in schemas (raise `ValidationError` → 422).

## Acceptance
- Passwords stored only as Argon2id hashes (never plaintext, never reversible).
- Register persists locale + currency; `me` returns them.
- Bad credentials and duplicate email return the right codes/status.
- `get_current_user` rejects missing/invalid tokens with 401 `AuthError`.

## Tests
- `test_auth.py`: register→login→me happy path; duplicate email 409; wrong password 401;
  protected route without token 401; invalid currency/locale 422. No plaintext password in DB.

## Commits
- `feat(auth): add Argon2id hashing and token security helpers`
- `feat(auth): add register, login, logout, and me endpoints`
- `feat(core): implement get_current_user dependency`
