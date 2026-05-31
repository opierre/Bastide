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

Define once as theme constants (Flutter `ThemeData` + a token file); never hardcode hex in
widgets. Suggested dark palette (tune for contrast/AA):

- **Surfaces**: base `#0E1116`, raised `#161B22`, overlay `#1F2630`.
- **Text**: primary `#E6EAF0`, secondary `#9AA4B2`, disabled `#5B6573`.
- **Brand/primary accent**: a confident teal/green (e.g. `#2BD9A8`) signalling growth/savings.
- **Semantic**: income/positive green `#3FB950`, expense/negative red `#F85149`, warning amber
  `#D29922`, info blue `#58A6FF`.
- **Lines/borders**: `#2A313C`. **Focus ring**: brand accent at full opacity.
- Money color rule: income positive uses the positive green, expenses the negative red — applied
  consistently on every panel (dashboard, transactions, categories).

**One coherent palette across all panels.** Same semantic colors mean the same thing everywhere.

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

- **Left nav (primary navigation)**: Dashboard, Accounts, Transactions, Imports, Categories,
  (later: Goals, Mortgages, Taxes), Settings. Persistent on desktop.
- **Top bar**: current panel title, account/period selector where relevant, global search,
  user/profile menu.
- **Bottom bar**: status/secondary info (e.g. sync/import status, app state). Reserved and
  consistent even where minimal.

Consistency of chrome is a hard acceptance criterion: a screen that moves or restyles the
nav/top/bottom bar is wrong.

## Component inventory (shared, themed)

Build these as reusable themed widgets so panels stay coherent: app shell/scaffold, nav item,
metric/stat card (with trend delta arrow + color), transaction row (logo/monogram + merchant +
category chip + signed amount), category chip, amount text (locale + sign + tabular), trend
indicator, chart container (income/expense, by-category), empty state (encouraging, with a clear
next action), loading skeleton, error+retry, form field, primary/secondary/danger buttons,
toast/snackbar.

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
