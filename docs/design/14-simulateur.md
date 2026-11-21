# 14 — Simulateur

Mockup: `#panel=simulator`. Ticket #214. Read `00-design-system.md` first.

## Concept (binding)
Inputs and result stay on screen together and the result recomputes on every keystroke. The
HCSF block is a reading (ratio against 35 %, duration against 25 years, borrowing capacity at
the reference), stated with its reference points, in the `warning` tone when above: never a
refusal and never a lecture. A small capacity is explained by its cause. All money and rates
are neutral figures.

## Title bar
Title « Simulateur ». Right: secondary « Enregistrer le scénario » (`bookmark`).

## Layout
Flush panel, two panes: **inputs** (380 px, right hairline, padding 24) · **reading**
(flexible, padding 24 32). The comparison replaces the reading pane.

## Inputs pane, top to bottom, 14 px apart
1. « Nouveau crédit » 13/600.
2. Two-column field grid (gap 12), amounts right-aligned: Prix du bien · Apport · Frais ·
   Montant emprunté (helper « calculé : prix − apport + frais »; still editable, and editing it
   stops the calculation until price or down payment change) · Taux nominal · Assurance par
   mois.
3. « Durée » with its value on the same line (« 25 ans · 300 mois »), a slider 60–360 months,
   step 12, and the end labels « 5 ans » · « 30 ans » 11 `textTertiary`.
4. Toggle row: « Inclure mes crédits actuels » over « Ajoute {charge} par mois à la lecture »
   12 `textTertiary`.
5. Hairline.
6. « Scénarios enregistrés » 13/600; right: secondary « Comparer ({n}/3) », disabled at 0.
7. Scenario rows: checkbox · name over « taux · durée » 12 `textTertiary` · spacer · instalment
   `textSecondary` · `ellipsis` on hover (Renommer, Supprimer). The live, unsaved simulation is
   always first, with « en cours · » before its sub-line.

## Reading pane, top to bottom, 22 px apart
1. **Summary line:** lead « Échéance mensuelle » 40 px with « {payment} de mensualité +
   {insurance} d’assurance · {n} échéances » · « Coût total » 20 px with « intérêts {x} ·
   assurance {y} · frais {z} » · « TAEG indicatif » 20 px with « taux, assurance et frais ».
2. Hairline.
3. **Lecture HCSF:** heading row: « Lecture HCSF » 13/600 · when above the reference, a
   `warning` status text « Au-dessus du repère » · spacer · 12 `textTertiary` « Lecture
   indicative, qui n’engage aucun prêteur. » Then three equal columns (gap 40):
   - « Taux d’endettement » with the ratio at 20 px on the right; repère 0–70 %, mark at 35 %
     « repère 35 % », `over` above it; caption « {instalment} sur un revenu {déclaré | médian
     constaté} de {income} ». With current loans included the caption reads « {total}
     ({instalment} + crédits actuels {charge}) sur… ».
   - « Durée » with « 25 ans » at 20 px; repère 0–30 years, mark at 25 years « repère 25 ans »;
     caption « Au repère, pas au-delà » or « Sous le repère » or, above, « Au-delà du repère ».
   - « Capacité d’emprunt au repère » over the amount at 20 px; caption « {available}
     d’échéance disponibles sous 35 %, à ces conditions ». When current loans shrink it: « Vos
     crédits actuels laissent {available} d’échéance sous 35 %. C’est ce qui limite la
     capacité, pas le bien visé. »
4. Hairline.
5. **Projection annuelle:** heading; legend « Capital » (`accent`) · « Intérêts »
   (`textTertiary`) on the heading line. Stacked bars, one per year, labels every 4 years and
   on the last. Hover card: the year, « Capital : {x} », « Intérêts : {y} ».

## Comparison (replaces the reading pane)
Heading « Comparaison de {n} scénarios »; right: ghost « Fermer la comparaison » (`x`).
Table: first column the row label (190 px, `textSecondary`), then one right-aligned column per
scenario, headed by its name (« en cours » in `textTertiary` under the live one). Rows, in
order: Prix du bien · Apport · Frais · Montant emprunté · Taux nominal · Durée · Assurance par
mois · **Échéance mensuelle** · Intérêts totaux · Assurance totale · **Coût total** · Coût /
prix · TAEG indicatif · Taux d’endettement · Avec crédits actuels. The two bold rows are
13/600; a `lineStrong` hairline precedes « Échéance mensuelle » and « Taux d’endettement ». A
dash where a value does not apply. Under the table, a Note: « Taux d’endettement sur un revenu
{source} de {income} · repère HCSF 35 %. Lecture indicative, qui n’engage aucun prêteur. »

In the inputs pane, a fourth scenario's checkbox is disabled, with the note « Trois scénarios
au plus. Décochez-en un pour ajouter {name}. »

## States
| State | What shows |
|---|---|
| Simulation in progress | As above, `accent` repères. |
| Above the reference, current loans included | Toggle on; ratio repère `over`; status text; capacity caption names the cause. Nothing else turns `warning`. |
| Comparison of up to 3 | The comparison pane. |
| Income unknown | Ratio and capacity columns merge into one block: « — » `textTertiary`, « Aucun revenu connu. Sans revenu, ni taux ni capacité ne peuvent être lus. », secondary « Déclarer un revenu » (opens Paramètres → Préférences → Revenu déclaré, field focused). Duration column unchanged. |
| Empty, no scenario | Fields show placeholders (« 0,00 € », « — % »), price focused. Summary figures « — » with the caption « Renseignez un prix et un taux pour voir l’échéance. » The chart block shows the note « Renseignez un prix et un taux : la répartition par année s’affiche ici. » The scenarios block shows the note « Aucun scénario enregistré. » and no compare button. |
| Save dialog | Modal 420 px: Nom, prefilled « {lieu}, {prix} k€ ». « Annuler » · « Enregistrer ». |
| English | Same geometry. |

## Behaviour (kept)
- Capacity = available instalment under 35 % × (amount borrowed / total instalment of the
  current simulation), that is at the simulation's own rate, duration and insurance ratio.
- The ratio repère is 0–70 % (wider than Crédits' 0–60 %) so a reading in the sixties stays
  inside; above 70 % the fill clamps and the number stays exact.
- The toggle recomputes the HCSF block only; the summary line never depends on it.
- « indicatif » is always attached to the TAEG label.
- The live simulation counts toward the three compared scenarios when checked.
- Yearly projection only: never 300 monthly bars. Above the reference is never red.

## Copy
Delete `navSimulatorSubtitle`, `simulatorFormSubtitle`, `simulatorCompareSubtitle`,
`simulatorChartSubtitle`. `simulatorHcsfCaveat` per `00` §14. « DÉRIVÉ » pill → the helper
« calculé : prix − apport + frais ». « EN COURS » pill → « en cours ». « INDICATIF » pill →
« TAEG indicatif ». `simulatorCapacityCaptionExisting` → the two-sentence form above.
`simulatorSaveNamePrefill` separator « — » → « , ».

## Removed from v1
Form card and scenarios card, tinted « Échéance mensuelle » hero, result cards, HCSF card with
the amber border, marker pills, cyan interest bars (interest is `textTertiary` now), comparison
card with washed rows.
