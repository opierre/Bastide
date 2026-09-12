# P3-12 — Crédits panel
Scope: frontend
Depends on: P3-04, P3-11
Skills: flutter-frontend, design-system, i18n-l10n, testing
PROJECT.md: §5c, §15, §9
Design: `docs/design/12-credits.md` + `00-shared-design-block.md` — both normative, and they win
over this card's prose (see the README note)

## Objective
The Crédits panel: declared loans with their derived figures, the debt-ratio summary, the
amortisation table with its year navigation, and the loan form.

## Files
- `frontend/lib/features/mortgages/presentation/mortgages_screen.dart` (replace placeholder),
  `mortgage_card.dart`, `mortgage_detail.dart`, `mortgage_form_modal.dart`, `schedule_table.dart`,
  `debt_ratio_card.dart`
- `frontend/lib/features/mortgages/application/mortgages_controller.dart`
- `frontend/lib/features/mortgages/data/mortgages_repository.dart`
- `frontend/lib/features/mortgages/domain/mortgage.dart`, `schedule_row.dart`
- ARB keys (fr + en); `frontend/test/features/mortgages/...`

## Steps
1. Repository and controller: list with status filter, create, patch, archive, restore, summary,
   and the schedule for one year window. No business logic in widgets (flutter-frontend skill) —
   and in this feature that specifically means **no arithmetic**: every figure on screen comes from
   the backend, because a second amortisation implementation in Dart would drift from the one the
   tests pin (§15).
2. Summary row carries the debt ratio, its income source and the HCSF reference. When
   `income_source` is `unknown`, say why and offer the way out (declare an income) rather than
   drawing an empty gauge. When `over_limit` is true it is information in the warning tone, never
   an error and never a block — the panel states that no lender is bound by it.
3. Loan cards: label, lender monogram chip (00 §Components — monogram, never an image), monthly
   instalment, outstanding, progress bar with the paid share, and the next payment date. Money
   follows the money rule; an instalment is a neutral figure, not a red expense — it is a scheduled
   charge, not a booked transaction (the same call `10-subscriptions.md` made).
4. Detail: the cost totals, `taeg_bps` **labelled indicative**, and the schedule table paged by
   year with a year switcher. Show the insurance column separately from interest and principal —
   folding it in is exactly the misstatement §15 forbids.
5. Form modal: label, lender, repayment type, principal, rate (as a percent input that converts to
   bps at the edge — the user types 3,45, the API gets 345), insurance, term, first payment date,
   optional fees, optional property link. Rate and money parsing is locale-aware (fr uses a comma).
6. The 422 from a degenerate loan (instalment below its first interest) renders as an inline field
   error explaining the cause, not a toast — the user has to change a number, and the number is on
   screen.
7. Empty state per the design frame, with the « Nouveau crédit » CTA. Loading uses the existing
   LoadingSkeleton silhouettes; failure uses ErrorRetry.
8. ARB fr + en for every string, including the HCSF caveat and the TAEG disclaimer.

## Acceptance
- The panel is reachable from the sidebar with the standard chrome and top-bar controls.
- No amortisation or ratio arithmetic exists in Dart (grep-able: no payment formula, no bps maths
  beyond the percent-to-bps conversion at the form edge).
- Amounts, dates, percentages and rates are locale-formatted in fr and en, tabular and aligned.
- The ratio card renders all three income sources correctly, including `unknown`.
- An over-limit ratio warns and still allows every action.
- The schedule table's yearly totals match its rows; the insurance column is separate.
- A degenerate loan shows an inline error; archive removes the loan from the list and the summary.
- Empty, loading and error states render per the frames.
- fr + en parity; `flutter analyze` clean.

## Tests
- Controller (mocked repo): load and filter; create; patch; archive and restore; summary mapping
  including all three income sources; schedule window paging.
- Widget: card figures in fr and en; ratio card for declared, ledger and unknown; over-limit
  warning present and non-blocking; schedule table renders a year and its totals; form submits a
  comma-typed rate as bps; the 422 surfaces inline; empty state.

## Commits
- `feat(mortgages): add the mortgages repository and controller`
- `feat(mortgages): add the credits panel with the debt ratio summary`
- `feat(mortgages): add the amortisation schedule table`
