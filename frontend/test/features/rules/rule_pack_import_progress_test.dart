import 'dart:async';

import 'package:bastide/core/api/api_client.dart';
import 'package:bastide/core/api/api_client_provider.dart';
import 'package:bastide/core/runs/run_event.dart';
import 'package:bastide/core/runs/run_progress_provider.dart';
import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/features/rules/application/rule_pack_import_controller.dart';
import 'package:bastide/features/rules/application/rule_packs_controller.dart';
import 'package:bastide/features/rules/application/rules_controller.dart';
import 'package:bastide/features/rules/domain/rule_pack.dart';
import 'package:bastide/features/rules/presentation/rule_pack_import_sheet.dart';
import 'package:bastide/features/transactions/application/transactions_controller.dart';
import 'package:bastide/features/transactions/domain/transaction.dart';
import 'package:bastide/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_rules_controller.dart';
import '../../support/fake_transactions_controller.dart';
import '../../support/pack_import_runs.dart';

class MockApiClient extends Mock implements ApiClient {}

const _emptyPage = TransactionsPage(
  items: <Transaction>[],
  page: 1,
  pageSize: 50,
  total: 0,
);

final _preview = RulePackPreview.fromJson(const {
  'name': 'Commerces du quartier',
  'total': 3,
  'new_count': 3,
  'duplicate_count': 0,
  'unresolved': <String>[],
  'would_match_count': 12,
  'samples': <Map<String, dynamic>>[],
  'logo_count': 3,
  'logo_download_count': 3,
});

final _pending = PendingRulePack(preview: _preview, builtinId: 'fr-common');

Map<String, dynamic> _result({
  int recategorized = 0,
  List<Map<String, dynamic>> failures = const [],
}) => {
  'created_count': 3,
  'skipped_count': 0,
  'unresolved': <String>[],
  'recategorized_count': recategorized,
  'logo_count': 3 - failures.length,
  'logo_skipped_count': 0,
  'logo_failures': failures,
};

void main() {
  late MockApiClient apiClient;
  late MockRunProgressClient progress;
  late StreamController<RunUpdate> updates;
  late FakeTransactionsController transactions;

  setUpAll(() => registerFallbackValue(<String, dynamic>{}));

  setUp(() {
    apiClient = MockApiClient();
    progress = MockRunProgressClient();
    updates = StreamController<RunUpdate>.broadcast();
    when(() => progress.watch(any())).thenAnswer((_) => updates.stream);
    transactions = FakeTransactionsController(initialPage: _emptyPage);
    when(
      () =>
          apiClient.post('/rules/packs/import-runs', body: any(named: 'body')),
    ).thenAnswer((_) async => packImportRunJson());
    addTearDown(updates.close);
  });

  void snapshotIs(Map<String, dynamic> json) => when(
    () => apiClient.get('/rules/packs/import-runs/$packImportRunId'),
  ).thenAnswer((_) async => json);

  List<Override> overrides() => [
    apiClientProvider.overrideWithValue(apiClient),
    runProgressClientProvider.overrideWithValue(progress),
    rulesControllerProvider.overrideWith(() => FakeRulesController()),
    transactionsControllerProvider.overrideWith(() => transactions),
  ];

  group('RulePackImportController', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(overrides: overrides());
      addTearDown(container.dispose);
      // `autoDispose`: in the app the sheet keeps it alive.
      container.listen(
        rulePackImportControllerProvider,
        (_, _) {},
        fireImmediately: true,
      );
    });

    RulePackImportState read() =>
        container.read(rulePackImportControllerProvider);

    Future<void> start({bool downloadLogos = true}) => container
        .read(rulePackImportControllerProvider.notifier)
        .start(_pending, applyNow: true, downloadLogos: downloadLogos);

    Future<void> push(RunUpdate update) async {
      updates.add(update);
      await Future<void>.delayed(Duration.zero);
    }

    test('start posts the pack source and follows the run', () async {
      await start();

      final body = verify(
        () => apiClient.post(
          '/rules/packs/import-runs',
          body: captureAny(named: 'body'),
        ),
      ).captured.single;
      expect(body, {
        'builtin_id': 'fr-common',
        'apply_now': true,
        'download_logos': true,
      });
      expect(read().run?.id, packImportRunId);
      expect(read().isInFlight, isTrue);
      verify(() => progress.watch(packImportRunId)).called(1);
      expect(updates.hasListener, isTrue);
    });

    test('logo events move the progress with no REST read', () async {
      await start();

      await push(
        RunEventUpdate(packImportEvent(RunEventType.started, total: 3)),
      );
      expect(read().isDownloading, isTrue);
      expect(read().run?.logoTotal, 3);

      await push(
        RunEventUpdate(
          packImportEvent(RunEventType.progress, done: 2, total: 3),
        ),
      );
      expect(read().run?.logoDone, 2);
      verifyNever(() => apiClient.get(any()));
    });

    test('the finished event reads the result once, then stops '
        'listening', () async {
      snapshotIs(
        packImportRunJson(
          status: 'finished',
          logoDone: 3,
          logoTotal: 3,
          result: _result(recategorized: 4),
        ),
      );
      await start();
      await push(
        RunEventUpdate(packImportEvent(RunEventType.started, total: 3)),
      );

      await push(
        RunEventUpdate(
          packImportEvent(RunEventType.finished, done: 3, total: 3),
        ),
      );

      expect(read().result?.createdCount, 3);
      expect(read().hasLogoDownloads, isTrue);
      expect(read().isInFlight, isFalse);
      expect(updates.hasListener, isFalse);
      verify(
        () => apiClient.get('/rules/packs/import-runs/$packImportRunId'),
      ).called(1);
      // The import recategorized rows: the views showing them are reloaded.
      expect(transactions.refreshQuietlyCalls, 1);
    });

    test('a resync that does not know the run reads the snapshot', () async {
      snapshotIs(packImportRunJson(status: 'finished', result: _result()));
      await start(downloadLogos: false);

      await push(const RunResync(null));

      expect(read().result, isNotNull);
      expect(read().hasLogoDownloads, isFalse);
    });

    test('a dropped socket falls back to the snapshot', () async {
      snapshotIs(packImportRunJson(logoDone: 1, logoTotal: 3));
      await start();

      await push(const RunConnectionLost());

      expect(read().run?.logoDone, 1);
      expect(read().isDownloading, isTrue);
    });

    test('a snapshot older than the last event is ignored', () async {
      snapshotIs(packImportRunJson(logoDone: 1, logoTotal: 3));
      await start();
      await push(
        RunEventUpdate(
          packImportEvent(RunEventType.progress, done: 2, total: 3),
        ),
      );

      await push(const RunConnectionLost());

      expect(read().run?.logoDone, 2);
    });

    test('a failed run is reported as failed', () async {
      snapshotIs(
        packImportRunJson(
          status: 'failed',
          errorMessage: 'The rule pack import could not finish.',
        ),
      );
      await start();

      await push(
        RunEventUpdate(packImportEvent(RunEventType.failed, total: 3)),
      );

      expect(read().hasFailed, isTrue);
      expect(read().isInFlight, isFalse);
      expect(updates.hasListener, isFalse);
    });

    test('a refused start keeps the error and follows nothing', () async {
      when(
        () => apiClient.post(
          '/rules/packs/import-runs',
          body: any(named: 'body'),
        ),
      ).thenThrow(
        const ApiFailure(
          code: 'RULE_PACK_IMPORT_IN_PROGRESS',
          message: 'A rule pack import is already running.',
        ),
      );

      await start();

      expect(read().error, isA<ApiFailure>());
      expect(read().isInFlight, isFalse);
      verifyNever(() => progress.watch(any()));
    });
  });

  for (final locale in const [Locale('fr'), Locale('en')]) {
    final l10n = lookupAppLocalizations(locale);

    group('${locale.languageCode}: the import sheet', () {
      Future<void> openSheet(WidgetTester tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: overrides(),
            child: MaterialApp(
              locale: locale,
              theme: appDarkTheme,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => RulePackImportSheet(pending: _pending),
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
      }

      Future<void> importWithLogos(WidgetTester tester) async {
        await openSheet(tester);
        final checkbox = find.byKey(const Key('rulePackDownloadLogos'));
        await tester.ensureVisible(checkbox);
        await tester.tap(checkbox);
        await tester.pump();
        await tester.tap(find.byKey(const Key('rulePackImportConfirm')));
        await tester.pump();
        await tester.pump();
      }

      Future<void> push(WidgetTester tester, RunUpdate update) async {
        updates.add(update);
        await tester.pump();
        await tester.pump();
      }

      testWidgets('shows the logo progress advancing to the total, then the '
          'result in the same sheet', (tester) async {
        snapshotIs(
          packImportRunJson(
            status: 'finished',
            logoDone: 3,
            logoTotal: 3,
            result: _result(
              failures: [
                {
                  'index': 1,
                  'pattern': 'LIBRAIRIE DES QUAIS',
                  'reason': 'download_failed',
                },
              ],
            ),
          ),
        );
        await importWithLogos(tester);

        await push(
          tester,
          RunEventUpdate(packImportEvent(RunEventType.started, total: 3)),
        );
        expect(find.byKey(const Key('rulePackLogoProgress')), findsOneWidget);
        expect(find.text(l10n.rulePackLogoProgress(0, 3)), findsOneWidget);
        expect(find.text(l10n.rulePackLogoProgressNotice), findsOneWidget);
        // The form gives way to the bar, and the sheet can't be closed while
        // the run it would lose the result of is going.
        expect(find.byKey(const Key('rulePackImportConfirm')), findsNothing);
        final cancel = tester.widget<OutlinedButton>(
          find.byKey(const Key('rulePackImportCancel')),
        );
        expect(cancel.onPressed, isNull);

        for (final done in [1, 2, 3]) {
          await push(
            tester,
            RunEventUpdate(
              packImportEvent(RunEventType.progress, done: done, total: 3),
            ),
          );
          expect(find.text(l10n.rulePackLogoProgress(done, 3)), findsOneWidget);
        }

        await push(
          tester,
          RunEventUpdate(
            packImportEvent(RunEventType.finished, done: 3, total: 3),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('rulePackLogoProgress')), findsNothing);
        expect(find.byKey(const Key('rulePackImportResult')), findsOneWidget);
        expect(find.text(l10n.rulePackImportedTitle(3)), findsOneWidget);
        expect(find.text(l10n.rulePackLogoFailuresTitle(1)), findsOneWidget);
        expect(
          find.text(
            l10n.rulePackLogoFailureDownloadFailed('LIBRAIRIE DES QUAIS'),
          ),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('rulePackImportDone')));
        await tester.pumpAndSettle();
        expect(find.byType(RulePackImportSheet), findsNothing);
      });

      testWidgets('an import with no logo to download closes on the toast, '
          'as before', (tester) async {
        snapshotIs(packImportRunJson(status: 'finished', result: _result()));
        await openSheet(tester);
        await tester.tap(find.byKey(const Key('rulePackImportConfirm')));
        await tester.pump();
        await tester.pump();

        await push(
          tester,
          RunEventUpdate(packImportEvent(RunEventType.started)),
        );
        expect(find.byKey(const Key('rulePackLogoProgress')), findsNothing);
        await push(
          tester,
          RunEventUpdate(packImportEvent(RunEventType.finished)),
        );
        await tester.pumpAndSettle();

        expect(find.byType(RulePackImportSheet), findsNothing);
        expect(find.text(l10n.rulePackImportedTitle(3)), findsOneWidget);
      });

      testWidgets('a failed run says so in the sheet and allows a retry', (
        tester,
      ) async {
        snapshotIs(
          packImportRunJson(
            status: 'failed',
            logoDone: 1,
            logoTotal: 3,
            errorMessage: 'The rule pack import could not finish.',
          ),
        );
        await importWithLogos(tester);
        await push(
          tester,
          RunEventUpdate(packImportEvent(RunEventType.started, total: 3)),
        );

        await push(
          tester,
          RunEventUpdate(
            packImportEvent(RunEventType.failed, done: 1, total: 3),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(l10n.rulePackImportRunFailed), findsOneWidget);
        expect(find.byKey(const Key('rulePackImportConfirm')), findsOneWidget);
        // The backend's English message is never shown as is.
        expect(
          find.text('The rule pack import could not finish.'),
          findsNothing,
        );
      });

      testWidgets('another import still running is explained', (tester) async {
        when(
          () => apiClient.post(
            '/rules/packs/import-runs',
            body: any(named: 'body'),
          ),
        ).thenThrow(
          const ApiFailure(
            code: 'RULE_PACK_IMPORT_IN_PROGRESS',
            message: 'A rule pack import is already running.',
          ),
        );
        await openSheet(tester);

        await tester.tap(find.byKey(const Key('rulePackImportConfirm')));
        await tester.pumpAndSettle();

        expect(find.text(l10n.ruleErrorPackImportInProgress), findsOneWidget);
      });

      testWidgets('a pack that no longer exists is explained', (tester) async {
        when(
          () => apiClient.post(
            '/rules/packs/import-runs',
            body: any(named: 'body'),
          ),
        ).thenThrow(
          const ApiFailure(
            code: 'RULE_PACK_NOT_FOUND',
            message: 'Rule pack not found.',
          ),
        );
        await openSheet(tester);

        await tester.tap(find.byKey(const Key('rulePackImportConfirm')));
        await tester.pumpAndSettle();

        expect(find.text(l10n.ruleErrorPackNotFound), findsOneWidget);
      });
    });
  }
}
