import 'package:bastide/core/api/api_client.dart';
import 'package:bastide/core/api/api_client_provider.dart';
import 'package:bastide/features/networth/application/networth_controller.dart';
import 'package:bastide/features/networth/domain/networth_summary.dart';
import 'package:bastide/features/properties/application/properties_controller.dart';
import 'package:bastide/features/properties/domain/property.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

Map<String, dynamic> _summaryJson({
  int propertiesMinor = 49250000,
  int netWorthMinor = 28267079,
  bool heldFlat = true,
}) => {
  'assets': {'accounts_minor': 2430000, 'properties_minor': propertiesMinor},
  'liabilities': {'mortgages_minor': 23412921},
  'net_worth_minor': netWorthMinor,
  'composition': [
    {
      'group': 'account',
      'key': 'checking',
      'amount_minor': 1180000,
      'share_bps': 230,
    },
    {
      'group': 'property',
      'key': 'rental',
      'amount_minor': 7250000,
      'share_bps': 1400,
    },
  ],
  'month_delta_minor': -147778,
  'series': [
    {'month': '2026-02', 'net_worth_minor': 28000000},
    // March is absent: no snapshot that month.
    {'month': '2026-04', 'net_worth_minor': 28267079},
  ],
  'property_values_held_flat': heldFlat,
  'valued_on_oldest': heldFlat ? '2026-01-12' : null,
  'currency': 'EUR',
};

Map<String, dynamic> _propertyJson() => {
  'id': 'p2',
  'label': 'Studio Villeurbanne',
  'kind': 'rental',
  'market_value_minor': 14500000,
  'valued_on': '2026-03-05',
  'ownership_bps': 5000,
  'acquisition_price_minor': null,
  'acquired_on': null,
  'archived': false,
  'currency': 'EUR',
  'user_share_value_minor': 7250000,
  'acquisition_delta_minor': null,
  'created_at': '2026-03-05T00:00:00',
  'updated_at': '2026-03-05T00:00:00',
};

void main() {
  late MockApiClient apiClient;
  late ProviderContainer container;

  setUpAll(() => registerFallbackValue(<String, dynamic>{}));

  setUp(() {
    apiClient = MockApiClient();
    container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(apiClient)],
    );
    addTearDown(container.dispose);
    when(
      () => apiClient.get('/mortgages/summary'),
    ).thenAnswer((_) async => {'active_count': 2});
  });

  test('maps the summary exactly as returned', () async {
    when(
      () => apiClient.get('/networth/summary'),
    ).thenAnswer((_) async => _summaryJson());

    final summary = await container.read(networthControllerProvider.future);

    expect(summary.accountsMinor, 2430000);
    expect(summary.propertiesMinor, 49250000);
    expect(summary.assetsMinor, 51680000);
    expect(summary.mortgagesMinor, 23412921);
    expect(summary.netWorthMinor, 28267079);
    expect(summary.monthDeltaMinor, -147778);
    expect(summary.composition.last.group, CompositionGroup.property);
    expect(summary.composition.last.shareBps, 1400);
    expect(summary.propertyValuesHeldFlat, isTrue);
    expect(summary.valuedOnOldest, DateTime(2026, 1, 12));
    expect(summary.activeLoanCount, 2);
    expect(summary.isEmpty, isFalse);
    // A month the API omitted stays omitted.
    expect(summary.series.map((point) => point.month), [
      DateTime(2026, 2),
      DateTime(2026, 4),
    ]);
  });

  test('a user with nothing maps to an empty summary, not an error', () async {
    when(
      () => apiClient.get('/mortgages/summary'),
    ).thenAnswer((_) async => {'active_count': 0});
    when(() => apiClient.get('/networth/summary')).thenAnswer(
      (_) async => {
        'assets': {'accounts_minor': 0, 'properties_minor': 0},
        'liabilities': {'mortgages_minor': 0},
        'net_worth_minor': 0,
        'composition': <Map<String, dynamic>>[],
        'month_delta_minor': null,
        'series': <Map<String, dynamic>>[],
        'property_values_held_flat': false,
        'valued_on_oldest': null,
        'currency': 'EUR',
      },
    );

    final summary = await container.read(networthControllerProvider.future);

    expect(summary.isEmpty, isTrue);
    expect(summary.monthDeltaMinor, isNull);
    expect(summary.valuedOnOldest, isNull);
  });

  group('a property write invalidates the summary', () {
    late bool archived;

    setUp(() {
      archived = false;
      when(() => apiClient.get('/networth/summary')).thenAnswer(
        (_) async => archived
            ? _summaryJson(propertiesMinor: 42000000, netWorthMinor: 21017079)
            : _summaryJson(),
      );
      when(
        () => apiClient.get('/properties', query: any(named: 'query')),
      ).thenAnswer((invocation) async {
        final query = invocation.namedArguments[#query] as Map<String, String>?;
        final wantsArchived = query?['archived'] == 'true';
        return wantsArchived == archived ? [_propertyJson()] : const [];
      });
    });

    test('archiving re-reads net worth in the same interaction', () async {
      when(() => apiClient.delete('/properties/p2')).thenAnswer((_) async {
        archived = true;
        return null;
      });
      final before = await container.read(networthControllerProvider.future);
      await container.read(propertiesControllerProvider.future);

      await container.read(propertiesControllerProvider.notifier).archive('p2');
      final after = await container.read(networthControllerProvider.future);

      expect(before.propertiesMinor, 49250000);
      expect(after.propertiesMinor, 42000000);
      expect(after.netWorthMinor, 21017079);
      verify(() => apiClient.get('/networth/summary')).called(2);
    });

    test('declaring a property re-reads net worth too', () async {
      when(
        () => apiClient.post('/properties', body: any(named: 'body')),
      ).thenAnswer((_) async => _propertyJson());
      await container.read(networthControllerProvider.future);
      await container.read(propertiesControllerProvider.future);

      await container
          .read(propertiesControllerProvider.notifier)
          .create(
            PropertyDraft(
              label: 'Studio Villeurbanne',
              kind: PropertyKind.rental,
              marketValueMinor: 14500000,
              valuedOn: DateTime(2026, 3, 5),
              ownershipBps: 5000,
            ),
          );
      await container.read(networthControllerProvider.future);

      verify(() => apiClient.get('/networth/summary')).called(2);
    });
  });
}
