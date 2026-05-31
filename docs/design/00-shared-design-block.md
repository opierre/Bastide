# Shared Design Block

> Paste this block at the top of **every** panel prompt (for either tool). It is the single
> source of visual truth and is kept in sync with the `design-system` skill so mockups match the
> built app. Per-panel prompts add only screen-specific content below this block.

## Product
A desktop-first personal finance app (French-first, English second). Calm, modern, sleek, and
**encouraging** — it should make tracking money feel rewarding, not punitive. **Dark mode.**

## Palette (dark)
- Surfaces: base `#0E1116`, raised `#161B22`, overlay `#1F2630`
- Text: primary `#E6EAF0`, secondary `#9AA4B2`, disabled `#5B6573`
- Primary accent (growth/savings): teal-green `#2BD9A8`
- Semantic: income/positive `#3FB950`, expense/negative `#F85149`, warning `#D29922`, info `#58A6FF`
- Borders/lines `#2A313C`; focus ring = primary accent
- Money color rule everywhere: income positive = green, expense negative = red

## Typography
- **Open Sans** throughout. 400 body, 600 emphasis, 700 headings.
- Amounts/balances use **tabular figures** and right-align in columns.
- Assume French labels run ~15–20% longer than English — never size layouts to English only.

## Layout invariant (identical on every panel — do not move or restyle)
- **Left navigation rail** (persistent on desktop): Dashboard, Accounts, Transactions, Imports,
  Categories, Settings. Active item highlighted with the accent.
- **Top bar**: current panel title (left), contextual controls like account/period selector and
  global search (center/right), user/profile menu (far right).
- **Bottom bar**: slim status strip (e.g. import/sync status), consistent even when minimal.
- Only the **content region** between these bars changes per panel.

## Components (consistent across panels)
Metric/stat card (value + trend delta arrow in semantic color), transaction row (merchant
logo/monogram + description + category chip + signed amount), category chip, amount text,
chart container, encouraging empty state (with a clear CTA), loading skeleton, error+retry,
form fields, primary/secondary/danger buttons, toast/snackbar.

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
