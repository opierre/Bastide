import 'package:bastide/features/dashboard/domain/dashboard_summary.dart';
import 'package:bastide/features/dashboard/domain/dashboard_trends.dart';

/// The seven categories exactly as `docs/design/04-dashboard.md` tabulates them, in the spec's
/// descending order. The i18n keys are the ones `categorySlugFor` buckets into the pinned hues,
/// so a test asserting a legend color is asserting the real mapping.
const specCategories = [
  CategoryBreakdown(
    categoryId: 'c1',
    name: 'category.housing',
    amountMinor: 95000,
    pct: 42.9,
  ),
  CategoryBreakdown(
    categoryId: 'c2',
    name: 'category.food',
    amountMinor: 48620,
    pct: 22.0,
  ),
  CategoryBreakdown(
    categoryId: 'c3',
    name: 'category.other',
    amountMinor: 23655,
    pct: 10.7,
  ),
  CategoryBreakdown(
    categoryId: 'c4',
    name: 'category.transport',
    amountMinor: 21490,
    pct: 9.7,
  ),
  CategoryBreakdown(
    categoryId: 'c5',
    name: 'category.leisure',
    amountMinor: 18945,
    pct: 8.6,
  ),
  CategoryBreakdown(
    categoryId: 'c6',
    name: 'category.subscriptions',
    amountMinor: 7495,
    pct: 3.4,
  ),
  CategoryBreakdown(
    categoryId: 'c7',
    name: 'category.health',
    amountMinor: 6230,
    pct: 2.8,
  ),
];

/// May 2026's summary exactly as the spec's row 1 and row 2 draw it.
DashboardSummary specSummary({
  int incomeMinor = 285000,
  int expenseMinor = 221435,
  int netMinor = 63565,
  double savingsRate = 0.223,
  double incomeDeltaPct = 2.1,
  double expenseDeltaPct = 4.8,
  double netDeltaPct = -6.1,
  double savingsRateDeltaPct = 1.9,
  List<CategoryBreakdown> byCategory = specCategories,
}) => DashboardSummary(
  incomeMinor: incomeMinor,
  expenseMinor: expenseMinor,
  netMinor: netMinor,
  savingsRate: savingsRate,
  incomeDeltaPct: incomeDeltaPct,
  expenseDeltaPct: expenseDeltaPct,
  netDeltaPct: netDeltaPct,
  savingsRateDeltaPct: savingsRateDeltaPct,
  byCategory: byCategory,
  currency: 'EUR',
);

/// The trend series exactly as `docs/design/04-dashboard.md` draws them.
///
/// The two series are kept consistent with each other on purpose: the savings line's step into
/// May is May's net from the bars (`+635,65 €`), so a test that reads one against the other is
/// checking the app rather than the fixture. Février's net is negative, which is what puts the
/// one dip in an otherwise rising line.
DashboardTrends specTrends() => DashboardTrends(
  monthlySeries: [
    MonthlyTotals(
      month: DateTime(2026, 2),
      incomeMinor: 285000,
      expenseMinor: 296840,
      netMinor: -11840,
    ),
    MonthlyTotals(
      month: DateTime(2026, 3),
      incomeMinor: 285000,
      expenseMinor: 230980,
      netMinor: 54020,
    ),
    MonthlyTotals(
      month: DateTime(2026, 4),
      incomeMinor: 285000,
      expenseMinor: 211290,
      netMinor: 73710,
    ),
    MonthlyTotals(
      month: DateTime(2026, 5),
      incomeMinor: 285000,
      expenseMinor: 221435,
      netMinor: 63565,
    ),
  ],
  savingsSeries: [
    SavingsPoint(month: DateTime(2025, 6), savedMinor: 41200),
    SavingsPoint(month: DateTime(2025, 7), savedMinor: 18050),
    SavingsPoint(month: DateTime(2025, 8), savedMinor: -32500),
    SavingsPoint(month: DateTime(2025, 9), savedMinor: 55000),
    SavingsPoint(month: DateTime(2025, 10), savedMinor: 27310),
    SavingsPoint(month: DateTime(2025, 11), savedMinor: 30940),
    SavingsPoint(month: DateTime(2025, 12), savedMinor: 15000),
    SavingsPoint(month: DateTime(2026, 1), savedMinor: 24545),
    SavingsPoint(month: DateTime(2026, 2), savedMinor: -11840),
    SavingsPoint(month: DateTime(2026, 3), savedMinor: 54020),
    SavingsPoint(month: DateTime(2026, 4), savedMinor: 73710),
    SavingsPoint(month: DateTime(2026, 5), savedMinor: 63565),
  ],
  currency: 'EUR',
);

/// The four activity rows exactly as `docs/design/04-dashboard.md` tabulates them.
List<RecentTransaction> specRecent() => [
  RecentTransaction(
    id: 't1',
    label: 'Carrefour',
    accountLabel: 'BNP — Compte courant',
    bookedDate: DateTime(2026, 5, 14),
    amountMinor: -8642,
    currency: 'EUR',
  ),
  RecentTransaction(
    id: 't2',
    label: 'Novatech SARL',
    accountLabel: 'BNP — Compte courant',
    bookedDate: DateTime(2026, 5, 2),
    amountMinor: 285000,
    currency: 'EUR',
  ),
  RecentTransaction(
    id: 't3',
    label: 'SNCF Connect',
    accountLabel: 'Revolut',
    bookedDate: DateTime(2026, 5, 11),
    amountMinor: -4700,
    currency: 'EUR',
  ),
  RecentTransaction(
    id: 't4',
    label: 'Free Mobile',
    accountLabel: 'BNP — Compte courant',
    bookedDate: DateTime(2026, 5, 9),
    amountMinor: -1599,
    currency: 'EUR',
  ),
];

/// A user with no history at all — every series empty.
DashboardTrends emptyTrends() => const DashboardTrends(
  monthlySeries: [],
  savingsSeries: [],
  currency: 'EUR',
);
