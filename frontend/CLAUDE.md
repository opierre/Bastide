# CLAUDE.md — Frontend (Flutter / Dart)

> Stack-specific conventions for `frontend/`. Inherits the root `CLAUDE.md`.

## Load before working

- **flutter-frontend** — all Flutter/Dart work: building screens, widgets, Riverpod controllers/providers, API client, DTO mapping, navigation, state wiring.
- **design-system** — visual work: building screens, styling, theming, layout, icons, brand logos.
- **i18n-l10n** — user-facing text, date/number/currency formatting, locale handling.
- **testing** — flutter_test + mocktail conventions, widget tests, unit tests for state/services.
- **git-conventional-commits** — when committing.

## Tools

- **Flutter** (latest stable) · **Dart** with full type hints.
- **Riverpod** — state management. Controllers, providers, immutable state.
- **intl** · **flutter_localizations** — i18n/l10n with ARB files (`l10n/app_fr.arb`, `l10n/app_en.arb`).
- **flutter_test** · **mocktail** — testing. Widget tests for screens, unit tests for state.

## Structure

- `lib/core/` — theme, router, API client, l10n, utilities.
- `lib/features/` — auth, accounts, imports, transactions, categories, dashboard. Each feature owns its screens, controllers, providers, and widgets.
- `l10n/` — ARB files for translations (French and English).
- `test/` — flutter_test, mocktail.
- `main.dart` — entry point.
- `pubspec.yaml` — dependencies.

## Key rules

- **No logic in widgets.** Widgets are presentation only. All state and business logic live in Riverpod controllers/providers.
- **Feature-first folder shape.** A feature owns its screens, controllers, and widgets; no cross-feature reach-through.
- **Immutable models.** Use `@immutable` or freezed.
- **No hard-coded strings.** All user-facing text comes from ARB files and localizations.
- **Format at the edge.** Money, dates, numbers are formatted using `intl` and the current locale at the point of display.
- **Fixed chrome invariant.** The navbar, top bar, and bottom bar keep the same position and behaviour on every screen.

## See also

- Root `CLAUDE.md` for global conventions.
- `PROJECT.md` for the design system, API contract, and architectural overview.
