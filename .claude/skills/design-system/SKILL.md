---
name: design-system
description: Use for any visual/UI work in Bastide — building screens, styling, theming, layout, icons, brand logos, or writing design-tool prompts. Summarises the binding spec in docs/design/00-shared-design-block.md — the dark-first iris palette, Geist/Space Grotesk typography, the fixed sidebar/top bar invariant (no bottom bar), monogram-only brand logos, the component inventory, and the encouraging-UX direction. Builds on the general frontend-design skill for craft; this skill supplies the project-specific tokens and invariants.
---

# Design System

The single source of visual truth for every panel. For general design *craft* (avoiding generic
AI aesthetics, typography pairing, motion restraint), also follow the **frontend-design** skill.
This skill supplies the project-specific, non-negotiable tokens and invariants.

> **`docs/design/00-shared-design-block.md` is binding.** It transcribes the drawn mockup and
> outranks this file wherever they disagree. Panel specs live in
> `docs/design/02-*.md` … `09-*.md`; each is self-contained when paired with `00`. This skill
> summarises `00` — if you are about to write UI code, read `00` itself.

## Direction

Modern, sleek, calm, and **encouraging** — the UI should make tracking money feel rewarding, not
punitive. Lead screens with progress and positive framing (savings rate, goal progress, "you're
on track"), surface problems gently. **Dark mode first** (a light theme may come later; design
tokens are theme-keyed from the start).

## Tokens

Define once as theme constants (`core/theme/tokens.dart` + `core/theme/app_theme.dart`); never
hardcode hex in widgets. The dark palette (AA-verified against its intended surface):

- **Surfaces**, deepest to highest: sunken `#070910` (sidebar, auth page), base `#0A0D12` (content
  region), raised `#111620` (cards, panels), overlay `#19202B` (modals, popovers, toasts), hover
  `#1E2634` (pointer wash, inset plates, toggle tracks), field `#0A0F15` (every inset well — inputs,
  selects, read-only plates — and select popovers; one tone, since two near-identical darks in
  a form read as a rendering error rather than a distinction). Row hover *inside* a raised card is `#151B26`; sidebar nav hover is `#12161F`.
- **Text**: primary `#EDF1F7`, secondary `#97A3B6`, disabled/placeholder `#5A6579`.
- **Brand/primary accent**: iris violet `#8B8CF9`, deep end `#6C6AF0`. Primary buttons and the
  logomark use `linear-gradient(135deg, #8B8CF9, #6C6AF0)` with ink `#0E1030` and a glow
  `0 8px 22px rgba(108,106,240,.3)`; soft fill = iris @ 12–16%.
  **Iris is the accent role only** — never a category hue, never money. Cyan `#4FD1E8` is the
  leading chart/category hue.
- **Semantic**: income/positive `#4ADE80`, expense/negative `#FF5C6C`, warning `#FFB84D`, info
  `#5AA9FF`. Tinted fills = the color at 10–14% with a 30–55% border.
- **Category hues** (pinned, not derived — a hue means the same thing in the donut, the legend,
  and the chip): Logement `#4FD1E8` · Alimentation `#5AA9FF` · Transport `#2DD4BF` · Loisirs
  `#F472B6` · Abonnements `#FFB84D` · Santé `#A3E635` · Autres/Épargne `#64748B` · Revenus
  `#4ADE80`.
- **Lines/borders**: structural `#232B38`, subtle `#1A212C` (separators inside a card), card
  outline `#242E3E`, dashed read-only/uncategorized `#3A4556`.
  **Focus ring**: 1px `#8B8CF9` border + `0 0 0 3px rgba(139,140,249,.15)`.
- Money color rule: income green with `+`, expense red with `−` (U+2212, *not* an ASCII hyphen).
  Neutral figures (a total, a balance in a form, a form value) stay `#EDF1F7` and opt out of
  colorization rather than being tinted by default. Sign or icon always accompanies color.
- **Texture**: every frame carries a film-grain overlay (white @ 5%, 140px tile) above the
  content and a 1px luminous hairline across the top edge,
  `linear-gradient(90deg, transparent, rgba(139,140,249,.55), transparent)`.

**One coherent palette across all panels.** Same semantic colors mean the same thing everywhere.

Non-color tokens live alongside: spacing (the 4/8/16/24/32/48 ramp, plus the mockup's measured
gaps — nav gap 11, nav inset 13, sidebar gutter 12, grid gap 18, card padding 20–24, content
region 24×28), radii (sm 8, monogram 9, md 12, inset/toast 14, card 16, modal/plate 20, nav pill
20, pill), shadows (card, modal `0 24 60`), motion (**two keyframes only** — spin 0.8s for button
spinners, shimmer 1.6s for skeletons), and chrome dimensions (sidebar 252 / collapsed 76, top bar
72).

## Typography

- **Geist** as the UI family — 400 body, 600 emphasis/labels, 700 headings. (Amended from
  Manrope: narrower and lower-contrast at the 11.5–14px the UI lives at, which French labels
  need, with flat-sided figures that hold an amount column under `tnum`.)
- **Space Grotesk 700** for the display role: wordmark, panel titles, headline amounts, ring
  values. The split is by *role*, not size — a 14px card title stays Geist, an 18px panel title
  is Space Grotesk.
- Scale: 10px section labels (uppercase, +1.3 tracking) · 11–11.5 captions/badges · 12–12.5
  secondary · 13–13.5 body/rows · 14 card titles · 16–19 modal/empty-state titles · 18 top-bar
  title · 29–32 headline stat values.
- Numbers (amounts, balances) use **tabular figures** and are right-aligned in columns and signed.
- Respect French text length: French labels run ~15–20% longer than English; never size layouts
  to English-only.

## Icons & brand logos

- **Line icons**, 18px, 1.5px stroke, round caps, single consistent family; active nav uses the
  **filled** variant of the same glyph. Set: dashboard 4-square, wallet card, twin arrows,
  download-to-tray, rotated-square tag, slider rows (settings), magnifier, chevrons, lock, plus,
  drag-handle dots, check, ⋯ overflow. Category chips carry an 11px leading glyph (house, bowl,
  car, star, refresh, cross, coin, up-arrow). **No emoji anywhere.**
- **Brand logos are always monogram chips** — a deliberate decision instead of embedding
  third-party logos. Never an image, never broken. Hues are **pinned per brand** (BNP `#2FB574`,
  Crédit Agricole `#0AA396`, Revolut `#5AA9FF`, Caisse Locale `#4FD1E8`, Carrefour `#3B82F6`,
  Novatech `#6C6AF0`) at 16% alpha background with a full-strength letter; an unrecognised name
  renders `?` on `#1E2634`/`#97A3B6`. Pinned rather than hashed: an institution that changes color
  between launches looks like a bug.
- `InstitutionAvatar` stays the named seam a real logo image would drop into later.

## Fixed chrome — the layout invariant (non-negotiable)

The **sidebar and top bar keep identical position and behaviour on every panel.** Implement once
as a shared shell scaffold (`core/`); feature screens render into the content region only and
never alter the chrome. **There is no bottom bar** — the privacy reminder it used to carry now
lives at the sidebar foot.

- **Left sidebar (primary navigation)**, 252px on the sunken surface, 12px inner gutter: brand
  lockup at the top (30px gradient logomark with three ascending dark bars + 17px/700 wordmark),
  then grouped destinations under small uppercase section labels — *Vue d'ensemble* (Tableau de
  bord, Comptes, Transactions), *Gestion* (Imports, Catégories), and later Goals/Mortgages.
  Settings is pinned to the bottom behind a `#1A212C` divider so the primary items keep their
  vertical position as the app grows. Items are 40px pills (radius 20), 18px icons, gap 11,
  padding 0 13; the active one gets an iris 12% fill, iris label, the filled variant of its icon,
  and a flush-left 3×22px iris rail (so selection isn't carried by color alone). Hover is a
  `#12161F` wash.
  **Collapsible**: a 26px double-chevron control sits right of the lockup; collapsed is a 76px
  icon-only rail (40px icon pills, same active treatment, privacy badge kept at the foot).
- **Sidebar foot**: lock glyph + « Données 100 % locales » / "All data stays on this device" in
  the disabled tone, under Paramètres.
- **Top bar**, 72px on the base surface with a `#1A212C` hairline: panel title 18/700 + 12px
  secondary descriptor beneath it (left), then right-aligned **contextual controls** (38px pills —
  month selector, search, primary CTA; each panel spec names its own) and the user pill (44px,
  bordered: 32px iris-tint monogram + name/email + chevron).
- **Content region** padding 24×28 — 20 top on panels that open with a filter bar.

Consistency of chrome is a hard acceptance criterion: a screen that moves or restyles the
sidebar/top bar is wrong. The contextual-controls slot is the one sanctioned way a panel reaches
into the chrome.

## Component inventory (shared, themed)

Build these as reusable themed widgets so panels stay coherent. Prefer the shared widget over a
raw Material one — Material's defaults carry touch-sized padding and a light-mode look that
drifts from the system. Already in `core/widgets/`:

- `AppShell` — sidebar + top bar; feature screens render into the content region and supply the
  top bar's contextual controls.
- `AppCard` — the raised, hairline-bordered plate every panel builds on; brand-tinted border on
  hover when tappable. Use instead of Material's `Card`.
- `AmountText` — locale + sign + tabular figures, with `showPositiveSign` for movements and
  `colorize: false` for neutral figures.
- `MonogramAvatar` / `InstitutionAvatar` — deterministic tinted monogram plate; the seam a real
  brand logo drops into later.
- `AppChip` — taxonomy pill (account type, category, import status). Use instead of `Chip`.
- `AppSegmented` — inset segmented control for 2–3 fixed options. Use instead of `ChoiceChip`.
- `LabeledField` — label *above* the control, not floating inside it; French labels truncate in
  Material's border notch.
- `InlineErrorBanner` — tinted failure message paired with an icon.
- `EmptyStateView` / `ErrorStateView` / `SkeletonList` — the three non-happy-path views, all on
  the same silhouette so a screen doesn't restructure between them.
- `BrandMark` / `BrandLockup` — drawn (not asset) logomark and wordmark.

- `PrimaryButton` — the iris-gradient primary. Material's `ButtonStyle` cannot paint a gradient,
  so this widget owns it; `FilledButton` is a solid-iris fallback, not the spec'd primary.
- `CategoryChip` — 22px pill, category hue @ 14% + full-hue text + 11px leading glyph; dashed
  `#3A4556` neutral variant when uncategorized.
- `FrameTexture` — the film-grain overlay and top hairline, applied once by the shell.

Still to build (see the panel specs for exact geometry): `StatCard`, `SavingsRateCard` (96px ring),
`TransactionRow` (52px + 48px compact), `DataTable`, `DropZone`, `ChartContainer`, `Donut`
(r80 stroke24), `HorizontalBars`, `Sparkline`, `AreaLine`, `StackedBars`, `Toggle` (34×20 with an
explicit knob), `Toast`, `Modal`, `Select`/`Combobox` popover.

## Motion & feel

**Two keyframes only**: `spin` (0.8s, button spinners) and `shimmer` (1.6s opacity pulse,
skeletons). Hovers are instant fills or border changes. **No data-view animation** — charts do not
animate in. `prefers-reduced-motion` kills all animation.

## Accessibility

AA contrast on text and semantic colors; never encode meaning by **color alone** — meaning is
always doubled (sign + color on money, icon + hue on chips, badge + lock glyph on system rows);
visible focus states; sensible hit targets; respect reduced-motion.

## For design-tool prompts (Stitch / Claude Design)

The prompts in `docs/design/` reuse this skill's tokens verbatim as the shared design block, then
add per-tool wrappers. When generating or updating those prompts, pull palette/type/chrome from
here so the mockups and the built app never diverge.
