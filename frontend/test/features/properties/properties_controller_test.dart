import 'package:finstride/core/api/api_client.dart';
import 'package:finstride/core/api/api_client_provider.dart';
import 'package:finstride/features/properties/application/properties_controller.dart';
import 'package:finstride/features/properties/domain/property.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

Map<String, dynamic> _propertyJson({
  String id = 'p2',
  String label = 'Studio Villeurbanne',
  String kind = 'rental',
  int ownershipBps = 5000,
  bool archived = false,
  int? acquisitionPriceMinor = 13200000,
  String? acquiredOn = '2021-06-14',
  int? acquisitionDeltaMinor = 650000,
}) => {
  'id': id,
  'label': label,
  'kind': kind,
  'market_value_minor': 14500000,
  'valued_on': '2026-03-05',
  'ownership_bps': ownershipBps,
  'acquisition_price_minor': acquisitionPriceMinor,
  'acquired_on': acquiredOn,
  'archived': archived,
  'currency': 'EUR',
  'user_share_value_minor': 7250000,
  'acquisition_delta_minor': acquisitionDeltaMinor,
  'created_at': '2026-03-05T00:00:00',
  'updated_at': '2026-03-05T00:00:00',
};

PropertyDraft _studioDraft({
  int? acquisitionPriceMinor,
  DateTime? acquiredOn,
}) => PropertyDraft(
  label: 'Studio Villeurbanne',
  kind: PropertyKind.rental,
  marketValueMinor: 14500000,
  valuedOn: DateTime(2026, 3, 5),
  ownershipBps: 5000,
  acquisitionPriceMinor: acquisitionPriceMinor,
  acquiredOn: acquiredOn,
);

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
  });

  /// Serves the live and the archived list from two mutable lists, so a write
  /// can move a property between them the way the server would.
  void stubLists({
    required List<Map<String, dynamic>> live,
    List<Map<String, dynamic>> archived = const [],
  }) {
    when(
      () => apiClient.get('/properties', query: any(named: 'query')),
    ).thenAnswer((invocation) async {
      final query = invocation.namedArguments[#query] as Map<String, String>?;
      return query?['archived'] == 'true' ? archived : live;
    });
  }

  PropertiesController notifier() =>
      container.read(propertiesControllerProvider.notifier);

  test('build maps the live and the archived properties', () async {
    stubLists(
      live: [_propertyJson()],
      archived: [_propertyJson(id: 'p9', label: 'Terrain', kind: 'other')],
    );

    final state = await container.read(propertiesControllerProvider.future);

    final studio = state.properties.single;
    expect(studio.kind, PropertyKind.rental);
    expect(studio.marketValueMinor, 14500000);
    expect(studio.valuedOn, DateTime(2026, 3, 5));
    expect(studio.ownershipBps, 5000);
    expect(studio.isPartlyOwned, isTrue);
    expect(studio.userShareValueMinor, 7250000);
    expect(studio.acquisitionDeltaMinor, 650000);
    expect(studio.acquiredOn, DateTime(2021, 6, 14));
    expect(state.archived.single.kind, PropertyKind.other);
    verify(() => apiClient.get('/properties', query: const {})).called(1);
    verify(
      () => apiClient.get('/properties', query: {'archived': 'true'}),
    ).called(1);
  });

  test('a property without a price maps its delta to null', () async {
    stubLists(
      live: [
        _propertyJson(
          acquisitionPriceMinor: null,
          acquiredOn: null,
          acquisitionDeltaMinor: null,
        ),
      ],
    );

    final property = (await container.read(
      propertiesControllerProvider.future,
    )).properties.single;

    expect(property.acquisitionPriceMinor, isNull);
    expect(property.acquiredOn, isNull);
    expect(property.acquisitionDeltaMinor, isNull);
  });

  test('create posts the declared inputs in bps and reloads', () async {
    final live = <Map<String, dynamic>>[];
    stubLists(live: live);
    when(
      () => apiClient.post('/properties', body: any(named: 'body')),
    ).thenAnswer((_) async {
      live.add(_propertyJson());
      return _propertyJson();
    });
    await container.read(propertiesControllerProvider.future);

    await notifier().create(
      _studioDraft(
        acquisitionPriceMinor: 13200000,
        acquiredOn: DateTime(2021, 6, 14),
      ),
    );

    final body =
        verify(
              () => apiClient.post(
                '/properties',
                body: captureAny(named: 'body'),
              ),
            ).captured.single
            as Map<String, dynamic>;
    expect(body, {
      'label': 'Studio Villeurbanne',
      'kind': 'rental',
      'market_value_minor': 14500000,
      'valued_on': '2026-03-05',
      'ownership_bps': 5000,
      'acquisition_price_minor': 13200000,
      'acquired_on': '2021-06-14',
    });
    expect(
      container.read(propertiesControllerProvider).value!.properties,
      hasLength(1),
    );
  });

  test('update leaves an unset acquisition out of the patch', () async {
    stubLists(live: [_propertyJson()]);
    when(
      () => apiClient.patch('/properties/p2', body: any(named: 'body')),
    ).thenAnswer((_) async => _propertyJson());
    await container.read(propertiesControllerProvider.future);

    await notifier().updateProperty('p2', _studioDraft());

    final body =
        verify(
              () => apiClient.patch(
                '/properties/p2',
                body: captureAny(named: 'body'),
              ),
            ).captured.single
            as Map<String, dynamic>;
    expect(body.containsKey('acquisition_price_minor'), isFalse);
    expect(body.containsKey('acquired_on'), isFalse);
    expect(body['ownership_bps'], 5000);
  });

  test('a refused create is rethrown for the form to show inline', () async {
    stubLists(live: const []);
    when(
      () => apiClient.post('/properties', body: any(named: 'body')),
    ).thenThrow(
      const ApiFailure(code: 'PROPERTY_VALUATION_IN_FUTURE', message: 'no'),
    );
    await container.read(propertiesControllerProvider.future);

    await expectLater(
      notifier().create(_studioDraft()),
      throwsA(isA<ApiFailure>()),
    );
    expect(container.read(propertiesControllerProvider).hasValue, isTrue);
  });

  test('a new valuation patches the value and its date together', () async {
    stubLists(live: [_propertyJson()]);
    when(
      () => apiClient.patch('/properties/p2', body: any(named: 'body')),
    ).thenAnswer((_) async => _propertyJson());
    await container.read(propertiesControllerProvider.future);

    await notifier().revalue(
      'p2',
      marketValueMinor: 15000000,
      valuedOn: DateTime(2026, 5, 2),
    );

    verify(
      () => apiClient.patch(
        '/properties/p2',
        body: {'market_value_minor': 15000000, 'valued_on': '2026-05-02'},
      ),
    ).called(1);
  });

  test(
    'archive deletes and the reload moves the property to archived',
    () async {
      final live = [_propertyJson()];
      final archived = <Map<String, dynamic>>[];
      stubLists(live: live, archived: archived);
      when(() => apiClient.delete('/properties/p2')).thenAnswer((_) async {
        archived.add(_propertyJson(archived: true));
        live.clear();
        return null;
      });
      await container.read(propertiesControllerProvider.future);

      await notifier().archive('p2');

      final state = container.read(propertiesControllerProvider).value!;
      expect(state.properties, isEmpty);
      expect(state.archived.single.id, 'p2');
      expect(state.actionError, isNull);
    },
  );

  test('unarchive patches archived back to false', () async {
    stubLists(live: const [], archived: [_propertyJson(archived: true)]);
    when(
      () => apiClient.patch('/properties/p2', body: any(named: 'body')),
    ).thenAnswer((_) async => _propertyJson());
    await container.read(propertiesControllerProvider.future);

    await notifier().unarchive('p2');

    verify(
      () => apiClient.patch('/properties/p2', body: {'archived': false}),
    ).called(1);
  });

  test(
    'a refused archive is kept as an action error, the list stays',
    () async {
      stubLists(live: [_propertyJson()]);
      when(() => apiClient.delete('/properties/p2')).thenThrow(
        const ApiFailure(code: 'PROPERTY_NOT_FOUND', message: 'gone'),
      );
      await container.read(propertiesControllerProvider.future);

      await notifier().archive('p2');

      final state = container.read(propertiesControllerProvider).value!;
      expect((state.actionError! as ApiFailure).code, 'PROPERTY_NOT_FOUND');
      expect(state.properties, hasLength(1));
    },
  );

  test(
    'the archived link only opens when there is something to show',
    () async {
      stubLists(live: const [], archived: [_propertyJson(archived: true)]);
      await container.read(propertiesControllerProvider.future);

      notifier().toggleArchived();
      expect(
        container.read(propertiesControllerProvider).value!.showArchived,
        isTrue,
      );
      notifier().toggleArchived();
      expect(
        container.read(propertiesControllerProvider).value!.showArchived,
        isFalse,
      );
    },
  );

  test('the held-share preview rounds half up like the server', () {
    expect(previewHeldShareMinor(14500000, 5000), 7250000);
    expect(previewHeldShareMinor(1, 5000), 1);
    expect(previewHeldShareMinor(3, 3333), 1);
    expect(previewHeldShareMinor(42000000, 10000), 42000000);
  });
}
