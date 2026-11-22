# 00 — Design system (v2)

This file is binding for every screen of Bastide. A value that is not written here does not
exist: add it here first, then to `frontend/lib/core/theme/tokens.dart`.

- **Order of authority:** this file, then the panel spec (`02` to `18`), then the mockup.
  Where the mockup and a written spec disagree, the written spec wins. Known differences are
  listed in §15.
- **Mockup:** `docs/design/proposal_v6/index.html`, opened in a browser. Each spec names its
  screen as `#panel=<id>`. Every figure, name and date in the mockup is invented. v6 repeats
  `proposal_v5` and adds every modal (`#panel=m-frame` and one page per feature) and the
  window controls (`#panel=window`).
- **Reference frame:** 1440 × 900. French copy sizes every box; English uses the same geometry.
- This file replaces `00-shared-design-block.md` (v1: iris gradient, navy ground, grain). The v1
  text is in the git history and no longer applies.

## 1. Principles

1. **The figure leads.** Each panel opens on one summary line set in type: the main figure at
   40 px, its supporting figures at 28 or 20 px. No tinted "hero" card.
2. **Sections, not cards.** Parts of one page are separated by 24 px of space and a hairline.
   A bordered box is used only for an object the user can open or move (an account tile is not
   one in v2; see each panel), and for things that float: popover, modal, toast, banner.

   **Hairlines between blocks.** Two blocks of a page (the summary line counts as one) are
   always separated by space, a 1 px `line` hairline, then the same space again: 24, 1, 24 in
   the content region. Space alone never separates two blocks, even where the mockup draws
   nothing (§15). A panel spec may set another gap (the inspector's 16, §7; the Simulateur
   reading pane's 22, that is 11, 1, 11), never drop the hairline. A Banner or a Note belongs
   to the block it concerns and sits 24 px from it, with no hairline of its own.
3. **One accent, flat.** Ink for the primary action, blue for selection, links, focus and
   progress. No gradient, no glow, no coloured shadow anywhere.
4. **Colour carries meaning or nothing.** Green and red are the sign of money. Amber is
   "worth a look". Category hues identify categories. Everything else is neutral.
5. **The repère.** A value compared with a reference is always drawn the same way: a thin bar
   and a labelled vertical mark (§8). No ring, no gauge card.
6. **Texture lives in empty space** (§12), never behind a figure, a table or a chart.
7. **Two themes at parity.** Dark is the reference theme and the default (CLAUDE.md,
   "dark-first"); light is complete, not derived by inversion.

## 2. Colour tokens

Token names are the ones `tokens.dart` exposes through a `ThemeExtension`. Never write a hex in
a widget.

### 2.1 Surfaces, lines, text

| Token | Role | Dark | Light |
|---|---|---|---|
| `bg` | Window and content ground | `#111214` | `#FFFFFF` |
| `rail` | Sidebar, inspector panes, group rows, auth ground stays `bg` | `#0C0D0F` | `#F6F6F7` |
| `surface` | Popover, modal, toast, banner, button ground | `#191A1D` | `#FFFFFF` |
| `field` | Input and select wells | `#17181B` | `#FFFFFF` |
| `hover` | Row and item hover, active nav item, segmented "on", monogram ground | `#1F2125` | `#F0F1F2` |
| `line` | Hairline between sections and rows | `#25272B` | `#E6E7E9` |
| `lineStrong` | Control borders, meter and slider track, dashed outlines | `#35383E` | `#D0D2D6` |
| `text` | Primary text and figures | `#ECEDEF` | `#17181A` |
| `textSecondary` | Labels, captions, secondary cells | `#A3A7AE` | `#5A5E65` |
| `textTertiary` | Column headers, notes, axis labels, placeholders, disabled | `#8A8E96` | `#666A71` |
| `scrim` | Behind a modal | `rgba(0,0,0,.55)` | `rgba(23,24,26,.32)` |
| `shadow` | Popover, modal, toast only | `0 12px 32px rgba(0,0,0,.5), 0 2px 6px rgba(0,0,0,.4)` | `0 12px 32px rgba(20,22,26,.14), 0 2px 6px rgba(20,22,26,.08)` |

### 2.2 Accent and meaning

| Token | Role | Dark | Light |
|---|---|---|---|
| `accent` | Selection, links, focus, meter and slider fill, toggle on, checkbox on, chart line | `#7FA6FF` | `#2B5CD0` |
| `onAccent` | Glyph on an accent fill | `#111214` | `#FFFFFF` |
| `accentSoft` | Selected row, focus ring halo | `accent` at 14 % | `accent` at 14 % |
| `primary` | Primary button fill (ink) | = `text` | = `text` |
| `onPrimary` | Primary button label | = `bg` | = `bg` |
| `positive` | Money in, goal reached, success | `#4CC38A` | `#18794E` |
| `negative` | Money out, failure, destructive | `#F2777A` | `#C4292E` |
| `warning` | Worth a look: price rise, missed charge, above a reference, stale value | `#E0A44A` | `#8F5F00` |

There is no separate "info" colour: informational banners are neutral.

Measured contrast (WCAG): every text token is ≥ 4.5:1 on `bg`, `rail` and `hover` in both
themes; `positive`, `negative`, `warning` and `accent` used as text are ≥ 4.7:1 on those three
surfaces. The tokens ticket adds a test that recomputes this.

### 2.3 Money

- Signed amounts carry `+` or `−` (U+2212, never the ASCII hyphen). Income is `positive`,
  expense is `negative`. The sign always accompanies the colour.
- **Neutral figures** take `text`, with a sign only when negative: totals, balances in a summary
  line or a form, expected charges, loan figures, property values, net worth, investment values
  and gains, percentages, rates.
- Sign-coloured: transaction amounts, a single account's balance when negative (`negative`;
  positive balances are neutral in tables and `positive` only in the account detail headline),
  the dashboard Net, allocation lines, month variations.
- Figures always use tabular numerals and are right-aligned in columns.
- Trend lines: an icon (`trending-up`, `trending-down`, `minus`) plus an unsigned percent, in
  `positive` when the news is good and `negative` when it is bad (a rise in expenses is bad).

### 2.4 Category palette

Fixed order. A hue follows its category everywhere and always sits beside the category name.

| Slot | Category | Dark | Light |
|---|---|---|---|
| `cat1` | Logement | `#3987E5` | `#2A78D6` |
| `cat2` | Alimentation | `#D95926` | `#EB6834` |
| `cat3` | Transport | `#199E70` | `#1BAF7A` |
| `cat4` | Abonnements | `#C98500` | `#EDA100` |
| `cat5` | Loisirs | `#D55181` | `#E87BA4` |
| `cat6` | Santé | `#9085E9` | `#6250D6` |
| `cat0` | Autres, Épargne, any custom category without a hue | `#6B7078` | `#9A9EA6` |
| — | Revenus | = `positive` | = `positive` |

A custom category picks one of `cat1`–`cat6` or `cat0`. A category therefore stores a
**slot**, not a hex: the v1 hex values held in the database (`backend/app/core/seed.py` and
user categories) are mapped to their slot once, and the theme resolves the slot to a colour. Category hues are marks (dots, bars),
never text colour. The net-worth composition bar reuses the slots in order for its segments.

## 3. Typography

One family: **Geist** (400, 500, 600). **Geist Mono** (400) only for raw bank labels, rule
patterns, file names, file paths, URLs and codes to copy (a recovery code). Space Grotesk is removed.

| Size / weight | Tracking | Use |
|---|---|---|
| 40 / 600 | −0.03 em | The panel's lead figure |
| 28 / 600 | −0.02 em | Supporting figures of the summary line; lead figure of an inspector |
| 20 / 600 | −0.01 em | Minor figures of a summary line |
| 16 / 600 | 0 | Inspector title, settings section title, modal title |
| 14 / 600 | 0 | Title-bar title, brand name in the sidebar |
| 13 / 400 | 0 | Body, table cells, nav items, field values |
| 13 / 500 | 0 | Emphasised cell, button label, active nav item, active tab |
| 13 / 600 | 0 | Section heading inside a panel |
| 12 / 400 | 0 | Field labels, column headers, captions, group labels |
| 11 / 400 | 0 | Notes, chart axis labels, meter labels. Nothing smaller, except a monogram's initials (10/600, §6). |

Line height 1.45 for text, 1.1 for figures. No uppercase labels, no letter-spaced labels.
All numerals tabular.

**No-break spaces.** A line never breaks inside a figure, between a figure and its unit, or
between a day and its month. In French, `intl` groups thousands with U+202F (narrow no-break
space) and puts U+00A0 (no-break space) before « € » and « % » (« 1 234,56 € », « 35 % »):
keep what it emits, never an ordinary space. Any other unit after a figure (« 320 k€ »,
« 2,2 × ») takes U+00A0. A date in words takes U+00A0 between the day and the month
(« 12 mai 2026 », « May 12, 2026 »); `DateFormat` writes an ordinary space there, so the
formatter replaces it.

## 4. Shape, spacing, density

- **Radius:** 6 on controls (buttons, fields, nav items, segmented, tabs' focus), 4 on items
  inside a control or popover and on checkboxes, 8 on containers (banner, popover, toast, drop
  target, account-type header), 12 on modals, 2 on meter and bar ends, full on avatars and
  toggles. Monogram: 5 (22 px) and 7 (32 px).
- **Spacing ramp:** 2, 4, 6, 8, 12, 16, 24, 32, 40. Inside a group 8; between a label and its
  value 4–6; between sections 24; page margin 32 horizontal, 24 vertical; two-column gutter 40.
  Off the ramp, by name: fields 14 apart (`AppSpacing.fieldGap`), in a modal (§7) and down
  the auth column; the drop target's padding 18 / 20 (`dropTargetY`, `dropTargetX`, §7).
  Panel-local values are listed in §16.
- **Heights:** title bar 48; nav item 30; button 28 (large 36); toolbar select 28; form field
  and form select 32; table row 36 (48 when the first cell has two lines); group row 30; tab
  40; popover item 28.
- **Widths:** sidebar 224 (collapsed 56); inspector 440; search field 240; the auth screens'
  single form column 320 (`AppSizes.authColumn`, `02-login.md`); modal widths in §7.
- **Elevation:** only `shadow`, only on popover, modal, toast. A Material menu, which takes an
  elevation rather than a shadow, uses 12 (`AppShadows.popoverElevation`).

## 5. Shell (identical on every panel)

Mockup: any panel.

- **Sidebar**, 224 px, `rail`, right hairline `line`, padding 12 / 8 / 8.
  1. Brand row: Plan mark 20 px + « Bastide » 14/600, padding 4 8 14.
  2. Groups, each with a 12/400 `textTertiary` label (padding 14 8 4), sentence case:
     « Vue d’ensemble » (Tableau de bord, Comptes, Transactions), « Gestion » (Imports,
     Catégories, Abonnements, Objectifs), « Patrimoine » (Crédits, Placements, Simulateur,
     Synthèse).
  3. Item: 30 px, radius 6, padding 0 8, icon 16 px + 9 px gap + label 13/400 `textSecondary`.
     Hover: `hover` ground. Active: `hover` ground, `text`, 13/500. No rail, no tint, no filled
     icon. Transactions carries the review count on the right, 11 `textTertiary`, hidden at 0.
  4. Flexible empty stretch: tomettes, faded top and bottom (§12).
  5. « Paramètres » item.
  6. Foot, above a `line` hairline: user row (22 px avatar, display name, `chevrons-up-down`
     14 px) that opens the user menu (Paramètres, Se déconnecter); then the privacy line, `lock`
     14 px + « Données locales » 12 `textTertiary`.
- **Collapsed sidebar**, 56 px: icons only, centred, tooltips with the label; brand row shows
  the mark; foot shows the avatar and the lock. Group labels become an 8 px gap. Toggled from
  Paramètres → Préférences and with `Ctrl+B`.
- **Title bar**, 48 px, `bg`, bottom hairline, padding 0 24: optional parent crumb
  (13 `textTertiary`, « Comptes / », a link), title 14/600, spacer, contextual controls (28 px,
  8 px apart). **No subtitle, no descriptor.**
- **Window controls** (Windows and Linux): the app draws its own; there is no native title
  bar. Réduire, Agrandir / Restaurer, Fermer sit at the right end of the title bar, 8 px after
  the last contextual control; the bar then has no right padding, so Fermer meets the window
  corner. Each control is 46 × 48, no border, no radius, a 16 px Lucide icon in
  `textSecondary` (`minus`, `square`, `copy` for restore, `x`). Hover: `hover` ground, icon
  `text`. Pressed: `lineStrong` ground. Fermer on hover: `negative` ground, icon `bg`; pressed:
  `negative` at 85 % over `text` (lighter in dark, darker in light, as the primary's hover). While the window is inactive the title and the icons take
  `textTertiary`; hover and pressed keep their colours. Tooltips and accessible labels « Réduire », « Agrandir », « Restaurer »,
  « Fermer ».
- **Drag area:** the empty stretch of the title bar and the sidebar's brand row. Double-click
  maximizes or restores. Controls, crumb and title do not drag.
- **macOS:** the system's three window buttons, drawn by macOS, 16 px from the left edge in
  the sidebar's brand row, centred in its 48 px band (they span 52 px: three 12 px buttons,
  8 apart); the brand row starts 14 px after them; no controls on the right.
  The buttons do not drag; the rest of the brand row does. With the sidebar collapsed, the
  buttons keep their place and overhang the title bar by 12 px; its 24 px padding leaves 12 px
  before the crumb or title, and the rail hides the mark. On auth screens the buttons sit
  top-left and the top 48 px band drags.
- **Auth screens** (no title bar), Windows and Linux: the three controls float in the top-right corner and the
  top 48 px band drags the window.
- **Content region:** padding 24 32, sections 24 apart. A panel marked "flush" has no padding
  and draws its own (tables and panes that run edge to edge).
- No bottom bar. No texture or decoration on the window frame.

Navigation icons (Lucide): `layout-dashboard`, `wallet`, `arrow-left-right`, `download`, `tags`,
`repeat`, `flag`, `house`, `chart-line`, `calculator`, `chart-pie`, `settings`.

## 6. Controls

Every control has: rest, hover, focus, pressed, disabled. Focus is always visible: 2 px `accent`
outline, 1 px offset; text fields instead take an `accent` border and a 3 px `accentSoft` ring.
A field in error keeps its `negative` border when focused and takes the ring in `negative` at
14 %. A control drawn only as an icon or a swatch has an accessible name and a tooltip in the
user's language (« Tirelire », « Bleu »), never an internal identifier.
Disabled is 45 % opacity and not focusable.

| Control | Recipe |
|---|---|
| **Button, secondary** (default) | 28 px, padding 0 10, radius 6, `surface` ground, 1 px `lineStrong`, 13/500 `text`, optional 14 px leading icon, 6 px gap. Hover `hover`. |
| **Button, primary** | Same geometry, `primary` ground, `onPrimary` label, no border. Hover: 8 % lighter in dark, 8 % darker in light. One per view. Loading: 14 px spinner replaces the icon, label stays, width does not change. |
| **Button, ghost** | No border, no ground, `textSecondary`. Hover `hover`. For dismiss and tertiary actions. |
| **Button, danger** | Secondary with `negative` label and a `negative` 45 % border. The solid `negative` fill exists only inside a destructive confirmation modal. |
| **Button, destructive** | Primary geometry, `negative` ground, `bg` label, no border. Hover as primary. Only as the confirm action of a destructive confirmation modal. |
| **Button, large** | 36 px, padding 0 14, centred label. Auth screens and modal-wide actions. |
| **Text field** | 32 px, padding 0 10, radius 6, `field`, 1 px `lineStrong`. Label above, 12 `textSecondary`, 5 px gap. Helper below, 11 `textTertiary`. Error: `negative` border, helper in `negative`. Amounts right-aligned. Read-only: no border, value in `textSecondary` with a leading `lock` 14 px. A unit (€, %) sits inside the field. |
| **Select** | Field look with a trailing `chevron-down` 14 px `textTertiary`. 28 px in a toolbar, 32 px in a form. Opens a popover as wide as the field. |
| **Search field** | 240 px × 28 px, `search` icon, placeholder « Rechercher », `Ctrl K` hint in a 1 px `lineStrong` box, radius 4, 11 px. Inside a modal or a popover, to filter a picker's list as you type: a full-width 32 px form field (the Text field size) with the leading `search` icon and no hint. Every such field has this one size. |
| **Segmented** | 1 px `lineStrong`, radius 6, padding 2, gap 2, `field` ground; segment padding 2 10, radius 4, 13 `textSecondary`; selected: `hover` ground, `text`, 500. |
| **Tabs** | Row on a `line` hairline; tab padding 10 0, 20 px apart, 13 `textSecondary`; selected: `text` 500 and a 2 px `text` underline. A count follows the label in `textTertiary`. |
| **Toggle** | 28 × 16, radius 8, `lineStrong` off, `accent` on; 12 px knob in `bg`. |
| **Checkbox** | 14 px, radius 4, 1 px `lineStrong`; checked: `accent` fill, `onAccent` check. |
| **Slider** | 4 px `lineStrong` track, `accent` fill, 14 px `text` thumb with a 2 px `bg` ring. The value is printed beside it. |
| **Link** | `accent`, 13 or 12 px, underline on hover. Never an arrow glyph typed in the string. |

## 7. Data display

| Component | Recipe |
|---|---|
| **Section heading** | 13/600. Optional right side on the same line: a secondary figure, a link, or a segmented control. 8–12 px above its content. |
| **Summary line** | A row, items bottom-aligned, 40 px apart, separated by vertical `line` hairlines. Each item: label 12 `textSecondary`, figure (40, 28 or 20), optional caption 12 `textTertiary` or a trend line. The first item holds the lead figure. |
| **Table** | Header 12/400 `textTertiary`, no ground, 8 px below; rows 36 px with a top `line` hairline; cell padding-right 12; numeric columns right-aligned. Row hover `hover`. Selected row `accentSoft`. Dimmed row (cancelled, disabled, archived): all cells `textTertiary`. Sortable header: label + `chevron-up`/`chevron-down` 14 px on the sorted column. |
| **Group row** | 30 px, `rail` ground, 12 `textTertiary`, spans the table (a day, an account type). |
| **Key/value list** | Two columns, label `textSecondary` left, value right-aligned, 8 px rows. A comparison adds one value column per source, 24 px apart, each headed 12 `textTertiary` right-aligned (« Sauvegarde · Actuel »); values stay `text`, a difference is not coloured. |
| **Monogram** | 22 px (32 px "large"), radius 5 (7), `hover` ground, 1 px `line`, initials 10/600 (12/600) `textSecondary`. Always neutral. Unknown: « ? ». A user-supplied logo replaces it in the same box, cover-cropped. |
| **Category label** | 8 px square dot (radius 2) in the category hue + name in `textSecondary`; subcategory after « › » in `textTertiary`. Uncategorised: « Non catégorisé » in `textTertiary` with a 1 px dashed `lineStrong` underline. An AI proposal is the same label followed by « confiance 78 % » 12 `textTertiary`; no gauge. |
| **Status text** | Icon 13 px + text 12 px in one colour: `positive` (`check`), `warning` (`triangle-alert`, `trending-up`, `clock-alert`), `negative` (`circle-x`), neutral `textSecondary`. No pill, no dot badge. Nothing is shown for a healthy item. |
| **Banner** | For something the user can act on. 1 px `lineStrong`, radius 8, padding 8 12, `surface`; leading 14 px icon, 13 px text, actions on the right, optional ghost close. Neutral by default; the icon alone takes `warning` or `negative`. |
| **Note** | For something to know. 14 px `textTertiary` icon + 12 `textSecondary` text, no box. |
| **Popover / menu** | `surface`, 1 px `lineStrong`, radius 8, `shadow`, padding 4; items 28 px, radius 4, hover `hover`; a `check` 14 px on the selected item. |
| **Modal** | `surface`, radius 12, `shadow`, on `scrim`; padding 24; title 16/600, optional lead 13 `textSecondary`; fields 14 px apart; footer right-aligned, secondary then primary, 8 px apart. Widths are given per panel. Only for a task that needs protected focus (a form, a confirmation). Full recipe under « Modal » below. |
| **Toast** | Bottom-right, 24 px from the edges; `surface`, 1 px `lineStrong`, radius 8, `shadow`, padding 10 14; status icon + 13 px text, optional second line 12 `textSecondary`; leaves after 4 s. |
| **Inspector pane** | Right pane, 440 px (`AppSizes.inspector`), `rail`, left hairline, padding 24; blocks separated by a hairline with 16 px on each side (16, 1, 16; `InspectorPane.blockGap`). Shows the row selected in the list on its left. Used by Transactions, Objectifs, Placements. |
| **Drop target** | 1 px dashed `lineStrong`, radius 8, padding 18 vertical, 20 horizontal (`AppSpacing.dropTargetY`, `dropTargetX`); icon, one line of text, one line of help, a secondary button. Drag-over: `accent` dashed border and `accentSoft` ground. |

### Modal

Mockup: `proposal_v6/index.html#panel=m-frame`, then one page per feature.

- **Frame:** `surface`, radius 12, `shadow`, no border, centred on `scrim`; at most the window
  height minus 24 px above and below.
- **Header:** padding 24 24 14; title 16/600; optional lead 13 `textSecondary` 4 px under it.
  No icon or glyph plate before the title, no close button. A long title wraps, its lines
  balanced; it never truncates and never widens the modal. The lead
  never leaves one word alone on its last line.
- **Body:** padding 0 24, fields 14 px apart, two-column grids with a 16 px gutter. Fields in
  a row align by their input: a helper under one does not push its neighbour down, and a
  label on two lines moves both inputs down together. A grid
  leaves no empty cell before its last row. Only the body scrolls; while it does, a `line`
  hairline separates it from the header and the footer, 14 px from the body's content. An
  introductory sentence is the header's lead, not the body's first line. List rows inside a
  body follow §4: 36 px, 48 px when they have two lines, radius 4 when selectable.
- **Footer:** padding 24; actions right-aligned, secondary then primary, 8 px apart, wrapping
  to a second line rather than overflowing. A tertiary ghost action (« Supprimer » in an edit
  form, « Retour à l’aperçu » in a second step) sits alone on the left. Navigation to another
  place is not a footer action: it is a link in the body. The secondary reads « Annuler »,
  or « Plus tard » when Bastide proposed the task itself (the settlement rule). A modal
  without a body (a confirmation) keeps the footer 24 px under the lead.
- **Widths:** 420, 440, 480, 500, 520, 560, 600, 620; each panel spec names its modal's width.
  A modal never widens for a label.
- **Closing:** Escape and a click on the scrim act as the secondary action on a confirmation
  and on a form nobody has changed. Once a form holds unsaved input, the scrim does nothing,
  and Escape or « Annuler » asks « Abandonner les modifications ? » (420 px, lead naming the
  form; « Continuer la saisie » · ink « Abandonner »; its own Escape returns to the form).
  Nothing closes while a save is running, nor a modal with a single way out.
- **Keyboard:** focus stays inside the modal (Tab cycles header, body, footer, left to right).
  It lands on the first field of a form, on « Annuler » in a destructive confirmation, on the
  primary action in a reversible one, and on the copy action in a single way out. Enter
  submits a form from a single-line field. On close, focus returns to what opened the modal.
  The modal is named by its title and described by its lead.
- **Variants:**
  - Confirmation: the title asks the question, the lead says what changes, the primary action
    repeats the title's verb (« Archiver ») or names its effect when the verb alone would be
    vague (« Remplacer mes données » for a restore). Reversible actions keep the ink primary.
  - Destructive confirmation: the same, with the destructive button (§6) as the confirm
    action. The title names what goes (« Supprimer la règle « CARREFOUR » ? »), never
    « cette règle ». When the action needs typing a word, the button stays disabled until it matches.
  - Single way out: something shown once (a recovery code); one primary action, Escape and
    the scrim do nothing. Initial focus goes to the copy action, never to the closing one, so
    Enter cannot dismiss it; a secondary « Enregistrer dans un fichier » writes it to a text
    file on this machine.
  - Acknowledgement: a result to read (a refused pack, logos not added); body only, one
    primary « Fermer »; Escape and the scrim close it.
  - List editor: a modal that edits a list in place (Historique déclaré); the entry row in the
    body carries the primary action, the footer has a single secondary « Fermer ».
  - Crop: the lead says what to do, then the body holds the window the picture shows through, centred, radius 8, 1 px `line`:
    320 × 320 for a square crop, the body's full width at the target ratio otherwise (44:19 for
    a goal banner). Under it, as wide as the window, a « Zoom » slider (§6) between `zoom-out`
    and `zoom-in` icons, 1 to 5 ×, value printed (« 2,2 × »). Drag moves, wheel, pinch or the
    slider zooms; with the window focused, arrow keys move and + / − zoom. The avatar crop
    draws the round avatar's circle and veils the corners with `scrim`. The circle sits on the photo,
    not on the theme: 1 px white at 80 % with 1 px black at 30 % outside, in both themes.
  - Zoom: the picture alone, 240 × 240, radius 12, `shadow`, on `scrim`; any click or Escape
    closes it.
- **States:** a refused field takes the field error of §6; a failed save shows a Banner with
  a `negative` icon at the top of the body and keeps the input; a running save shows the
  spinner in the primary button and disables the other actions and the fields, and a second
  click does nothing (a confirmation's action behaves the same); a loading body shows its silhouette
  (as §7 « Loading »); a body that cannot load shows a Banner with a `warning` icon and a
  secondary « Réessayer ». An action that runs without closing the modal (« Exporter
  d’abord ») gives way, once it succeeds, to status text in `positive` with `check` that
  names the result (« Sauvegarde enregistrée »), in the button's place, until the modal
  closes. It is announced to screen readers, stands in for the toast the action shows
  elsewhere, and focus moves to the modal's initial focus (« Annuler » in a destructive
  confirmation).

### States of a panel

- **Empty:** centred in the content region, on tomettes faded toward the edges: title 16/600,
  one sentence 13 `textSecondary` (≤ 44 ch: at most 300 px wide,
  `CenteredStatePane.maxSentenceWidth`), one button. No icon plate.
- **Loading:** the layout's own silhouette in `hover` blocks (radius 4), opacity pulsing 1 → .5
  over 1.6 s. No spinner for a whole panel.
- **Error:** as empty, with a `warning` `triangle-alert` 16 px before the title and a secondary
  « Réessayer ». The sentence says what failed and that nothing was modified.

## 8. The repère (meter)

One component for every value read against a reference.

- Track 4 px, radius 2, `lineStrong`. Fill from the left, `accent`, radius 2.
- **Mark** (optional): a 2 × 12 px `text` bar centred on the track at the reference's position,
  with its label 11 `textSecondary` centred 5 px above (« objectif 20 % », « repère HCSF 35 % »).
  A meter with a mark reserves 18 px above the track.
- Variants: `over` (fill `warning`, the value is past a reference it should stay under), `done`
  (fill `positive`, the target is reached), `muted` (fill `textTertiary`, archived).
- The value itself is printed beside or above the meter in text, never inside it.
- The fill clamps at 100 %; the printed value stays exact.
- When the value changes the fill animates once, 240 ms (§13).

| Use | Scale | Mark |
|---|---|---|
| Savings rate (Dashboard) | 0 to 2 × the goal | the goal |
| Goal progress | 0 to target | none (the end of the track is the target) |
| Debt ratio (Crédits) | 0–60 % | 35 % |
| Debt ratio (Simulateur) | 0–70 % | 35 % |
| Loan duration (Simulateur) | 0–30 years | 25 years |
| Loan repaid | 0 to principal | none |
| Investment payment ceiling | 0 to ceiling | none |
| Investment age | 0–8 years | the envelope's milestone |
| Review progress | 0 to total | none |

Progress rings, confidence gauges and the four-segment password meter are removed.

## 9. Charts

All charts share one frame: value axis in a 56 px left gutter, labels right-aligned ending 8 px
before the plot, 11 `textTertiary`; horizontal gridlines 1 px `line` on clean ticks; the zero
line 1 px `lineStrong` when a series crosses it; category axis in a 22 px band beneath, 11
`textTertiary`. No vertical gridlines, no chart border, no animation on appearance.

| Form | Recipe |
|---|---|
| **Bars by sign** (monthly savings, card cycles) | One bar per period, ≤ 18 px wide, radius 3 on the outer end; `positive` above zero, `negative` below. |
| **Line / area** (balances, net worth, loan trajectory) | 2 px `accent` line, round joins; area `accent` at 10 %; a 4 px dot ringed 2 px in `bg` on the last point and on the hovered point; a 3 px dot per point when there are ≤ 24 points. |
| **Step line** (subscription price) | As line, step-after. The point where the price changed takes a `warning` dot and a 1 px `warning` 35 % vertical guide. |
| **Second series** (net payments under an investment's value) | 1.5 px `textTertiary` step line, no area. |
| **Stacked bars** (capital + interest) | Capital `accent` at the base, interest `textTertiary` above, 2 px gap, radius 2 on top. |
| **Ranked bars** (spending by category, table cell bars) | 6 px, radius 3, in the category hue, length proportional to the largest row. The amount and the share are printed in the row. |
| **Composition bar** | 8 px, segments 2 px apart, radius 2, hues `cat1` onward in rank order; a table below carries name, share and amount. |

- **Hatching** marks what is not yet a fact: the month in progress, a projected value, a value
  held flat between two declarations. 45° lines, 1.5 px on a 5 px pitch, in the mark's own
  colour, with a 1 px outline in that colour. It replaces dashed outlines. On bars, the bar is
  hatched.
- **Line and area charts** show a stretch that is not yet a fact in two ways at once: its
  **area is hatched** (in the line's colour, with no outline of its own: the line is its upper
  edge), and its **line is dashed** (5 on, 4 off, same width and colour). Dots and the hover
  card keep their rules.
- Dashed strokes (5 on, 4 off) are otherwise for annotation lines only: "today", an end date,
  a declared-history segment.
- **Legend:** required for two or more series, as category labels (dot + name) on the heading
  line. One series needs none.
- **Hover:** a popover-style card (`surface`, 1 px `lineStrong`, radius 8, `shadow`), shown at
  once, placed clear of the hovered mark: the period, then each value signed and coloured per
  §2.3. The hit area is the full column of the period.
- Text in a chart uses text tokens, never the series colour.
- No donut, no pie, no sparkline, no dual axis.

## 10. Iconography

Lucide only (`lucide_icons_flutter`, the weight that draws a 1.5 px stroke), navigation
included. 16 px by default, 14 px inside buttons, selects and notes, 13 px in status text. A
category stores its icon as a Lucide name. No emoji, no Unicode glyph standing in for an icon.

## 11. Brand

Summary; `18-brand.md` is the full spec.

- **Mark « Plan »:** a rounded tile (radius 22 % of the side) in `primary`, holding a 3 × 3 grid
  of rounded squares in `onPrimary`; the centre square is `accent`. It is the grid plan of a
  bastide around its square.
- **Name:** « Bastide », Geist 600, tracking −0.02 em at display sizes.
- Institutions and merchants are neutral monograms. No third-party logo is bundled or looked
  up; a logo appears only when the user supplied it on a rule.

## 12. Texture

One pattern: **tomettes**, a hexagonal line pattern (Provençal floor tiles).

- Tile 24.25 × 42 px, path
  `M0 7 12.125 0l12.125 7M0 7v14M24.25 7v14M0 21l12.125 7 12.125-7M12.125 28v14`,
  1 px stroke, no fill: white at 7 % opacity in dark, black at 7 % in light.
- Allowed in exactly five places:
  1. Login and registration: full frame, faded to nothing behind the form (radial mask, clear
     from the centre to 22 % of the radius, full at 75 %).
  2. A panel's empty state: behind the sentence, same radial fade.
  3. The sidebar's empty stretch: faded at its top and bottom thirds.
  4. An objective without an image: fills the inspector banner.
  5. Paramètres → À propos: behind the header row (mark, name, version).
  Plus the installer splash and the startup screen (`18-brand.md`).
- Never behind a table, a figure, a chart, a form, or an inspector's content.
- No grain, noise, paper or stone image, luminous hairline, or radial glow.

## 13. Motion

- Hover and pressed states change at once.
- Popover, menu, modal, toast and inspector content: 120 ms ease-out (opacity, and 4 px of
  travel for popovers and toasts).
- A meter's fill: 240 ms ease-out, once, when its value changes.
- Loading silhouette pulse: 1.6 s.
- Nothing animates on first paint of a panel. Charts are drawn, not animated.
- With the OS "reduce motion" setting, every duration is 0.

## 14. Voice and copy

French first, English at parity (same keys, same structure). The interface is calm and factual.

**Rules**

1. A title names the place. No subtitle, tagline or slogan anywhere in the app.
2. One idea per sentence. Do not join two clauses with « — »; write two sentences, or use a
   colon when the second explains the first. The dash « — » is only the empty-value placeholder.
3. Empty states: a title that states the fact (« Aucun objectif »), one sentence that says what
   to do, one button. No « pour l’instant », no metaphor.
4. Encouragement is a fact with a number (« 4 sur 16 classées », « Objectif
   atteint »), never an exclamation.
5. The privacy promise appears in three places only: the sidebar (« Données locales »), the
   auth screens (« Vos données restent sur cet ordinateur. ») and the AI settings row. It also
   appears on the splash and in À propos, which describe the product.
6. Do not explain the interface (« Le résultat se recalcule à chaque saisie »). Say something
   about the user's money, or say nothing.
7. Sentence case everywhere. No uppercase marker (« INDICATIF », « DÉRIVÉ », « IRRÉVERSIBLE »):
   write « TAEG indicatif », « calculé : prix − apport + frais ».
8. No arrow or check glyph typed in a string; the widget draws the icon. `{from} → {to}` is
   data notation and stays.
9. Failures say what failed, that nothing was modified, and what to do next.
10. Readings that bind no one (HCSF ratio, TAEG, fiscal milestones) say so in body text:
    « Lecture indicative, qui n’engage aucun prêteur. »
11. An optional field says so in its label, « Note (facultative) », « Bien financé
    (facultatif) »; a required field carries no mark. No « optionnel », no helper that only
    says « Facultative ».
12. A typed confirmation word is lower-case in the label (« Saisissez « supprimer » pour
    confirmer ») and matches in any case.

**String changes** (apply the same change to `app_en.arb`)

| Key | Action |
|---|---|
| `navDashboardSubtitle`, `navAccountsSubtitle`, `navTransactionsSubtitle`, `navImportsSubtitle`, `navCategoriesSubtitle`, `navSubscriptionsSubtitle`, `navGoalsSubtitle`, `navMortgagesSubtitle`, `navSimulatorSubtitle`, `navNetworthSubtitle`, `navSettingsSubtitle` | delete |
| `authTagline` | delete |
| `authPrivacyLine` | « Vos données restent sur cet ordinateur. » |
| `sidebarPrivacyBadge` | « Données locales » |
| `authEmailTaken` | « Cet e-mail a déjà un compte. Connectez-vous. » |
| `dashboardEmptyTitle` | « Aucune donnée pour ce mois » |
| `dashboardEmptyBody` | « Importez un relevé OFX ou QFX pour voir vos revenus, vos dépenses et votre taux d’épargne. » |
| `accountsEmptyBody` | « Créez un compte, ou importez un relevé : Bastide crée le compte qu’il décrit. » |
| `importHistoryEmptyTitle` | « Aucun import » |
| `transactionsEmptyTitle` | « Aucune transaction » |
| `categoriesEmptyTitle` | « Aucune catégorie » |
| `subscriptionsEmptyTitle` | « Aucun paiement récurrent détecté » |
| `settingsBackupNone` | « Aucune sauvegarde. » |
| `goalsEmptyTitle` | « Aucun objectif » |
| `goalsEmptyBody` | « Un objectif réserve une somme sur le papier. Vos comptes ne sont pas modifiés. » |
| `rulesEmptyTitle` | « Aucune règle » |
| `networthEmptyTitle` | « Aucun compte, bien ou crédit » |
| `networthEmptyBody` | « Importez un compte ou déclarez un bien. La synthèse additionne vos avoirs et soustrait vos crédits. » |
| `mortgagesEmptyBody` | « Ajoutez un emprunt pour suivre son coût, son échéancier et votre taux d’endettement. » |
| `reviewQueueEncouragement` | delete |
| `importFailedNote` | « Fichier illisible. Rien n’a été modifié. » |
| `importUnreadableAccount` | « Ce fichier n’indique aucun compte. Choisissez la destination. » |
| `importDetectedAccountAmbiguous` | « Ce relevé vient de {account}, mais plusieurs comptes y correspondent. Choisissez la destination. » |
| `importDropZoneHint` | « Le relevé indique son compte. Rien n’est importé avant votre confirmation. » |
| `rulesPriorityNote` | « Appliquées dans cet ordre. Une catégorie choisie à la main n’est jamais remplacée. » |
| `settingsBackupPrivacy` | « Ce fichier n’est pas chiffré et contient tout votre historique. Conservez-le en lieu sûr. » |
| `settingsAiModelUnavailable` | « Moteur injoignable : aucun modèle à proposer. » |
| `settingsAiSubtitle` | becomes the toggle's label « Catégorisation par IA » |
| `subscriptionDetailFootnote` | « La série est déduite de ces prélèvements. Vérifiez-les avant de confirmer un changement. » |
| `subscriptionDetailHistorySubtitle` | « {account} » |
| `goalHistorySubtitle`, `simulatorFormSubtitle`, `simulatorCompareSubtitle`, `simulatorChartSubtitle`, `mortgagesChartSubtitle`, `networthCompositionSubtitle`, `networthSeriesSubtitle` | delete |
| `networthExclusionGoalsBody` | « Les objectifs réservent de l’argent déjà présent sur un compte. Ils ne sont pas comptés une seconde fois. » |
| `simulatorHcsfCaveat` | « Lecture indicative, qui n’engage aucun prêteur. » |
| `mortgagesRatioDeclareLink`, `networthCompositionInviteAction` | remove the « → » |
| every other value containing « — » between two clauses | split into two sentences (rule 2) |

A test in the copy ticket fails when an ARB value contains « — » between words, « → » outside
`{a} → {b}`, « ! », or « pour l’instant ».

## 15. Where the mockup differs from this file

The written values win.

- The mockup draws some labels at 12.5 and 11.5 px; the scale here is 13, 12, 11.
- The mockup's tertiary text is `#7F838B` / `#6D7178`; the token is `#8A8E96` / `#666A71`
  (contrast on `hover`).
- Inspector panes are 380, 440 and 460 px wide in the mockup; the token is 440.
- The mockup's charts use a 52 px gutter and basic hover titles; the frame here is 56 px with
  the hover card of §9.
- Toasts, popover menus other than the category picker, and the loading and error states of
  panels are specified here and not drawn. Modals and the window controls are drawn in
  proposal v6, which also takes the tertiary text token and the 13, 12, 11 scale for its
  controls.
- The mockup's « Logos » and « Textures » pages keep the eight-mark and three-texture
  comparison code; only Plan and tomettes are retained.
- The mockup separates some blocks with space only (the account detail, the subscription
  detail); the hairline of §1.2 is drawn there too.

## 16. Panel values

Layout values that belong to one panel. Each comes from that panel's spec (or its mockup
frame where the spec is silent) and lives in `tokens.dart` under the class named in the
heading. A new panel value is added here and to its spec, then to `tokens.dart`; a value two
panels share moves to §4.

### Objectifs: `AppGoalBanner` (`11-goals.md` §Inspector pane)

| Value | Token | Use |
|---|---|---|
| 190 px | `height` | Banner with a picture, edge to edge at the top of the inspector |
| 120 px | `heightEmpty` | Banner without a picture: tomettes on `rail` |
| 100 px | `fadeHeight` | Bottom fade under the title, over the picture |
| `rgba(12,14,24,.82)` | `fade` | The fade's bottom colour, transparent at its top |
| `#FFFFFF` | `title` | The name and the percent over the fade |
| `#D9DCE6` | `caption` | The deadline line over the fade |
| 18 px | `contentTop` | Top padding of the inspector content under the banner (18 24 24) |
| 36 × 24 px | `thumbWidth`, `thumbHeight` | The table's thumbnail of the picture, radius 4 |
| 44:19 | `aspectRatio` | The picture's proportions, also the crop's |

The fade and the two text colours sit on the picture, not on the theme, so they are the same
in both themes (like the crop circle, §7).

### Simulateur: `AppSimulator` (`14-simulateur.md`)

| Value | Token | Use |
|---|---|---|
| 380 px | `inputsWidth` | The inputs pane, right hairline, padding 24 |
| 14 px | `inputsGap` (= `fieldGap`) | Between the inputs pane's blocks, and around its hairline |
| 22 px | `readingGap` | Between the reading pane's blocks, the hairline in the middle (11, 1, 11) |
| 190 px | `compareLabelColumn` | The comparison table's row-label column |
| 640 px | `flexibleMinHeight` | Below this pane height the reading pane scrolls … |
| 220 px | `fixedChartHeight` | … and the projection chart keeps this height |
| 44 px | `projectionBarMaxWidth` | The widest a yearly projection bar gets |
| 0–70 % | `ratioScaleBps` | The debt-ratio repère's scale (§8) |
| 0–30 years | `termScaleMonths` | The duration repère's scale (§8) |

### Comptes: `AppAccountSection` (`05-accounts.md` §Section)

| Value | Token | Use |
|---|---|---|
| 10 / 12 px | `headerPaddingY`, `headerPaddingX` | The account-type header bar's padding |
| 10 px | `tableGap` | Between the header bar and its table |
| 120 px | `subtotalWidth` | The right-aligned subtotal slot |

### Crédits: `AppLoans` (`12-credits.md`)

| Value | Token | Use |
|---|---|---|
| 360 px | `ratioWidth` | The debt-ratio item of the summary line |
| 0–60 % | `ratioScaleBps` | The debt-ratio repère's scale (§8) |
| 28 px | `scheduleRow` | The amortisation table's dense rows |
| 96 px | `yearSelectWidth` | The schedule's year select |
| 22 % | `repaidFlex` | The « Remboursé » column's share of the loans table |
| 4 / 10 px | `instalmentLineTop`, `instalmentLabelGap` | The loan form's « Mensualité calculée » line: 4 px more than the field gap above it, 10 px between label and figures |

### Synthèse: `AppNetworth` (`15-synthese.md` §Layout)

| Value | Token | Use |
|---|---|---|
| 28 px | `equationGap` | Between the equation line's items and operators |
| 440 / 48 px | `compositionWidth`, `compositionGutter` | « Composition de l’actif », then the gutter before « Patrimoine net » |
| 230 px | `chartHeight` | The series chart, axis included |
| 72 / 140 px | `shareColumn`, `amountColumn` | Composition table columns |
| 96 / 140 px | `propertyShareColumn`, `propertyValueColumn` | Properties table columns |
| 40 px | `menuColumn` | The row-menu column (a 28 px button and 12 px) |
| 130 / 100 / 72 px | `declaredMonthField`, `declaredMonthColumn`, `declaredActionsColumn` | « Historique déclaré »: the entry row's month field, the list's month and action columns |

### Placements: `AppPlacements` (`17-placements.md`)

| Value | Token | Use |
|---|---|---|
| 20 px | `listGap` | Between the list pane's blocks |
| 170 px | `chartHeight` | The inspector chart, axis included |
| 112 / 112 / 160 / 108 px | `netPaymentsColumn`, `valueColumn`, `gainColumn`, `valuedOnColumn` | Investments table columns; « Placement » takes the rest |
| 96 / 116 px | `historyDateColumn`, `historyAmountColumn` | Movements table columns; the label takes the rest |

### Catégories et règles: `AppCategoriesPanel` (`08-categories-rules.md`)

| Value | Token | Use |
|---|---|---|
| 340 px | `treeWidth` | The category tree, right hairline |
| 52 px | `subcategoryIndent` | A subcategory's indent, past its parent's chevron, dot and icon |
| 60 / 120 / 56 px | `orderColumn`, `matchesColumn`, `activeColumn` | Rules table columns |
| 520 / 480 / 560 px | `ruleEditorWidth`, `categoryFormWidth`, `packModalWidth` | Modal widths |
| 32 / 20 / 12 px | `iconCell`, `colorSquare`, `colorCheck` | The category form's icon cell, colour square and its `check` |

### Transactions: `AppTransactions` (`07-transactions.md`)

| Value | Token | Use |
|---|---|---|
| 12 px | `filterRowY` | The filter row's vertical padding (12 32), controls 8 apart |
| 10 px | `pagerY` | The pager's vertical padding (10 32) |
| 220 px | `filterMaxWidth` | The widest a filter-row select grows |
| 240 / 128 px | `categoryColumn`, `amountColumn` | Table columns |
| 230 / 280 px | `pickerWidth`, `pickerListHeight` | The category picker popover and its list |
| 260 / 420 px | `progressWidth`, `noteMaxWidth` | The review tab's progress block and the Note beside it |
| 88 / 380 px | `reviewDateColumn`, `reviewActionsColumn` | Review table columns |

### Abonnements: `AppSubscriptions` (`10-subscriptions.md`)

| Value | Token | Use |
|---|---|---|
| 96 px | `chargeDateColumn` | A charge list's date column in the modals, its 12 px gap included |
