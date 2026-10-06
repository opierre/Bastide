---
name: i18n-l10n
description: Use whenever adding or changing any user-facing text, formatting dates/numbers/currency, or handling locale in the finstride. Enforces no-hardcoded-strings, the ARB workflow for Flutter, fr/en parity, locale-aware formatting via intl, backend i18n-key-friendly error messages, and localized seed data. French-first, English-second.
---

# i18n / l10n

French first, English second, both from day one. No string ships hardcoded.

## Frontend (Flutter)

- Use `flutter_localizations` + `intl` with **ARB** files: `frontend/lib/l10n/app_fr.arb`
  (template) and `app_en.arb`. Generated `AppLocalizations` is the only source of UI strings.
- **No hardcoded user-facing strings** in widgets — ever. If you type a quote-delimited label in
  a widget, you've made a bug. Add a key to the ARB files instead.
- **fr/en parity**: every key exists in *both* ARB files. A key in one but not the other is a
  build-time failure to fix, not defer. French is the template/reference.
- Use **named placeholders and ICU plurals/select** for counts and gendered/variable text
  (`"{count, plural, =0{aucune transaction} =1{1 transaction} other{{count} transactions}}"`).
  Never build sentences by string concatenation.
- Locale is chosen at registration (stored on the user), switchable in settings, and drives
  `MaterialApp.locale`.

## Formatting (locale-aware, at the edge)

- Money: `NumberFormat.currency(locale: ..., name: <ISO currency>)`. `fr_FR` renders
  `1 234,56 €` (space thousands, comma decimal, trailing symbol); `en_*` renders its own form.
  Input parsing must accept the locale's format too.
- Dates: `DateFormat` with the locale (`dd/MM/yyyy` for fr). Never hand-format dates.
- Numbers/percentages: `NumberFormat` with the locale. Savings rate etc. respect locale.
- All formatting happens in the presentation layer from the canonical integer-minor-units +
  currency code — see **flutter-frontend** and **database**.

## Backend

- API responses are **locale-agnostic data**, not prose. The backend does not localize numbers
  or dates — it returns integer minor units, ISO currency codes, and ISO dates; the frontend
  formats.
- Error envelope `message` fields are written as **stable, translatable strings or i18n keys**
  (e.g. `code: "ACCOUNT_NOT_FOUND"`); the frontend maps `code` → a localized message. The agent
  must add the matching ARB key whenever a new error `code` is introduced.
- **Seed data** (the rich ~25+ system categories) is seeded with localized names for fr and en.
  System category display names resolve through i18n keys, not stored prose.

## Definition of done (i18n facet)

A feature is not done until: every new user-facing string has fr + en ARB entries; every new
error `code` has a localized frontend message; all dates/numbers/money use locale-aware
formatters; and switching the app locale changes everything with no leftover English (or French)
literals. This is part of the project-wide Definition of Done.

## Testing

- A test/CI check asserts **ARB key parity** between fr and en (no missing keys either way).
- Widget tests run under both locales for at least the key screens (dashboard, transactions,
  auth) to catch hardcoded strings and overflow from longer French labels.
