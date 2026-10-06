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
- `lib/features/` — one folder per feature (accounts, imports, transactions, rules, recurring, goals, mortgages, simulator, networth, …). Each feature owns its screens, controllers, providers, and widgets.
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
- **Fixed chrome invariant.** The sidebar and top bar keep the same position and behaviour on every screen. There is no bottom bar. A panel reaches the chrome only through the top bar's contextual-controls slot (`AppShell.actionsBuilder`); the collapsible sidebar is chrome state, not panel state.
- **`docs/design/00-shared-design-block.md` is binding** for every visual value, and `docs/design/NN-*.md` for each panel. Never invent a color, font, radius, or spacing value — add it to `core/theme/tokens.dart` from the spec.

## See also

- Root `CLAUDE.md` for global conventions.
- `PROJECT.md` for decisions and architecture; `docs/api.md` for the generated endpoint reference; `docs/design/` for the binding design specs.
