# P1-13 — Transactions frontend
Scope: frontend
Depends on: P1-10, P1-12
Skills: flutter-frontend, design-system, i18n-l10n, ai-categorization, testing
PROJECT.md: §5, §7, §9

## Objective
Transactions panel: a filterable, searchable, paginated list with category chips and signed
amounts, inline category editing, and a review queue surfacing `needs_review` items to confirm
or correct.

## Files
- `frontend/lib/features/transactions/presentation/{transactions_screen,transaction_row,review_queue.dart}`
- `frontend/lib/features/transactions/application/transactions_controller.dart`
- `frontend/lib/features/transactions/data/transactions_repository.dart`
- `frontend/lib/features/transactions/domain/transaction.dart`
- ARB keys (fr+en); `frontend/test/features/transactions/...`

## Steps
1. Repository + controller: paginated list with filters (account, date range, category,
   needs_review, search), category patch.
2. Transaction row (reusable): merchant logo/monogram, description, category chip, signed amount
   via shared `amount_text` (income green / expense red, tabular). Consistent with design-system.
3. Filtering + search UI in the top bar / panel header; infinite scroll or pager.
4. Inline category edit: pick a category → calls patch → row updates, leaves review state.
5. Review queue view: lists `needs_review=true`; confirm or correct; optional "always categorize
   like this" affordance (creates a rule via the rules endpoint — wired for Phase 2 learning).
6. Empty + error states; ARB parity; analyze clean.

## Acceptance
- List filters/searches/paginates correctly; amounts formatted per locale with correct sign color.
- Editing a category persists and clears the review flag.
- Review queue shows only uncategorized/uncertain items and lets the user resolve them.
- Consistent chrome; fr + en.

## Tests
- Controller test (mocked repo): load/filter/paginate/patch transitions.
- Widget test: row renders amount/sign/category correctly for fr + en; review queue resolves an
  item; empty state renders.

## Commits
- `feat(transactions): add transactions repository and controller`
- `feat(transactions): add filterable transaction list with category editing`
- `feat(transactions): add review queue for uncategorized transactions`
