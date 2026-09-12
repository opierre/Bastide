# P3-11 — « Patrimoine » nav group & routes
Scope: frontend
Depends on: P2-14
Skills: flutter-frontend, design-system, i18n-l10n, testing
PROJECT.md: §9, §2
Design: `docs/design/00-shared-design-block.md` Phase 3 amendment (nav) — normative

## Objective
The third sidebar group and its four routes, with placeholder screens the panel cards fill in.
Done first and on its own so four panel cards can then proceed in parallel without four agents
each editing the shell.

## Files
- `frontend/lib/core/widgets/app_shell.dart` — edit: the third nav group
- `frontend/lib/core/router/app_router.dart` — edit: four routes, top-bar action slots
- `frontend/lib/features/mortgages/presentation/mortgages_screen.dart` (placeholder)
- `frontend/lib/features/tax/presentation/tax_screen.dart` (placeholder)
- `frontend/lib/features/simulator/presentation/simulator_screen.dart` (placeholder)
- `frontend/lib/features/networth/presentation/networth_screen.dart` (placeholder)
- ARB keys (fr + en); `frontend/test/core/app_shell_test.dart` — edit

## Steps
1. Add the « Patrimoine » / "Wealth" group **after** Gestion, before the pinned Paramètres and its
   privacy badge, in this order: Crédits (`/mortgages`) · Impôts (`/tax`) · Simulateur
   (`/simulations`) · Synthèse (`/networth`).
2. Icons follow the existing language exactly — 1.5 px stroke, round caps, filled variant when
   active: Crédits = house with a key or a bank-column glyph, Impôts = document with a percent
   mark, Simulateur = sliders-and-curve, Synthèse = stacked-layers. Keep each distinct from the
   Phase 1 and 2 glyphs (dashboard 4-square, wallet, twin arrows, tray, tag, cycle, flag).
3. **The layout invariant is the constraint, not a suggestion.** The sidebar is 252 px with a
   3 + 4 + 4 + 1 stack now; verify the group fits without changing item height, padding or the
   40 px pill rhythm, and that the collapsed 76 px rail keeps a hairline separator between each
   group. If the stack no longer breathes at 900 px frame height, **stop and ask** — a scroll or a
   density change to the sidebar is a design decision, not an implementation detail (§9: fixed
   chrome is non-negotiable).
4. Register the four top-bar action slots in `_topBarActions` so each panel card can drop its
   controls in without touching the router again.
5. Placeholder screens: the panel's title and descriptor in the top bar and an empty content
   region. No fake data, no "coming soon" copy — a placeholder that ships by accident should look
   unfinished, not wrong.
6. ARB keys for the group label, the four item labels and the four top-bar descriptors, fr and en.

## Acceptance
- The four items appear in the named order, in their own group, with Paramètres and the privacy
  badge still pinned at the foot.
- Active, hover and collapsed treatments are identical to the existing items (iris 12 % fill, iris
  text, filled icon, 3 x 22 px rail; `#12161F` hover wash).
- At 1440 x 900 nothing in the sidebar scrolls or compresses; the collapsed rail groups read
  clearly.
- Each route renders its placeholder with the right title and descriptor in fr and en.
- `flutter analyze` clean; ARB parity holds.

## Tests
- `app_shell_test.dart`: the group renders with its four items in order; the active item resolves
  from the route for each of the four; the collapsed rail renders four icons plus separators; fr
  and en labels.

## Commits
- `feat(core): add the Patrimoine nav group and its four routes`
