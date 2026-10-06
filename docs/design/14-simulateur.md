# 14 — Simulateur

Everything below is exactly what the mockup frames `14-Simulateur — *` in the Patrimoine mockup canvas show. Colors, amounts, order and positions are normative — do not invent. Tokens per `00-shared-design-block.md`.

## Concept (binding)
Inputs and result stay **on screen together** and the result recomputes on every keystroke. The HCSF block is a **reading**: ratio against 35 %, duration against 25 ans, and the borrowing capacity at the reference — stated with their reference points, in the warning tone when above, **never a refusal and never a lecture**. A small capacity is explained by its cause (the existing loans), calmly. All money and rates are neutral figures.

## Nav
« Simulateur » / "Simulator" (`/simulations`), third in « Patrimoine ». Icon: calculator — rounded rect, display bar, 3×2 key dots, 1.5 px stroke, 2 px active.

## Top bar (this panel)
Title « Simulateur » / "Simulator" + descriptor « Ce qu'un nouveau crédit changerait » / "What a new loan would change". Right: secondary « Enregistrer le scénario » / "Save scenario", user pill.

## Layout (all states)
Grid `400px minmax(0,1fr)`, gap 18, row capped to content height. Left column: form Card then scenarios Card (fills the rest). Right column: result row, HCSF card, projection chart — or the comparison table (③). Chosen over form-above/result-below: at 900 px a stacked layout pushes either the chart or the scenarios out of view while typing.

### Form Card (padding 18/20)
Title « Nouveau crédit », sub « Le résultat se recalcule à chaque saisie ». FormField grid 2 columns (gap 12/14), amounts right-aligned tabular: Prix du bien **320 000,00 €** (focused) · Apport 40 000,00 € · Frais 4 500,00 € · Montant emprunté 284 500,00 € with a 16 px gray pill « DÉRIVÉ » (= prix − apport + frais, still editable; editing it stops the derivation until prix/apport change again) · Taux nominal 3,25 % · Assurance / mois 32,00 €.
**Durée Slider**: label « Durée » ⟷ value « 300 mois · 25 ans » 13/700; 5 px track `#1E2634`, iris gradient fill, 16 px `#EDF1F7` thumb (shared Slider); range 60–360 mois (labels « 5 ans » / « 30 ans »), step 12.
**Toggle** « Inclure mes crédits actuels » + sub « Ajoute 1 506,25 € / mois à la lecture » — off in ①, on in ② (iris gradient track, knob `#EDF1F7` right).

### Scenarios Card
Title « Scénarios enregistrés » ⟷ outline button « Comparer (n/3) » (gray `#232B38`/`#97A3B6` at 0, iris 45 % border/iris text once ≥ 1 checked). Rows 46 px (`#1A212C` dividers): 18 px checkbox (radius 5; checked = iris fill + `#0E1030` check) · name 13/600 (+ iris pill « EN COURS » on the live, unsaved simulation) · sub 11 `#5A6579` « taux · durée · échéance » · ⋯ overflow. Rows drawn: **Lyon 3e — 320 k€** (en cours) « 3,25 % · 25 ans · 1 418,41 € » · Villeurbanne — 265 k€ « 3,25 % · 25 ans · 1 115,45 € » · Lyon 7e — 350 k€ « 3,40 % · 20 ans · 1 845,70 € » · Lyon 8e — 290 k€ « 3,30 % · 25 ans · 1 274,40 € ». The three saved scenarios' inputs are *mock, à fournir*.

### Result row — grid `1.25fr 1fr 1fr`, gap 14
- **Échéance mensuelle** (iris-tint hero): **1 418,41 €** Space Grotesk 32; caption « 1 386,41 € de mensualité + 32,00 € d'assurance · 300 échéances » — payment and insurance are named separately.
- **Coût total**: 145 523,00 € (Space Grotesk 24); « intérêts 131 423,00 € + assurance 9 600,00 € + frais 4 500,00 € · 45,5 % du prix ».
- **TAEG** + iris pill « INDICATIF »: 3,67 %; « taux, assurance et frais inclus ».

### HCSF Card (padding 16/22)
Header: « Lecture HCSF » 14/700 · (StatusPill amber « Au-dessus du repère » when over) · right 11 `#5A6579` info glyph « Informative — ne lie aucun prêteur ». Three columns `1.3fr 1fr 1.3fr`, gap 22:
- **Taux d'endettement**: value Space Grotesk 22 + « repère 35 % »; 6 px gauge scale 0–70 %, `#EDF1F7` tick at 50 % (= 35 %); caption « 1 418,41 € sur un revenu déclaré de 4 600,00 € ». ①: **30,8 %**, iris fill 44 %.
- **Durée**: « 25 ans » + « repère 25 ans »; gauge scale 0–30 ans, tick at 83,3 % (= 25 ans), iris fill; caption « au repère, pas au-delà ».
- **Capacité d'emprunt au repère**: Space Grotesk 22 + caption. ①: **322 928,49 €** « 1 610,00 € d'échéance disponibles sous 35 %, à ces conditions ».
Capacity rule (decided in review): capacity = available instalment under 35 % × (montant emprunté / échéance totale of the current simulation) — i.e. at the simulation's own rate, duration and insurance ratio. The engine formalises this; the drawn values follow from it.

### Projection ChartContainer (fills the rest)
Title « Projection annuelle », sub « Capital remboursé et intérêts versés, année par année », legend « Capital » iris `#8B8CF9` · « Intérêts » cyan `#4FD1E8`. StackedBars: 25 bars (2026 → 2050), capital bottom, interest top, y grid 0 / 8 k€ / 16 k€, x labels every 4 years + last. Yearly, never 300 months.

## ② lecture au-dessus du repère, crédits actuels inclus
Toggle on. HCSF card border `rgba(255,184,77,.35)`, pill « Au-dessus du repère »; ratio **63,6 %** amber fill 90,9 % of the 0–70 % scale, caption « 2 924,66 € (1 418,41 € + crédits actuels 1 506,25 €) sur un revenu déclaré de 4 600,00 € »; capacity **20 809,83 €** with caption « il ne reste que 103,75 € d'échéance sous le repère une fois vos crédits actuels comptés — c'est ce qui rend la capacité si faible, pas le bien visé ». Nothing else turns amber or red; the result row is unchanged.

## ③ comparaison de 3 scénarios
Scenarios card: Lyon 3e (en cours), Villeurbanne, Lyon 7e checked; Lyon 8e at 50 % opacity with disabled checkbox; button « Comparer (3/3) » iris; note under the list « Trois scénarios au plus, pour rester lisibles côte à côte. Décochez-en un pour ajouter Lyon 8e. » Right column replaced by a **comparison Card**: title « Comparaison de 3 scénarios », sub « Mêmes lignes pour chaque colonne · un tiret quand la donnée ne s'applique pas », secondary « × Fermer la comparaison ». DataTable header 44 px `#151B26` with the three names (« EN COURS » pill on the first); rows 36 px, label 190 px `#97A3B6`, three right-aligned columns; emphasised rows (Échéance mensuelle, Coût total) 700 on an iris 5 % wash; section breaks (`#232B38`) before Échéance and before Taux d'endettement:

| | Lyon 3e — 320 k€ | Villeurbanne — 265 k€ | Lyon 7e — 350 k€ |
|---|---|---|---|
| Prix du bien | 320 000,00 € | 265 000,00 € | 350 000,00 € |
| Apport | 40 000,00 € | 40 000,00 € | 40 000,00 € |
| Frais | 4 500,00 € | 3 900,00 € | 5 000,00 € |
| Montant emprunté | 284 500,00 € | 228 900,00 € | 315 000,00 € |
| Taux nominal | 3,25 % | 3,25 % | 3,40 % |
| Durée | 300 mois | 300 mois | 240 mois |
| Assurance / mois | 32,00 € | — | 35,00 € |
| **Échéance mensuelle** | 1 418,41 € | 1 115,45 € | 1 845,70 € |
| Intérêts totaux | 131 423,00 € | 105 735,00 € | 119 568,00 € |
| Assurance totale | 9 600,00 € | — | 8 400,00 € |
| **Coût total** | 145 523,00 € | 109 635,00 € | 132 968,00 € |
| Coût / prix | 45,5 % | 41,4 % | 38,0 % |
| TAEG indicatif | 3,67 % | 3,39 % | 3,86 % |
| Taux d'endettement | 30,8 % | 24,2 % | 40,1 % |
| Avec crédits actuels | 63,6 % | 57,0 % | 72,9 % |

Foot 11 `#5A6579`: « Taux d'endettement sur un revenu déclaré de 4 600,00 € · repère HCSF 35 % · lecture informative, ne lie aucun prêteur. » Columns 2–3 are *mock, à fournir*; column 1 is the brief's simulation.

## ④ revenu inconnu — pas de ratio
HCSF card: ratio and capacity collapse into one 2/3-width block: « — » `#5A6579` + « repère 35 % », text « Aucun revenu connu : le grand livre n'a pas de revenus réguliers et aucun revenu n'est déclaré. Sans revenu, ni taux ni capacité ne peuvent être lus. », outline iris « + Déclarer un revenu ». Durée column unchanged. No gauge is drawn for the ratio.

## ⑤ vide, aucun scénario
Form with placeholder values (0,00 € / — % in `#5A6579`, prix focused). Result cards show « — » in `#5A6579` with their captions (« Renseignez un prix et un taux pour voir l'échéance et sa part d'assurance. »). HCSF: ratio « — », durée at default 25 ans, capacity 322 928,49 € « — la seule lecture possible avant saisie ». Chart card: centered 12.5 `#5A6579` « Renseignez un prix et un taux : la répartition capital / intérêts par année s'affiche ici. » Scenarios card: mini EmptyState (44 px iris plate, « Aucun scénario enregistré », « Enregistrez une simulation pour la retrouver ici et la comparer à deux autres. »), no compare button.

## States to show
① simulation en cours (fr) ② lecture au-dessus du repère, crédits actuels inclus (fr) ③ comparaison de 3 scénarios (fr) ④ revenu inconnu — pas de ratio (fr) ⑤ vide, aucun scénario (fr) ⑥ simulation (en).

## Notes
- « Enregistrer le scénario » names the current inputs (small Modal: Nom, prefilled « Lyon 3e — 320 k€ » pattern « lieu — prix k€ ») and appends a row; the live simulation row « EN COURS » is always first and counts toward the 3-of-3 limit when checked.
- Ratio gauge scale 0–70 % (wider than Crédits' 0–60 % because 63,6 % must sit inside it); the 35 % tick is therefore at 50 %. Above 70 % the fill clamps, the number stays exact.
- Toggle on/off recomputes only the HCSF block; the result row never depends on it.
- The 12 monthly TAEG components (frais amortised over the duration, insurance included) are the engine's; « indicatif » is always attached to the TAEG label.
- Rejected: a monthly projection (300 bars is noise at 700 px), and a red state for the over-reference reading (a reading is not a verdict).
