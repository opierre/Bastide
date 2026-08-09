# P1-05 — Auth frontend
Scope: frontend
Depends on: P1-02, P1-04
Skills: flutter-frontend, design-system, i18n-l10n, testing
PROJECT.md: §5, §8, §9

## Objective
Login and Registration screens (registration includes language + base-currency selection),
an auth controller managing session/token, and auth-gated routing that sends unauthenticated
users to login.

## Files
- `frontend/lib/features/auth/presentation/{login_screen,register_screen}.dart`
- `frontend/lib/features/auth/application/auth_controller.dart` — Riverpod `AsyncNotifier`
  exposing auth state; methods `login`, `register`, `logout`.
- `frontend/lib/features/auth/data/auth_repository.dart` — calls auth endpoints via api client.
- `frontend/lib/features/auth/domain/auth_user.dart` — immutable user model.
- Token storage in a local secure/store wrapper (`core/`); inject into api client's bearer hook.
- Update `core/router/app_router.dart` — redirect to `/login` when unauthenticated; to dashboard
  when authenticated.
- ARB keys (fr+en) for all auth strings; validation messages localized.
- `frontend/test/features/auth/auth_controller_test.dart`, `register_screen_test.dart`

## Steps
1. Repository wraps register/login/logout/me; maps envelope errors to typed failures.
2. `auth_controller` holds `AsyncValue<AuthUser?>`; persists token; restores session on launch
   via `me`.
3. Login screen: email + password, error states (invalid creds → localized message), loading.
4. Register screen: email, password, display name, **language selector (fr/en)** and
   **currency selector (ISO list)** — these set the account-wide currency and UI locale.
5. Wire router redirects; on logout clear token + state.
6. All strings via ARB (parity); `flutter analyze` clean.

## Acceptance
- New user can register choosing locale + currency, lands authenticated on the dashboard.
- Returning user logs in; session restored on app restart.
- Wrong credentials show a localized error, not a crash.
- Unauthenticated navigation always redirects to login.
- No hardcoded strings; works in fr and en.

## Tests
- `auth_controller_test.dart`: login success → authed state; failure → error state; logout clears.
  (api client mocked.)
- `register_screen_test.dart`: renders locale + currency selectors; submitting calls controller
  with chosen values; renders under fr and en.

## Commits
- `feat(auth): add auth repository and controller`
- `feat(auth): add login and register screens with locale and currency selection`
- `feat(core): gate routing on auth state`
