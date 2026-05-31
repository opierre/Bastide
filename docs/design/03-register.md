# Panel: Register

Account creation. Same centered auth layout as Login, with a few more fields and — importantly —
**language and base-currency selectors**, since these set the UI locale and the currency applied
to all of the user's accounts in Phase 1.

## Layout
- Centered card matching Login's styling.
- Fields, in order: Display name, Email, Password (with strength/show-hide), then a row with
  **Language** (French / English) and **Currency** (ISO list, e.g. EUR, USD, GBP, CHF…).
- Primary button "Create account" (accent). Secondary link "Already have an account? Log in".
- Brief reassuring microcopy near the currency/language selectors ("You can change the language
  later; currency applies to all your accounts.").

## Content / copy
- Localized French + English variants for all labels and the microcopy.
- Currency selector shows code + symbol + name (e.g. "EUR — € — Euro").

## States to show
1. Empty. 2. Filled valid (button enabled). 3. Validation error (e.g. email taken / weak password).

## Notes
Keep the language + currency selectors visually distinct (a settings-like row) so users notice
these are setup choices, not throwaway fields. Open Sans; accent only on the primary action.
