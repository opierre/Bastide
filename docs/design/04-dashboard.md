# 04 — Dashboard

## Top bar (this panel)
Title « Tableau de bord » / "Dashboard" + descriptor « Votre mois en un coup d'œil ». Right: month selector pill (‹ Mai 2026 ›, 38 px, raised surface), global search pill (250 px, placeholder « Rechercher… »), user pill.

## Content layout
Three stacked rows. (1) Stat grid 1fr 1fr 1fr 1.35fr, gap 18: StatCards Revenus (+2 850,00 € green, delta +2,1 % green up), Dépenses (−2 214,35 € red, delta +4,8 % red up — rising expenses are bad), Net (+635,65 € neutral primary, delta −6,1 % red down), then SavingsRateCard last-but-widest: iris gradient card, 96 px ring at 22,3 %, delta +1,9 pt, caption « Objectif : 20 % · atteint ». (2) split row 1.35fr/1fr, 322 px: ChartContainer « Dépenses par catégorie » (250 px donut column, 212 px Donut r 80 stroke 24, center total 2 214,35 €, legend name · amount · % — Logement 42,9 % → Santé 2,8 %) beside « Évolution de l’épargne » — 6-month cumulative-savings area line (iris 2.5 px stroke over 16 % fill, current-point dot, Déc.→Mai axis; header: 10 840,00 € + green monthly delta +635,65 €). (3) split row 1fr/1fr: « Revenus vs dépenses » — stacked bars, one 44 px bar per month over the last 4 months (Févr.→Mai; income #4ADE80 above expense #FF5C6C, 2 px gap), month label + net beneath (net colored green if positive, red if negative — Févr. is negative), green/red legend in the header; hovering a bar shows an overlay tooltip with the month's income and expense amounts — beside a narrowed « Activité récente »: four compact rows (28 px monogram · merchant + account block · right column amount over date; no CategoryChip) + « Voir toutes les transactions » iris link.

## States to show
① populated (fr). ② populated (en) — same geometry, May 2026, €1,234.56-style formatting. ③ empty (fr) — single centered EmptyState: bar-chart glyph plate, « Importez un relevé pour donner vie à votre argent », reassurance line, CTA « Aller aux imports ». ④ loading (fr) — LoadingSkeleton: 4 stat silhouettes + donut/legend silhouette + activity silhouette, opacity pulse. ⑤ populated, nav réduite (fr) — same data with the sidebar collapsed to the 76 px icon rail.

## Notes
Savings rate is the only gradient-tinted card on the screen — deliberate single hero. Net stays neutral per the money rule even when positive. Donut colors match legend and CategoryChips exactly.