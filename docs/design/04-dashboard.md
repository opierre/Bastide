# 04 — Dashboard

Everything below is exactly what the mockup frames `04-Dashboard — *` in `Bastide Mockups.dc.html` show. Do not guess: colors, amounts, order, and positions are normative. Colors reference the tokens in `00-shared-design-block.md`.

## Top bar (this panel)
Title « Tableau de bord » / "Dashboard" + descriptor « Votre mois en un coup d'œil » / "Your month at a glance". Right side, in order: month selector pill (‹ Mai 2026 › / ‹ May 2026 ›, 38 px, raised surface), global search pill (250 px, placeholder « Rechercher… » / "Search…"), user pill.

## Content layout — three stacked rows

### Row 1 — KPI strip, one card, columns `1.35fr 1fr 1fr 1fr`
One Card split by 1 px `#1A212C` vertical dividers, left → right:
1. **Taux d'épargne** / "Savings rate" (widest, 1.35fr) — label 11 px/600 uppercase in iris `#8B8CF9`; value `22,3 %` 29 px/700 tabular `#EDF1F7`; a 6 px progress bar toward the 20 % goal (`#1E2634` track, goal-progress iris fill, full once the goal is met); then one line « ✓ Objectif 20 % atteint · +1,9 pt » / "✓ Goal 20% reached · +1.9 pt" — the check glyph and goal text green when reached; « Objectif 20 % en cours » / "Goal 20% in progress" in `#97A3B6` with no check otherwise; the point delta green when up, red when down.
2. **Net** — value `+635,65 €` signed, colorized by sign (the strip's one colorized figure); trend line « ↓ 6,1 % vs avril » with the arrow and percent red.
3. **Revenus** / "Income" — value `+2 850,00 €` signed in neutral `#EDF1F7`; « ↑ 2,1 % vs avril » / "↑ 2.1% vs April", arrow and percent green.
4. **Dépenses** / "Expenses" — value `−2 214,35 €` signed in neutral `#EDF1F7`; « ↑ 4,8 % vs avril », arrow and percent **red** (inverted: rising expenses are bad; a fall reads green).

Arrows are line glyphs, not characters; the percent is unsigned (the arrow carries direction) and formatted per locale. « vs <mois> » is 11.5 px `#97A3B6`.

(Amended — row 1 was drawn as four cards, `1fr 1fr 1fr 1.35fr`, in the order Revenus · Dépenses · Net · Taux d'épargne, the last an iris-tinted SavingsRateCard with a 96 px ring and a « Objectif : 20 % · atteint » caption beside a delta pill. Four plates read as four separate objects; one strip led by the savings rate is easier to scan and puts the encouraging figure first. The bar replaces the ring because it shows the distance to the goal; the net caption « revenus − dépenses » gave way to the same « vs <mois> » as its neighbours so the three trend lines read alike.)

### Row 2 — split `1fr / 1.35fr`, height 322 px (amended — the savings chart's twelve bars take the wider share)
**Left — « Dépenses par catégorie » / "Spending by category"**, sub « Mai 2026 · 7 catégories ». 250 px donut column: Donut r 80, stroke 24, 3 px segment gaps, center total `2 214,35 €` + « dépensés » / "spent". Those are the numbers at the drawn frame; below it the donut is what gives way — radius, stroke, gap, and the centred total all scale together (down to 96 px, keeping the column's gutter), because the legend is the part that carries the figures. Legend right of donut, one row per category `name · amount · %`, in this exact descending order with these exact colors:

| Catégorie (fr / en) | Color | Amount | % |
|---|---|---|---|
| Logement / Housing | `#4FD1E8` | 950,00 € | 42,9 % |
| Alimentation / Food | `#5AA9FF` | 486,20 € | 22,0 % |
| Autres / Other | `#64748B` | 236,55 € | 10,7 % |
| Transport / Transport | `#2DD4BF` | 214,90 € | 9,7 % |
| Loisirs / Leisure | `#F472B6` | 189,45 € | 8,6 % |
| Abonnements / Subscriptions | `#FFB84D` | 74,95 € | 3,4 % |
| Santé / Health | `#A3E635` | 62,30 € | 2,8 % |

Donut segments use the same colors in the same order (starting at 12 o'clock, clockwise). These colors also match CategoryChips everywhere.

**Right — « Évolution de l'épargne » / "Savings over time"**, sub « Épargne mensuelle · 12 mois » / "Saved per month · 12 months". (Amended — was a 6-month cumulative AreaLine; a running total hid what each month actually put aside.) Header: the monthly average, signed and colored (`+302,50 €`), over « en moyenne par mois » / "on average per month" (11.5 secondary). Chart: one bar per month, each the month's own net (income − expense): green `#4ADE80` @ 70 % above a zero line, red `#FF5C6C` @ 70 % below it for a month that spent more than it earned, ≤ 22 px wide, 5 px radius on the tip; the current month, still moving, as a dashed outline in its sign's color over a 8 % fill. Gridlines at the low end, zero and the high end, labelled in a 56 px left gutter with compact amounts, as on the Synthèse's « Patrimoine net »; x-axis month abbreviations. Hover tooltip: month, signed colored amount, anchored to the hovered mark (amended): centred on it, 8 px off the bar's tip — above a saving or an empty month, below a shortfall — floating over the card rather than held inside the plot, so it never covers the bar.

**View switch** (amended — issue #68): an `AppSegmented` « Barres » / « Courbe » ("Bars" / "Line"), 128 px wide, left of the headline on the card's trailing edge; bars by default, the choice kept for the session. The line view draws the same twelve months on the same scale, gridlines and axis: an iris 2.5 px line through each month's slot centre over an iris 10 % area closed on the zero line — up to a saving's point, down to a shortfall's — as under the Synthèse's « Patrimoine net », an 8 px dot per month in its sign's color (green / red) ringed in the card surface, a dashed `#3A4556` zero baseline when a month dips below zero, and the current month open — the last segment dashed, its dot hollow. Same hover tooltip in both views, anchored the same way off the hovered dot (its ring, then 8 px).

### Row 3 — three-card split `1fr .95fr .85fr` (three cards)
Normative reference: frame `04-Dashboard — avec carte objectifs (fr)` in the Gestion & AI mockup canvas) re-splits row 3 into three columns: **col 1 « Revenus vs dépenses »** · **col 2 « Activité récente »** · **col 3 « Objectifs »** (new). Objectifs card: soft iris tint `linear-gradient(160deg,rgba(139,140,249,.10),rgba(108,106,240,.03) 55%),#111620`, border `rgba(139,140,249,.3)`; header « Objectifs » + iris link « Voir tout »; three compact goal rows (name 12.5/600 · right `6 400 € / 10 000 €` 11 px `#97A3B6` · 6 px iris-gradient progress bar, track `#1E2634`): Fonds d'urgence 64 % · Apport immobilier 43 % · Voyage Japon 100 % with green check « Atteint » instead of the amounts. Shows the top 3 active (non-archived) goals; hidden if none exist.

**Left — « Revenus vs dépenses » / "Income vs expenses"**, sub « 4 derniers mois » / "Last 4 months"; green/red dot legend « Revenus / Dépenses » in the header. One 44 px-wide stacked bar per month, income segment `#4ADE80` on top, expense `#FF5C6C` below, 2 px gap. Beneath each bar: month label + net (green if positive, red if negative). Exact data:

| Month | Income | Expense | Net (color) |
|---|---|---|---|
| Févr. / Feb | +2 850,00 € | −2 968,40 € | −118,40 € (red) |
| Mars / Mar | +2 850,00 € | −2 309,80 € | +540,20 € (green) |
| Avr. / Apr | +2 850,00 € | −2 112,90 € | +737,10 € (green) |
| Mai / May | +2 850,00 € | −2 214,35 € | +635,65 € (green) |

Current month (Mai) label is `#EDF1F7`; earlier months `#97A3B6`. Hovering a bar shows an overlay tooltip with that month's income and expense amounts.

**Right — « Activité récente » / "Recent activity"**. Compact rows (28 px monogram chip · merchant + account name block · right column: amount over date; **no CategoryChip** in this compact variant), with the « Voir toutes les transactions » / "View all transactions" iris link on the **top right**, level with the card title. The list is drawn to *fill* the card: as many rows as fit at 48 px, sharing any remainder (rows grow no more than a quarter over 48). The card is as tall as row 2 beside it, so the count follows the window — four on this frame. Exact rows:

| Monogram (color) | Merchant | Account | Date (fr) | Amount (color) |
|---|---|---|---|---|
| CA `#3B82F6` | Carrefour | BNP — Compte courant | 14/05/2026 | −86,42 € (red) |
| NV `#6C6AF0` | Salaire — Novatech SARL / "Salary — Novatech SARL" | BNP — Compte courant | 02/05/2026 | +2 850,00 € (green) |
| SC `#4FD1E8` | SNCF Connect | Revolut | 11/05/2026 | −47,00 € (red) |
| FM `#F472B6` | Free Mobile | BNP — Compte courant | 09/05/2026 | −15,99 € (red) |

Monogram chip: 2-letter initials, color at 16 % alpha background, full color text. EN dates: "May 14, 2026" style.

## States to show
① populated (fr). ② populated (en) — same geometry, May 2026, `€1,234.56`-style formatting (e.g. `+€2,850.00`, `€10,840.00`). ③ empty (fr) — single centered EmptyState: bar-chart glyph plate, « Importez un relevé pour donner vie à votre argent », reassurance « Tout reste sur cet ordinateur — rien n'est envoyé en ligne. », CTA « Aller aux imports ». ④ loading (fr) — LoadingSkeleton: one KPI-strip silhouette + donut/legend silhouette + activity silhouette, opacity pulse. ⑤ populated, nav réduite (fr) — same data with the sidebar collapsed to the 76 px icon rail.

## Notes
The savings rate leads row 1 as the encouraging headline, in the strip's widest column and its one iris label; the strip is a single plain card, so the four figures read as one row. Net is signed and colorized by sign; income and expenses stay neutral. All amounts tabular-nums, right-aligned, always signed (− is U+2212). Donut colors match legend and CategoryChips exactly. Grain texture is on the frame background only — never on these cards.
