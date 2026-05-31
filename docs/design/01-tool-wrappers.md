# Design Prompts — How to use

Each panel below is tool-agnostic. To produce a mockup, assemble:

```
[ 00-shared-design-block.md ]  +  [ tool wrapper ]  +  [ the panel prompt ]
```

The shared block is ~80% of every prompt and is written once; only the thin wrapper changes per
tool. That's the token-efficient part — you don't re-describe the design system per screen.

## Priority order (generate in this sequence)
1. Login  2. Register  3. Dashboard  4. Accounts  5. Imports (+ CSV mapping wizard)  6. Transactions
Categories/Settings reuse the same components and can come last or be skipped for mockups.

## Stitch wrapper (Google)
Stitch prefers concise, natural-language screen descriptions and infers layout. Prepend:

> "Design a single desktop screen (1440×900), dark theme, for the app described below. Follow the
> palette, typography, and the fixed left-rail / top-bar / bottom-bar layout exactly. Render the
> full app shell with this panel in the content region. Use Open Sans and tabular figures for
> amounts. Keep it clean, modern, and encouraging. Here is the design system and the screen:"

Then paste the shared block + panel prompt. Generate French and English variants by adding:
"Produce two versions: one with French labels, one with English." Keep each Stitch request to one
screen for best results.

## Claude Design (Anthropic) wrapper
Claude Design works well with structured component specs it can iterate on. Prepend:

> "Create a high-fidelity desktop mockup (1440×900), dark theme. Treat the Design System section
> as binding tokens and the Layout Invariant as fixed structure. Build the panel from the listed
> components. After the first pass, I'll ask for refinements, so keep the structure component-based
> and named. Here is the design system and the screen spec:"

Then paste the shared block + panel prompt. Iterate with targeted follow-ups ("tighten the stat
card spacing", "show the empty state variant", "show the fr version").

## Notes
- Both tools: ask for the **empty state** and the **populated state** of data panels (dashboard,
  accounts, transactions) — empty states are first impressions and easy to forget.
- Don't ask either tool to invent new colors/fonts; the shared block is binding so mockups match
  the Flutter build.
