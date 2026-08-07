# 03 — Register

## Top bar (this panel)
None — same auth scaffold as 02 (smaller lockup: 34 px mark, 22 px wordmark; privacy line kept, tagline dropped).

## Content layout
Card 470 px. Field order: Nom affiché · Adresse e-mail · Mot de passe (show/hide + 4-segment strength meter with right-aligned verdict label: iris « Robuste », red « Trop faible »). Then a settings-like inset row (field surface, radius 14, own border) holding Langue as a SegmentedControl (Français/English) and Devise as a read-only select-look showing « EUR (€) — Euro », with microcopy beneath: « Vous pourrez changer la langue plus tard ; la devise s'applique à tous vos comptes et ne pourra plus être modifiée dans cette version. » Primary « Créer mon compte » (disabled #1E2634 until valid). Below card: « Déjà un compte ? Se connecter ».

## States to show
① empty (fr) — placeholders, meter unfilled, button disabled. ② filled valid (fr) — meter 3/4 iris « Robuste », button enabled. ③ validation errors (fr) — email taken helper « Cet e-mail est déjà utilisé — connectez-vous plutôt. » + weak password (1/4 red segment, helper with fix guidance), button disabled. ④ empty (en) — English segment active.

## Notes
Currency is presented as a value, not a picker — no chevron-less lock here (chevron kept on the select-look but the row reads as configuration, and the microcopy carries the permanence). Validation helpers are 11.5 px with a leading red dot, never toasts.