# 04 — Dashboard

Everything below is exactly what the mockup frames `04-Dashboard — *` in `FinStride Mockups.dc.html` show. Do not guess: colors, amounts, order, and positions are normative. Colors reference the tokens in `00-shared-design-block.md`.

## Top bar (this panel)
Title « Tableau de bord » / "Dashboard" + descriptor « Votre mois en un coup d'œil » / "Your month at a glance". Right side, in order: month selector pill (‹ Mai 2026 › / ‹ May 2026 ›, 38 px, raised surface), global search pill (250 px, placeholder « Rechercher… » / "Search…"), user pill.

## Content layout — three stacked rows

### Row 1 — stat grid `1fr 1fr 1fr 1.35fr`, gap 18
Four cards, left → right:
1. **Revenus (mois)** / "Income (month)" — value `+2 850,00 €` in income green `#4ADE80`; delta pill `+2,1 %` green (`#4ADE80` on `rgba(74,222,128,.12)`), arrow up; caption « vs avril » / "vs April".
2. **Dépenses (mois)** / "Expenses (month)" — value `−2 214,35 €` in expense red `#FF5C6C`; delta pill `+4,8 %` **red** (rising expenses are bad), arrow up; caption « vs avril ».
3. **Net** — value `+635,65 €` in neutral `#EDF1F7` (never green, per money rule); delta pill `−6,1 %` red, arrow down; caption « revenus − dépenses » / "income − expenses".
4. **SavingsRateCard** (widest, 1.35fr) — the only gradient card on screen: iris gradient `linear-gradient(135deg,#8B8CF9,#6C6AF0)`; label « Taux d'épargne » / "Savings rate"; 96 px ring (r 40) at **22,3 %**; delta `+1,9 pt`; caption « Objectif : 20 % · atteint » / "Goal: 20% · reached".

### Row 2 — split `1.35fr / 1fr`, height 322 px
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

**Right — « Évolution de l'épargne » / "Savings over time"**, sub « Épargne cumulée · 6 mois » / "Total saved · 6 months". Header: `10 840,00 €` + green delta `+635,65 € en mai` / "+€635.65 in May". AreaLine chart: cumulative savings, iris `#8B8CF9` 2.5 px stroke over 16 % iris fill, dot on the current (last) point; x-axis Déc. · Janv. · Févr. · Mars · Avr. · Mai (Dec–May), rising trend.

### Row 3 — split `1fr / 1fr`
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
① populated (fr). ② populated (en) — same geometry, May 2026, `€1,234.56`-style formatting (e.g. `+€2,850.00`, `€10,840.00`). ③ empty (fr) — single centered EmptyState: bar-chart glyph plate, « Importez un relevé pour donner vie à votre argent », reassurance « Tout reste sur cet ordinateur — rien n'est envoyé en ligne. », CTA « Aller aux imports ». ④ loading (fr) — LoadingSkeleton: 4 stat silhouettes + donut/legend silhouette + activity silhouette, opacity pulse. ⑤ populated, nav réduite (fr) — same data with the sidebar collapsed to the 76 px icon rail.

## Notes
Savings rate is the only gradient-tinted card on the screen — deliberate single hero. Net stays neutral per the money rule even when positive. All amounts tabular-nums, right-aligned, always signed (− is U+2212). Donut colors match legend and CategoryChips exactly. Grain texture is on the frame background only — never on these cards.
