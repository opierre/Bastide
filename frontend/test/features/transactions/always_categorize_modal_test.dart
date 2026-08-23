import 'package:finstride/core/api/api_client.dart';
import 'package:finstride/core/api/api_client_provider.dart';
import 'package:finstride/core/theme/app_theme.dart';
import 'package:finstride/features/rules/application/rule_preview_controller.dart';
import 'package:finstride/features/transactions/application/transactions_controller.dart';
import 'package:finstride/features/transactions/domain/transaction.dart';
import 'package:finstride/features/transactions/presentation/always_categorize_modal.dart';
import 'package:finstride/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_transactions_controller.dart';

class MockApiClient extends Mock implements ApiClient {}

final _transaction = Transaction(
  id: 't1',
  accountId: 'a1',
  bookedDate: DateTime(2026, 5, 11),
  valueDate: null,
  amountMinor: -18744,
  currency: 'EUR',
  descriptionRaw: 'PRLV SEPA ASSUR MAIF',
  descriptionClean: 'Assur Maif',
  memo: null,
  merchant: 'MAIF',
  category: null,
  categorizationSource: CategorizationSource.uncategorized,
  categorizationConfidence: null,
  needsReview: true,
  fitid: null,
  dedupHash: 'hash-1',
  createdAt: DateTime.utc(2026, 5, 11),
  updatedAt: DateTime.utc(2026, 5, 11),
);

/// « Logement » and its « Assurance habitation » child, so the select renders
/// the disambiguating parent path the rules editor uses.
List<Map<String, dynamic>> _categoryCatalog() => [
  {
    'id': 'c-housing',
    'user_id': null,
    'parent_id': null,
    'name': 'category.housing',
    'kind': 'expense',
    'icon': 'home',
    'color': '#4FD1E8',
    'is_system': true,
  },
  {
    'id': 'c-home-insurance',
    'user_id': null,
    'parent_id': 'c-housing',
    'name': 'category.housing.home_insurance',
    'kind': 'expense',
    'icon': 'home',
    'color': '#4FD1E8',
    'is_system': true,
  },
];

Map<String, dynamic> _ruleJson() => {
  'id': 'r9',
  'priority': 4,
  'match_field': 'description_clean',
  'match_type': 'contains',
  'pattern': 'ASSUR MAIF',
  'category_id': 'c-home-insurance',
  'enabled': true,
  'created_at': '2026-05-11T00:00:00Z',
};

void main() {
  late MockApiClient apiClient;
  late FakeTransactionsController transactions;

  setUpAll(() => registerFallbackValue(<String, dynamic>{}));

  setUp(() {
    apiClient = MockApiClient();
    transactions = FakeTransactionsController(
      initialPage: TransactionsPage(
        items: [_transaction],
        page: 1,
        pageSize: 50,
        total: 1,
      ),
    );

    when(() => apiClient.get('/rules')).thenAnswer((_) async => <dynamic>[]);
    when(() => apiClient.get('/categories')).thenAnswer((_) async => _categoryCatalog());
    when(
      () => apiClient.get('/rules/suggestion', query: any(named: 'query')),
    ).thenAnswer(
      (_) async => {
        'match_field': 'description_clean',
        'match_type': 'contains',
        'pattern': 'ASSUR MAIF',
      },
    );
    when(() => apiClient.post('/rules/preview', body: any(named: 'body'))).thenAnswer(
      (_) async => {'match_count': 7, 'samples': <dynamic>[]},
    );
    when(
      () => apiClient.post('/rules/from-transaction', body: any(named: 'body')),
    ).thenAnswer((_) async => {'rule': _ruleJson(), 'recategorized_count': 7});
  });

  Widget wrap({Locale locale = const Locale('fr')}) => ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(apiClient),
      transactionsControllerProvider.overrideWith(() => transactions),
    ],
    child: MaterialApp(
      locale: locale,
      theme: appDarkTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: AlwaysCategorizeModal(transaction: _transaction)),
    ),
  );

  /// The modal is 520 px on the 1440×900 desktop frame the design targets;
  /// the default 800×600 test surface makes its body scroll, which puts the
  /// footer controls out of reach of a tap.
  void useDesktopSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  /// The preview is debounced, so the banner only appears once the pause has
  /// elapsed — the same wait the rules editor needs.
  Future<void> settlePreview(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.pump(rulePreviewDebounce);
    await tester.pumpAndSettle();
  }

  testWidgets('pre-fills the form from the server suggestion', (tester) async {
    useDesktopSurface(tester);
    await tester.pumpWidget(wrap());
    await settlePreview(tester);

    expect(
      find.text('Une règle classe ces transactions sans IA, à chaque import — '
          'pré-remplie depuis « PRLV SEPA ASSUR MAIF ».'),
      findsOneWidget,
    );
    expect(
      tester.widget<TextFormField>(find.byKey(const Key('alwaysRulePattern'))).controller?.text,
      'ASSUR MAIF',
    );
    final captured = verify(
      () => apiClient.get('/rules/suggestion', query: captureAny(named: 'query')),
    ).captured.single;
    expect(captured, {'transaction_id': 't1'});
  });

  testWidgets('shows the live match count in its info banner', (tester) async {
    useDesktopSurface(tester);
    await tester.pumpWidget(wrap());
    await settlePreview(tester);

    expect(find.byKey(const Key('rulePreviewBanner')), findsOneWidget);
    expect(find.textContaining('7 transactions existantes'), findsOneWidget);
  });

  testWidgets('creating posts the expected payload and reports the count', (tester) async {
    useDesktopSurface(tester);
    await tester.pumpWidget(wrap());
    await settlePreview(tester);

    await tester.tap(find.byKey(const Key('alwaysRuleCategory')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Logement › Assurance habitation').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('alwaysRuleSubmit')));
    await tester.pumpAndSettle();

    final payload =
        verify(
              () => apiClient.post(
                '/rules/from-transaction',
                body: captureAny(named: 'body'),
              ),
            ).captured.single
            as Map<String, dynamic>;
    expect(payload, {
      'transaction_id': 't1',
      'match_field': 'description_clean',
      'match_type': 'contains',
      'pattern': 'ASSUR MAIF',
      'category_id': 'c-home-insurance',
      // Checked by default, per frame ⑧.
      'apply_now': true,
    });
  });

  testWidgets('unchecking the box keeps the rule off existing rows', (tester) async {
    useDesktopSurface(tester);
    await tester.pumpWidget(wrap());
    await settlePreview(tester);

    await tester.tap(find.byKey(const Key('alwaysRuleCategory')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Logement › Assurance habitation').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('alwaysRuleApplyExisting')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('alwaysRuleSubmit')));
    await tester.pumpAndSettle();

    final payload =
        verify(
              () => apiClient.post(
                '/rules/from-transaction',
                body: captureAny(named: 'body'),
              ),
            ).captured.single
            as Map<String, dynamic>;
    expect(payload['apply_now'], isFalse);
  });

  testWidgets('a category is required before the rule can be created', (tester) async {
    useDesktopSurface(tester);
    await tester.pumpWidget(wrap());
    await settlePreview(tester);

    await tester.tap(find.byKey(const Key('alwaysRuleSubmit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('alwaysRuleError')), findsOneWidget);
    verifyNever(
      () => apiClient.post('/rules/from-transaction', body: any(named: 'body')),
    );
  });

  testWidgets('a pre-fill that fails leaves the form usable', (tester) async {
    when(
      () => apiClient.get('/rules/suggestion', query: any(named: 'query')),
    ).thenThrow(const ApiFailure(code: 'TRANSACTION_NOT_FOUND', message: 'gone'));

    useDesktopSurface(tester);
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('alwaysRuleSuggestionFailed')), findsOneWidget);
    expect(find.byKey(const Key('alwaysRulePattern')), findsOneWidget);
    expect(find.byKey(const Key('alwaysRuleSubmit')), findsOneWidget);
  });

  testWidgets('renders under en with no leftover French', (tester) async {
    useDesktopSurface(tester);
    await tester.pumpWidget(wrap(locale: const Locale('en')));
    await settlePreview(tester);

    expect(find.text('Always categorize like this'), findsOneWidget);
    expect(find.text('Apply to existing transactions'), findsOneWidget);
    expect(find.text('Create the rule'), findsOneWidget);
    expect(find.text('Target category'), findsOneWidget);
    expect(find.textContaining('pré-remplie'), findsNothing);
  });
}
