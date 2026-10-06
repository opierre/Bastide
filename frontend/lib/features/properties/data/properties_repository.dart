import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_client_provider.dart';
import '../domain/property.dart';

/// Calls the `/properties` endpoints and maps the wire JSON to domain models.
/// The only place in this feature that knows the response shapes.
class PropertiesRepository {
  PropertiesRepository(this._apiClient);

  final ApiClient _apiClient;

  /// The live properties, or the archived ones when [archived] — the API never
  /// returns both in one list.
  Future<List<Property>> list({bool archived = false}) async {
    final json =
        await _apiClient.get(
              '/properties',
              query: {if (archived) 'archived': 'true'},
            )
            as List<dynamic>;
    return [
      for (final entry in json.cast<Map<String, dynamic>>()) _parse(entry),
    ];
  }

  Future<Property> create(PropertyDraft draft) async {
    final json =
        await _apiClient.post('/properties', body: _draftJson(draft))
            as Map<String, dynamic>;
    return _parse(json);
  }

  /// Patches every declared input. The acquisition fields are only sent when
  /// set: `null` is indistinguishable from absent on this API.
  Future<Property> update(String propertyId, PropertyDraft draft) async {
    final json =
        await _apiClient.patch(
              '/properties/$propertyId',
              body: _draftJson(draft),
            )
            as Map<String, dynamic>;
    return _parse(json);
  }

  /// « Nouvelle estimation »: a new declared value with its date, sent together.
  /// The property keeps one declared value (§4), so this replaces it.
  Future<Property> revalue(
    String propertyId, {
    required int marketValueMinor,
    required DateTime valuedOn,
  }) async {
    final json =
        await _apiClient.patch(
              '/properties/$propertyId',
              body: {
                'market_value_minor': marketValueMinor,
                'valued_on': _date(valuedOn),
              },
            )
            as Map<String, dynamic>;
    return _parse(json);
  }

  /// Archives the property — the API never hard-deletes one.
  Future<void> archive(String propertyId) =>
      _apiClient.delete('/properties/$propertyId');

  Future<Property> unarchive(String propertyId) async {
    final json =
        await _apiClient.patch(
              '/properties/$propertyId',
              body: {'archived': false},
            )
            as Map<String, dynamic>;
    return _parse(json);
  }

  Map<String, dynamic> _draftJson(PropertyDraft draft) => {
    'label': draft.label,
    'kind': draft.kind.wireValue,
    'market_value_minor': draft.marketValueMinor,
    'valued_on': _date(draft.valuedOn),
    'ownership_bps': draft.ownershipBps,
    'acquisition_price_minor': ?draft.acquisitionPriceMinor,
    if (draft.acquiredOn case final acquiredOn?)
      'acquired_on': _date(acquiredOn),
  };

  static String _date(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static DateTime? _optionalDate(Object? value) =>
      value == null ? null : DateTime.parse(value as String);

  Property _parse(Map<String, dynamic> json) => Property(
    id: json['id'] as String,
    label: json['label'] as String,
    kind: PropertyKind.fromWire(json['kind'] as String),
    marketValueMinor: json['market_value_minor'] as int,
    valuedOn: DateTime.parse(json['valued_on'] as String),
    ownershipBps: json['ownership_bps'] as int,
    acquisitionPriceMinor: json['acquisition_price_minor'] as int?,
    acquiredOn: _optionalDate(json['acquired_on']),
    archived: json['archived'] as bool,
    currency: json['currency'] as String,
    userShareValueMinor: json['user_share_value_minor'] as int,
    acquisitionDeltaMinor: json['acquisition_delta_minor'] as int?,
  );
}

final propertiesRepositoryProvider = Provider<PropertiesRepository>((ref) {
  return PropertiesRepository(ref.watch(apiClientProvider));
});
