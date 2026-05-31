# P1-14 — Dashboard backend
Scope: backend
Depends on: P1-12
Skills: fastapi-backend, database, testing
PROJECT.md: §5

## Objective
A single summary endpoint computing, for a given month: total income, total expense, net,
savings rate, month-over-month deltas, and the by-category expense breakdown — all in the user's
single currency.

## Files
- `backend/app/features/dashboard/{router,schemas,service,repository}.py`
- `backend/tests/features/dashboard/test_dashboard.py`

## Contract slice
```
GET /api/v1/dashboard/summary ?month=YYYY-MM → {
  income_minor, expense_minor, net_minor, savings_rate,
  income_delta_pct, expense_delta_pct,        // vs previous month
  by_category: [{category_id, name, amount_minor, pct}],
  currency
}
```

## Steps
1. Repository: aggregate the user's transactions for the target month and the previous month
   (user-scoped, summed in integer minor units). Income = sum of positive (kind=income),
   expense = sum of negative (kind=expense); transfers excluded from income/expense.
2. Service: compute net = income − expense; **savings_rate = (income − expense) / income**
   (guard divide-by-zero → 0 or null when no income); MoM deltas vs previous month; by-category
   expense breakdown with pct of total expense.
3. Localized category names resolved for display (system via i18n keys).
4. All math in integer minor units; never floats for money (percentages are derived ratios only).

## Acceptance
- Correct income/expense/net for the month; transfers excluded.
- Savings rate correct and safe when income is zero.
- MoM deltas correct (and sane when previous month is zero/absent).
- By-category breakdown sums to the expense total; pcts sum ~100%.
- User-scoped; single currency.

## Tests
- `test_dashboard.py`: known fixture set → exact income/expense/net/savings_rate; MoM delta math;
  divide-by-zero guard; by-category sums; transfers excluded; user-scoping.

## Commits
- `feat(dashboard): add monthly summary endpoint with savings rate and trend`
