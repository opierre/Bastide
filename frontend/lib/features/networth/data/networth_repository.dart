import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_client_provider.dart';
import '../domain/networth_summary.dart';

/// Calls `/networth/summary` and the declared-total endpoints, and maps the
/// wire JSON to the domain models.
///
/// It also reads `/mortgages/summary` for one figure the net-worth response
/// doesn't carry — the active loan count the Passif card names — the same
/// arrangement the mortgages repository uses for `/properties`.
class NetworthRepository {
  NetworthRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<NetWorthSummary> summary() async {
    final json =
        await _apiClient.get('/networth/summary') as Map<String, dynamic>;
    final loans =
        await _apiClient.get('/mortgages/summary') as Map<String, dynamic>;

    final assets = json['assets'] as Map<String, dynamic>;
    final liabilities = json['liabilities'] as Map<String, dynamic>;
    final valuedOnOldest = json['valued_on_oldest'] as String?;

    return NetWorthSummary(
      accountsMinor: assets['accounts_minor'] as int,
      propertiesMinor: assets['properties_minor'] as int,
      mortgagesMinor: liabilities['mortgages_minor'] as int,
      netWorthMinor: json['net_worth_minor'] as int,
      composition: [
        for (final entry
            in (json['composition'] as List<dynamic>)
                .cast<Map<String, dynamic>>())
          CompositionEntry(
            group: CompositionGroup.fromWire(entry['group'] as String),
            key: entry['key'] as String,
            amountMinor: entry['amount_minor'] as int,
            shareBps: entry['share_bps'] as int,
          ),
      ],
      monthDeltaMinor: json['month_delta_minor'] as int?,
      series: [
        for (final point
            in (json['series'] as List<dynamic>).cast<Map<String, dynamic>>())
          NetWorthPoint(
            month: _month(point['month'] as String),
            netWorthMinor: point['net_worth_minor'] as int,
            declared: point['source'] == 'declared',
          ),
      ],
      propertyValuesHeldFlat: json['property_values_held_flat'] as bool,
      valuedOnOldest: valuedOnOldest == null
          ? null
          : DateTime.parse(valuedOnOldest),
      activeLoanCount: loans['active_count'] as int,
      currency: json['currency'] as String,
    );
  }

  /// The month-end totals the user declared, oldest first.
  Future<List<DeclaredBalance>> declared() async {
    final json = await _apiClient.get('/networth/declared') as List<dynamic>;
    return [
      for (final entry in json.cast<Map<String, dynamic>>())
        _parseDeclared(entry),
    ];
  }

  /// Declares, or replaces, the total for [month] (its first day).
  Future<DeclaredBalance> declare(DateTime month, int amountMinor) async {
    final json =
        await _apiClient.put(
              '/networth/declared/${_monthKey(month)}',
              body: {'amount_minor': amountMinor},
            )
            as Map<String, dynamic>;
    return _parseDeclared(json);
  }

  Future<void> removeDeclared(DateTime month) async {
    await _apiClient.delete('/networth/declared/${_monthKey(month)}');
  }

  static DeclaredBalance _parseDeclared(Map<String, dynamic> json) =>
      DeclaredBalance(
        month: _month(json['month'] as String),
        amountMinor: json['amount_minor'] as int,
        currency: json['currency'] as String,
        superseded: json['superseded'] as bool,
      );

  static DateTime _month(String key) => DateTime.parse('$key-01');

  static String _monthKey(DateTime month) =>
      '${month.year.toString().padLeft(4, '0')}-'
      '${month.month.toString().padLeft(2, '0')}';
}

final networthRepositoryProvider = Provider<NetworthRepository>((ref) {
  return NetworthRepository(ref.watch(apiClientProvider));
});
