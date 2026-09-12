# 13 — Impôts (Phase 3)

Everything below is exactly what the mockup frames `13-Impôts — *` in `FinStride Phase 3 Mockups.dc.html` show. Colors, amounts, order and positions are normative for the **visual**; tokens per `00-shared-design-block.md`. See Notes: the figures are mock data, not a calculation reference.

## Concept (binding)
An **estimation, not a declaration**: FinStride files nothing, gives no advice, and says so in the panel body — the limits card is content, not a footnote. Nothing is **silently pre-filled**: ledger suggestions sit under an empty field with their source, coverage and confidence until the user accepts them. Tax amounts and rates are neutral figures (`#EDF1F7`, never green/red, rates without money sign, French formatting). The workings live beside the number: the parameter set for the displayed year is visible and editable in place, an adjusted value is marked and keeps the official value next to it.

## Nav
« Impôts » / "Taxes" (`/tax`), second in « Patrimoine ». Icon: percent sign — diagonal + two 1.8 px-radius rings (`M4.5 13.5l9-9` + rings at 5.8,5.6 and 12.2,12.4), 1.5 px stroke, 2 px active.

## Top bar (this panel)
Title « Impôts » / "Taxes" + descriptor « Une estimation, pas une déclaration » / "An estimate, not a return". Right: **year pill** ‹ 2025 › (38 px, same geometry as the dashboard month pill: two 26 px chevron buttons around a 13/600 tabular year), user pill. No primary button.

## Panel head
SegmentedControl **Estimation | Paramètres fiscaux** (34 px, `#111620` on `#232B38` border, selected segment iris 14 % fill + iris text), margin-bottom 16. When at least one parameter is adjusted a pill « 1 paramètre ajusté » (iris 14 %/iris, 22 px) sits right of the control in both views — this is the way in from the estimate to the parameters.

## Estimation view (frames ① fr · ⑥ en)
Grid `minmax(0,1.15fr) minmax(0,1fr)`, gap 18, row capped to the content height (`minmax(0,1fr)`) — side by side, not stacked: the total must move under the eye while typing; stacked, it leaves the screen at 900 px.

**Left — declaration Card** (padding 20/22): title « Votre déclaration », sub « Foyer et revenus de l'année affichée · rien n'est pré-rempli sans vous ». FormField grid 2 columns, gap 10/16, fields in this order:
Foyer fiscal (Select « Couple ») · Personnes à charge (« 1 », left-aligned) · Parent isolé (Toggle off, « Non ») · Salaires 64 200,00 € · Pensions 0,00 € (placeholder tone `#5A6579`) · Dividendes 1 200,00 € · Intérêts 320,00 € · Plus-values 0,00 € · Imposition des revenus du capital (SegmentedControl in a field: **PFU** | Barème) · Charges déductibles 0,00 € · Crédits d'impôt 0,00 €. Amounts right-aligned tabular.
Below the grid: **property note plate** (`#0A0F15`, dashed `#3A4556`, house glyph) « Les revenus fonciers ne se saisissent pas ici : ils viennent de vos biens déclarés (Studio Villeurbanne · micro-foncier · 3 900,00 €). **Modifier dans Synthèse →** » — no property-income field exists.

**Prefill states** (frame ① shows accepted; ② pending):
- *Accepted*: inline after the label, 11 px `#4ADE80` 600 with check glyph « Suggéré d'après vos imports · 12 mois · accepté »; the field shows the value normally.
- *Pending* (**SuggestionRow**, new composition): field stays **empty** (« 0,00 € » in `#5A6579`); under it a 1 px **dashed** iris 45 % plate (`rgba(139,140,249,.06)`, radius 10, padding 4/8/4/10): amount 12/600 · source 11 `#97A3B6` « d'après vos imports · 12 mois » · ConfidenceGauge 44×5 (track `#1E2634`; fill iris 86 % « Confiance élevée », or **amber `#FFB84D` 38 % « Confiance faible »** for the low-confidence variant « · 4 mois ») · 24 px iris-tint button « Accepter ». Accepting writes the amount into the field and swaps the row for the accepted inline label.
- Card header gains an outline iris button « Tout accepter (2) » when suggestions are pending.

**Right column** (flex column, gap 14):
1. **Result hero** (iris tint Card, padding 18/22): label « TOTAL ESTIMÉ 2025 » iris; value **4 419,99 €** Space Grotesk 32; three 24 px `#1E2634` pills « **5,8 %** taux moyen » · « **11 %** taux marginal » · « **2,5** parts (résultat) » — parts are displayed as a result, never an input; line « Revenu net imposable 60 510,00 € · couple, 1 personne à charge ».
2. **Breakdown Card** (padding 6/22, rows separated by `#1A212C`, label 13/600 + sub 11.5 `#5A6579`, amount 14/700 right) — accounts for the total exactly:
   - Impôt sur le revenu — 3 494,43 € — « Décote non applicable · quotient non plafonné : avantage 989,53 € sous le plafond de 1 791,00 € »
   - PFU — 456,00 € — « IR 194,56 € + prélèvements sociaux 261,44 € sur 1 520,00 € »
   - Revenus fonciers — prélèvements sociaux — 469,56 € — « Net 2 730,00 € (micro-foncier, abattement 30 %) · la part d'IR est déjà dans la ligne impôt sur le revenu »
   - IFI — 0,00 € (`#5A6579`) + gray StatusPill « Non redevable » — « Base 143 957,30 € contre un seuil de 1 300 000,00 € ». **Not liable is a drawn state**, with base and threshold.
3. **Limits Card** (fills the rest, padding 18/22): amber triangle + « Ce que cette estimation ne couvre pas » 14/700; lead 12.5 `#EDF1F7` « Une estimation, pas une déclaration ni un conseil : FinStride ne dépose rien et ne remplace ni votre avis d'imposition ni un professionnel. Certaines situations sont volontairement laissées de côté. »; label « ÉCARTS NOMMÉS »; 2-column bullet list 11.5 `#97A3B6`: Prélèvement à la source déjà versé · Versements PER · Déficits fonciers reportés · CSG déductible · Abattements pour durée de détention · Plus-values immobilières · Micro-BIC / LMNP · Taxe foncière · Autres dettes déductibles de l'IFI · Revenus de source étrangère · Demi-parts d'invalidité.

## ② estimation avec suggestions non acceptées
Salaires accepted (12 mois); **Dividendes pending** 1 200,00 € · 12 mois · confiance élevée; **Intérêts pending** 320,00 € · 4 mois · confiance faible (amber gauge). Header button « Tout accepter (2) ». Result recomputed on entered values: total **3 963,99 €**, hero note « 2 suggestions en attente » iris 11.5; PFU row shows « — » in `#5A6579` with sub « En attente de vos dividendes et intérêts ».

## ⑤ année sans revenus déclarés (year pill on 2024)
Form: all amounts 0,00 € placeholder tone, Personnes à charge 0, pending SuggestionRows on Salaires (61 800,00 € · 12 mois · élevée — *mock, à fournir*) and Dividendes (1 150,00 € · 12 mois · élevée — *mock, à fournir*). Hero « TOTAL ESTIMÉ 2024 » **0,00 €** in `#5A6579`, pills « — » for both rates, parts 2,5. In place of the breakdown an **invitation Card** (centered): 48 px iris plate with percent glyph, « Aucun revenu déclaré pour 2024 », « Le grand livre propose 2 montants pour cette année. Acceptez-les ou saisissez vos revenus pour obtenir une estimation — rien n'est pré-rempli sans vous. », gradient « Accepter les 2 suggestions » + secondary « Saisir manuellement ». Limits card unchanged.

## Paramètres fiscaux view (frames ③ · ④)
Head: « Paramètres fiscaux 2025 » Space Grotesk 16 + sub « Valeurs officielles pour les revenus 2025, modifiables en place. Une valeur ajustée est marquée et garde l'officielle à côté. » + secondary 34 px « ↺ Rétablir les valeurs officielles » (whole year, confirmed via Modal). Grid `minmax(0,1fr) minmax(0,1.1fr)`, gap 18.

**Left column** — two bracket DataTables (Card padding 16/20; table header `#151B26` 30 px; columns Tranche 80 · Plancher · Plafond implicite (`#97A3B6`) · Taux = 78×28 px inline field `#0A0F15`, editable):
- « Barème de l'impôt sur le revenu » — sub « Par part de quotient familial · le plafond d'une tranche est le plancher de la suivante », rows 40 px: 1 · 0,00 € · 11 497,00 € · 0 % / 2 · 11 497,00 € · 29 315,00 € · 11 % / 3 · 29 315,00 € · 83 823,00 € · 30 % / 4 · 83 823,00 € · 180 294,00 € · 41 % / 5 · 180 294,00 € · — · 45 %.
- « Barème de l'IFI » — sub « Appliqué au patrimoine immobilier net dès que le seuil est franchi », rows 38 px: 0 → 800 000,00 € 0 % / 800 000,00 → 1 300 000,00 € 0,50 % / 1 300 000,00 → 2 570 000,00 € 0,70 % / 2 570 000,00 → 5 000 000,00 € 1,00 % / 5 000 000,00 → 10 000 000,00 € 1,25 % / 10 000 000,00 → — 1,50 %.

**Right — Paramètres Card**: rows (padding 7/0, `#1A212C` dividers): label 12.5/600 + one-line help 11 `#5A6579` left; 30 px value field right (min 96 px, value 12.5/600 + unit `#5A6579`):
Plafond du quotient familial 1 791,00 € « Avantage maximal apporté par chaque demi-part supplémentaire. » · Décote — plafond d'impôt (couple) 3 248,00 € · Décote — forfait (couple) 1 470,00 € « Décote = forfait − 45,25 % de l'impôt brut. » · Abattement forfaitaire sur salaires 10 % « Minimum 504,00 €, maximum 14 426,00 € par personne. » · PFU — part impôt sur le revenu 12,8 % · Prélèvements sociaux 17,2 % « Sur les revenus du capital et les revenus fonciers. » · Abattement micro-foncier 30 % « Si les loyers bruts restent sous 15 000,00 €. » · IFI — seuil d'imposition 1 300 000,00 € « Le barème s'applique dès 800 000,00 € une fois le seuil franchi. » · IFI — abattement résidence principale 30 %.
The IR barème and the 1 791,00 € ceiling are the values the brief's 3 494,43 € / 989,53 € derive from; the other parameter values are *mock, à fournir* (see Notes).

**④ valeur ajustée + modal**: Prélèvements sociaux row → value **18,0 %** in iris with iris field border, pill « AJUSTÉ » (iris 14 %, 10 px uppercase) after the label, « officiel 17,2 % » 11 `#5A6579` and a 26 px ↺ per-row restore button (immediate) before the field. Head pill « 1 paramètre ajusté ». Modal 460 px: « Rétablir les valeurs officielles 2025 ? », « 1 paramètre ajusté sera remplacé par sa valeur officielle. L'estimation 2025 sera recalculée aussitôt. », plate « Prélèvements sociaux 18,0 % → **17,2 %** », « Annuler » · gradient « Rétablir » (not destructive: no red).

## States to show
① estimation (fr) ② estimation avec suggestions non acceptées (fr) ③ paramètres fiscaux (fr) ④ paramètres fiscaux, valeur ajustée + modal de rétablissement (fr) ⑤ année sans revenus déclarés — estimation à zéro, invitation (fr) ⑥ estimation (en).

## Notes
- **These figures are visual mock data, not a calculation oracle.** The verified tax engine is the backend's (`PROJECT.md` §16, card P3-07); this file fixes where each number sits and how it is dressed, never how it is computed. Where the mock arithmetic and the engine disagree, the engine wins and the layout must absorb the engine's figures at these widths. The brief's total 4 419,98 € was replaced by **4 419,99 €** so the drawn breakdown accounts exactly (decision recorded in review).
- Parameter values other than the IR barème and quotient ceiling, and the 2024 suggestion amounts, are placeholders — *à fournir* by the owner before build.
- Year pill changes both views; parameters are stored per year. Editing a barème rate or a parameter marks the row adjusted immediately and recomputes the estimate; adjusted rows never lose their official value.
- Suggestions come only from ledger imports; coverage (« N mois ») and confidence are always shown together; a field with an accepted suggestion that the user then edits by hand drops the accepted label.
- The parts pill is a result of foyer + personnes à charge + parent isolé; it is never editable.
- EN strings render in the same geometry (frame ⑥); « Net worth » is the EN name of Synthèse used in the property link.
