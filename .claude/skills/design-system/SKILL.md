---
name: design-system
description: Use for any visual/UI work in Bastide — building screens, styling, theming, layout, icons, brand logos, textures or charts. Points to the binding v2 design system in docs/design/00-design-system.md (graphite dark and light themes, ink and blue accent, Geist only, the "repère" meter, sections instead of cards, Plan logo, tomettes texture) and to the per-panel specs, and lists the rules agents break most often.
---

# Design System

`docs/design/00-design-system.md` is binding and is followed to the letter. This skill does
not restate it: **read that file before writing any UI code**, then the spec of the panel you
are touching (`docs/design/01-index.md` lists them and their tickets).

Order of authority: `00-design-system.md`, then the panel spec, then the mockup
(`docs/design/proposal_v5/index.html#panel=<id>`). Written specs win over the mockup.

## Before you write a widget

1. Find the component in `00` §6–§9 and build that recipe. If it is not there, stop and ask:
   do not invent a component, a size or a colour.
2. Take every value from `frontend/lib/core/theme/tokens.dart`. A value missing from tokens
   is added to `00` first, then to tokens. No colour, radius, size or duration literal in a
   widget.
3. Check both themes. Dark is the default and the reference; light is at parity.
4. Check every state the spec lists: empty, loading, error, hover, focus, disabled.
5. Apply the panel's « Copy » section and the voice rules of `00` §14.

## What v2 is, in ten lines

- Neutral graphite dark theme and white light theme; tokens in `00` §2.
- Primary button in ink; blue accent for selection, links, focus and progress. Flat.
- Green and red are the sign of money; amber is "worth a look"; categories have six fixed
  hues plus grey, stored as slots.
- Geist only (400, 500, 600), Geist Mono for raw labels and paths. Sizes 40, 28, 20, 16, 14,
  13, 12, 11.
- Radius 6 on controls, 8 on containers, 12 on modals. Title bar 48, sidebar 224, rows 36.
- A panel opens on a summary line set in type; sections are separated by space and hairlines.
- The repère: a thin bar with a labelled mark, for every value against a reference.
- Charts on one frame; hatching for what is not yet a fact.
- Lucide icons everywhere, 1.5 px stroke. Neutral monograms.
- Plan mark; tomettes texture in five empty places only.

## Never

- A gradient, a glow, a coloured shadow, grain, a luminous hairline, a radial glow.
- A tinted "hero" card, a card around a section, a card inside a card.
- A pill-shaped button, filter or badge; an icon in a tinted plate.
- An uppercase or letter-spaced label; a subtitle or tagline under a title.
- A progress ring, a donut, a sparkline, a confidence gauge.
- Space Grotesk, or any second display face.
- A coloured monogram; a bundled or looked-up third-party logo.
- A hard-coded user-facing string, an em dash joining two clauses, an exclamation mark.
- Texture behind a figure, a table, a chart, a form or an inspector's content.

## Invariants that did not change

- Money is signed integer minor units; `−` is U+2212; tabular numerals; sign plus colour.
- The sidebar and the title bar are identical on every panel; no bottom bar.
- French first, English at parity; French copy sizes every box.
- Meaning is never carried by colour alone.
- The HCSF reading and other indicative readings say so in body text.
- Nothing from the user's real data in code, tests, docs or mockups.
