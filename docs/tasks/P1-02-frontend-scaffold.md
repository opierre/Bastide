# P1-02 — Frontend scaffold (Flutter shell)
Scope: frontend
Depends on: P1-00
Skills: flutter-frontend, design-system, i18n-l10n, architecture
PROJECT.md: §3, §9

## Objective
A runnable Flutter desktop app showing the shared app shell (fixed navbar/top bar/bottom bar) in
dark theme, with the design tokens, router, typed API client skeleton, and fr/en localization
wired. Nav items route to placeholder screens.

## Files
- `frontend/pubspec.yaml` — deps: flutter_riverpod, go_router, intl, flutter_localizations,
  google_fonts (Open Sans) or bundled font; dev: flutter_lints, mocktail, flutter_test.
- `frontend/lib/core/theme/` — `tokens.dart` (palette/spacing/radii from design-system),
  `app_theme.dart` (dark `ThemeData`, Open Sans, tabular figures for numbers).
- `frontend/lib/core/router/app_router.dart` — go_router; auth-gated redirect stub; routes for
  Dashboard, Accounts, Transactions, Imports, Categories, Settings (placeholder screens).
- `frontend/lib/core/api/api_client.dart` — typed client skeleton: base URL (sidecar),
  bearer-header injection hook, JSON encode/decode, maps the `{error:{code,message}}` envelope to
  typed Dart failures.
- `frontend/lib/core/widgets/app_shell.dart` — scaffold with the fixed left nav, top bar, bottom
  bar; content region renders the active route. **This is the layout invariant.**
- `frontend/lib/l10n/app_en.arb`, `app_fr.arb` — initial keys (app title, nav labels). `l10n.yaml`.
- `frontend/lib/main.dart` — `ProviderScope` + `MaterialApp.router` + localization delegates.
- `frontend/test/app_shell_test.dart`.

## Steps
1. `flutter create` desktop-enabled; add deps; set up `l10n.yaml` + ARB generation.
2. Implement theme tokens + dark theme per design-system (palette, Open Sans, tabular numbers).
3. Build `app_shell.dart` with the three fixed bars; wire go_router so nav items swap only the
   content region.
4. API client skeleton (no real calls yet) with error-envelope mapping + auth-header hook.
5. Seed ARB keys for app title + nav labels in both fr and en (parity).
6. `flutter analyze` clean; widget test passes.

## Acceptance
- App launches on desktop in dark mode; nav/top/bottom bars present and consistent across routes.
- Switching locale (fr/en) changes nav labels; no hardcoded strings in the shell.
- API client compiles and exposes the error-envelope mapping; no live calls required.
- `flutter analyze` clean.

## Tests
- `app_shell_test.dart`: shell renders all three bars; tapping a nav item changes the content
  region but not the chrome; renders under both `fr` and `en` locales without missing-key errors.

## Commits
- `chore(frontend): scaffold flutter app with riverpod, router, l10n`
- `feat(theme): add dark design tokens and Open Sans theme`
- `feat(core): add fixed app shell and typed api client skeleton`
