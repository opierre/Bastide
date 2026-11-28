# 04 — Tableau de bord

Mockup: `#panel=dashboard&variant=D` (proposal v7; the other variants are not retained).
Tickets #205, #381. Read `00-design-system.md` first.

## Title bar
Title « Tableau de bord ». Right: month selector (a 28 px select-look: `chevron-left`, « Mai
2026 », `chevron-right`), then the search field.

## Layout
Content region with standard padding. Five blocks, top to bottom, 24 px apart:

1. **Reading line** (Summary line).
2. Hairline.
3. Two columns (1fr 1fr, gutter 40): « Dépenses par catégorie » · « Épargne mensuelle ».
4. Hairline.
5. Two columns (1fr 1fr, gutter 40): « Par rapport à vos habitudes » on the left; the right
   half is itself two columns (1fr 1fr, gutter 40): « Objectifs » · « À venir ».

Every block reads the month selected in the title bar, except « À venir », which always reads
the current month (§5c).

## Content

### 1. Reading line
| Item | Label | Figure | Under the figure |
|---|---|---|---|
| Lead, 300 px wide | « Taux d’épargne » | `22,3 %` at 40 px | The repère: scale 0 to twice the goal, mark at the goal labelled « objectif 20 % ». Then a status text: goal met → `check` `positive` « Objectif atteint » + « · +1,9 pt depuis avril » in `textSecondary`; not met → « Objectif 20 % en cours · −0,8 pt depuis avril » in `textSecondary`, no icon. |
| 2 | « Revenus » | `+2 850,00 €` 28 px, neutral | Trend line « 2,1 % vs avril » (rise = good). |
| 3 | « Dépenses » | `−2 214,35 €` 28 px, neutral | Trend line « 4,8 % vs avril » (rise = bad, `negative`). |
| 4 | « Net » | `+635,65 €` 28 px, sign-coloured | Trend line « 6,1 % vs avril ». |

Order is fixed: the savings rate leads. Items are separated by vertical hairlines.

### 3a. Dépenses par catégorie
Heading with the month's total spending on the right (`textSecondary`). Ranked bars, one 30 px
row per top-level category with spending this month, largest first:
category label (130 px) · bar (6 px, category hue, length relative to the largest) · amount
(right, 90 px) · share (right, 56 px, `textTertiary`). No row borders. At most 8 rows; beyond,
the smallest fold into « Autres ». Clicking a row opens Transactions filtered on that category
and month.

### 3b. Épargne mensuelle
Heading; right side: the 12-month average, signed and coloured, + « en moyenne sur 12 mois ».
Bars by sign, one per month, the last 12 months ending on the selected month. The month in
progress is hatched when it is in the window; an earlier selected month shows no hatched bar.
Hover card: month, signed amount. Bars only: there is no line view and no view switch.

### 5a. Par rapport à vos habitudes
Each category's spending this month against its own average.

**Heading.** « Par rapport à vos habitudes »; right side, `textSecondary`: the total gap,
« 102,99 € de plus que votre moyenne », « 47,20 € de moins que votre moyenne », or « Égal à
votre moyenne » at 0. The total is the sum of month − average over every row that has an
average, the rows left out by the 8-row limit included.

**Month in progress.** When the selected month is the current one, a Note sits between the
heading and the table: `calendar-clock` « Mai n’est pas terminé : ces montants comparent 14
jours à un mois entier. » The comparison itself does not change: the month's spending so far
is read against the full-month average, so the bars and the gaps still grow until the month
ends. An earlier month shows no Note.

**Table**, with a header row, one row per top-level category with spending this month:

| Column | Width | Header | Cell |
|---|---|---|---|
| Category | 130 px | « Catégorie » | Category label (dot + name), as in §3a |
| Repère | rest | « moyenne sur 12 mois », 11 `textSecondary`, centred on the track | The repère, scale 0 to twice the average, mark at the average, without a label on the row: the header labels the marks of the whole column. Fill `over` when the month's spending reaches 120 % of the average, `accent` otherwise. |
| Month | 90 px, right | The selected month, « Mai » | The month's spending in the category, unsigned |
| Gap | 96 px, right | « Écart » | Status text with the unsigned gap: a rise is `trending-up` `negative`; a fall is `trending-down` `positive`; 0 is `minus` `textSecondary` |

- Rows are ordered by the size of the gap, largest first, rises and falls mixed. At most 8
  rows; the smallest gaps are left out.
- The spending figure is the one of §3a: a top-level category with its subcategories,
  outflows, transfers excluded.
- **Average** (decided): the mean monthly spending of the category over the 12 months
  **before** the selected month, the selected month excluded, so the average stays fixed
  through the month and a spike never softens its own gap. Months before the user's first
  transaction are not counted; inside that range a month without spending in the category
  counts as 0. With fewer than 12 months counted, the header reads « moyenne sur {n} mois ».
- **No history**: a category with no spending in the months counted shows « Aucune dépense
  sur les mois précédents » in `textTertiary` in place of the repère, and « — » in the gap
  column. It is placed after the rows that have a gap and does not count in the heading total.
  When no row has an average (the first month of data), the heading shows no total.
- Clicking a row opens Transactions filtered on that category and month, as in §3a.

### 5b. Objectifs
Heading; right link « Tous les objectifs ». Table without header, up to 4 active goals by
creation order, on half the right half's width. Each row is 48 px and holds two lines, 2 px
apart:

1. Name (ellipsis) · percent, right.
2. Repère (`done` when reached), filling the width · « saved / target » 12 `textSecondary`,
   the target in `textTertiary`, 12 px after the repère.

Clicking a row opens Objectifs with that goal selected.

### 5c. À venir
The recurring charges still due before the end of the **current** month, even when an earlier
month is selected in the title bar: it answers « what will still leave my accounts », which only
the current month can.

**Heading.** « À venir d’ici le 31 mai » (the last day of the current month); right side,
`textSecondary`: the total still due, signed, « −33,48 € ». A missed charge is not in the total.

**Table** without header, up to 4 rows of 48 px. Each row: monogram (22 px) · two lines,
label (ellipsis, at most 150 px) over its date line · signed amount, right, `text`.

| Charge | Date line | Amount |
|---|---|---|
| Expected, same amount as before | « 22 mai », 12 `textTertiary` | `text` |
| Expected, amount risen (Abonnements « Hausse ») | Status text `trending-up` `warning` « 15 mai · hausse de 2,00 € » (new amount − previous) | the new amount, `text` |
| Missed (Abonnements « Prélèvement manquant ») | Status text `clock-alert` `warning` « Attendu le 5 mai » | `textTertiary`, left out of the total |

- Rows come from the active recurring series of Abonnements (`10-subscriptions.md`): a cancelled
  or dismissed series never shows. « Hausse » and « Prélèvement manquant » follow the same rules
  as there.
- Expected charges first, by due date; missed charges after them, oldest first. Beyond 4 rows,
  the latest expected charges are left out; the heading total still counts them.
- Below the table, 4 px apart: link « Tous les abonnements », which opens Abonnements. Clicking
  a row opens Abonnements with that series selected.

## States
| State | What shows |
|---|---|
| Populated | As above. |
| Empty (no transaction at all) | Empty state: « Aucune donnée pour ce mois » · « Importez un relevé OFX ou QFX pour voir vos revenus, vos dépenses et votre taux d’épargne. » · primary « Aller aux imports ». Title bar keeps the month selector. |
| Month without data | Reading line with « — » figures in `textTertiary`; « Dépenses par catégorie » and « Par rapport à vos habitudes » each show the note « Aucune dépense ce mois. »; the savings chart, « Objectifs » and « À venir » still show their own ranges. |
| No charge left to show this month, or no recurring series | « À venir » is hidden; « Objectifs » takes the whole right half, in 36 px one-line rows: name 150 px · repère · « saved / target » 190 px, right · percent 44 px, right. |
| No active goal | « Objectifs » is hidden; « À venir » takes the whole right half, same rows. |
| Neither | « Par rapport à vos habitudes » takes the full width. |
| Category without history | The row says « Aucune dépense sur les mois précédents » instead of drawing a repère (§5a). |
| Current month selected | The Note of §5a under the habits heading. |
| Loading | Silhouette of the five blocks. |
| Error | Error state with « Réessayer ». |
| Collapsed sidebar | Same blocks, wider. |
| English | `+€2,850.00`, « May 2026 », « vs April », « Due by May 31 ». |

## Behaviour (kept)
- Savings rate = (income − expense) / income for the month; the goal comes from Paramètres →
  Préférences. No rate when income is 0: the figure is « — » and the repère is not drawn.
- « Net » is the only sign-coloured figure of the line; income and expenses stay neutral.
- Trend percent is unsigned; the icon carries the direction. Flat = `minus`, `textSecondary`.
- Transfers do not count.
- The income-versus-expense comparison of v1 (« Revenus vs dépenses », grouped bars) is no
  longer on the dashboard: the reading line states both figures and the savings chart shows
  their difference over time.

## Copy
Delete `navDashboardSubtitle`. Empty state strings per `00` §14. Kept: « en moyenne sur 12
mois », « Tous les objectifs », « Objectif atteint ». « Toutes les transactions » leaves the
dashboard with « Activité récente »; delete its key unless another panel uses it.

New, French then English:

| French | English |
|---|---|
| « Par rapport à vos habitudes » | "Compared with your habits" |
| « {amount} de plus que votre moyenne » | "{amount} more than your average" |
| « {amount} de moins que votre moyenne » | "{amount} less than your average" |
| « Égal à votre moyenne » | "Same as your average" |
| « {month} n’est pas terminé : ces montants comparent {days, plural, one {# jour} other {# jours}} à un mois entier. » | "{month} is not over: these amounts compare {days, plural, one {# day} other {# days}} with a full month." |
| « Catégorie » | "Category" |
| « moyenne sur {n} mois » (12 in the usual case) | "{n}-month average" |
| « Écart » | "Gap" |
| « Aucune dépense sur les mois précédents » | "No spending in the previous months" |
| « À venir d’ici le {date} » | "Due by {date}" |
| « {date} · hausse de {amount} » | "{date} · up {amount}" |
| « Attendu le {date} » | "Expected on {date}" |
| « Tous les abonnements » | "All subscriptions" |

`{month}` is the month name with a capital (« Mai », "May"); `{date}` is day and month in the
locale's short form (« 31 mai », "May 31").

## Removed from v1
KPI strip card, donut and its legend column, « Revenus vs dépenses » card, tinted Objectifs
card, card frames around every block, Space Grotesk figures, compact activity rows with the
date under the amount.

## Removed from v2
« Activité récente » (#367): the recent operations are one click away in Transactions; the
dashboard reads the month instead. Variants A (habits only), B (biggest spending and upcoming
charges) and C (spending pace) of proposal v7 are not retained.
