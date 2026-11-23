import 'dart:convert';
import 'dart:typed_data';

import 'package:bastide/core/api/api_client.dart';
import 'package:bastide/core/api/api_client_provider.dart';
import 'package:bastide/core/session/current_user_provider.dart';
import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/core/widgets/app_button.dart';
import 'package:bastide/features/auth/domain/auth_user.dart';
import 'package:bastide/features/settings/application/backup_controller.dart';
import 'package:bastide/features/settings/application/reset_controller.dart';
import 'package:bastide/features/settings/domain/database_reset.dart';
import 'package:bastide/features/settings/presentation/reset_group.dart';
import 'package:bastide/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/desktop_surface.dart';

class MockApiClient extends Mock implements ApiClient {}

/// Stands in for the save dialog of « Exporter d’abord ».
class FakeBackupFiles implements BackupFiles {
  final written = <String, Uint8List>{};

  @override
  Future<String?> chooseSaveLocation(String suggestedName) async =>
      'C:/sauvegardes/bastide';

  @override
  Future<void> write(String path, Uint8List bytes) async =>
      written[path] = bytes;

  @override
  Future<({String name, Uint8List bytes})?> pick() async => null;
}

final _archive = Uint8List.fromList([80, 75, 3, 4]);

final _backupSummaryJson = {
  'format_version': 8,
  'app_version': '0.1.0',
  'exported_at': '2026-09-11T12:32:00Z',
  'currency': 'EUR',
  'last_import_at': null,
  'counts': {
    for (final key in [
      'accounts',
      'transactions',
      'categories',
      'rules',
      'recurring',
      'goals',
      'mortgages',
      'properties',
      'simulations',
    ])
      key: 0,
  },
};

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
  late FakeBackupFiles files;

  setUp(() {
    apiClient = MockApiClient();
    files = FakeBackupFiles();
    when(() => apiClient.get('/settings')).thenAnswer(
      (_) async => {
        'ai_enabled': false,
        'inference_base_url': 'http://127.0.0.1:11434/v1',
        'model_tag': null,
        'confidence_threshold': 0.8,
        'savings_rate_goal_percent': 20,
        'last_backup_at': null,
      },
    );
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
      backupFilesProvider.overrideWithValue(files),
    ],
    child: MaterialApp(
      locale: locale,
      theme: AppTheme.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(
        body: SingleChildScrollView(
          child: SizedBox(width: 900, child: ResetGroup()),
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
    testWidgets('the button sits against the right edge of its row', (
      tester,
    ) async {
      useDesktopSurface(tester);
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      final row = tester.getRect(find.byKey(const Key('settingsResetRow')));
      final button = tester.getRect(
        find.byKey(const Key('settingsResetButton')),
      );
      expect(button.right, row.right);
      expect(button.width, lessThan(row.width / 2));
    });

    testWidgets('⑩ states the stake and opens the confirmation', (
      tester,
    ) async {
      useDesktopSurface(tester);
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.text('Réinitialisation'), findsOneWidget);
      expect(find.text('Réinitialiser la base de données'), findsOneWidget);
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

    testWidgets('the delete waits for the word, in any case', (tester) async {
      useDesktopSurface(tester);
      stubReset();
      await openModal(tester);

      Future<void> type(String value) async {
        await tester.enterText(
          find.byKey(const Key('resetConfirmInput')),
          value,
        );
        await tester.pumpAndSettle();
      }

      expect(
        find.text('Saisissez « supprimer » pour confirmer'),
        findsOneWidget,
      );
      expect(
        find.text('Majuscules ou minuscules, peu importe.'),
        findsOneWidget,
      );
      expect(tester.widget<AppButton>(_submit).onPressed, isNull);

      await type('suppr');
      expect(tester.widget<AppButton>(_submit).onPressed, isNull);
      verifyNever(() => apiClient.post('/database/reset'));

      for (final word in ['supprimer', 'SUPPRIMER', 'Supprimer']) {
        await type(word);
        expect(tester.widget<AppButton>(_submit).onPressed, isNotNull);
      }
    });

    testWidgets('lists the live counts 8 px apart', (tester) async {
      useDesktopSurface(tester);
      await openModal(tester);

      final accounts = tester.getBottomLeft(find.text('Comptes')).dy;
      final transactions = tester.getTopLeft(find.text('Transactions')).dy;
      expect(transactions - accounts, moreOrLessEquals(8, epsilon: 1));
      expect(find.text('Catégories personnalisées'), findsOneWidget);
    });

    testWidgets('« Exporter d’abord » saves without closing, then says so', (
      tester,
    ) async {
      useDesktopSurface(tester);
      when(() => apiClient.postForBytes('/backup/export')).thenAnswer(
        (_) async => ApiBytesResponse(
          bytes: _archive,
          headers: {'x-backup-summary': jsonEncode(_backupSummaryJson)},
        ),
      );
      await openModal(tester);

      await tester.tap(find.byKey(const Key('exportFirstButton')));
      await tester.pumpAndSettle();

      expect(files.written, hasLength(1));
      expect(find.text('Réinitialiser la base de données ?'), findsOneWidget);
      expect(find.byKey(const Key('exportFirstButton')), findsNothing);
      expect(find.text('Sauvegarde enregistrée'), findsOneWidget);
    });

    testWidgets('⑪ confirming deletes, closes and says the catalog is back', (
      tester,
    ) async {
      useDesktopSurface(tester);
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
      expect(find.text('Base de données réinitialisée.'), findsOneWidget);
      // Let the toast's timer run out so no timer outlives the test.
      await tester.pump(const Duration(seconds: 7));
    });

    testWidgets('a refused reset closes the modal and reports it on the row', (
      tester,
    ) async {
      useDesktopSurface(tester);
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
      useDesktopSurface(tester);
      await tester.pumpWidget(wrap(locale: const Locale('en')));
      await tester.pumpAndSettle();

      expect(find.text('Reset the database'), findsOneWidget);

      await tester.tap(find.byKey(const Key('settingsResetButton')));
      await tester.pumpAndSettle();

      expect(find.text('Reset the database?'), findsOneWidget);
      expect(find.text('Type “delete” to confirm'), findsOneWidget);
      expect(find.text('Upper or lower case, either works.'), findsOneWidget);
      expect(find.text('Export first'), findsOneWidget);
      expect(find.text('Delete everything'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('resetConfirmInput')),
        'DELETE',
      );
      await tester.pumpAndSettle();
      expect(tester.widget<AppButton>(_submit).onPressed, isNotNull);
    });
  });
}

final _submit = find.byKey(const Key('resetConfirmSubmit'));
