import 'package:finstride/core/api/api_client.dart';
import 'package:finstride/core/api/api_client_provider.dart';
import 'package:finstride/features/dashboard/application/dashboard_controller.dart';
import 'package:finstride/features/rules/application/rules_controller.dart';
import 'package:finstride/features/rules/domain/rule.dart';
import 'package:finstride/features/transactions/application/transactions_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

Map<String, dynamic> _ruleJson({
  String id = 'r1',
  int priority = 1,
  String matchField = 'merchant',
  String matchType = 'contains',
  String pattern = 'CARREFOUR',
  String categoryId = 'groceries',
  bool enabled = true,
}) => {
  'id': id,
  'priority': priority,
  'match_field': matchField,
  'match_type': matchType,
  'pattern': pattern,
  'category_id': categoryId,
  'enabled': enabled,
  'created_at': '2026-01-01T00:00:00Z',
};

/// Three rules at priorities 1, 2, 3.
List<Map<String, dynamic>> _threeRules() => [
  _ruleJson(id: 'r1', priority: 1, pattern: 'CARREFOUR'),
  _ruleJson(id: 'r2', priority: 2, pattern: 'SNCF'),
  _ruleJson(id: 'r3', priority: 3, pattern: 'AMAZON'),
];

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

  test('build loads the rules in priority order', () async {
    when(() => apiClient.get('/rules')).thenAnswer((_) async => _threeRules());

    final rules = await container.read(rulesControllerProvider.future);

    expect(rules.map((rule) => rule.id), ['r1', 'r2', 'r3']);
    expect(rules.first.matchField, RuleMatchField.merchant);
    expect(rules.first.matchType, RuleMatchType.contains);
  });

  test('create files the new rule last and appends it', () async {
    when(() => apiClient.get('/rules')).thenAnswer((_) async => _threeRules());
    when(() => apiClient.post('/rules', body: any(named: 'body'))).thenAnswer(
      (_) async => _ruleJson(id: 'r4', priority: 4, pattern: 'EDF'),
    );

    await container.read(rulesControllerProvider.future);
    await container
        .read(rulesControllerProvider.notifier)
        .create(
          matchField: RuleMatchField.merchant,
          matchType: RuleMatchType.contains,
          pattern: 'EDF',
          categoryId: 'utilities',
        );

    final body =
        verify(
              () => apiClient.post('/rules', body: captureAny(named: 'body')),
            ).captured.single
            as Map<String, dynamic>;
    expect(body['priority'], 4);
    expect(container.read(rulesControllerProvider).value!.map((rule) => rule.id), [
      'r1',
      'r2',
      'r3',
      'r4',
    ]);
  });

  test('updateRule replaces the rule and re-sorts on a priority change', () async {
    when(() => apiClient.get('/rules')).thenAnswer((_) async => _threeRules());
    when(() => apiClient.patch('/rules/r3', body: any(named: 'body'))).thenAnswer(
      (_) async => _ruleJson(id: 'r3', priority: 0, pattern: 'AMAZON'),
    );

    await container.read(rulesControllerProvider.future);
    await container.read(rulesControllerProvider.notifier).updateRule('r3', priority: 0);

    expect(container.read(rulesControllerProvider).value!.map((rule) => rule.id), [
      'r3',
      'r1',
      'r2',
    ]);
  });

  test('delete drops the rule', () async {
    when(() => apiClient.get('/rules')).thenAnswer((_) async => _threeRules());
    when(() => apiClient.delete('/rules/r2')).thenAnswer((_) async => null);

    await container.read(rulesControllerProvider.future);
    await container.read(rulesControllerProvider.notifier).delete('r2');

    expect(container.read(rulesControllerProvider).value!.map((rule) => rule.id), [
      'r1',
      'r3',
    ]);
  });

  test('reorder writes the expected priorities, patching only what moved', () async {
    when(() => apiClient.get('/rules')).thenAnswer((_) async => _threeRules());
    when(
      () => apiClient.patch(any(), body: any(named: 'body')),
    ).thenAnswer((invocation) async => _ruleJson());

    await container.read(rulesControllerProvider.future);
    // Drag the last rule to the front: 3, 1, 2.
    await container.read(rulesControllerProvider.notifier).reorder(2, 0);

    final rules = container.read(rulesControllerProvider).value!;
    expect(rules.map((rule) => rule.id), ['r3', 'r1', 'r2']);
    expect(rules.map((rule) => rule.priority), [1, 2, 3]);

    // All three moved, so all three are patched — and each carries its new
    // priority, not its old one.
    final patched = verify(
      () => apiClient.patch(captureAny(), body: captureAny(named: 'body')),
    ).captured;
    expect(patched, [
      '/rules/r3',
      {'priority': 1},
      '/rules/r1',
      {'priority': 2},
      '/rules/r2',
      {'priority': 3},
    ]);
  });

  test('reorder patches only the rules whose priority actually changed', () async {
    when(() => apiClient.get('/rules')).thenAnswer((_) async => _threeRules());
    when(
      () => apiClient.patch(any(), body: any(named: 'body')),
    ).thenAnswer((_) async => _ruleJson());

    await container.read(rulesControllerProvider.future);
    // Swap the last two: r1 keeps priority 1 and is left alone.
    await container.read(rulesControllerProvider.notifier).reorder(2, 1);

    final paths = verify(
      () => apiClient.patch(captureAny(), body: any(named: 'body')),
    ).captured;
    expect(paths, ['/rules/r3', '/rules/r2']);
  });

  test('a failed reorder restores the previous order and rethrows', () async {
    when(() => apiClient.get('/rules')).thenAnswer((_) async => _threeRules());
    when(
      () => apiClient.patch(any(), body: any(named: 'body')),
    ).thenThrow(const ApiFailure(code: 'RULE_NOT_FOUND', message: 'gone'));

    await container.read(rulesControllerProvider.future);

    await expectLater(
      () => container.read(rulesControllerProvider.notifier).reorder(2, 0),
      throwsA(isA<ApiFailure>()),
    );

    final rules = container.read(rulesControllerProvider).value!;
    expect(rules.map((rule) => rule.id), ['r1', 'r2', 'r3']);
    expect(rules.map((rule) => rule.priority), [1, 2, 3]);
  });

  test('setEnabled flips the rule optimistically', () async {
    when(() => apiClient.get('/rules')).thenAnswer((_) async => _threeRules());
    when(() => apiClient.patch('/rules/r3', body: any(named: 'body'))).thenAnswer(
      (_) async => _ruleJson(id: 'r3', priority: 3, enabled: false),
    );

    await container.read(rulesControllerProvider.future);
    final pending = container
        .read(rulesControllerProvider.notifier)
        .setEnabled('r3', false);

    // Already off before the patch resolves — that is what "optimistic" buys.
    expect(
      container.read(rulesControllerProvider).value!.last.enabled,
      isFalse,
    );
    await pending;
    expect(container.read(rulesControllerProvider).value!.last.enabled, isFalse);
  });

  test('a failed toggle puts the switch back and rethrows', () async {
    when(() => apiClient.get('/rules')).thenAnswer((_) async => _threeRules());
    when(
      () => apiClient.patch('/rules/r3', body: any(named: 'body')),
    ).thenThrow(const ApiFailure(code: 'RULE_NOT_FOUND', message: 'gone'));

    await container.read(rulesControllerProvider.future);

    await expectLater(
      () => container.read(rulesControllerProvider.notifier).setEnabled('r3', false),
      throwsA(isA<ApiFailure>()),
    );
    expect(container.read(rulesControllerProvider).value!.last.enabled, isTrue);
  });

  test('apply returns the recategorized count', () async {
    when(() => apiClient.get('/rules')).thenAnswer((_) async => <dynamic>[]);
    when(
      () => apiClient.post('/rules/apply', body: any(named: 'body')),
    ).thenAnswer((_) async => {'recategorized_count': 48});

    await container.read(rulesControllerProvider.future);

    expect(await container.read(rulesControllerProvider.notifier).apply(), 48);
  });

  group('apply reloads what it recategorized', () {
    setUp(() {
      when(() => apiClient.get('/rules')).thenAnswer((_) async => <dynamic>[]);
      when(
        () => apiClient.post('/rules/apply', body: any(named: 'body')),
      ).thenAnswer((_) async => {'recategorized_count': 48});
      when(
        () => apiClient.get('/transactions', query: any(named: 'query')),
      ).thenAnswer((_) async => _emptyPage());
      when(() => apiClient.get('/accounts')).thenAnswer((_) async => <dynamic>[]);
      when(
        () => apiClient.get('/dashboard/summary', query: any(named: 'query')),
      ).thenAnswer((_) async => _summaryJson());
      when(
        () => apiClient.get('/dashboard/trends'),
      ).thenAnswer((_) async => _trendsJson());
    });

    test('the transaction list is re-read, so the new categories show', () async {
      await container.read(transactionsControllerProvider.future);
      await container.read(rulesControllerProvider.future);
      // The load above is the only read so far; what follows is the refresh.
      verify(() => apiClient.get('/transactions', query: any(named: 'query'))).called(1);

      await container.read(rulesControllerProvider.notifier).apply();

      verify(() => apiClient.get('/transactions', query: any(named: 'query'))).called(1);
    });

    test('the dashboard is invalidated, so the répartition follows', () async {
      await container.read(dashboardControllerProvider.future);
      await container.read(rulesControllerProvider.future);

      await container.read(rulesControllerProvider.notifier).apply();
      await container.read(dashboardControllerProvider.future);

      // Twice: the first load, then the rebuild the invalidation forced. A
      // dashboard still showing the pre-run split is the bug this guards.
      verify(
        () => apiClient.get('/dashboard/summary', query: any(named: 'query')),
      ).called(2);
    });

    test('a run that moved nothing refreshes nothing', () async {
      when(
        () => apiClient.post('/rules/apply', body: any(named: 'body')),
      ).thenAnswer((_) async => {'recategorized_count': 0});

      await container.read(transactionsControllerProvider.future);
      await container.read(rulesControllerProvider.future);
      verify(() => apiClient.get('/transactions', query: any(named: 'query'))).called(1);

      await container.read(rulesControllerProvider.notifier).apply();

      verifyNever(() => apiClient.get('/transactions', query: any(named: 'query')));
    });
  });
}

Map<String, dynamic> _emptyPage() => {
  'items': <dynamic>[],
  'page': 1,
  'page_size': 50,
  'total': 0,
};

Map<String, dynamic> _summaryJson() => {
  'income_minor': 250000,
  'expense_minor': -180000,
  'net_minor': 70000,
  'savings_rate': 0.28,
  'income_delta_pct': 0.0,
  'expense_delta_pct': 0.0,
  'net_delta_pct': 0.0,
  'savings_rate_delta_pct': 0.0,
  'by_category': <dynamic>[],
  'currency': 'EUR',
};

Map<String, dynamic> _trendsJson() => {
  'monthly_series': <dynamic>[],
  'savings_series': <dynamic>[],
  'currency': 'EUR',
};
