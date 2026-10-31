# 16 — Account detail

Paste `00-shared-design-block.md` verbatim first as binding tokens, then this file. Render every
state under « States to show » as a separate 1440×900 frame named `16-AccountDetail — <variant>`.
French first; English only where listed. Reference components by their §Components names.

## Entry & navigation
Opened by clicking an account Card on 05 — Accounts. It is a sub-view of « Comptes »: the sidebar
keeps « Comptes » active (iris rail, filled wallet glyph). Chrome does not move or restyle.
- Top bar: title = account name (18/700 Space Grotesk, e.g. « BNP Compte courant »), descriptor =
  « Comptes › BNP Paribas » (12 secondary, « Comptes » is a link). Contextual controls: ghost pill
  « Modifier » (opens the existing 480 px account Modal) + 38 px ⋯ overflow (Archiver). No delete.
- Content region opens with a 13 px ghost back link « ‹ Tous les comptes » (secondary, hover
  primary), 16 px above the first card.

## Content layout (1440 wide, content 24×28, grid gap 18)

**Row 1 — Identity + headline (full-width Card, padding 24)**
Left: 48 px InstitutionAvatar (BNP `#2FB574` monogram) + name 19/700 + institution 12.5 secondary
+ type AppChip (« Courant »). Right, right-aligned: label « Solde actuel » (10 px uppercase
section label) over the balance 32 px Space Grotesk, tabular, sign-colored (+3 486,12 €), and a
12 px caption beneath: « Au 30 oct. 2026 · recalculé il y a 2 min ».
A meta strip along the card's bottom edge, separated by a `#1A212C` hairline, two inline facts in
12 secondary with 11 px line glyphs:
  ① calendar glyph « Historique depuis le 3 janv. 2025 » (date of the earliest imported
     transaction)
  ② download glyph « Dernier import : 28 oct. 2026 » (link to Imports, filtered)

**Row 2 — Balance evolution (Card, ~2/3 width) + Period stats (Card, ~1/3 width)**
Evolution card: title « Évolution du solde » (14/600 Geist) + AppSegmented right
(« 6 mois · 12 mois · Tout », default 12 mois). AreaLine of month-end balances (one point per
month — the data is monthly snapshots, so no daily wiggle), final point = today's balance with a
4 px dot and a value label. Line cyan `#4FD1E8` 2 px, fill cyan 18 %→0 % gradient; when the
series crosses zero, draw a dashed `#3A4556` zero baseline and tint the sub-zero area `#FF5C6C`
at 10 %. Value axis labels the min / mid / max gridlines in a 56 px left gutter with compact
amounts (« 3,5 k€ »), as on the dashboard's savings chart; x-axis month abbreviations
(« janv. », « févr. »…). Hover tooltip (overlay surface, radius 14): month, balance, delta vs
previous month signed and colored (« +412,30 € »). No animate-in.
Stats card, 3 stacked rows separated by `#1A212C`: « Variation sur 12 mois » +1 240,50 € (green,
with up-arrow glyph) · « Entrées » +28 410,00 € · « Sorties » −27 169,50 €. Under the rows, an
encouraging one-liner in 12.5 secondary: « Votre solde progresse depuis 4 mois consécutifs. »
(only when true — otherwise omit, never a scolding line).

**Row 3 — Linked cards (full-width Card)**
Title « Cartes rattachées » + caption « Cartes à débit différé réglées sur ce compte ».
One 64 px row per card: 36 px InstitutionAvatar + card name (« Visa Premier ») + masked number
13 secondary tabular (« •••• 4821 », omitted when unknown) + AppChip « Débit différé » + right
side: « En cours ce mois » −612,40 € (red, 16 px tabular) and a 12 px caption « Prélevé le
5 nov. ». Chevron → opens that card's own detail view. Row hover `#151B26`.
If the card's settlement rule is missing, an inline warning chip (warning `#FFB84D` @ 12 %,
border 40 %, triangle glyph) « Règle de règlement à configurer » that opens the existing
settlement-rule dialog. If no card is linked: the section shows a single dashed-border row
« Aucune carte rattachée » in disabled tone — never hide the section silently, never an alarm
color.

**Row 4 — Recent transactions (full-width Card)**
Title « Dernières opérations » + right link « Tout voir › » (opens Transactions filtered on this
account). 8 TransactionRow (52 px) with CategoryChip, signed AmountText, date column.

## Variant: the account IS a deferred card (type deferred_card)
Row 1 chip « Débit différé », masked number in the meta strip. Headline label becomes « Encours
du cycle » (the balance resets each month). Row 2 swaps the AreaLine for single bars: one bar per
settlement cycle = total charged that cycle (expense red at 70 %, the current in-progress cycle
drawn as a dashed outline), because a sawtooth balance line reads as noise. Row 3 becomes
« Compte de règlement »: one row with the paying account (avatar, name, balance) + the
settlement rule summary « Libellé : CARTE X4821 · Appliquée depuis le 5 févr. 2025 » + ghost
« Modifier la règle ».

## States to show
① populated, checking account with 2 linked cards (fr)
② populated, deferred card variant (fr)
③ populated (en) — same as ①; « Tracked since Jan 3, 2025 », « Linked cards », « Balance over
   time »; dates and amounts in the app's `en` locale, as on every other panel: month first
   (« Jan 3, 2025 », « Debited on Nov 5 »), symbol first (« €3,486.12 »).
④ fresh account, < 2 months of history: chart Card shows EmptyStateView inside its silhouette
   « Le graphique apparaîtra après votre deuxième mois d'historique » + ghost « Importer un
   relevé »; meta strip shows « Pas encore d'opérations » instead of the history date.
⑤ loading: SkeletonList / shimmer blocks on the exact silhouette of ①.
⑥ settlement rule missing on one linked card (the warning chip from Row 3).

## Notes
- Balance figures in the headline and linked-card rows are sign-colored (they are the data
  point); stats-card entrées/sorties follow the money color rule; axis labels stay neutral.
- Money: tabular figures, U+2212 minus, French « 3 486,12 € » with narrow no-break spaces.
- French labels run 15–20 % longer — the meta strip must wrap to two lines rather than truncate.
- No per-account currency shown anywhere.
- Every figure, date and card number here is invented mock data.
