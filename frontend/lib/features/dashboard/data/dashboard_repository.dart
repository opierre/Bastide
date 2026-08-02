import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_client_provider.dart';
import '../domain/dashboard_summary.dart';

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
        await _apiClient.get('/dashboard/summary', query: {'month': _monthParam.format(month)})
            as Map<String, dynamic>;
    return _parse(json);
  }

  /// The first-of-month for the most recent transaction, or `null` if the user has none yet —
  /// used to default the month selector to where the user's data actually is, rather than the
  /// calendar's current month (which may have no imports).
  Future<DateTime?> latestMonthWithData() async {
    final json = await _apiClient.get('/transactions', query: {'page': '1'}) as Map<String, dynamic>;
    final items = json['items'] as List<dynamic>;
    if (items.isEmpty) return null;
    final latest = DateTime.parse((items.first as Map<String, dynamic>)['booked_date'] as String);
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

  CategoryBreakdown _parseCategory(Map<String, dynamic> json) => CategoryBreakdown(
    categoryId: json['category_id'] as String?,
    name: json['name'] as String,
    amountMinor: json['amount_minor'] as int,
    pct: (json['pct'] as num).toDouble(),
  );
}

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(ref.watch(apiClientProvider));
});
