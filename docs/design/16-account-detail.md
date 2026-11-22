# 16 — Détail d’un compte

Mockup: `#panel=account`. Ticket #207. Read `00-design-system.md` first.

## Entry
Opened from a row of Comptes. The sidebar keeps « Comptes » active.

## Title bar
Crumb « Comptes / » (link back to the list), title = account name. Right: secondary
« Modifier » (opens the account form of `05-accounts.md`), then a secondary icon button
`ellipsis` whose menu holds « Archiver ». No delete.

## Layout
Standard padding. Blocks separated by 24 px, a hairline, 24 px (`00` §1.2); the summary
line is the first of them:

1. **Summary line.**
2. **Balance chart** block.
3. **Linked cards** block (only when the account settles cards, or is itself a card).
4. **Operations** block.

## Content

### 1. Summary line
| Item | Label | Figure | Under |
|---|---|---|---|
| Lead | « Solde au {date} » | balance at 40 px, sign-coloured (this headline is the one place a positive balance is `positive`) | — |
| 2 | « Entrées en {mois} » | 20 px, neutral with `+` | — |
| 3 | « Sorties en {mois} » | 20 px, neutral with `−` | — |
| 4 | « Net » | 20 px, neutral with its sign | — |

Right-aligned at the end of the line, two 12 `textSecondary` lines: « {institution} · {type} »
and « Historique depuis le {date} · » + link « dernier import le {date} » (opens Imports
filtered on this account). French runs long: the two lines may wrap, never truncate.

### 2. Solde en fin de mois
Heading; right: segmented « 6 mois · 12 mois · Tout » (default 12 mois). Line/area chart of
month-end balances, one point per month, the last point being today's balance. When the series
crosses zero, the zero line is drawn and the area below it takes `negative` at 10 %. Hover
card: month, balance, change from the previous month signed and coloured.

Under the chart, only when true, one 12 `textSecondary` sentence: « Votre solde progresse
depuis {n} mois. » Never a sentence about a decline.

### 3. Cartes rattachées
Heading « Cartes rattachées ». Table without header, rows 48 px: monogram + card name with the
masked number under it (« •••• 4821 », `textTertiary`, omitted when unknown) · neutral text
« Débit différé » · right: « En cours ce mois » amount (`negative`) over « Prélevé le
{date} » 11 `textTertiary` · `chevron-right`. A row opens that card's detail.
- Settlement rule missing: a `warning` status text « Règle de règlement à configurer » that
  opens the settlement-rule dialog.
- No card: the block is not drawn (a current account without cards has nothing to show).

### 4. Opérations
Heading; right link « Ouvrir dans Transactions » (filtered on this account). Table: Opération
(monogram + label) · Catégorie (category label) · Date (right, `textSecondary`) · Montant
(right, signed). The 8 most recent.

## Variant: the account is a deferred-debit card
- Summary lead label « Encours du cycle »; items 2–4 become « Cycle précédent », « Moyenne
  sur 6 cycles », « Prélevé le {date} ».
- Block 2 becomes « Dépenses par cycle »: bars by sign (all `negative`), one per settlement
  cycle, the cycle in progress hatched.
- Block 3 becomes « Compte de règlement »: one row with the paying account (monogram, name,
  balance), the rule summary « Libellé : {pattern} · appliquée depuis le {date} » in
  `textSecondary`, and a secondary « Modifier la règle ».

## States
| State | What shows |
|---|---|
| Populated, current account | As above. |
| Populated, deferred card | The variant. |
| Less than two months of history | Chart block shows the note « Le graphique apparaîtra après le deuxième mois d’historique. » and a secondary « Importer un relevé »; the right-hand line reads « Aucune opération ». |
| Settlement rule missing | The `warning` status text in block 3. |
| Loading | Silhouette of the blocks. |
| English | « Balance on May 14, 2026 », month-first dates, `€3,486.12`. |

## Behaviour (kept)
- The opening balance is edited in the account form; correcting it shifts the balance and its
  history by the same amount and modifies no transaction.
- The chart's data is monthly snapshots: no daily points.
- Balances shown here are recalculated; the caption states the date.
- No per-account currency.

## Copy
New: « Solde au {date} », « Entrées en {mois} », « Sorties en {mois} », « Solde en fin de
mois », « Ouvrir dans Transactions », « Dépenses par cycle ». The old « Évolution du solde »
and « Dernières opérations » strings are replaced.

## Removed from v1
Identity card with a 48 px avatar and a type chip, meta strip with glyphs, stats card, cyan
chart line (the accent is used now), « ‹ Tous les comptes » back link (the crumb replaces it),
full-width cards around each block.
