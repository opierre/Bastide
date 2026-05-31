# Panel: Login

A focused, welcoming entry screen. The fixed app shell may be minimal or hidden on auth screens
(the rail/bars appear after login) — show a clean centered auth layout on the dark base surface.

## Layout
- Centered card (raised surface `#161B22`, soft border, generous padding) on the base background,
  optionally with a subtle atmospheric gradient/texture behind (no purple-on-white clichés).
- App name/logo lockup at the top of the card.
- Fields: Email, Password (with show/hide). Primary button "Log in" (accent). Secondary link
  "Create an account" → Register.
- Inline error area for invalid credentials (use the expense-red semantic color, calm tone).
- Loading state on the button while authenticating.

## Content / copy
- Encouraging one-line subtitle under the app name (e.g. "Your money, clearly.").
- Localized: provide French and English versions (e.g. "Se connecter" / "Log in",
  "Créer un compte" / "Create an account").

## States to show
1. Default empty. 2. Filled with a validation/credential error. 3. Loading.

## Notes
Open Sans; accent only on the primary action; clear focus rings; comfortable field sizing for
desktop. This is the simplest screen — keep it elegant and uncluttered.
