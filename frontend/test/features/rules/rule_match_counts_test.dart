import 'package:bastide/core/api/api_client.dart';
import 'package:bastide/core/api/api_client_provider.dart';
import 'package:bastide/features/rules/application/rule_match_counts.dart';
import 'package:bastide/features/rules/application/rules_controller.dart';
import 'package:bastide/features/rules/application/rules_filter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

Map<String, dynamic> _ruleJson(String id, int priority) => {
  'id': id,
  'priority': priority,
  'match_field': 'description_clean',
  'match_type': 'contains',
  'pattern': 'CAFE DU PORT',
  'category_id': 'food',
  'enabled': true,
  'created_at': '2026-01-01T00:00:00Z',
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
      () => apiClient.get('/rules'),
    ).thenAnswer((_) async => [_ruleJson('r1', 1), _ruleJson('r2', 4)]);
  });

  test('maps the counts by rule id', () async {
    when(() => apiClient.get('/rules/match-counts')).thenAnswer(
      (_) async => [
        {'rule_id': 'r1', 'match_count': 12},
        {'rule_id': 'r2', 'match_count': 0},
      ],
    );

    final subscription = container.listen(ruleMatchCountsProvider, (_, _) {});
    addTearDown(subscription.close);
    // The rules loading counts once more: the settled counts follow them.
    await container.read(rulesControllerProvider.future);
    final counts = await container.read(ruleMatchCountsProvider.future);

    expect(counts, {'r1': 12, 'r2': 0});
  });

  test('counts again when the rules change', () async {
    when(
      () => apiClient.get('/rules/match-counts'),
    ).thenAnswer((_) async => <dynamic>[]);
    final subscription = container.listen(ruleMatchCountsProvider, (_, _) {});
    addTearDown(subscription.close);
    await container.read(ruleMatchCountsProvider.future);
    await container.read(rulesControllerProvider.future);
    await container.read(ruleMatchCountsProvider.future);
    clearInteractions(apiClient);

    when(
      () => apiClient.patch('/rules/r1', body: any(named: 'body')),
    ).thenAnswer((_) async => {..._ruleJson('r1', 1), 'enabled': false});
    await container
        .read(rulesControllerProvider.notifier)
        .setEnabled('r1', false);
    await container.read(ruleMatchCountsProvider.future);

    verify(() => apiClient.get('/rules/match-counts')).called(1);
  });

  test('positions follow the order, not the stored priority', () async {
    await container.read(rulesControllerProvider.future);

    expect(container.read(rulePositionsProvider), {'r1': 1, 'r2': 2});
  });
}
