# 04 — Tableau de bord

Mockup: `#panel=dashboard`. Ticket #205. Read `00-design-system.md` first.

## Title bar
Title « Tableau de bord ». Right: month selector (a 28 px select-look: `chevron-left`, « Mai
2026 », `chevron-right`), then the search field.

## Layout
Content region with standard padding. Five blocks, top to bottom, 24 px apart:

1. **Reading line** (Summary line).
2. Hairline.
3. Two columns (1fr 1fr, gutter 40): « Dépenses par catégorie » · « Épargne mensuelle ».
4. Hairline.
5. Two columns (1fr 1fr, gutter 40): « Activité récente » · « Objectifs ».

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
progress is hatched. Hover card: month, signed amount. A « Barres · Courbe » segmented control
sits before the average (bars by default, kept for the session); the line view draws the same
values with the line recipe, a dot per month in its sign's colour.

### 5a. Activité récente
Heading; right link « Toutes les transactions ». Table without header, as many rows as fit
(6 at 900 px): monogram + label · account (`textTertiary`) · signed amount. Raw bank labels in
Geist Mono. A row opens Transactions with that operation selected.

### 5b. Objectifs
Heading; right link « Tous les objectifs ». Table without header, up to 4 active goals by
creation order: name (150 px) · repère (`done` when reached) · « saved / target » right
(`textSecondary`, target in `textTertiary`) · percent right. Hidden when the user has no active
goal; « Activité récente » then takes the full width.

## States
| State | What shows |
|---|---|
| Populated | As above. |
| Empty (no transaction at all) | Empty state: « Aucune donnée pour ce mois » · « Importez un relevé OFX ou QFX pour voir vos revenus, vos dépenses et votre taux d’épargne. » · primary « Aller aux imports ». Title bar keeps the month selector. |
| Month without data | Reading line with « — » figures in `textTertiary`; category block shows the note « Aucune dépense ce mois. »; charts and activity still show their own ranges. |
| Loading | Silhouette of the five blocks. |
| Error | Error state with « Réessayer ». |
| Collapsed sidebar | Same blocks, wider. |
| English | `+€2,850.00`, « May 2026 », « vs April ». |

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
Delete `navDashboardSubtitle`. Empty state strings per `00` §14. New: « en moyenne sur 12
mois », « Toutes les transactions », « Tous les objectifs », « Objectif atteint ».

## Removed from v1
KPI strip card, donut and its legend column, « Revenus vs dépenses » card, tinted Objectifs
card, card frames around every block, Space Grotesk figures, compact activity rows with the
date under the amount.
