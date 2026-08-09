# P1-15 — Dashboard frontend
Scope: frontend
Depends on: P1-13, P1-14
Skills: flutter-frontend, design-system, i18n-l10n, testing
PROJECT.md: §5, §9

## Objective
The main dashboard: month selector, headline stat cards (income, expense, net, savings rate)
with month-over-month trend indicators, and a by-category expense breakdown chart — encouraging
and locale-aware. This completes Phase 1.

## Files
- `frontend/lib/features/dashboard/presentation/{dashboard_screen,stat_card,category_breakdown.dart}`
- `frontend/lib/features/dashboard/application/dashboard_controller.dart`
- `frontend/lib/features/dashboard/data/dashboard_repository.dart`
- `frontend/lib/features/dashboard/domain/dashboard_summary.dart`
- Reusable chart container in `core/widgets/`; ARB keys (fr+en); tests.

## Steps
1. Repository + controller: fetch `dashboard/summary` for the selected month.
2. Month selector in the panel header; default to the latest month with data.
3. Stat cards (reusable): income, expense, net, **savings rate** as a first-class metric; each
   shows the MoM trend delta with direction + semantic color (up-income good, up-expense bad).
4. By-category breakdown: a chart (donut/bar) of expense by category with localized names + the
   shared category colors; legend with amounts (locale-formatted).
5. Encouraging empty state when no data yet ("import a statement to see your money come to life",
   CTA to Imports). Positive framing per design-system.
6. Loading skeletons + error/retry; ARB parity; analyze clean.

## Acceptance
- Dashboard shows correct figures for the selected month, formatted per locale/currency.
- Savings rate is prominent; trend arrows/colors correct (expense increase is not shown as
  "good").
- Category breakdown matches backend totals; colors consistent with the rest of the app.
- Encouraging empty state when there's no data; consistent chrome; fr + en.

## Tests
- Controller test (mocked repo): load/month-change/error transitions.
- Widget test: stat cards render formatted values + correct trend semantics for fr + en; chart
  renders from summary; empty state renders with CTA.

## Commits
- `feat(dashboard): add dashboard repository and controller`
- `feat(dashboard): add summary stat cards with savings rate and trend`
- `feat(dashboard): add by-category expense breakdown and empty state`
