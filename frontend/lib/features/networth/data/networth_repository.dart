import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_client_provider.dart';
import '../domain/networth_summary.dart';

/// Calls `/networth/summary` and maps the wire JSON to the domain model.
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
            month: DateTime.parse('${point['month'] as String}-01'),
            netWorthMinor: point['net_worth_minor'] as int,
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
}

final networthRepositoryProvider = Provider<NetworthRepository>((ref) {
  return NetworthRepository(ref.watch(apiClientProvider));
});
