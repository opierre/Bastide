# 02 — Connexion

Mockup: `#panel=login`. Ticket #204. Read `00-design-system.md` first.

## Title bar
None. Auth screens have no sidebar and no title bar.

## Layout
- Ground `bg`, tomettes full frame, faded behind the form (`00` §12, place 1).
- One column, 320 px wide, centred horizontally and vertically. No card, no border, no shadow.
- Children 14 px apart, top to bottom:
  1. Brand row: Plan mark 20 px + « Bastide » 16/600, 8 px below.
  2. Field « E-mail ou nom d’utilisateur » (en: "Email or username").
  3. Field « Mot de passe », with a trailing `eye` / `eye-off` 14 px button that shows or hides it.
  4. Primary button, large, full width: « Se connecter ».
  5. A row, space-between, 12 px links: « Créer un compte » · « Mot de passe oublié ».
  6. Hairline, 8 px above.
  7. Note: `lock` + « Vos données restent sur cet ordinateur. »

## States
| State | What changes |
|---|---|
| Empty | Placeholders in `textTertiary`. Button enabled; submitting empty fields shows the field errors. |
| Focus | The focused field takes the accent border and ring. |
| Wrong credentials | Both fields take the error border; under the password field, helper in `negative`: « Identifiant ou mot de passe incorrect. » No banner. |
| Loading | Button shows the spinner and « Connexion… »; fields disabled. |
| Engine not ready | The startup screen (`18-brand.md`) shows instead of this one. |
| English | Same geometry. |

## Behaviour (kept)
- Login accepts the e-mail or the username, and its field label says so.
- `Enter` in either field submits. The button never changes width.
- « Mot de passe oublié » opens the recovery-code flow (same column layout: « E-mail ou nom
  d’utilisateur », recovery code, new password, confirm; primary « Réinitialiser le mot de passe »).
- After the first registration, the recovery code is shown once in this same column layout:
  the code in Geist Mono 16 on a `field` well, a « Copier » secondary button, the sentence
  « Notez ce code et gardez-le en lieu sûr : il ne sera plus affiché. », and a primary
  « J’ai noté ce code ».

## Copy
- Delete `authTagline`. `authPrivacyLine` → « Vos données restent sur cet ordinateur. »
- Identifier label → « E-mail ou nom d’utilisateur » / "Email or username", on login and on
  « Mot de passe oublié ».
- Credential error → « Identifiant ou mot de passe incorrect. » / "Wrong email, username or
  password."

## Removed from v1
Radial glows, sunken ground, 416 px raised card, lockup + tagline stack above the card, error
banner inside the card, gradient button, letter-spaced password dots.
