# P1-07 — Accounts frontend
Scope: frontend
Depends on: P1-05, P1-06
Skills: flutter-frontend, design-system, i18n-l10n, testing
PROJECT.md: §5, §9

## Objective
Accounts panel: list accounts with balances, create/edit, archive, using the shared chrome and
locale-aware money formatting. Institution shown with brand logo or monogram fallback.

## Files
- `frontend/lib/features/accounts/presentation/{accounts_screen,account_form.dart}`
- `frontend/lib/features/accounts/application/accounts_controller.dart`
- `frontend/lib/features/accounts/data/accounts_repository.dart`
- `frontend/lib/features/accounts/domain/account.dart`
- Shared `amount_text.dart` + institution logo/monogram widget in `core/widgets/` (reused later).
- ARB keys (fr+en); `frontend/test/features/accounts/...`

## Steps
1. Repository + controller (`AsyncValue<List<Account>>`): load, create, update, archive.
2. Accounts screen renders into the shell: account cards with name, type, institution
   logo/monogram, and balance via the shared `amount_text` (locale + tabular + sign color).
3. Account form (create/edit): name, type, institution, opening balance. **No currency picker**
   (Phase 1 — currency is the user's, shown read-only).
4. Archive action with confirm; archived hidden from default list.
5. Empty state: encouraging "add your first account" with a clear CTA (design-system).
6. All strings via ARB; analyze clean.

## Acceptance
- Lists accounts with correctly formatted balances in the user's locale/currency.
- Create/edit/archive work against the backend; errors surface as localized messages.
- Institution shows a logo when known, monogram otherwise — never a broken image.
- Consistent chrome; works fr + en.

## Tests
- Controller test (mocked repo): load/create/archive state transitions.
- Widget test: list renders amounts formatted for fr (`1 234,56 €`) and en; empty state renders;
  form submits chosen values.

## Commits
- `feat(accounts): add accounts repository and controller`
- `feat(accounts): add accounts list, form, and archive UI`
- `feat(core): add reusable amount text and institution logo widgets`
