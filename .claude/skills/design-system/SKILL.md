---
name: design-system
description: Use for any visual/UI work in the finstride — building screens, styling, theming, layout, icons, brand logos, or writing design-tool prompts. Defines the dark-first palette, Open Sans typography, the fixed navbar/top bar/bottom bar invariant, brand-logo handling with monogram fallback, the component inventory, and the encouraging-UX direction. Builds on the general frontend-design skill for craft; this skill supplies the project-specific tokens and invariants.
---

# Design System

The single source of visual truth for every panel. For general design *craft* (avoiding generic
AI aesthetics, typography pairing, motion restraint), also follow the **frontend-design** skill.
This skill supplies the project-specific, non-negotiable tokens and invariants. See
`PROJECT.md` §9.

## Direction

Modern, sleek, calm, and **encouraging** — the UI should make tracking money feel rewarding, not
punitive. Lead screens with progress and positive framing (savings rate, goal progress, "you're
on track"), surface problems gently. **Dark mode first** (a light theme may come later; design
tokens are theme-keyed from the start).

## Tokens

Define once as theme constants (`core/theme/tokens.dart` + `core/theme/app_theme.dart`); never
hardcode hex in widgets. The dark palette (AA-verified against its intended surface):

- **Surfaces**, deepest to highest: sunken `#070910` (app chrome — sidebar, bottom bar), base
  `#0A0D12` (content region), raised `#111620` (cards, panels), overlay `#19202B` (dialogs,
  menus), hover `#1E2634` (pointer wash), field `#0D1219` (inset wells: inputs, read-only slots).
- **Text**: primary `#EDF1F7`, secondary `#97A3B6`, disabled `#5A6579`.
- **Brand/primary accent**: jade `#2FE0A6`, signalling growth/savings. Deep end `#14B989`
  (gradients, pressed states); soft `#2FE0A6` @ 12% for selected nav pills and tinted chips.
- **Secondary accent**: violet `#8B7CF6` — charts, category hues, decorative pairing. Never used
  for money, so it can't be confused with the sign rule.
- **Semantic**: income/positive `#4ADE80`, expense/negative `#FF5C6C`, warning `#FFB84D`, info
  `#5AA9FF`. Positive green is deliberately yellower than the brand jade so a balance never reads
  as a brand element.
- **Lines/borders**: structural `#232B38`, subtle `#1A212C` (separators inside a card).
  **Focus ring**: brand accent at full opacity.
- Money color rule: income positive uses the positive green, expenses the negative red — applied
  consistently on every panel (dashboard, transactions, categories). Neutral figures (a total, a
  form value) opt out of colorization rather than being tinted green by default.

**One coherent palette across all panels.** Same semantic colors mean the same thing everywhere.

Non-color tokens live alongside: spacing (4/8/16/24/32/48), radii (sm 8, md 12, lg 16, xl 20,
pill), shadows (card, overlay), motion (fast 120ms, base 200ms, slow 320ms, `easeOutCubic`), and
chrome dimensions (sidebar 252, top bar 72, bottom bar 30).

## Typography

- **Open Sans** (Google Fonts) as the UI family — clean, highly readable, multilingual (handles
  French accents). Use weights deliberately: 400 body, 600 emphasis, 700 headings.
- Numbers (amounts, balances) use **tabular figures** so columns align.
- Respect French text length: French labels run ~15–20% longer than English; never size layouts
  to English-only.

## Icons & brand logos

- **Modern icon set**, single consistent family (outline style), used for nav, categories,
  actions. Category icons map to the system categories.
- **Brand logos**: where a transaction merchant or an account institution maps to a known brand,
  show its logo (sourced via a permissive logo service or a bundled curated set). **Fallback**:
  when no logo exists, render a generated **monogram chip** (first letters on a color derived
  deterministically from the name). Never show a broken/empty image.
- Logos are decorative enhancements — never required for function, and never block rendering on a
  network fetch (cache locally; degrade to monogram offline).

## Fixed chrome — the layout invariant (non-negotiable)

The **navbar, top bar, and bottom bar keep identical position and behaviour on every panel.**
Implement once as a shared shell scaffold (`core/`); feature screens render into the content
region only and never alter the chrome.

- **Left sidebar (primary navigation)**, 252px on the sunken surface: brand lockup at the top,
  then grouped destinations under small uppercase section labels — *Overview* (Dashboard,
  Accounts, Transactions), *Manage* (Imports, Categories), and later Goals/Mortgages/Taxes.
  Settings is pinned to the bottom behind a divider so the primary items keep their vertical
  position as the app grows. Items are 40px rounded pills; the active one gets a brand-tinted
  fill, brand-colored label, a flush-left 3px accent rail, and the filled variant of its icon
  (so selection isn't carried by color alone). Hover is a neutral wash.
- **Top bar**, 72px: current panel title with a one-line panel descriptor beneath it (left),
  account/period selector and global search where relevant (center/right), user/profile menu at
  the far right — monogram avatar + name/email, opening the session menu.
- **Bottom bar**, 30px: a status dot and label on the left (sync/import status, app state), and a
  right-aligned local-data reminder. Reserved and consistent even where minimal.

Consistency of chrome is a hard acceptance criterion: a screen that moves or restyles the
nav/top/bottom bar is wrong.

## Component inventory (shared, themed)

Build these as reusable themed widgets so panels stay coherent. Prefer the shared widget over a
raw Material one — Material's defaults carry touch-sized padding and a light-mode look that
drifts from the system. Already in `core/widgets/`:

- `AppShell` — sidebar + top bar + bottom bar; feature screens render into the content region.
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

Still to build: metric/stat card with trend delta arrow, transaction row, trend indicator, chart
container (income/expense, by-category), toast/snackbar wrapper.

## Motion & feel

Purposeful, restrained motion (per frontend-design): one well-orchestrated screen-load reveal,
smooth state transitions, subtle hover/press feedback on desktop. No gratuitous animation on
data-dense views. Charts animate in once, not on every rebuild.

## Accessibility

AA contrast on text and semantic colors; never encode meaning by **color alone** (pair
income/expense color with sign and/or icon); visible focus states; sensible hit targets; respect
reduced-motion.

## For design-tool prompts (Stitch / Claude Design)

The prompts in `docs/design/` reuse this skill's tokens verbatim as the shared design block, then
add per-tool wrappers. When generating or updating those prompts, pull palette/type/chrome from
here so the mockups and the built app never diverge.
