# 05 — Comptes

Mockup: `#panel=accounts`. Ticket #206. Read `00-design-system.md` first.

## Title bar
Title « Comptes ». Right: segmented « Par type · Par établissement », then primary
« Ajouter un compte » (`plus`).

## Layout
Standard padding. Top to bottom, 24 px apart:

1. **Total line:** label « Solde total » 12 `textSecondary` over the total at 40 px, neutral.
   Right-aligned on the same baseline, 12 `textTertiary`: « {n} comptes · soldes recalculés
   il y a 2 min ».
2. **One section per group**, in a fixed order.

## Content

### Section
- **Header bar:** 1 px `line`, radius 8 (top corners only when the section is open), `rail`
  ground, padding 10 12. Left to right: `chevron-down` (open) or `chevron-right` (closed)
  14 px `textTertiary` · type icon 14 px · name 13/600 · count `textTertiary` · spacer ·
  « {share} % du total » 12 `textTertiary` · subtotal 13/600, right-aligned in a 120 px slot.
  The whole bar is the toggle.
- **Table** (10 px below the bar, only when open):

| Column | Content |
|---|---|
| Compte | Monogram + account name; when cards settle on the account, a neutral status text `credit-card` + « 1 carte » 8 px after the name (click opens the linked-cards menu) |
| Établissement | `textSecondary` |
| Dernier import | date, `textSecondary`; « — » when none |
| Variation en {mois} | right-aligned, sign-coloured; `0,00 €` in `textTertiary` |
| Solde | right-aligned; neutral with its sign; `negative` when below zero |

A row opens the account detail (`16-account-detail.md`).

### Groups « Par type »
In this order, each shown only when it has an account:
« Comptes courants » (`landmark`) · « Épargne » (`piggy-bank`) · « Cartes à débit différé »
(`credit-card`) · « Crédits » (credit-type accounts, `hand-coins`) · « Autres » (`wallet`).
The share is the group's part of the sum of positive subtotals; a group with a negative
subtotal shows its share of the total in absolute value.

### Groups « Par établissement »
One section per institution, by descending subtotal; the header shows the institution's
monogram instead of a type icon. Accounts without an institution go to « Sans établissement ».

## States
| State | What shows |
|---|---|
| Populated | As above; all sections open on first visit. |
| Section closed | Only its header bar, with all four corners rounded. |
| Empty | Empty state: « Ajoutez votre premier compte » · « Créez un compte, ou importez un relevé : Bastide crée le compte qu’il décrit. » · primary « Ajouter un compte », secondary « Aller aux imports ». |
| Loading | Total line and three header-bar silhouettes. |
| Account form | Modal 480 px, title « Nouveau compte » / « Modifier le compte »: Nom · Type (select) · Établissement (text with the monogram or user logo previewed inside the field) · Solde d’ouverture (amount, neutral) · Devise (read-only, « EUR, euro », helper « La devise est celle de votre profil. »). Footer « Annuler » · « Enregistrer ». |
| Linked-cards menu | Popover listing each card: name, « Modifier », « Archiver », and « Règle de prélèvement » for a deferred card. |

## Behaviour (kept)
- The grouping choice and each section's open/closed state are remembered per user.
- A card account settled from a shown account has no row of its own: it is reached through
  that account's linked-cards control. An unlinked card, or one whose settlement account is
  hidden or gone, keeps its row under « Cartes à débit différé ».
- The total and the count include every account, with or without a row.
- Accounts are archived, never deleted. « Modifier » and « Archiver » for an account live in
  its detail's title bar.
- No per-account currency anywhere.
- Placements (PEA, assurance vie) are not accounts; they live in `17-placements.md`.

## Copy
Delete `navAccountsSubtitle`. `accountsEmptyBody` per `00` §14. New: « Par type », « Par
établissement », « {share} % du total », « Sans établissement », group names above.

## Removed from v1
Summary card, two-column grid of account cards, type badge pills, iris hover border, 40 px
coloured monograms.
