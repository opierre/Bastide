# 07 — Transactions

Mockup: `#panel=transactions&variant=A` (tab « Toutes »), `&variant=B` (tab « À vérifier »).
Ticket #208. Read `00-design-system.md` first.

## Title bar
Title « Transactions ». Right: the search field (« Rechercher », searches description and
merchant; `Ctrl K` focuses it).

## Layout
Flush panel. Top to bottom:

1. **Tabs:** « Toutes » · « À vérifier {n} ». Padding 0 32. The count is hidden at 0.
2. The selected tab's body, filling the rest.

## Tab « Toutes »
Two panes: list (flexible) · inspector (440 px, `00` §7).

### List pane
- **Filter row,** padding 12 32, 8 px apart: select « Tous les comptes » · select-look with
  `calendar` « 1 – 31 mai 2026 » (opens the period modal) · select « Toutes les catégories »
  (top-level categories, each with its icon) · spacer · 12 `textTertiary`: « 38 opérations ·
  net » + the net, signed and coloured.
- **Table,** edge to edge (first and last cells padded 32):

| Column | Content |
|---|---|
| Opération | Monogram + label. A raw bank label that no rule has named is set in Geist Mono with the « ? » monogram. |
| Catégorie | Category label (top level only in this pane). Clicking it opens the category picker under it. |
| Montant | Right-aligned, signed and coloured. |

  Rows are grouped by day under a group row (« 14 mai 2026 »), newest first. The selected row
  takes `accentSoft`. Keyboard: `↑` `↓` move the selection, `C` opens the category picker.
- **Pager,** padding 10 32, top hairline: « 1 – 50 sur 128 » 12 `textTertiary` · spacer ·
  two secondary icon buttons `chevron-left`, `chevron-right`.

### Inspector pane (selected operation)
1. Header row: large monogram + name 13/600 over the raw bank label in Geist Mono
   `textTertiary`.
2. Amount at 28 px, signed and coloured.
3. Key/value list: Date · Compte · Catégorie (a 28 px select showing the full category label;
   changing it clears the review flag) · Classée par (« règle « {pattern} » », « IA locale,
   confiance 78 % », « vous », or « non classée ») · Import (file name, link to Imports).
4. Hairline. Recurring row, when the operation belongs to a series: `repeat` 14 px · « Paiement
   récurrent » over « {cadence} · prochain le {date} » 12 `textTertiary` · link « Voir la
   série ». Otherwise a ghost button « Marquer comme récurrent » (opens the existing dialog).
5. Hairline. « Même marchand » heading + up to 5 previous operations: date `textSecondary` ·
   signed amount.
6. Bottom of the pane: secondary « Créer une règle » (or « Modifier la règle » when one
   classed it) · secondary « Exclure des totaux ».

Nothing selected: the pane shows the note « Sélectionnez une opération pour voir son détail. »

### Category picker (popover, 230 px)
A 28 px search field « Changer de catégorie », then categories and subcategories as items
(category label), a `check` on the current one. Choosing closes it and applies.

### Period modal (420 px)
Title « Période ». Two date fields « Du » · « Au » on the app's calendar picker. Both empty
lifts the filter. Footer « Annuler » · « Appliquer ».

## Tab « À vérifier »
Single pane.

- **Progress row,** padding 16 32: left, 260 px: « {done} sur {total} » 13/600 + « classées
  aujourd’hui » `textSecondary`, over a repère without mark. Right, a Note (`cpu` icon):
  « L’IA locale propose une catégorie pour {n} opérations. Rien n’est classé sans votre
  accord. »
- **Table,** edge to edge:

| Column | Content |
|---|---|
| Libellé du relevé | Raw bank label, Geist Mono |
| Date | right, `textSecondary` |
| Proposition | Category label + « confiance 78 % » 12 `textTertiary`; or « Aucune proposition » `textTertiary` |
| (actions) | With a proposal: primary « Confirmer » (`check`) · secondary « Corriger » · ghost « Créer une règle » (`wand-sparkles`). Without: secondary « Choisir une catégorie » · ghost « Créer une règle ». Only the row under the pointer or with focus shows a primary button; the others show « Confirmer » as secondary, so one screen never carries six primaries. |
| Montant | right, signed and coloured |

| State of the tab | What shows |
|---|---|
| Classification running | The progress row is replaced by a Banner: 14 px spinner · « Catégorisation en cours : 84 sur 213 opérations » · « 61 classées · 23 à vérifier » `textSecondary` · secondary « Annuler » · a repère under the text. The table stays usable. |
| Finished with failures | Banner, `warning` icon, dismissible: « Catégorisation terminée. 12 opérations n’ont pas pu être analysées. » + link « Voir ». |
| AI not configured | Rows show « Aucune proposition »; under the table a Note: « Activez l’IA locale pour classer les opérations que vos règles n’ont pas reconnues. » + link « Paramètres ». Shown nowhere else. |
| Queue empty | Empty state: « Rien à vérifier » · « Toutes vos opérations ont une catégorie. » No button. |

### Rule modal « Toujours catégoriser ainsi » (520 px)
Lead: « Une règle classe ces opérations à chaque import, sans IA. » Fields: Champ (select,
« Description ») · Condition (select, « contient ») · Motif (Geist Mono, focused, prefilled
from the label) · Catégorie cible (select with the category label). Checkbox « Appliquer aux
opérations existantes ». Note: « Correspond à 7 opérations existantes. » Footer « Annuler » ·
« Créer la règle ». On success, toast « Règle créée · 7 opérations recatégorisées ».

## States of the panel
Populated · empty (no transaction: empty state « Aucune transaction » · « Importez un relevé
pour voir vos opérations ici. » · primary « Aller aux imports »; tabs and filters hidden) ·
no result for the filters (in the table area: « Aucune opération pour ces filtres. » + link
« Effacer les filtres ») · loading (silhouette of rows) · English.

## Behaviour (kept)
- Proposals never apply on their own. Below the confidence threshold (Paramètres → Données)
  an operation enters the queue; at or above it, it is classed and does not appear.
- « Confirmer » assigns the proposal and clears the review flag. « Corriger » opens the
  category picker. Deterministic rules always win over AI proposals.
- Choosing a category by hand is never overwritten by a rule or by the AI.
- The classification run is asynchronous and cancellable; the panel stays usable.
- The filters, the tab and the page survive leaving and returning to the panel in a session.
- An operation excluded from totals stays listed, dimmed, with « exclue des totaux » after its
  label.

## Copy
Delete `navTransactionsSubtitle`, `reviewQueueEncouragement`. `transactionsEmptyTitle` per
`00` §14. Replace « — aucune proposition » with « Aucune proposition ». New: « Classée par »,
« Même marchand », « Exclure des totaux », « Sélectionnez une opération pour voir son
détail. », « Rien à vérifier ».

## Removed from v1
Pill filter bar, the « À vérifier » toggle with its amber badge (now a tab), 52 px two-line
rows with the account under the merchant (the account is in the inspector and in the filter),
tinted review header card, ConfidenceGauge, dashed ProposedCategoryChip, gradient « Confirmer »
buttons, coloured monograms, list card frame.
