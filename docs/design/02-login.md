# 02 — Login

## Top bar (this panel)
None. Auth exception: centered column on sunken #070910 with iris (top-left) and violet (bottom-right) radial glows at ~7 % opacity. Above the card: brand lockup (40 px logomark + 26 px wordmark), tagline « Votre argent, en clair. » / "Your money, clearly.", then lock glyph + privacy line « Local et privé — vos données ne quittent jamais cet ordinateur. »

## Content layout
Card (416 px, radius 20, raised surface, padding 30) holds only the task: FormField Adresse e-mail; FormField Mot de passe with trailing show/hide eye; primary Button « Se connecter » (46 px, full width). Below the card: « Pas encore de compte ? Créer un compte » (iris link). Credential error renders as an InlineBanner (expense-red tint, calm copy « E-mail ou mot de passe incorrect. Vérifiez vos identifiants et réessayez. ») at the top of the card, plus red field borders on both fields.

## States to show
① empty (fr) — placeholder text in disabled tone. ② credential error (fr) — filled values, banner, red borders. ③ loading (fr) — filled, button shows spinner + « Connexion… ». ④ empty (en) — same geometry, English strings.

## Notes
Password dots at letter-spacing 2px. Button loading swaps label, never shrinks. French strings size the card; English reuses it unchanged.