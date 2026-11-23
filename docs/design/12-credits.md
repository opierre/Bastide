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

## Loan form (modal, 960 px)
Title « Nouveau crédit » / « Modifier le crédit ». The body is laid out as the Simulateur
(`14-simulateur.md` §Layout) and shares its widgets: an **inputs pane** (the Simulateur's 380 px,
measured from the modal's edge, right hairline running the body's height) and a **reading pane**
32 px after the hairline. Modal metrics apply inside it (fields 14 px apart, 16 px gutter).

Inputs pane, top to bottom: Libellé (full width) · Prêteur · 1re échéance · Type (full width:
Crédit immobilier, Prêt travaux, Crédit à la consommation, Crédit auto) · Remboursement (full
width: Échéance constante, In fine) · then the Simulateur's terms block: Frais de dossier ·
Capital emprunté · Taux nominal · Assurance par mois (amounts right-aligned, placeholder
« 0,00 », rate placeholder « — ») and « Durée » with its value on the same line, a slider from
« 1 an » to « 30 ans » **a month at a time** (a contracted term need not be whole years; the value
reads « 7 ans · 84 mois » on whole years, « 90 mois » otherwise; a new loan opens on 25 years) ·
Bien financé (facultatif, full width, select; an option shows the property's address on a second
line; absent while there is no property to link).

Reading pane, recomputed on every keystroke, 22 px apart with a hairline between: the
Simulateur's summary line (« Échéance mensuelle » 40 px · « Coût total » · « TAEG indicatif »,
captions up to three lines) and its « Projection annuelle » (400 px, heading included). Before a
principal and a rate the figures are « — » with « Renseignez le capital et le taux pour voir
l’échéance. » and the chart note « Renseignez le capital et le taux : la répartition par année
s’affiche ici. » An in-fine loan, which the simulator does not compute, keeps the dashes with
« La mensualité d’un prêt in fine s’affiche une fois le crédit enregistré. » and the note « La
répartition par année d’un prêt in fine se lit dans son tableau d’amortissement, une fois le
crédit enregistré. » A refused computation is explained under the rate or the fees when one of
them is the cause, otherwise as a Banner above the summary line. No HCSF block and no
existing-loans toggle: the debt ratio is read on the Crédits list.

Footer: ghost « Supprimer » on the left (edit only; its confirmation says the loan leaves the
net worth) · « Annuler » · « Enregistrer ».

**Delete confirmation** (440 px), destructive: « Supprimer le crédit « {libellé} » ? », lead
« Il ne sera plus déduit de votre patrimoine dans la Synthèse, et son tableau d’amortissement
disparaît. Vos comptes ne sont pas modifiés. »

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
