import 'package:finstride/core/api/api_client.dart';
import 'package:finstride/core/api/api_client_provider.dart';
import 'package:finstride/core/theme/app_theme.dart';
import 'package:finstride/features/categories/application/categories_controller.dart';
import 'package:finstride/features/rules/application/rule_preview_controller.dart';
import 'package:finstride/features/rules/application/rules_controller.dart';
import 'package:finstride/features/rules/presentation/rule_editor_modal.dart';
import 'package:finstride/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_categories_controller.dart';
import '../../support/fake_rules_controller.dart';

class MockApiClient extends Mock implements ApiClient {}

Map<String, dynamic> _previewJson({int count = 7, bool withSample = true}) => {
  'match_count': count,
  'samples': withSample
      ? [
          {
            'id': 't1',
            'description_clean': 'CB CARREFOUR PARIS 15',
            'booked_date': '2026-05-14',
          },
        ]
      : <dynamic>[],
};

Widget _wrap(MockApiClient apiClient, {FakeRulesController? rules}) {
  return ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(apiClient),
      rulesControllerProvider.overrideWith(
        () => rules ?? FakeRulesController(),
      ),
      categoriesControllerProvider.overrideWith(
        () => FakeCategoriesController(
          initialCategories: [
            testCategory(id: 'food', name: 'category.food'),
            testCategory(
              id: 'groceries',
              parentId: 'food',
              name: 'category.food.groceries',
            ),
          ],
        ),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('fr'),
      theme: appDarkTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showRuleEditor(context),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
}

Future<void> _openEditor(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

/// Advances past the debounce and lets the response land.
///
/// `pumpAndSettle` alone will not do it: it only advances the clock while
/// frames are scheduled, and a resting form schedules none — so the debounce
/// timer would sit unfired and every preview assertion would pass for the
/// wrong reason.
Future<void> _settlePreview(WidgetTester tester) async {
  await tester.pump(rulePreviewDebounce + const Duration(milliseconds: 50));
  await tester.pumpAndSettle();
}

void main() {
  late MockApiClient apiClient;

  setUpAll(() => registerFallbackValue(<String, dynamic>{}));

  setUp(() => apiClient = MockApiClient());

  testWidgets(
    'the preview is debounced: one request for a burst of keystrokes',
    (tester) async {
      when(
        () => apiClient.post('/rules/preview', body: any(named: 'body')),
      ).thenAnswer((_) async => _previewJson());

      await tester.pumpWidget(_wrap(apiClient));
      await _openEditor(tester);

      for (final text in ['C', 'CA', 'CAR', 'CARR', 'CARREFOUR']) {
        await tester.enterText(find.byKey(const Key('ruleFormPattern')), text);
        await tester.pump(const Duration(milliseconds: 60));
      }
      verifyNever(
        () => apiClient.post('/rules/preview', body: any(named: 'body')),
      );

      await _settlePreview(tester);
      final body =
          verify(
                () => apiClient.post(
                  '/rules/preview',
                  body: captureAny(named: 'body'),
                ),
              ).captured.single
              as Map<String, dynamic>;
      expect(body['pattern'], 'CARREFOUR');
    },
  );

  testWidgets('the banner reports the count and quotes one example', (
    tester,
  ) async {
    when(
      () => apiClient.post('/rules/preview', body: any(named: 'body')),
    ).thenAnswer((_) async => _previewJson(count: 7));

    await tester.pumpWidget(_wrap(apiClient));
    await _openEditor(tester);
    await tester.enterText(
      find.byKey(const Key('ruleFormPattern')),
      'CARREFOUR',
    );
    await _settlePreview(tester);

    expect(find.byKey(const Key('rulePreviewBanner')), findsOneWidget);
    expect(
      find.textContaining('Correspond à 7 transactions existantes'),
      findsOneWidget,
    );
    expect(find.textContaining('CB CARREFOUR PARIS 15'), findsOneWidget);
  });

  testWidgets('zero matches is reported as zero, not as an error', (
    tester,
  ) async {
    when(
      () => apiClient.post('/rules/preview', body: any(named: 'body')),
    ).thenAnswer((_) async => _previewJson(count: 0, withSample: false));

    await tester.pumpWidget(_wrap(apiClient));
    await _openEditor(tester);
    await tester.enterText(find.byKey(const Key('ruleFormPattern')), 'ZZZ');
    await _settlePreview(tester);

    expect(
      find.text('Ne correspond à aucune transaction existante.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'an uncompilable regex renders on the pattern field, not as zero matches',
    (tester) async {
      when(
        () => apiClient.post('/rules/preview', body: any(named: 'body')),
      ).thenThrow(
        const ApiFailure(
          code: 'RULE_PATTERN_INVALID',
          message: 'unbalanced parenthesis',
        ),
      );

      await tester.pumpWidget(_wrap(apiClient));
      await _openEditor(tester);
      await tester.enterText(
        find.byKey(const Key('ruleFormPattern')),
        '(CARREFOUR',
      );
      await _settlePreview(tester);

      expect(
        find.text("Ce motif n'est pas une expression régulière valide."),
        findsOneWidget,
      );
      expect(find.byKey(const Key('rulePreviewBanner')), findsNothing);
      expect(find.textContaining('aucune transaction'), findsNothing);
    },
  );

  testWidgets('saving creates the rule with the typed condition', (
    tester,
  ) async {
    when(
      () => apiClient.post('/rules/preview', body: any(named: 'body')),
    ).thenAnswer((_) async => _previewJson());
    when(() => apiClient.post('/rules', body: any(named: 'body'))).thenAnswer(
      (_) async => {
        'id': 'r9',
        'priority': 1,
        'match_field': 'merchant',
        'match_type': 'contains',
        'pattern': 'CARREFOUR',
        'category_id': 'groceries',
        'enabled': true,
        'created_at': '2026-01-01T00:00:00Z',
      },
    );

    await tester.pumpWidget(_wrap(apiClient));
    await _openEditor(tester);

    await tester.enterText(
      find.byKey(const Key('ruleFormPattern')),
      'CARREFOUR',
    );
    await _settlePreview(tester);

    await tester.tap(find.byKey(const Key('ruleFormCategory')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alimentation › Courses').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('ruleFormSubmit')));
    await tester.pumpAndSettle();

    final body =
        verify(
              () => apiClient.post('/rules', body: captureAny(named: 'body')),
            ).captured.single
            as Map<String, dynamic>;
    expect(body['pattern'], 'CARREFOUR');
    expect(body['category_id'], 'groceries');
    expect(body['match_type'], 'contains');
    expect(find.byKey(const Key('ruleFormSubmit')), findsNothing);
  });

  testWidgets(
    'an empty pattern clears the banner instead of counting everything',
    (tester) async {
      when(
        () => apiClient.post('/rules/preview', body: any(named: 'body')),
      ).thenAnswer((_) async => _previewJson());

      await tester.pumpWidget(_wrap(apiClient));
      await _openEditor(tester);
      await tester.enterText(
        find.byKey(const Key('ruleFormPattern')),
        'CARREFOUR',
      );
      await _settlePreview(tester);
      expect(find.byKey(const Key('rulePreviewBanner')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('ruleFormPattern')), '');
      await _settlePreview(tester);

      expect(find.byKey(const Key('rulePreviewBanner')), findsNothing);
      verify(
        () => apiClient.post('/rules/preview', body: any(named: 'body')),
      ).called(1);
    },
  );

  testWidgets('the debounce is the documented one', (tester) async {
    expect(rulePreviewDebounce, const Duration(milliseconds: 350));
  });
}
