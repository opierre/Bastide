# 03 — Inscription

Mockup: `#panel=register`. Ticket #204. Read `00-design-system.md` first.

## Title bar
None.

## Layout
Same scaffold as `02-login.md`: `bg`, tomettes faded behind the form, one 320 px column, 14 px
between children.

1. Brand row (mark 20 px + « Bastide » 16/600).
2. Field « Nom d’utilisateur » (en: "Username"), the name Settings › Profil uses. It is
   also a login identifier. Rule, shared with the Settings modal (`09-settings.md`): 3 to 32
   characters, letters, digits, spaces, « . », « _ » or « - ». Spaces are allowed, so
   « Camille Dubois » is valid.
3. Field « Adresse e-mail ».
4. Field « Mot de passe » with the show/hide button. Helper line under it (11 px):
   - not yet valid: « 12 caractères minimum. » in `textTertiary`;
   - valid: `check` 14 px `positive` + « {n} caractères. Le minimum est de 12. »
5. Two columns, 12 px apart: « Langue » as a segmented control (Français · English);
   « Devise » as a 28 px select showing « EUR, euro ».
6. One 11 px `textTertiary` line: « La langue se change dans les paramètres. La devise est
   définitive et s’applique à tous vos comptes. »
7. Primary button, large, full width: « Créer mon compte ».
8. 12 px line: « Déjà un compte ? » + link « Se connecter ».
9. Hairline, then the note `lock` + « Vos données restent sur cet ordinateur. »

## States
| State | What changes |
|---|---|
| Empty | Placeholders; button disabled until every field is valid. |
| Valid | Password helper turns to the check form; button enabled. |
| E-mail taken | E-mail field error border; helper « Cet e-mail a déjà un compte. Connectez-vous. » |
| Password too short | Password field error border; helper « Encore {n} caractères. » in `negative`. |
| Loading | Button spinner + « Création… ». |
| English | English segment selected; same geometry. |

## Behaviour (kept)
- Choosing a language switches the screen's strings at once.
- The currency is chosen here and never again; it applies to every account.
- On success the recovery code is shown once (see `02-login.md`), then the app opens on the
  empty Dashboard.
- Validation messages sit under their field, never in a toast.

## Copy
- The username field is « Nom d’utilisateur » / "Username", as in Settings; never « Nom
  affiché ».
- Drop the four-level strength verdicts (« Robuste », « Trop faible »).
- Currency microcopy as in item 6.

## Removed from v1
470 px card, four-segment strength meter, inset settings-like row with its own border,
read-only select look with a lock, glows.
