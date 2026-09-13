# P3-11 — « Patrimoine » nav group & routes
Scope: frontend
Depends on: P2-14
Skills: flutter-frontend, design-system, i18n-l10n, testing
PROJECT.md: §9, §2
Design: `docs/design/00-shared-design-block.md` Phase 3 amendment (nav) + the §Nav section of
`12-credits.md`, `14-simulateur.md`, `15-synthese.md` — all normative, and they win over this
card's prose

> **Amended after the tax feature was removed.** Impôts (`/tax`), its placeholder screen, its
> percent glyph and its strings are gone: the group is Crédits · Simulateur · Synthèse, the stack is
> 3 + 4 + 3 + 1, and the collapsed rail carries three glyphs. Where the steps below still name four
> items, read three.

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
2. Icons are **drawn, not chosen** — take them from the frames, not from this card's intuition:
   Crédits = **house** (pentagon roof/walls with a door notch, `M3 8.2L9 3l6 5.2V15H3zM7.2 15v-4.2h3.6V15`,
   `12-credits.md` §Nav) · Simulateur =
   **calculator** (rounded rect, display bar, 3 x 2 key dots, `14-simulateur.md` §Nav) · Synthèse =
   **pie** (full disc with one separated 90° sector, `15-synthese.md` §Nav). 1.5 px stroke, round
   caps, 2 px when active. Each must stay distinct at 18 px from the existing eight (dashboard
   4-square, wallet, twin arrows, tray, tag, cycle, flag, sliders).
3. **The layout invariant is the constraint, not a suggestion.** The frames measure the 3 + 4 + 4 + 1
   stack at ≈ 720 px inside 900 — ≈ 176 px of slack, no token changed (`00` §Phase 3 additions).
   Verify that holds in the built shell without changing item height, padding or the 40 px pill
   rhythm, and that the collapsed 76 px rail carries a 28 px `#1A212C` hairline between **each**
   group boundary (Aperçu/Gestion, Gestion/Patrimoine) and one before Paramètres. If the stack no
   longer breathes at 900 px frame height, **stop and ask** — a scroll or a density change to the
   sidebar is a design decision, not an implementation detail (§9: fixed chrome is non-negotiable).
4. Register the four top-bar action slots in `_topBarActions` so each panel card can drop its
   controls in without touching the router again.
5. Placeholder screens: the panel's title and descriptor in the top bar and an empty content
   region. No fake data, no "coming soon" copy — a placeholder that ships by accident should look
   unfinished, not wrong.
6. ARB keys for the group label, the four item labels and the four top-bar descriptors, fr and en.
   The EN label of Synthèse is **"Net worth"**, not "Overview": the Aperçu group already owns
   "Overview" (decided in design review, `15-synthese.md` §Nav). The four descriptors are the ones
   the frames carry: « Vos emprunts, leur coût et votre capacité » · « Une estimation, pas une
   déclaration » · « Ce qu'un nouveau crédit changerait » · « Ce que vous possédez, ce que vous
   devez ».

## Acceptance
- The four items appear in the named order, in their own group, with Paramètres and the privacy
  badge still pinned at the foot.
- Active, hover and collapsed treatments are identical to the existing items (iris 12 % fill, iris
  text, filled icon, 3 x 22 px rail; `#12161F` hover wash).
- At 1440 x 900 nothing in the sidebar scrolls or compresses; the collapsed rail groups read
  clearly.
- Each route renders its placeholder with the right title and descriptor in fr and en, and the
  EN label of `/networth` is "Net worth".
- The four glyphs match the frames' paths and are distinguishable from the existing eight at 18 px.
- `flutter analyze` clean; ARB parity holds.

## Tests
- `app_shell_test.dart`: the group renders with its four items in order; the active item resolves
  from the route for each of the four; the collapsed rail renders four icons plus separators; fr
  and en labels.

## Commits
- `feat(core): add the Patrimoine nav group and its four routes`
