# 15 — Synthèse

Mockup: `#panel=networth`. Ticket #215 (placements are added by #218). Read
`00-design-system.md` first.

## Concept (binding)
Net worth = accounts + declared value of investments + held share of declared properties −
outstanding loan principal. It is a neutral figure, positive or negative, with a leading `−`
(U+2212) when negative. Property values are held flat at their declared value; investments
count for their last declared value. What is deliberately not counted (objectives,
subscriptions) is said on the panel.

## Title bar
Title « Synthèse » (English: « Net worth »). Right: secondary « Nouveau bien » (`plus`).

## Layout
Standard padding. Five blocks, 24 px apart:
1. **Equation line.** 2. Hairline. 3. Two columns (440 px · flexible, gutter 48):
« Composition de l’actif » · « Patrimoine net ». 4. Hairline. 5. Two columns (1fr 1fr, gutter
40): « Biens » · « À savoir ».

There is no Synthèse | Biens switch: properties are block 5 of the same page.

## Content

### 1. Equation line
A row, bottom-aligned, 28 px apart, read as a sum:
« Actif » 28 px with « Comptes {x} · Placements {y} · Biens {z} » · the operator `−` 28 px
`textTertiary` · « Passif » 28 px with « {n} crédits, capital restant dû » · the operator `=` ·
« Patrimoine net » 40 px with a neutral status text: `trending-up` or `trending-down` +
« +1 977,78 € depuis avril » (never `positive` or `negative`: a net-worth move is not income).
Parts that are zero are left out of the Actif caption.

### 3a. Composition de l’actif
Composition bar (`00` §9), then a table without header: category-style label (dot in the
segment's hue + name, in `text`) · share right `textTertiary` · amount right. Rows by
descending amount: one per property nature (« Résidence principale », « Locatif, part
détenue »…), « Placements », and one per account type (« Livret A », « Comptes courants »…).
Under the table, when a property is held in part, 12 `textTertiary`: « Un bien compte pour la
part détenue : {label}, {held} sur {full}. »

### 3b. Patrimoine net
Heading; after it the shown range 12 `textTertiary` (« juin 2025 – mai 2026 »); right:
segmented « Tout · 3 ans · 12 mois » (default 12 mois). Line/area chart, one point per month.
The y scale's floor sits 12 % of the range below the lowest month. A segment that touches a
declared month is dashed; when the range holds one, a legend under the chart reads « Comptes
importés » (solid) · « Montants déclarés » (dashed). Hover card: month, net worth, and
« Montants déclarés » when the month was declared. Bottom-right of the block: link
« Historique déclaré ».

### 5a. Biens
Heading with the count. Table: Bien (name; the address under it in 12 `textTertiary` when
there is one, row 48 px) · Nature `textSecondary` · Quote-part right `textSecondary` · Valeur
détenue right. Row menu `ellipsis`: Modifier · Nouvelle estimation · Archiver. Under the
table: `archive` + « {n} biens archivés » when any. A row opens the property form.

### 5b. À savoir
Heading, then Notes:
- `chart-line` « Les placements comptent pour leur dernière valeur saisie. Entre deux
  saisies, la courbe reste plate. »
- `flag` « Les objectifs réservent de l’argent déjà présent sur un compte. Ils ne sont pas
  comptés une seconde fois. »
- `repeat` « Un abonnement est une dépense à venir, pas une dette due aujourd’hui. »
- `info` « Les biens sont maintenus à leur valeur déclarée (estimation la plus ancienne :
  {date}) et ne comptent qu’à partir de leur date d’acquisition, les crédits qu’à partir de
  leur déblocage. Les mois sans donnée sont absents. »

## Modals
- **Property form** (620 px): « Nouveau bien » / « Modifier le bien ». Two columns: Libellé (full
  width) · Adresse (optional, full width, ≤ 255 characters) · Nature (select) · Quote-part
  détenue (the label carries « part : {amount} » live) · Valeur déclarée · Date d’estimation ·
  Prix d’acquisition · Date d’acquisition. Footer « Annuler » · « Enregistrer ».
- **Nouvelle estimation** (420 px): lead « {label} : {value} estimés le {date}. La nouvelle
  estimation remplace celle-ci. » Valeur · Date.
- **Historique déclaré** (560 px): lead « Le total de tous vos comptes à la fin d’un mois,
  pour la période avant vos imports. Un mois couvert par vos imports garde le chiffre
  importé. » One row: Mois (« MM/AAAA ») · Total des comptes · primary « Enregistrer ». Then
  the list, newest first, rows 36 px: month · « Couvert par vos imports » when the ledger has
  it · amount · icon buttons edit and delete. A covered month is a dimmed row and keeps only
  delete: its declared figure is no longer used. Footer « Fermer » (`00` §7 list editor).

## States
| State | What shows |
|---|---|
| Populated | As above. |
| No property | Actif caption without « Biens »; composition without property rows; block 5a shows the note « Aucun bien déclaré : l’actif ne compte que vos comptes et vos placements. » + link « Nouveau bien ». Net worth may be negative: `−209 829,21 €`, neutral. |
| No investment | « Placements » absent from caption, composition and notes. |
| Empty (no account, property, loan or investment) | Empty state: « Aucun compte, bien ou crédit » · « Importez un compte ou déclarez un bien. La synthèse additionne vos avoirs et soustrait vos crédits. » · primary « Nouveau bien », secondary « Aller aux imports ». |
| Loading | Silhouette of the blocks. |
| English | « Assets », « Liabilities », « Net worth ». |

## Behaviour (kept)
- Delta = this month's net worth minus last month's.
- A month's point = account balances at month end + investments at their last declared value
  on that date + held property shares − loan balances after that month's instalments. A month
  with no account snapshot is skipped, not zeroed.
- Declared history stands in for account balances before the first import; the ledger always
  wins on a month it covers, and the two are never added. Only an ended month can be declared.
- A property counts from its acquisition month (all along when it has no date); a loan from
  the month before its first instalment.
- Over 12 months the x labels thin to at most 12, labelled « janv. 24 ».
- Archiving a property keeps its history and removes it from the assets from that date;
  archived properties can be restored.
- « Nouvelle estimation » appends a dated value; the latest is shown; the note names the
  oldest current estimate.
- No donut for the composition.

## Copy
Delete `navNetworthSubtitle`, `networthCompositionSubtitle`, `networthSeriesSubtitle`.
`networthEmptyTitle`, `networthEmptyBody`, `networthExclusionGoalsBody`,
`networthCompositionInviteAction` per `00` §14. « VOLONTAIREMENT NON COMPTÉ » → « À savoir ».
`networthDeltaCaption` → « {delta} depuis {month} ». `networthSeriesCaveat`: drop
« simplement ».

## Removed from v1
The Synthèse | Biens segmented control and the PropertyCard grid, tinted « Patrimoine net »
hero, iris delta pill, Actif and Passif cards, the uppercase « non compté » card, the dashed
« Nouveau bien » tile, the caveat banner (now a note).
