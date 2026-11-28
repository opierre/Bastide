import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_client_provider.dart';
import '../domain/dashboard_habits.dart';
import '../domain/dashboard_summary.dart';
import '../domain/dashboard_trends.dart';
import '../domain/upcoming_charges.dart';
import '../../../core/logos/logo_ref.dart';

final _monthParam = DateFormat('yyyy-MM');

/// Calls the `/dashboard/*`, `/recurring/upcoming` and `/transactions` endpoints and maps the
/// wire JSON to domain models. `/transactions` is read directly (rather than through the
/// transactions feature) to find the latest month with data — the same pattern the transactions repository itself uses to
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

  /// The savings series behind « Épargne mensuelle »: the 12 months ending with [month].
  ///
  /// [currentMonth] is the calendar month at the time of the call; the result carries it so
  /// the chart can hatch the month in progress when the window includes it.
  Future<DashboardTrends> trends(
    DateTime month, {
    required DateTime currentMonth,
  }) async {
    final json =
        await _apiClient.get(
              '/dashboard/trends',
              query: {'month': _monthParam.format(month)},
            )
            as Map<String, dynamic>;
    return DashboardTrends(
      savingsSeries: (json['savings_series'] as List<dynamic>)
          .map((entry) => _parseSavingsPoint(entry as Map<String, dynamic>))
          .toList(),
      currency: json['currency'] as String,
      currentMonth: DateTime(currentMonth.year, currentMonth.month),
    );
  }

  /// « Par rapport à vos habitudes » for [month]: each category's spending
  /// against its average over the months before it.
  ///
  /// [today] is the calendar date at the time of the call: when [month] is the
  /// month in progress, the result carries how many of its days have passed.
  Future<DashboardHabits> habits(
    DateTime month, {
    required DateTime today,
  }) async {
    final json =
        await _apiClient.get(
              '/dashboard/habits',
              query: {'month': _monthParam.format(month)},
            )
            as Map<String, dynamic>;
    final parsedMonth = _parseMonth(json['month'] as String);
    final inProgress =
        parsedMonth.year == today.year && parsedMonth.month == today.month;
    return DashboardHabits(
      month: parsedMonth,
      daysElapsed: inProgress ? today.day : null,
      monthsCounted: json['months_counted'] as int,
      rows: (json['rows'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(
            (row) => CategoryHabit(
              categoryId: row['category_id'] as String?,
              name: row['name'] as String,
              hue: row['hue'] as String,
              amountMinor: row['amount_minor'] as int,
              averageMinor: row['average_minor'] as int?,
              gapMinor: row['gap_minor'] as int?,
            ),
          )
          .toList(),
      totalGapMinor: json['total_gap_minor'] as int?,
      currency: json['currency'] as String,
    );
  }

  /// The recurring charges still due before the end of the current month, and
  /// the missed ones, for « À venir ». Reads `/recurring/upcoming` directly
  /// rather than through the recurring feature, as [latestMonthWithData] reads
  /// `/transactions`. The server picks the month from its own clock: the block
  /// never follows the month selector.
  Future<UpcomingCharges> upcoming() async {
    final json =
        await _apiClient.get('/recurring/upcoming') as Map<String, dynamic>;
    return UpcomingCharges(
      through: DateTime.parse(json['through'] as String),
      totalMinor: json['total_minor'] as int,
      due: [
        for (final entry
            in (json['charges'] as List<dynamic>).cast<Map<String, dynamic>>())
          UpcomingDue(
            seriesId: entry['series_id'] as String,
            label: entry['label'] as String,
            amountMinor: entry['amount_minor'] as int,
            logo: LogoRef.fromJson(entry),
            dueOn: DateTime.parse(entry['due_on'] as String),
            priceIncreaseMinor: entry['price_increase_minor'] as int?,
          ),
      ],
      missed: [
        for (final entry
            in (json['missed'] as List<dynamic>).cast<Map<String, dynamic>>())
          UpcomingMissed(
            seriesId: entry['series_id'] as String,
            label: entry['label'] as String,
            amountMinor: entry['amount_minor'] as int,
            logo: LogoRef.fromJson(entry),
            expectedOn: DateTime.parse(entry['expected_on'] as String),
          ),
      ],
      currency: json['currency'] as String,
    );
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
    // A whole percent on the wire, a ratio like `savings_rate` in the domain.
    savingsRateGoal: (json['savings_rate_goal_percent'] as int) / 100,
    byCategory: (json['by_category'] as List<dynamic>)
        .map((entry) => _parseCategory(entry as Map<String, dynamic>))
        .toList(),
    currency: json['currency'] as String,
  );

  SavingsPoint _parseSavingsPoint(Map<String, dynamic> json) => SavingsPoint(
    month: _parseMonth(json['month'] as String),
    savedMinor: json['saved_minor'] as int,
  );

  /// `YYYY-MM` → the first of that month. `DateTime.parse` needs a day component, and the wire
  /// deliberately carries none — these are months, not dates.
  DateTime _parseMonth(String value) => _monthParam.parse(value);

  CategoryBreakdown _parseCategory(Map<String, dynamic> json) =>
      CategoryBreakdown(
        categoryId: json['category_id'] as String?,
        name: json['name'] as String,
        hue: json['hue'] as String,
        amountMinor: json['amount_minor'] as int,
        pct: (json['pct'] as num).toDouble(),
      );
}

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(ref.watch(apiClientProvider));
});
