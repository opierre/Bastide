# Shared Design Block

> Paste this block at the top of **every** panel prompt (for either tool). It is the single
> source of visual truth and is kept in sync with the `design-system` skill so mockups match the
> built app. Per-panel prompts add only screen-specific content below this block.

## Product
A desktop-first personal finance app (French-first, English second). Calm, modern, sleek, and
**encouraging** — it should make tracking money feel rewarding, not punitive. **Dark mode.**

## Palette (dark)
- Surfaces: sunken `#070910` (sidebar + bottom bar), base `#0A0D12` (content), raised `#111620`
  (cards), overlay `#19202B` (dialogs/menus), hover `#1E2634`, field `#0D1219` (inputs)
- Text: primary `#EDF1F7`, secondary `#97A3B6`, disabled `#5A6579`
- Primary accent (growth/savings): jade `#2FE0A6`; deep end `#14B989`; soft = jade @ 12%
- Secondary accent: violet `#8B7CF6` (charts, category hues — never used for money)
- Semantic: income/positive `#4ADE80`, expense/negative `#FF5C6C`, warning `#FFB84D`, info `#5AA9FF`
- Borders/lines: structural `#232B38`, subtle `#1A212C`; focus ring = primary accent
- Money color rule everywhere: income positive = green, expense negative = red. Neutral figures
  (totals, form values) stay in primary text color rather than being tinted.
- Radii: 8 / 12 / 16 / 20, plus fully-rounded pills. Corners are generous — nothing square.

## Typography
- **Open Sans** throughout. 400 body, 600 emphasis, 700 headings.
- Amounts/balances use **tabular figures** and right-align in columns.
- Assume French labels run ~15–20% longer than English — never size layouts to English only.

## Layout invariant (identical on every panel — do not move or restyle)
- **Left sidebar**, 252px wide on the sunken surface, persistent on desktop. Brand lockup at the
  top (jade gradient logomark + "FinStride" wordmark), then destinations grouped under small
  uppercase section labels: *Overview* — Dashboard, Accounts, Transactions; *Manage* — Imports,
  Categories. Settings sits pinned at the bottom behind a divider. Items are 40px rounded pills;
  the active one has a jade-tinted fill, jade label and icon, a flush-left 3px jade accent rail,
  and a filled (not outline) icon. Hover is a faint neutral wash.
- **Top bar**, 72px on the base surface with a hairline underneath: current panel title with a
  one-line descriptor beneath it (left); contextual controls like account/period selector and
  global search (center/right); user menu at the far right — monogram avatar + name and email in
  a bordered pill with a chevron.
- **Bottom bar**, 30px on the sunken surface: green status dot + status label on the left, and a
  right-aligned lock icon + "local data" reminder. Consistent even when minimal.
- Only the **content region** between these bars changes per panel.

## Components (consistent across panels)
Card (raised plate, 16px radius, hairline border, accent border on hover when clickable),
metric/stat card (small uppercase label + large tabular value + caption, action button on the
right), transaction row (merchant logo/monogram + description + category chip + signed amount),
category chip (tinted pill with a small leading icon), amount text, segmented control (inset
track, tinted active segment) for 2–3 fixed choices, form fields with the label **above** the
control (not floating inside), chart container, encouraging empty state (tinted 64px glyph plate
+ title + one-line reassurance + single CTA), loading skeleton matching the content shape,
error+retry on the same silhouette as the empty state, inline error banner (tinted, with icon),
primary/secondary/danger buttons, toast/snackbar.

## Iconography & logos
- One consistent modern outline icon family.
- Show brand logos for known merchants/institutions; **fall back to a colored monogram chip**
  (initials) when no logo exists. Never show a broken/empty image.

## Motion & accessibility
- Restrained, purposeful motion: one orchestrated load reveal, smooth transitions, subtle
  hover/press on desktop. No animation noise on data-dense views.
- AA contrast; never encode meaning by color alone (pair income/expense color with sign/icon);
  visible focus states; reduced-motion respected.

## Output expectation
Desktop canvas (~1440×900). Show the full app shell (rail + top bar + bottom bar) with the
panel rendered in the content region. Provide both **French and English** versions of the screen
where text is prominent (at minimum the dashboard, auth, and transactions panels).
