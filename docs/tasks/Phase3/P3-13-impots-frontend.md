# P3-13 — Impôts panel: declaration & estimate
Scope: frontend
Depends on: P3-07, P3-11
Skills: flutter-frontend, design-system, i18n-l10n, testing
PROJECT.md: §5c, §16, §9
Design: `docs/design/13-impots.md` + `00-shared-design-block.md` — both normative and they win over
this card's prose

## Objective
The Impôts panel: the year picker, the declaration form with its accept-or-ignore prefill, the
estimate with a component breakdown, and the limits statement that makes the figure honest.

## Files
- `frontend/lib/features/tax/presentation/tax_screen.dart` (replace placeholder),
  `tax_profile_form.dart`, `estimate_summary.dart`, `estimate_breakdown.dart`,
  `prefill_banner.dart`, `tax_limits_card.dart`
- `frontend/lib/features/tax/application/tax_controller.dart`
- `frontend/lib/features/tax/data/tax_repository.dart`
- `frontend/lib/features/tax/domain/tax_profile.dart`, `tax_estimate.dart`
- ARB keys (fr + en); `frontend/test/features/tax/...`

## Steps
1. Repository and controller: profile list, profile for a year (lazily created server-side), patch,
   estimate, prefill. The year picker follows the dashboard's month-selector pattern (a top-bar
   pill), since it is the same gesture applied to a different period.
2. **No tax arithmetic in Dart.** Not one bracket, not one abattement, not the average rate. Every
   figure comes from `/estimate`; a second implementation would be a second, unverified tax engine
   (§16 puts the verified one in Python with hand-computed tests).
3. The declaration form patches field by field, locale-aware for amounts (fr comma). Household,
   dependents and the single-parent flag drive the parts figure the estimate returns — display it,
   never compute it.
4. Prefill: `/tax/prefill` offers figures the user **accepts per field**, drawn as the frames'
   **SuggestionRow** — the field above stays visibly empty (`0,00 €` in placeholder tone) and a
   dashed iris plate under it carries the amount, the source and coverage (« d'après vos imports ·
   N mois »), a ConfidenceGauge — **amber when confidence is low** — and an « Accepter » button.
   Accepting writes the value into the field and swaps the row for an inline accepted label; a
   field the user then edits by hand drops that label. A « Tout accepter (N) » outline button sits
   in the card header while suggestions are pending. Never auto-fill on load: a figure the app
   wrote is indistinguishable later from one the user declared (§5c), and this is the panel where
   that distinction matters most.
4b. **There is no property-income field in this form** (§4c, P3-06 step 4). In its place the frames
   put a read-only note plate naming the properties the figure comes from and linking to Synthèse
   — so a user looking for the field finds the answer instead of concluding it is missing.
5. Estimate: the total, the average and marginal rates, the **parts** figure (displayed as a
   *result* of household + dependents + single-parent, never an input), and the per-component
   breakdown (IR, PFU or barème capital, social charges, property income, IFI). Each row carries
   its own one-line derivation, as drawn. **« Non redevable » is a drawn state, not an absence**:
   an IFI of 0 renders with a gray StatusPill and names the base against the threshold. A
   component still waiting on an unaccepted suggestion renders as a dash with the reason, never as
   0. The breakdown is not optional detail — §16 requires the total to arrive with its derivation,
   and it must account for the total **exactly**.
5b. Layout: declaration left, result right, **side by side and never stacked** — at 900 px a
   stacked layout pushes the total off screen while the user types, and the point is that the
   total moves under the eye (`13-impots.md` §Estimation view).
6. **The limits card is part of the feature, not a footnote.** Render `ignored_keys` as localised
   lines beside the figure, plus the estimation-first statement: this is a planning figure, not a
   return, not advice, no filing. Do not collapse it behind a tooltip or an expander.
7. The « ajusté » marker: whenever `parameter_source` is `overridden`, render the frames' « N
   paramètre(s) ajusté(s) » pill beside the panel-head control, and make it the way into the
   parameters view (P3-14) — an unexpected total should lead the user to the numbers they changed.
   This card ships the Estimation | Paramètres fiscaux SegmentedControl **disabled or absent until
   P3-14 lands**; it must never render as a control that goes nowhere.
8. Empty and error states per the frames. A year with nothing declared shows a zero estimate — the
   hero at `0,00 €` in the disabled tone, both rate pills as dashes — and replaces the breakdown
   with the frames' **invitation card** offering the year's pending suggestions or manual entry.
   Zero is a valid answer, not an error, and the limits card stays visible.
9. ARB fr + en for every string, including each `ignored_keys` line and the whole disclaimer.

## Acceptance
- The panel renders for any selectable year; switching years refetches profile and estimate.
- No tax arithmetic exists in Dart (grep-able: no bracket tables, no rate maths).
- Prefill never writes without an explicit per-field accept, and shows confidence and coverage.
- The breakdown accounts for the total exactly as returned; nothing is recomputed client-side, and
  a component awaiting an unaccepted suggestion shows a dash with its reason rather than 0.
- No property-income input exists; the property note plate names the source and links to Synthèse.
- The parts figure renders as a result and is not editable anywhere.
- The limits statement and every `ignored_keys` line are visible beside the figure, in fr and en.
- The « ajusté » marker appears only under an override and navigates to the parameters view.
- A zero profile renders a zero estimate without an error.
- Amounts and percentages are locale-formatted, tabular; fr + en parity; `flutter analyze` clean.

## Tests
- Controller (mocked repo): year switching; patch; prefill accept per field leaves other fields
  untouched; estimate mapping including `ignored_keys` and `parameter_source`.
- Widget: breakdown sums to the displayed total for a fixture; limits card renders every ignored
  key in fr and en; the SuggestionRow leaves its field empty until accepted, shows an amber gauge
  for a part-imported year, and « Tout accepter » accepts all pending fields; « ajusté » marker
  present only under an override; zero-profile state renders the invitation card, not an error;
  the IFI « non redevable » row renders with its base and threshold; a comma-typed amount patches
  correctly.

## Commits
- `feat(tax): add the tax repository and controller`
- `feat(tax): add the impots panel with the declaration form`
- `feat(tax): add the estimate breakdown and its limits statement`
