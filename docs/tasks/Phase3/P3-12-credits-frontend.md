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
2. Summary row (three cards: charge mensuelle · capital restant dû · taux d'endettement) carries
   the debt ratio, its income source and the HCSF reference. The **RatioGauge** has a fixed 0–60 %
   scale so the 35 % reference tick sits at the same x in every state, iris fill under the
   reference and amber `#FFB84D` above, and a ratio past 60 % clamps the fill while still printing
   the exact percent (`12-credits.md` §1, §Notes). When `income_source` is `unknown`, **no gauge is
   drawn**: say why and offer the way out (declare an income) rather than drawing an empty one.
   When `over_limit` is true it is information in the warning tone — an amber StatusPill and an
   amber fill, the card border unchanged — never an error, never a block, and the line « Lecture
   informative : ce repère ne lie aucun prêteur. » is body content on the card, never a tooltip.
   The caption always names the income *and* its source, so wording must follow §15: the ledger
   figure is the **median** of the last 12 complete months.
3. Loan cards — **cards in a 2-column grid, not a DataTable** (`12-credits.md` §2: at n <= 5 a
   table header organises less than it costs, and two loans of very different size each keep a
   progress bar and their dates at equal rank): label, lender monogram chip (00 §Components —
   monogram, never an image), monthly instalment, outstanding, progress bar with the paid share,
   and a footer of taux nominal · assurance · prochaine échéance. Money follows the money rule; an
   instalment is a neutral figure, not a red expense — it is a scheduled charge, not a booked
   transaction (the same call `10-subscriptions.md` made).
3b. **The trajectory chart is part of this panel, not an extra.** Under the loan cards, an AreaLine
   of the *combined* outstanding principal of all active loans, month by month to the last
   instalment, with dashed annotations for today and for each loan's end date (`12-credits.md` §3).
   It is what the cards cannot show: when each debt ends and the step a second loan adds. The
   series comes from `/mortgages/summary` (P3-04 step 9) — **not** from summing schedules in Dart.
4. Detail: the cost totals, `taeg_bps` **labelled indicative** (an iris « INDICATIF » pill on the
   label), and the schedule table paged by year with a **YearSwitcher** — a ‹ year › pill plus a
   segmented strip of the loan's years, opening on the year of the current instalment, the strip
   jumping when the chevrons step. Rows use the dense 28 px table variant so twelve rows and the
   year's foot total fit at 900 px, the current instalment's row carries an iris 6 % wash, and the
   insurance column is separate from interest and principal — folding it in is exactly the
   misstatement §15 forbids. **No amortisation curve in the detail**: the frames reject it, since
   the table carries the numbers and the list's trajectory chart already carries the shape.
5. Form modal: label, lender, repayment type, principal, rate (as a percent input that converts to
   bps at the edge — the user types 3,45, the API gets 345), insurance, term, first payment date,
   optional fees, optional property link. Rate and money parsing is locale-aware (fr uses a comma).
   The frame's read-only « Mensualité calculée » plate under the fields (`#0A0F15`, dashed border,
   lock glyph) updates **live** as the fields change — feed it from a debounced
   `POST /simulations/compute` (P3-09, stateless and free to call), never from a payment formula
   written in Dart. `« Modifier »` opens the same modal prefilled, and deletion lives inside it as
   a secondary text button whose confirmation names both consequences: the loan leaves Synthèse's
   passif and leaves the IFI base when it was linked to a property.
5b. **Open question — the frame's « Type » select.** `12-credits.md` §Modal draws a Type field with
   *product* values (Crédit immobilier / Prêt travaux / Crédit à la consommation / Crédit auto) and
   the loan cards print it in their sub-line, but §4c has no such column — `repayment_type`
   (`constant_payment` | `interest_only`) is a different axis and cannot carry it. **Stop and ask**
   before building: this needs either a new `mortgages.kind` column (a P3-01 change) or the frame's
   sub-line reduced to lender + term. Do not silently map one onto the other.
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
- The schedule table's yearly totals match its rows; the insurance column is separate; rows are the
  dense 28 px variant and a full year plus its foot fits at 900 px without scrolling the panel.
- The trajectory chart renders the combined outstanding of all active loans from the API's series,
  with today and each loan's end annotated; no schedule is summed in Dart.
- The ratio gauge uses the fixed 0–60 % scale with the reference tick, clamps above it, and is
  absent (not empty) when the income source is unknown.
- A degenerate loan shows an inline error; archive removes the loan from the list and the summary.
- Empty, loading and error states render per the frames.
- fr + en parity; `flutter analyze` clean.

## Tests
- Controller (mocked repo): load and filter; create; patch; archive and restore; summary mapping
  including all three income sources; schedule window paging.
- Widget: card figures in fr and en; ratio card for declared, ledger and unknown; the gauge absent
  under unknown and clamped past 60 %; over-limit warning present and non-blocking; schedule table
  renders a year and its totals; the YearSwitcher opens on the current instalment's year; the
  trajectory chart renders from a fixture series; form submits a comma-typed rate as bps and its
  live mensualité plate follows a mocked compute; the 422 surfaces inline; empty state.

## Commits
- `feat(mortgages): add the mortgages repository and controller`
- `feat(mortgages): add the credits panel with the debt ratio summary`
- `feat(mortgages): add the amortisation schedule table`
