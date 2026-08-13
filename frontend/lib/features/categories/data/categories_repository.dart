import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_client_provider.dart';
import '../domain/category.dart';
import '../domain/category_spend.dart';

final _monthParam = DateFormat('yyyy-MM');

/// Calls `/categories` and maps the wire JSON to [AppCategory].
///
/// `PATCH` and `DELETE` are offered for every category, system ones included:
/// the API 404s a system category because it isn't user-owned, and that refusal
/// is the guarantee — the lock glyph in the UI only *states* it. A repository
/// that filtered those calls out client-side would hide whether the guarantee
/// exists at all.
class CategoriesRepository {
  CategoriesRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<AppCategory>> list() async {
    final json = await _apiClient.get('/categories') as List<dynamic>;
    return json
        .map((entry) => AppCategory.fromJson(entry as Map<String, dynamic>))
        .toList();
  }

  Future<AppCategory> create({
    required String name,
    required String kind,
    required String icon,
    required String color,
    String? parentId,
  }) async {
    final json = await _apiClient.post(
      '/categories',
      body: {
        'name': name,
        'kind': kind,
        'icon': icon,
        'color': color,
        'parent_id': parentId,
      },
    );
    return AppCategory.fromJson(json as Map<String, dynamic>);
  }

  Future<AppCategory> update(
    String id, {
    String? name,
    String? kind,
    String? icon,
    String? color,
    String? parentId,
    bool clearParent = false,
  }) async {
    final json = await _apiClient.patch(
      '/categories/$id',
      body: {
        'name': ?name,
        'kind': ?kind,
        'icon': ?icon,
        'color': ?color,
        if (clearParent) 'parent_id': null else 'parent_id': ?parentId,
      },
    );
    return AppCategory.fromJson(json as Map<String, dynamic>);
  }

  Future<void> delete(String id) => _apiClient.delete('/categories/$id');

  /// The expense split behind the spend-share bars, for the most recent month
  /// the user actually has data in.
  ///
  /// Reads `/dashboard/summary` and `/transactions` directly rather than through
  /// the dashboard feature's Dart internals — a feature owns everything it needs
  /// (see the architecture skill), the same way the dashboard repository calls
  /// `/transactions` and `/accounts` itself.
  ///
  /// The month is the latest one with transactions rather than the calendar's
  /// current month, for the same reason the dashboard's picker defaults there:
  /// a user who imports in arrears would otherwise open the panel onto a column
  /// of zeroes and read it as the bars being broken.
  Future<MonthlySpend> monthlySpend() async {
    final month = await latestMonthWithData() ?? _currentMonth();
    final json =
        await _apiClient.get('/dashboard/summary', query: {'month': _monthParam.format(month)})
            as Map<String, dynamic>;

    return MonthlySpend(
      month: month,
      currency: json['currency'] as String,
      totalMinor: json['expense_minor'] as int,
      byCategoryId: {
        for (final entry in (json['by_category'] as List<dynamic>).cast<Map<String, dynamic>>())
          // The uncategorized bucket comes back under a null id; it has no row
          // in the tree to sit on, so it is dropped rather than mapped to one.
          if (entry['category_id'] case final String id) id: entry['amount_minor'] as int,
      },
    );
  }

  /// The first-of-month for the user's most recent transaction, or `null` when
  /// they have none yet.
  Future<DateTime?> latestMonthWithData() async {
    final json =
        await _apiClient.get('/transactions', query: {'page': '1'}) as Map<String, dynamic>;
    final items = json['items'] as List<dynamic>;
    if (items.isEmpty) return null;
    final latest = DateTime.parse(
      (items.first as Map<String, dynamic>)['booked_date'] as String,
    );
    return DateTime(latest.year, latest.month);
  }

  DateTime _currentMonth() {
    final now = DateTime.now();
    return DateTime(now.year, now.month);
  }
}

final categoriesRepositoryProvider = Provider<CategoriesRepository>((ref) {
  return CategoriesRepository(ref.watch(apiClientProvider));
});
