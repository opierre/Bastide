# 12 — Crédits

Mockup: `#panel=loans`. Ticket #213. Read `00-design-system.md` first.

## Concept (binding)
A loan is a scheduled amount, not a booked transaction. Every figure here (instalment,
outstanding principal, interest, TAEG, ratio) is neutral: never green, never red, never
signed. The debt ratio is a reading, stated with its income, the income's source and the HCSF
35 % reference. The sentence « Lecture indicative, qui n’engage aucun prêteur. » is body text,
never a tooltip. Above the reference the tone is `warning`, never `negative`, and never
moralised. With no known income, no ratio is drawn.

## Title bar
Title « Crédits ». Right: primary « Nouveau crédit » (`plus`).

## Layout (list)
Standard padding. Three blocks, 24 px apart:
1. **Summary line.** 2. **Loans table.** 3. **Trajectory chart**, taking the remaining height.

## Content

### 1. Summary line
| Item | Label | Figure | Under |
|---|---|---|---|
| Lead | « Charge mensuelle » | `1 506,25 €` 40 px | « 2 échéances le 1 juin 2026, assurance comprise » |
| 2 | « Capital restant dû » | `234 129,21 €` 20 px | « sur 255 000,00 € · 8,2 % remboursés » |
| 3, 360 px wide | « Taux d’endettement » on the left, the ratio `32,7 %` at 20 px on the right of the same line | — | The repère: scale 0–60 %, mark at 35 % labelled « repère HCSF 35 % ». Then 12 `textTertiary`: « 1 506,25 € sur un revenu déclaré de 4 600,00 €. Lecture indicative, qui n’engage aucun prêteur. » |

Vertical hairlines between the three items.

Ratio states of item 3:
| State | What shows |
|---|---|
| Declared income, under 35 % | As above, `accent` fill. |
| Ledger income, above 35 % | A `warning` status text « Au-dessus du repère » after the label; repère `over`; caption « … sur un revenu médian constaté de 2 850,00 € (12 mois). Un revenu déclaré remplace cette lecture. » + link « Déclarer un revenu » (opens Paramètres → Préférences → Revenu déclaré). |
| No income known | Figure « — » in `textTertiary`; no repère; caption « Aucun revenu connu. Sans revenu, il n’y a pas de taux à calculer. » + secondary « Déclarer un revenu » (same destination). The HCSF sentence stays. |

### 2. Loans table (rows 48 px)
| Column | Content |
|---|---|
| Crédit | Lender monogram + loan name 13/500 |
| Prêteur | « BNP · 300 mois » `textSecondary` |
| Taux | right |
| Assurance | right, `textSecondary`; « — » when none |
| Remboursé | 22 % of the width: repère (0 to principal) over « 7,3 % · 267 échéances restantes » 11 `textTertiary` |
| Capital restant dû | right |
| Fin | right, month and year, `textSecondary` |
| Échéance | right, 13/500, insurance included |

A row opens the loan detail.

### 3. Trajectory
Heading « Capital restant dû jusqu’au dernier remboursement ». Line/area chart of the total
outstanding principal of all loans, monthly, from the first loan's start to the last
instalment; year labels on the x axis. Dashed annotation lines: « {mois} · {amount} » at today
(`text` label) and one per loan end (« fin du prêt travaux », `textTertiary`). A new loan shows
as a step up.

## Loan detail
Title bar: crumb « Crédits / », title = loan name, right: secondary « Modifier ».

1. Summary line: lead « Échéance totale » 40 px with « 1 195,07 € + 28,80 € d’assurance » ·
   « Capital restant dû » 20 px with « 7,3 % remboursé · 267 échéances » · « Prochaine
   échéance » 20 px with the paying account · right-aligned 12 `textSecondary`: « Crédit
   immobilier · BNP · 240 000,00 € sur 300 mois » and « 1re échéance le 1 sept. 2023 · frais de
   dossier 1 450,00 € ».
2. Cost line, a second Summary line at 20 px: « Taux nominal » (« fixe sur toute la durée ») ·
   « TAEG indicatif » (« taux, assurance et frais ») · « Intérêts totaux » (« dont {x} encore à
   verser ») · « Coût total du crédit » (« intérêts + assurance {x} + frais {y} »).
3. Block « Tableau d’amortissement »: heading; under it 12 `textTertiary` « Année 4 sur 25 · 12
   échéances · l’assurance est comptée à part »; right: year switcher (secondary icon buttons
   `chevron-left` `chevron-right` around the year, then a select listing every year). Table,
   dense rows 28 px: Échéance · Intérêts · Capital · Assurance · Total versé · Capital restant
   dû, all right-aligned. The current instalment's row takes `accentSoft`. Last row, 13/600 with
   a top `lineStrong` hairline: « Total 2026 » and the year's sums; last cell « au 31 déc.
   2026 : {amount} » `textSecondary`.

No amortisation curve in the detail: the table carries the numbers, the list's chart the shape.

## Loan form (modal, 600 px)
Title « Nouveau crédit » / « Modifier le crédit ». Two-column grid: Libellé (full width) ·
Prêteur · Type (Crédit immobilier, Prêt travaux, Crédit à la consommation, Crédit auto) ·
Capital emprunté · Taux nominal · Durée (unit « mois ») · 1re échéance · Assurance par mois ·
Frais de dossier · Bien financé (select, optional; an option shows the property's address on
a second line). Under the grid, a read-only line that updates live: « Mensualité calculée »
13/600 + « échéance totale {x} · intérêts totaux {y} » `textSecondary`. Footer: ghost
« Supprimer » on the left (edit only; its confirmation says the loan leaves the net worth) ·
« Annuler » · « Enregistrer ».

## States
List with declared income · list above the reference (ledger income) · list without income ·
detail with schedule · form · empty (« Aucun crédit enregistré » · « Ajoutez un emprunt pour
suivre son coût, son échéancier et votre taux d’endettement. » · primary « Nouveau crédit »;
no summary, no chart) · loading · English (collapsed sidebar).

## Behaviour (kept)
- Income source precedence for the ratio: declared, then ledger (the **median** of the last 12
  complete months of income-category totals; the caption says « médian », never « moyen »),
  then unknown. The caption always names the source.
- The repère scale is fixed at 0–60 % so the 35 % mark never moves; above 60 % the fill clamps
  and the printed percent stays exact.
- The year switcher opens on the year of the current instalment. 300 rows never show at once.
- The schedule is the engine's constant-instalment schedule; nothing here is stored.

## Copy
Delete `navMortgagesSubtitle`, `mortgagesChartSubtitle`. `mortgagesEmptyBody`,
`mortgagesRatioDeclareLink` per `00` §14. « INDICATIF » pill → « TAEG indicatif ». The HCSF
sentence becomes « Lecture indicative, qui n’engage aucun prêteur. »

## Removed from v1
Tinted « Charge mensuelle » hero with lender legend squares, RatioCard, StatusPill, LoanCards
grid, the 4 StatCards of the detail, the segmented year strip, header card with stat trio,
gradient progress bars, dashed read-only plate in the form.
