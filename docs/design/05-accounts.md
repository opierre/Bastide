# 05 — Accounts

## Top bar (this panel)
Title « Comptes » + descriptor « Tous vos comptes, une seule devise ». Right: primary « Ajouter un compte » (38 px, plus glyph), search pill (230 px), user pill.

## Content layout
Summary Card: label « Solde total », 32 px neutral 14 013,72 €; right-aligned meta « 4 comptes actifs · EUR » + last-recalc timestamp. Below, 2-column card grid (gap 18): each account Card = 40 px BrandLogo monogram + name (14.5/700) + institution (12 secondary) + ⋯ overflow (Edit/Archive — archive only, no delete), footer row = type badge pill (Courant/Épargne/Crédit) + signed balance 21 px (green +3 486,12 € BNP, green +8 240,00 € Livret A, red −312,40 € Revolut credit, green +2 600,00 € Caisse Locale d'Épargne — the unknown-institution monogram case). Cards hover with iris border.

## States to show
① populated (fr) — 4 varied accounts incl. monogram fallback. ② add/edit modal (fr) — 480 px Modal: Nom, Type select, Solde d'ouverture (neutral figure), Établissement with live logo preview (the chip alone — no « recognized » caption beside it), Devise read-only (dashed field + lock + note « La devise est celle de votre profil et s'applique à tous les comptes. »), footer Annuler/Enregistrer. ③ empty (fr) — EmptyState « Ajoutez votre premier compte » + CTA.

## Notes
Account-card balances use sign colors (they are the card's one data point); the summary total stays neutral. No per-account currency appears anywhere.