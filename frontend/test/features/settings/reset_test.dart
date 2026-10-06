import 'package:finstride/core/api/api_client.dart';
import 'package:finstride/core/api/api_client_provider.dart';
import 'package:finstride/core/session/current_user_provider.dart';
import 'package:finstride/core/theme/app_theme.dart';
import 'package:finstride/features/auth/domain/auth_user.dart';
import 'package:finstride/features/settings/application/reset_controller.dart';
import 'package:finstride/features/settings/domain/database_reset.dart';
import 'package:finstride/features/settings/presentation/danger_zone_card.dart';
import 'package:finstride/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

Map<String, dynamic> _summaryJson({int transactions = 1284}) => {
  'counts': {
    'accounts': 4,
    'transactions': transactions,
    'categories': 12,
    'rules': 30,
    'recurring': 5,
    'goals': 2,
    'mortgages': 1,
    'properties': 1,
    'simulations': 3,
  },
};

const _user = AuthUser(
  id: 'u1',
  email: 'camille@example.com',
  displayName: 'Camille Dubois',
  locale: 'fr',
  currency: 'EUR',
);

void main() {
  late MockApiClient apiClient;

  setUp(() {
    apiClient = MockApiClient();
    when(
      () => apiClient.get('/database/summary'),
    ).thenAnswer((_) async => _summaryJson());
  });

  void stubReset({Object? throws}) {
    final call = when(() => apiClient.post('/database/reset'));
    if (throws != null) {
      call.thenThrow(throws);
    } else {
      call.thenAnswer((_) async => _summaryJson());
    }
  }

  Widget wrap({Locale locale = const Locale('fr')}) => ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(apiClient),
      currentUserProvider.overrideWithValue(_user),
    ],
    child: MaterialApp(
      locale: locale,
      theme: appDarkTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(
        body: SingleChildScrollView(
          child: SizedBox(width: 640, child: DangerZoneCard()),
        ),
      ),
    ),
  );

  Future<void> openModal(WidgetTester tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settingsResetButton')));
    await tester.pumpAndSettle();
  }

  group('controller', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [apiClientProvider.overrideWithValue(apiClient)],
      );
      addTearDown(container.dispose);
    });

    test('the summary is read from the server', () async {
      final counts = await container.read(databaseSummaryProvider.future);

      expect(counts.transactions, 1284);
      expect(counts.categories, 12);
    });

    test('a reset reports what it deleted', () async {
      stubReset();

      final deleted = await container
          .read(resetControllerProvider.notifier)
          .reset();

      expect(deleted.accounts, 4);
      expect(container.read(resetControllerProvider).failure, isNull);
    });

    test(
      'a refused reset surfaces as a typed failure and is not retried',
      () async {
        stubReset(
          throws: const ApiFailure(code: 'RESET_RUN_ACTIVE', message: 'busy'),
        );

        await expectLater(
          container.read(resetControllerProvider.notifier).reset(),
          throwsA(
            isA<ResetException>().having(
              (e) => e.failure,
              'failure',
              ResetFailure.runActive,
            ),
          ),
        );
        expect(
          container.read(resetControllerProvider).failure,
          ResetFailure.runActive,
        );
      },
    );
  });

  group('card', () {
    testWidgets('⑩ states the stake and opens the confirmation', (
      tester,
    ) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.text('Zone de danger'), findsOneWidget);
      expect(find.text('IRRÉVERSIBLE'), findsOneWidget);
      expect(find.byKey(const Key('settingsResetError')), findsNothing);

      await tester.tap(find.byKey(const Key('settingsResetButton')));
      await tester.pumpAndSettle();

      expect(find.text('Réinitialiser la base de données ?'), findsOneWidget);
      expect(find.textContaining('Camille Dubois'), findsOneWidget);
      // The live counts, not a cached claim.
      // Formatted in the active locale — French groups with a narrow no-break
      // space, so the literal cannot be typed here.
      expect(
        find.text(NumberFormat.decimalPattern('fr').format(1284)),
        findsOneWidget,
      );
      expect(find.text('30'), findsOneWidget);
    });

    testWidgets('the delete waits for the word, typed exactly', (tester) async {
      stubReset();
      await openModal(tester);

      Future<void> type(String value) async {
        await tester.enterText(
          find.byKey(const Key('resetConfirmInput')),
          value,
        );
        await tester.pumpAndSettle();
      }

      expect(tester.widget<FilledButton>(_submit).onPressed, isNull);

      await type('supprimer');
      expect(tester.widget<FilledButton>(_submit).onPressed, isNull);
      verifyNever(() => apiClient.post('/database/reset'));

      await type('SUPPRIMER');
      expect(tester.widget<FilledButton>(_submit).onPressed, isNotNull);
    });

    testWidgets('⑪ confirming deletes, closes and says the catalog is back', (
      tester,
    ) async {
      stubReset();
      await openModal(tester);
      await tester.enterText(
        find.byKey(const Key('resetConfirmInput')),
        'SUPPRIMER',
      );
      await tester.pumpAndSettle();

      await tester.tap(_submit);
      await tester.pumpAndSettle();

      verify(() => apiClient.post('/database/reset')).called(1);
      expect(find.byKey(const Key('resetConfirmCounts')), findsNothing);
      expect(
        find.text(
          'Base de données réinitialisée. Les catégories système ont été restaurées.',
        ),
        findsOneWidget,
      );
      // Let the toast's timer run out so no timer outlives the test.
      await tester.pump(const Duration(seconds: 7));
    });

    testWidgets('a refused reset closes the modal and reports it on the card', (
      tester,
    ) async {
      stubReset(
        throws: const ApiFailure(code: 'RESET_RUN_ACTIVE', message: 'busy'),
      );
      await openModal(tester);
      await tester.enterText(
        find.byKey(const Key('resetConfirmInput')),
        'SUPPRIMER',
      );
      await tester.pumpAndSettle();

      await tester.tap(_submit);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('resetConfirmCounts')), findsNothing);
      expect(find.byKey(const Key('settingsResetError')), findsOneWidget);
      expect(
        find.textContaining('Réinitialisation impossible.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('catégorisation est en cours'),
        findsOneWidget,
      );
    });

    testWidgets('renders in English, with its own confirmation word', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(locale: const Locale('en')));
      await tester.pumpAndSettle();

      expect(find.text('Danger zone'), findsOneWidget);

      await tester.tap(find.byKey(const Key('settingsResetButton')));
      await tester.pumpAndSettle();

      expect(find.text('Reset the database?'), findsOneWidget);
      expect(find.text('Type DELETE to confirm'), findsOneWidget);
      expect(find.text('Delete everything'), findsOneWidget);
    });
  });
}

final _submit = find.byKey(const Key('resetConfirmSubmit'));
