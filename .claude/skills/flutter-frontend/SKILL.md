---
name: flutter-frontend
description: Use for any Flutter/Dart work in the finstride — building screens or widgets, Riverpod controllers/providers, the API client, DTO mapping, navigation, or wiring state. Encodes the no-logic-in-widgets rule, the feature folder shape, money/locale formatting at the edge, and the fixed-chrome invariant. Pairs with architecture, i18n-l10n, and design-system skills.
---

# Flutter Frontend

How to build the desktop client. Obey the frontend layering in the **architecture** skill, the
visual rules in **design-system**, and string/format rules in **i18n-l10n**.

## Stack

- **Flutter** (latest stable), desktop targets. **Riverpod** for state. `intl` +
  `flutter_localizations` for i18n. Immutable models (records or a codegen tool — pick one and
  stay consistent).
- Lints: `flutter_lints` / effective-dart. No analyzer warnings land in commits.

## Layering recap (enforced)

```
presentation (screens/widgets) → application (Riverpod) → data (repository) → core/api (client)
                                                              ↕
                                                        domain (models)
```

- **Widgets hold no business logic.** They watch providers and call controller methods. No HTTP,
  no JSON parsing, no money math, no conditional business rules inline.
- **application/** — Riverpod `Notifier`/`AsyncNotifier` controllers expose immutable state
  (`AsyncValue<T>` for loading/error/data). UI renders state; it does not orchestrate.
- **data/** — repositories call the api client and map JSON ↔ domain models. The only place that
  knows wire shapes.
- **domain/** — immutable models; no Flutter imports, no serialization logic leaking in.

## Feature folder

```
frontend/lib/features/<feature>/
├── presentation/   # screens + widgets
├── application/    # controllers/providers
├── data/           # repository + DTO mapping
└── domain/         # immutable models
```

App-wide shared widgets (the fixed navbar / top bar / bottom bar) live in `core/`, not in a
feature — they are invariants across every panel (see design-system).

## API client

- One typed client in `core/api/`, base URL = the local sidecar. It owns: bearer-header
  injection, JSON encode/decode, timeout, and mapping the backend **error envelope**
  (`{error:{code,message}}`) to typed Dart failures.
- Prefer generating the client/DTOs from the backend OpenAPI spec over hand-writing two copies;
  if hand-written, keep DTOs in `data/` and map to clean `domain/` models.
- Repositories return `Result`/throw typed failures; controllers translate to `AsyncValue`.

## Money & formatting — at the edge only

- The wire and domain carry **integer minor units + currency code**. Convert to a display string
  **only in the presentation layer**, via a shared formatter using `intl`'s `NumberFormat.currency`
  with the user's locale. Never do money math in widgets; never store formatted strings.
- Dates/numbers formatted via `intl` with the active locale (`fr_FR` → `1 234,56 €`,
  `dd/MM/yyyy`).

## State & errors

- Every async screen renders all three `AsyncValue` states: loading (skeleton/spinner),
  error (localized message + retry), data. No screen silently shows nothing on error.
- No `setState`-driven business logic; state lives in Riverpod. `StatefulWidget` only for
  purely-local UI ephemera (animation controllers, focus nodes).
- Dispose controllers/streams. Avoid rebuilding whole trees — scope `ref.watch` narrowly.

## Navigation & chrome

- Single router (`go_router` or equivalent) in `core/router/`. Auth-gated routes redirect to
  login when unauthenticated.
- The navbar/top bar/bottom bar are rendered by a shared shell scaffold so their position and
  behaviour are identical on every panel. Feature screens render *into* the shell, never
  replace the chrome.

## Testing

- `flutter_test` + `mocktail`. Widget tests assert states render correctly with mocked
  controllers; unit tests cover controllers/repositories with mocked api client. See **testing**.

## Comments

Document *why* for non-obvious state/UX decisions. Keep widgets small and named; extract rather
than nest deeply.
