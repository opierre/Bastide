# P3-14 — Impôts panel: « Paramètres fiscaux » view
Scope: frontend
Depends on: P3-08, P3-13
Skills: flutter-frontend, design-system, i18n-l10n, testing
PROJECT.md: §16, §5c
Design: `docs/design/13-impots.md` (the parameters frames) — normative

## Objective
The barème and parameter set for the displayed year, editable in place inside the Impôts panel,
with a reset to the official values. **It lives here, not in Paramètres** — the parameters are the
workings of the estimate, and the only moment anyone wants them is while reading a total that looks
wrong (§16).

## Files
- `frontend/lib/features/tax/presentation/tax_parameters_view.dart`, `bracket_table.dart`,
  `parameter_row.dart`
- `frontend/lib/features/tax/application/tax_parameters_controller.dart`
- `frontend/lib/features/tax/data/tax_repository.dart` — edit: parameters read, patch, reset
- `frontend/lib/features/tax/domain/tax_parameter.dart`, `tax_bracket.dart`
- ARB keys (fr + en); `frontend/test/features/tax/tax_parameters_test.dart`

## Steps
1. A second view within the panel — the segmented pattern `08-categories-rules.md` uses for
   Catégories | Règles, applied here as Estimation | Paramètres fiscaux. Reached from the control
   and from the « ajusté » marker (P3-13 step 7).
2. The IR and IFI bracket tables use the existing DataTable component: band floor, rate, and the
   band's ceiling implied by the next row. Editing is in place; the rate input takes a percent and
   converts to bps at the edge (the user types 11, the API gets 1100).
3. A bracket set is submitted **whole**, per §16 — the client sends the full set for a kind, and a
   locally invalid set (descending, gapped, overlapping, empty) is refused in the form before it
   reaches the API, with the reason on the offending row. The API refusal is the backstop, not the
   user's first feedback.
4. Scalar parameters: one row each, grouped and **labelled from ARB by key** — the backend stores
   machine keys and numbers only (P3-02 step 7), so every human-readable name and explanation is
   ARB, fr and en. A key with no translation must be visible as a missing string in review, not
   rendered raw to the user.
5. Each overridden row is marked « ajusté » with its seeded value shown alongside, so the user can
   always see what they changed from. Losing the official value behind an override would make the
   reset the only way to find it again.
6. « Rétablir les valeurs officielles » resets: whole-year from the view header, per row from the
   row. Confirm the whole-year reset through the standard modal (it discards work), and make the
   per-row reset immediate (it discards one number, and the number is on screen).
7. After any write, re-render from the resolved set the API returns — never from the local edit
   (§16: the panel shows the numbers the estimate ran on). Then invalidate the estimate so the
   total and the markers follow in the same interaction.
8. The year is the one the panel is showing; overriding 2025 must visibly not touch 2026, because
   that is the axis a barème changes on. Say the year in the view header.

## Acceptance
- The view is reachable from the control and from the « ajusté » marker, inside the Impôts panel,
  with no route into Paramètres.
- Bracket edits submit a whole set; an invalid set is caught in the form with a row-level reason.
- A percent typed with a comma converts to the right bps.
- Every parameter label and help string comes from ARB in fr and en; none renders a raw key.
- Overridden rows show « ajusté » and their seeded value.
- Whole-year reset confirms; per-row reset is immediate; both re-render from the API's resolved set.
- The estimate and its markers update after a write without a manual refresh.
- The header names the year; switching years shows that year's set.
- fr + en parity; `flutter analyze` clean.

## Tests
- Controller (mocked repo): load resolved set; patch a scalar; submit a bracket set; whole-year and
  per-row reset; the estimate is invalidated after each write.
- Widget: invalid bracket sets rejected in-form with the row reason; percent-to-bps at the edge;
  « ajusté » rows show the seeded value; reset confirmation modal for the year and none for a row;
  labels resolve from ARB in both locales; the year in the header follows the panel.

## Commits
- `feat(tax): add the tax parameters view with per-user overrides`
- `feat(tax): add bracket editing and the reset to official values`
