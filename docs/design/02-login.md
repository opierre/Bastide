# Panel: Login

A focused, welcoming entry screen. The fixed app shell may be minimal or hidden on auth screens
(the rail/bars appear after login) — show a clean centered auth layout on the dark base surface.

## Layout
- Centered card (raised surface `#111620`, 20px radius, hairline border, generous padding) on the
  sunken background, lit by two very low-opacity radial glows — jade top-left, violet
  bottom-right — for atmosphere without decoration competing with the form.
- Brand lockup (logomark + wordmark) and the privacy tagline sit **above** the card, so the card
  holds only the task at hand. The "switch to register" link sits below it.
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
