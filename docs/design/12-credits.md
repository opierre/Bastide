# 12 — Crédits (Phase 3)

Everything below is exactly what the mockup frames `12-Crédits — *` in `FinStride Phase 3 Mockups.dc.html` show. Colors, amounts, order and positions are normative — do not invent. Tokens per `00-shared-design-block.md` (Geist UI, Space Grotesk display, `#0A0F15` fields).

## Concept (binding)
A loan is a **scheduled amount, not a booked transaction**: every figure on this panel (échéance, capital restant dû, intérêts, TAEG, ratio) is a neutral `#EDF1F7` figure — never green, never red, never signed. The debt ratio is a **reading**, stated with its income, its income source and the 35 % HCSF reference; the line « Lecture informative : ce repère ne lie aucun prêteur. » is first-class card content, never a tooltip. Being above the reference is a warning-tone reading (amber `#FFB84D`), never a red refusal and never moralised. When no income is known, no ratio is drawn — the card says why and offers the way out.

## Nav
Sidebar group « Patrimoine » / "Wealth" (10 px uppercase label, after Gestion, before the Paramètres divider), first item « Crédits » / "Loans" (`/mortgages`). Icon: house — pentagon roof/walls with a door notch (`M3 8.2L9 3l6 5.2V15H3zM7.2 15v-4.2h3.6V15`), 1.5 px stroke, 2 px active. Sidebar stack 3 + 4 + 4 + 1 at the 40 px pill rhythm measures ≈ 720 px at 900 — ≈ 176 px of slack, no token changed. Collapsed 76 px rail (drawn on ⑦): 28 px `#1A212C` hairline between each icon group and before Paramètres; lock glyph at the foot.

## Top bar (this panel)
Title « Crédits » / "Loans" + descriptor « Vos emprunts, leur coût et votre capacité » / "Your loans, their cost and your capacity". Right: primary gradient « Nouveau crédit » / "New loan", user pill.

## List state (frames ① fr / ⑦ en)
Content padding 24×28, three blocks top to bottom, gap 18.

**1. Summary row** — grid `1fr 1fr 1.5fr`, gap 18, all Cards padding 20/22.
- **Charge mensuelle** (hero — the only iris-tinted card: SavingsRateCard tint, border `rgba(139,140,249,.35)`, label iris): value `1 506,25 €` (Space Grotesk 29), caption « 2 échéances le 01/06/2026 · assurance comprise », foot legend two 8 px squares in lender hues: BNP `#2FB574` 1 223,87 € · Crédit Agricole `#0AA396` 282,38 €.
- **Capital restant dû**: `234 129,21 €`, caption « sur 255 000,00 € empruntés · 2 crédits », foot 8 px progress bar (track `#1E2634`, iris gradient fill 8,2 %) + « 20 870,79 € remboursés · 8,2 % ».
- **Taux d'endettement** (RatioCard): label + optional StatusPill right; value `32,7 %` (Space Grotesk 29, neutral) beside « repère HCSF 35 % » 12 px `#97A3B6`; **RatioGauge** — 8 px track `#1E2634`, scale 0–60 %, iris fill to 54,5 % of width (= 32,7 %), 2 px `#EDF1F7` tick at 58,3 % (= 35 %) with « 35 % » 10.5 px label above; caption « Charge 1 506,25 € sur un revenu déclaré de 4 600,00 € »; foot line 11 px `#5A6579` with info-circle glyph « Lecture informative : ce repère ne lie aucun prêteur. »

**2. LoanCards** — grid 2 columns, gap 18 (cards, not rows: two loans of very different size each keep a progress bar and dates at equal rank; a DataTable header would organise less than it costs at n ≤ 5). Card padding 18/22, hover border `rgba(139,140,249,.45)`, whole card clickable → detail.
Header: 40 px lender monogram (radius 12) · name (Space Grotesk 16/700) + sub 12 `#97A3B6` · right: échéance totale (Space Grotesk 22) over « / mois » 11 `#5A6579`. Then « Capital restant dû » 12 `#97A3B6` ⟷ `bal` 14/700 « sur `principal` » 11.5 `#5A6579`; 8 px progress bar (iris gradient = repaid share); « `pct` remboursé » (pct iris 600) ⟷ « `n` échéances restantes ». Footer (border-top `#1A212C`): three uppercase 10.5 px labels Taux nominal · Assurance · Prochaine échéance with 13/600 values, chevron right.

| | Card 1 | Card 2 |
|---|---|---|
| Monogram | BNP `#2FB574` | CA `#0AA396` |
| Name / sub | Appartement Lyon 3e / Crédit immobilier · BNP · 300 mois | Travaux cuisine / Prêt travaux · Crédit Agricole · 60 mois |
| Échéance | 1 223,87 € | 282,38 € |
| Capital restant dû / sur | 222 542,70 € / 240 000,00 € | 11 586,51 € / 15 000,00 € |
| Remboursé · restantes | 7,3 % · 267 | 22,8 % · 45 |
| Taux · Assurance · Prochaine | 3,45 % · 28,80 € / mois · 01/06/2026 | 4,90 % · — · 01/06/2026 |

**3. Trajectory ChartContainer** (fills the rest): title « Trajectoire du capital restant dû », sub « Les deux crédits, échéance après échéance, jusqu'au dernier remboursement », legend right (iris line « Capital restant dû total », dashed « aujourd'hui »). AreaLine: total outstanding of both loans, monthly, from 09/2023 (255 000 € at the travaux start in 03/2025 is a visible step up) to 08/2048; y grid 0 / 100 k€ / 200 k€ `#1A212C`; x labels 2025 · 2030 · 2035 · 2040 · 2045. Annotations (dashed verticals + 3.5 px iris-ring dot): « mai 2026 · 234 129,21 € » (`#97A3B6` line, `#EDF1F7` text), « fin prêt travaux · 02/2030 », « fin crédit immobilier · 08/2048 » (`#5A6579`). The chart adds what the table cannot: when each debt ends and the step the second loan adds.

## Ratio states (frames ④ ⑤ — list state otherwise unchanged)
- **④ revenu du grand livre, au-dessus du repère**: StatusPill amber « Au-dessus du repère » top-right; value `52,9 %`; gauge fill amber `#FFB84D` to 88,2 %; caption « Charge 1 506,25 € sur un revenu moyen constaté de 2 850,00 € (12 mois du grand livre). Le ménage perçoit peut-être des revenus hors application : un revenu déclaré remplace cette lecture. »; iris link « Déclarer un revenu → ». Card border unchanged (`#242E3E`) — the tone lives in pill and fill only.
- **⑤ sans revenu connu**: value « — » in `#5A6579` beside « repère HCSF 35 % »; **no gauge**; text 12 « Aucun revenu connu : le grand livre ne contient pas de revenus réguliers et aucun revenu n'est déclaré. Sans revenu, il n'y a pas de taux à calculer. »; outline iris Button 30 px « + Déclarer un revenu ». HCSF foot line stays.

## Detail state (frame ②, crédit immobilier)
Iris back link « Retour aux crédits ». **Header Card** (padding 20/26): 48 px BNP monogram · « Appartement Lyon 3e » Space Grotesk 20 + sub « Crédit immobilier · BNP · 240 000,00 € sur 300 mois · 1re échéance le 01/09/2023 · frais de dossier 1 450,00 € » · three right stats (10.5 uppercase label / 15 700 value / 11 caption): Échéance totale 1 223,87 € « 1 195,07 € + 28,80 € assurance » · Capital restant dû 222 542,70 € « 7,3 % remboursé · 267 échéances » · Prochaine échéance 01/06/2026 « BNP — Compte courant » · secondary « Modifier ».
**Cost row** — 4 StatCards (padding 16/20, value Space Grotesk 24): Taux nominal 3,45 % « fixe sur toute la durée » · TAEG + iris pill « INDICATIF » 3,79 % « taux, assurance et frais inclus » · Intérêts totaux 118 521,00 € « dont 92 406,74 € encore à verser » · Coût total du crédit 128 611,00 € « intérêts + assurance 8 640,00 € + frais 1 450,00 € ».
**Amortisation Card** (fills the rest, padding 16/22): title « Tableau d'amortissement », sub « Année 4 sur 25 · 12 échéances · l'assurance est comptée à part »; **YearSwitcher** right = ‹ 2026 › pill (34 px, same geometry as the dashboard month pill) + a segmented year strip 2023 · 2024 · 2025 · **2026** (iris 12 % fill) · 2027 · « … 2048 » (disabled tone). DataTable, header `#151B26` 30 px, rows **28 px** (dense variant — 12 rows + foot must fit 900), columns Échéance 150 · Intérêts · Capital · Assurance · Total versé · Capital restant dû (1.3 fr), all amounts right-aligned tabular; the current instalment row (01/05/2026) has an iris 6 % wash and an iris 700 date. Foot row 34 px `#151B26` 700: « Total 2026 » · 7 667,82 € · 6 673,02 € · 345,60 € · 14 686,44 € · « au 31/12/2026 : 218 622,20 € » (`#97A3B6` 400). 300 rows never appear at once.

| Échéance | Intérêts | Capital | Assurance | Total versé | Capital restant dû |
|---|---|---|---|---|---|
| 01/01/2026 | 647,72 € | 547,35 € | 28,80 € | 1 223,87 € | 224 747,87 € |
| 01/02/2026 | 646,15 € | 548,92 € | 28,80 € | 1 223,87 € | 224 198,95 € |
| 01/03/2026 | 644,57 € | 550,50 € | 28,80 € | 1 223,87 € | 223 648,45 € |
| 01/04/2026 | 642,99 € | 552,08 € | 28,80 € | 1 223,87 € | 223 096,37 € |
| **01/05/2026** | 641,40 € | 553,67 € | 28,80 € | 1 223,87 € | **222 542,70 €** |
| 01/06/2026 | 639,81 € | 555,26 € | 28,80 € | 1 223,87 € | 221 987,44 € |
| 01/07/2026 | 638,21 € | 556,86 € | 28,80 € | 1 223,87 € | 221 430,58 € |
| 01/08/2026 | 636,61 € | 558,46 € | 28,80 € | 1 223,87 € | 220 872,13 € |
| 01/09/2026 | 635,01 € | 560,06 € | 28,80 € | 1 223,87 € | 220 312,06 € |
| 01/10/2026 | 633,40 € | 561,67 € | 28,80 € | 1 223,87 € | 219 750,39 € |
| 01/11/2026 | 631,78 € | 563,29 € | 28,80 € | 1 223,87 € | 219 187,10 € |
| 01/12/2026 | 630,16 € | 564,91 € | 28,80 € | 1 223,87 € | 218 622,20 € |

(Rows are the standard constant-instalment schedule anchored on the brief's 222 542,70 € at 01/05/2026; the engine's own schedule is the reference.)

No amortisation curve in the detail — rejected: the table carries the numbers and the list's trajectory chart already carries the shape; a second chart would repeat, not add.

## Modal nouveau crédit (frame ③, over the list)
600 px Modal (`#19202B`, radius 20, scrim `rgba(4,6,11,.62)`), title « Nouveau crédit », sub « La mensualité est calculée à partir du capital, du taux et de la durée. » Two-column FormField grid (gap 12/14): Libellé (full width, focused) · Prêteur (Select with 24 px monogram) · Type (Select: Crédit immobilier / Prêt travaux / Crédit à la consommation / Crédit auto) · Capital emprunté · Taux nominal · Durée (« mois » unit) · 1re échéance (date) · Assurance / mois · Frais de dossier. Amount fields right-aligned tabular. Below: read-only plate (`#0A0F15`, dashed `#3A4556`, lock glyph) « Mensualité calculée **282,38 €** · échéance totale 282,38 € — intérêts totaux 1 942,80 € », live as the fields change. Footer « Annuler » · gradient « Ajouter le crédit ». Frame shows the Prêt travaux values as the worked example.

## Empty state (frame ⑥)
Centered EmptyState: 64 px iris plate with the house glyph; « Aucun crédit enregistré »; « Ajoutez vos emprunts pour suivre leur coût réel, leur trajectoire et votre capacité — sans jamais relier FinStride à une banque. »; gradient CTA « Nouveau crédit ». Summary row and chart are not drawn.

## States to show
① liste (fr) ② détail + tableau d'amortissement (fr) ③ modal nouveau crédit (fr) ④ ratio sur revenu du grand livre, au-dessus du repère (fr) ⑤ ratio sans revenu connu (fr) ⑥ vide (fr) ⑦ liste (en, rail replié 76 px).

## Notes
- Income source precedence for the ratio: `declared` › `ledger` (12-month average of income-category transactions) › `unknown`. The card always names the source in its caption.
- Gauge scale is fixed 0–60 % so the 35 % tick sits at the same x in every state; a ratio above 60 % clamps the fill and still prints the real percent.
- LoanCard click → detail; YearSwitcher ‹ › steps one year, the strip jumps; the year of the current instalment is selected on open.
- « Modifier » opens the same modal as « Nouveau crédit » prefilled. Deleting a loan is done from that modal (secondary text button) and removes it from Synthèse passif and from the IFI base (mortgage on the main residence) — the confirmation says both.
- Money rule: all figures neutral; the only colored figures are the ratio value/fill (iris under, amber over) and lender monograms. EN frame: « Net worth » is the EN label of Synthèse (the group « Aperçu » already owns "Overview").
