# P3-15 — Simulateur panel
Scope: frontend
Depends on: P3-09, P3-11
Skills: flutter-frontend, design-system, i18n-l10n, testing
PROJECT.md: §17, §15, §9
Design: `docs/design/14-simulateur.md` + `00-shared-design-block.md` — both normative

## Objective
The Simulateur panel: the input form, the live result, the year-by-year projection, the HCSF
reading, and saved scenarios compared side by side.

## Files
- `frontend/lib/features/simulator/presentation/simulator_screen.dart` (replace placeholder),
  `simulator_form.dart`, `simulation_result.dart`, `yearly_projection_chart.dart`,
  `scenario_list.dart`, `scenario_compare.dart`
- `frontend/lib/features/simulator/application/simulator_controller.dart`
- `frontend/lib/features/simulator/data/simulations_repository.dart`
- `frontend/lib/features/simulator/domain/simulation.dart`, `simulation_result.dart`
- ARB keys (fr + en); `frontend/test/features/simulator/...`

## Steps
1. Repository and controller over `/simulations` and `/simulations/compute`. Compute is called on
   **debounced** input change (250–400 ms) — it is stateless and cheap (§17), so the panel can feel
   live without saving anything.
2. Inputs: property price, apport, borrowed amount, rate (percent to bps at the edge), insurance,
   term, fees, and the « inclure mes crédits actuels » switch. Borrowed defaults to
   price + fees − apport and stays editable — the default is a convenience, not a constraint.
3. **No arithmetic in Dart**, including the borrowed-amount default's arithmetic staying a trivial
   sum: the payment, cost, TAEG, ratio and `max_borrowable` all come from the API (§17: one engine).
4. Result block: monthly instalment (payment + insurance, and say so), total interest, total
   insurance, total cost, cost over price, and `taeg_bps` **labelled indicative**.
5. The projection uses the existing chart family — an AreaLine or StackedBars per 00 §Components,
   never a new chart idiom — over the yearly rows, not 300 months.
6. HCSF reading: ratio against the limit and term against the maximum, as a reading, never a
   verdict that blocks. When income is unknown the ratio is absent with the reason and the offer to
   declare an income; `max_borrowable` is likewise absent rather than zero.
7. Scenarios: save the current inputs with a label, list them, delete them (hard, no confirm modal
   for a scratchpad row — an undo-free delete of a saved *input set* is proportionate), and compare
   **at most 3** side by side. Beyond 3 the compare control is disabled with its reason (§17: more
   is a spreadsheet, not a comparison).
8. Comparison shows the same rows per scenario so columns are readable across; a figure absent for
   one scenario (no price, so no cost-over-price) renders as a dash, never as 0.
9. Empty state: the form with no result yet, and a line saying what the panel answers. Error state
   is ErrorRetry; a 422 from the engine (a degenerate loan) is an inline field error.
10. ARB fr + en, including the HCSF caveat and the no-lender-is-bound statement.

## Acceptance
- Editing an input updates the result without saving anything (assert no POST to `/simulations`).
- No loan arithmetic in Dart beyond the percent-to-bps conversion and the borrowed-amount default.
- The instalment is stated as payment plus insurance; TAEG is labelled indicative.
- The projection renders yearly rows in an existing chart idiom.
- With unknown income the ratio and `max_borrowable` are absent with a reason, not zero.
- An over-limit reading never blocks computing or saving.
- Scenarios save, list, delete; compare accepts up to 3 and disables beyond with a reason; missing
  figures render as a dash.
- Locale formatting for money, percentages and rates in fr and en; `flutter analyze` clean.

## Tests
- Controller (mocked repo): debounced compute; scenario CRUD; compare selection cap; unknown-income
  mapping.
- Widget: live result on input change with no save; comma-typed rate; TAEG label; projection
  renders; HCSF reading present and non-blocking; unknown income reason; compare of 3 with a dash
  for a missing figure; 422 inline; empty state; fr + en.

## Commits
- `feat(simulator): add the simulations repository and controller`
- `feat(simulator): add the simulator panel with live results`
- `feat(simulator): add saved scenarios and side-by-side comparison`
