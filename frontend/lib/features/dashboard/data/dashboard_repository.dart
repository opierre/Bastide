import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_client_provider.dart';
import '../domain/dashboard_summary.dart';
import '../domain/dashboard_trends.dart';

final _monthParam = DateFormat('yyyy-MM');

/// Calls the `/dashboard/summary` and `/transactions` endpoints and maps the wire JSON to domain
/// models. `/transactions` is read directly (rather than through the transactions feature) to
/// find the latest month with data — the same pattern the transactions repository itself uses to
/// call `/categories` and `/rules` — since a feature owns everything it needs rather than
/// reaching into another feature's Dart internals (see the architecture skill).
class DashboardRepository {
  DashboardRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<DashboardSummary> summary(DateTime month) async {
    final json =
        await _apiClient.get(
              '/dashboard/summary',
              query: {'month': _monthParam.format(month)},
            )
            as Map<String, dynamic>;
    return _parse(json);
  }

  /// The two trend series behind row 2's savings line and row 3's bars.
  ///
  /// Takes no month: both windows end at the current one, so this is fetched once and survives
  /// the month picker (see `PROJECT.md` §5).
  Future<DashboardTrends> trends() async {
    final json =
        await _apiClient.get('/dashboard/trends') as Map<String, dynamic>;
    return DashboardTrends(
      monthlySeries: (json['monthly_series'] as List<dynamic>)
          .map((entry) => _parseMonthlyTotals(entry as Map<String, dynamic>))
          .toList(),
      savingsSeries: (json['savings_series'] as List<dynamic>)
          .map((entry) => _parseSavingsPoint(entry as Map<String, dynamic>))
          .toList(),
      currency: json['currency'] as String,
    );
  }

  /// The newest [limit] transactions, with their account names already resolved.
  ///
  /// Reads `/transactions` and `/accounts` directly rather than through those features' Dart
  /// internals — a feature owns everything it needs (see the architecture skill), the same way
  /// the transactions repository calls `/categories` itself.
  /// The default is a ceiling, not a target: « Activité récente » draws as many of these as fit
  /// in the height row 3 gives it, so the list is fetched deep enough to fill a tall window
  /// rather than to the four rows the spec's own frame happens to show.
  Future<List<RecentTransaction>> recentTransactions({int limit = 8}) async {
    final (page, accounts) = await (
      _apiClient.get('/transactions', query: {'page': '1'}),
      _apiClient.get('/accounts'),
    ).wait;

    final names = {
      for (final entry
          in (accounts as List<dynamic>).cast<Map<String, dynamic>>())
        entry['id'] as String: _accountLabel(entry),
    };

    return [
      for (final entry
          in ((page as Map<String, dynamic>)['items'] as List<dynamic>)
              .cast<Map<String, dynamic>>()
              .take(limit))
        RecentTransaction(
          id: entry['id'] as String,
          label: _transactionLabel(entry),
          accountLabel: names[entry['account_id'] as String] ?? '',
          bookedDate: DateTime.parse(entry['booked_date'] as String),
          amountMinor: entry['amount_minor'] as int,
          currency: entry['currency'] as String,
        ),
    ];
  }

  /// « BNP — Compte courant ». The em dash matches the spec's activity rows; an account with
  /// no institution recorded falls back to its name alone rather than a dangling dash.
  String _accountLabel(Map<String, dynamic> json) {
    final institution = (json['institution'] as String?)?.trim() ?? '';
    final name = json['name'] as String;
    return institution.isEmpty ? name : '$institution — $name';
  }

  /// The merchant when the import recognised one, else the cleaned description.
  String _transactionLabel(Map<String, dynamic> json) {
    final merchant = (json['merchant'] as String?)?.trim() ?? '';
    return merchant.isEmpty ? json['description_clean'] as String : merchant;
  }

  /// The first-of-month for the most recent transaction, or `null` if the user has none yet —
  /// used to default the month selector to where the user's data actually is, rather than the
  /// calendar's current month (which may have no imports).
  Future<DateTime?> latestMonthWithData() async {
    final json =
        await _apiClient.get('/transactions', query: {'page': '1'})
            as Map<String, dynamic>;
    final items = json['items'] as List<dynamic>;
    if (items.isEmpty) return null;
    final latest = DateTime.parse(
      (items.first as Map<String, dynamic>)['booked_date'] as String,
    );
    return DateTime(latest.year, latest.month);
  }

  DashboardSummary _parse(Map<String, dynamic> json) => DashboardSummary(
    incomeMinor: json['income_minor'] as int,
    expenseMinor: json['expense_minor'] as int,
    netMinor: json['net_minor'] as int,
    savingsRate: (json['savings_rate'] as num).toDouble(),
    incomeDeltaPct: (json['income_delta_pct'] as num).toDouble(),
    expenseDeltaPct: (json['expense_delta_pct'] as num).toDouble(),
    netDeltaPct: (json['net_delta_pct'] as num).toDouble(),
    savingsRateDeltaPct: (json['savings_rate_delta_pct'] as num).toDouble(),
    byCategory: (json['by_category'] as List<dynamic>)
        .map((entry) => _parseCategory(entry as Map<String, dynamic>))
        .toList(),
    currency: json['currency'] as String,
  );

  MonthlyTotals _parseMonthlyTotals(Map<String, dynamic> json) => MonthlyTotals(
    month: _parseMonth(json['month'] as String),
    incomeMinor: json['income_minor'] as int,
    expenseMinor: json['expense_minor'] as int,
    netMinor: json['net_minor'] as int,
  );

  SavingsPoint _parseSavingsPoint(Map<String, dynamic> json) => SavingsPoint(
    month: _parseMonth(json['month'] as String),
    cumulativeMinor: json['cumulative_minor'] as int,
  );

  /// `YYYY-MM` → the first of that month. `DateTime.parse` needs a day component, and the wire
  /// deliberately carries none — these are months, not dates.
  DateTime _parseMonth(String value) => _monthParam.parse(value);

  CategoryBreakdown _parseCategory(Map<String, dynamic> json) =>
      CategoryBreakdown(
        categoryId: json['category_id'] as String?,
        name: json['name'] as String,
        amountMinor: json['amount_minor'] as int,
        pct: (json['pct'] as num).toDouble(),
      );
}

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(ref.watch(apiClientProvider));
});
