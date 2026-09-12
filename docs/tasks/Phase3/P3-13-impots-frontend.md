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
4. Prefill: `/tax/prefill` offers figures the user **accepts per field**, with its confidence and
   `months_covered` shown. A low-confidence suggestion from a part-imported year says so at the
   field. Never auto-fill on load: a figure the app wrote is indistinguishable later from one the
   user declared (§5c), and this is the panel where that distinction matters most.
5. Estimate: the total, the average and marginal rates, and the per-component breakdown (IR, PFU or
   barème capital, social charges, property income, IFI). The breakdown is not optional detail —
   §16 requires the total to arrive with its derivation.
6. **The limits card is part of the feature, not a footnote.** Render `ignored_keys` as localised
   lines beside the figure, plus the estimation-first statement: this is a planning figure, not a
   return, not advice, no filing. Do not collapse it behind a tooltip or an expander.
7. The « ajusté » marker: whenever `parameter_source` is `overridden`, mark it next to the affected
   figures, and make the marker the way into the parameters view (P3-14) — an unexpected total
   should lead the user to the numbers they changed.
8. Empty and error states per the frames. A year with nothing declared shows a zero estimate with
   its invitation, not an error — zero is a valid answer.
9. ARB fr + en for every string, including each `ignored_keys` line and the whole disclaimer.

## Acceptance
- The panel renders for any selectable year; switching years refetches profile and estimate.
- No tax arithmetic exists in Dart (grep-able: no bracket tables, no rate maths).
- Prefill never writes without an explicit per-field accept, and shows confidence and coverage.
- The breakdown accounts for the total exactly as returned; nothing is recomputed client-side.
- The limits statement and every `ignored_keys` line are visible beside the figure, in fr and en.
- The « ajusté » marker appears only under an override and navigates to the parameters view.
- A zero profile renders a zero estimate without an error.
- Amounts and percentages are locale-formatted, tabular; fr + en parity; `flutter analyze` clean.

## Tests
- Controller (mocked repo): year switching; patch; prefill accept per field leaves other fields
  untouched; estimate mapping including `ignored_keys` and `parameter_source`.
- Widget: breakdown sums to the displayed total for a fixture; limits card renders every ignored
  key in fr and en; prefill banner shows low confidence for a part-imported year and does not
  auto-fill; « ajusté » marker present only under an override; zero-profile state; a comma-typed
  amount patches correctly.

## Commits
- `feat(tax): add the tax repository and controller`
- `feat(tax): add the impots panel with the declaration form`
- `feat(tax): add the estimate breakdown and its limits statement`
