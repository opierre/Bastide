import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:bastide/core/api/api_client.dart';
import 'package:bastide/core/api/api_client_provider.dart';
import 'package:bastide/core/l10n/date_display.dart';
import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/core/widgets/app_modal.dart';
import 'package:bastide/core/widgets/inline_banner.dart';
import 'package:bastide/features/settings/application/backup_controller.dart';
import 'package:bastide/features/settings/application/settings_controller.dart';
import 'package:bastide/features/settings/domain/backup.dart';
import 'package:bastide/features/settings/presentation/backup_group.dart';
import 'package:bastide/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/desktop_surface.dart';

class MockApiClient extends Mock implements ApiClient {}

/// Stands in for the platform file dialogs.
class FakeBackupFiles implements BackupFiles {
  String? savePath = 'C:/sauvegardes/bastide';
  ({String name, Uint8List bytes})? picked;
  final written = <String, Uint8List>{};

  @override
  Future<String?> chooseSaveLocation(String suggestedName) async => savePath;

  @override
  Future<void> write(String path, Uint8List bytes) async =>
      written[path] = bytes;

  @override
  Future<({String name, Uint8List bytes})?> pick() async => picked;
}

final _exportedAt = DateTime.utc(2026, 9, 11, 12, 32);

Map<String, dynamic> _countsJson({
  int transactions = 1284,
  int accounts = 4,
  int rules = 30,
}) => {
  'accounts': accounts,
  'transactions': transactions,
  'categories': 12,
  'rules': rules,
  'recurring': 5,
  'goals': 2,
  'mortgages': 1,
  'properties': 1,
  'simulations': 3,
};

Map<String, dynamic> _summaryJson({
  int transactions = 1284,
  int accounts = 4,
}) => {
  'format_version': 1,
  'app_version': '0.1.0',
  'exported_at': _exportedAt.toIso8601String(),
  'currency': 'EUR',
  'last_import_at': '2026-09-04T08:00:00Z',
  'counts': _countsJson(transactions: transactions, accounts: accounts),
};

/// The data as it stands: one more import since the backup, on 18 September.
Map<String, dynamic> _currentJson({
  String? lastImportAt = '2026-09-18T08:00:00Z',
}) => {
  'app_version': '0.2.0',
  'last_import_at': lastImportAt,
  'counts': _countsJson(transactions: 1342, rules: 31),
};

Map<String, dynamic> _settingsJson({String? lastBackupAt}) => {
  'ai_enabled': false,
  'inference_base_url': 'http://127.0.0.1:11434/v1',
  'model_tag': null,
  'confidence_threshold': 0.8,
  'savings_rate_goal_percent': 20,
  'last_backup_at': lastBackupAt,
};

final _archive = Uint8List.fromList([80, 75, 3, 4]);

void main() {
  late MockApiClient apiClient;
  late FakeBackupFiles files;

  setUpAll(() {
    registerFallbackValue(<int>[]);
    registerFallbackValue(<String, String>{});
  });

  setUp(() {
    apiClient = MockApiClient();
    files = FakeBackupFiles();
    when(
      () => apiClient.get('/settings'),
    ).thenAnswer((_) async => _settingsJson());
    when(
      () => apiClient.get('/database/summary'),
    ).thenAnswer((_) async => _currentJson());
  });

  void stubExport() {
    when(() => apiClient.postForBytes('/backup/export')).thenAnswer(
      (_) async => ApiBytesResponse(
        bytes: _archive,
        headers: {'x-backup-summary': jsonEncode(_summaryJson())},
      ),
    );
  }

  void stubUpload(String path, {Object? throws}) {
    final call = when(
      () => apiClient.postMultipart(
        path,
        fileField: any(named: 'fileField'),
        fileName: any(named: 'fileName'),
        fileBytes: any(named: 'fileBytes'),
        fields: any(named: 'fields'),
      ),
    );
    if (throws != null) {
      call.thenThrow(throws);
    } else {
      call.thenAnswer((_) async => _summaryJson());
    }
  }

  ApiFailure failure(String code) => ApiFailure(code: code, message: code);

  group('controller', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(apiClient),
          backupFilesProvider.overrideWithValue(files),
        ],
      );
      addTearDown(container.dispose);
    });

    BackupController controller() =>
        container.read(backupControllerProvider.notifier);

    test(
      'export writes the archive where the user chose and records the time',
      () async {
        stubExport();
        await container.read(settingsControllerProvider.future);

        final summary = await controller().export();

        expect(summary?.counts.transactions, 1284);
        expect(files.written, {'C:/sauvegardes/bastide.bastide': _archive});
        expect(
          container
              .read(settingsControllerProvider)
              .value
              ?.settings
              .lastBackupAt,
          _exportedAt,
        );
        expect(container.read(backupControllerProvider).isExporting, isFalse);
      },
    );

    test('cancelling the save dialog builds nothing', () async {
      files.savePath = null;

      expect(await controller().export(), isNull);
      verifyNever(() => apiClient.postForBytes(any()));
    });

    test('a file from a newer version is refused before the modal', () async {
      files.picked = (name: 'future.bastide', bytes: _archive);
      stubUpload('/backup/inspect', throws: failure('BACKUP_TOO_NEW'));

      expect(await controller().pickForRestore(), isNull);
      expect(
        container.read(backupControllerProvider).restoreFailure,
        BackupFailure.tooNew,
      );
    });

    test(
      'a readable file comes back with its summary, and clears a past refusal',
      () async {
        files.picked = (name: 'future.bastide', bytes: _archive);
        stubUpload('/backup/inspect', throws: failure('BACKUP_INVALID'));
        await controller().pickForRestore();
        stubUpload('/backup/inspect');

        final pending = await controller().pickForRestore();

        expect(pending?.fileName, 'future.bastide');
        expect(pending?.summary.counts.accounts, 4);
        expect(container.read(backupControllerProvider).restoreFailure, isNull);
      },
    );

    test('a refused restore surfaces as a typed failure', () async {
      stubUpload('/backup/restore', throws: failure('BACKUP_CONFLICT'));
      final pending = PendingRestore(
        fileName: 'x.bastide',
        bytes: _archive,
        summary: BackupSummary.fromJson(_summaryJson()),
      );

      expect(
        () => controller().restore(pending),
        throwsA(
          isA<BackupException>().having(
            (e) => e.failure,
            'failure',
            BackupFailure.conflict,
          ),
        ),
      );
    });
  });

  group('card', () {
    Widget wrap({Locale locale = const Locale('fr')}) => ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(apiClient),
        backupFilesProvider.overrideWithValue(files),
      ],
      child: MaterialApp(
        locale: locale,
        theme: AppTheme.dark,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(width: 900, child: BackupGroup()),
          ),
        ),
      ),
    );

    testWidgets('⑤ idle shows the last backup in local time', (tester) async {
      useDesktopSurface(tester);
      when(() => apiClient.get('/settings')).thenAnswer(
        (_) async => _settingsJson(lastBackupAt: '2026-09-11T12:32:00Z'),
      );

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      final local = _exportedAt.toLocal();
      final expected =
          'Dernière sauvegarde le ${DayMonthFormat.yMMMMd('fr').format(local)} '
          'à ${DateFormat.Hm('fr').format(local)}';
      expect(find.text(expected), findsOneWidget);
      // The month is spelled out, as in the mockup, not « 11/09/2026 ».
      expect(find.textContaining('septembre 2026 à '), findsOneWidget);
      expect(find.byKey(const Key('settingsBackupRestoreError')), findsNothing);
    });

    testWidgets('says so when there has never been a backup', (tester) async {
      useDesktopSurface(tester);
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.text('Aucune sauvegarde.'), findsOneWidget);
    });

    testWidgets('⑥ then ⑦: preparing caption, then the toast with counts', (
      tester,
    ) async {
      useDesktopSurface(tester);
      final pending = Completer<ApiBytesResponse>();
      when(
        () => apiClient.postForBytes('/backup/export'),
      ).thenAnswer((_) => pending.future);

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settingsBackupExportButton')));
      await tester.pump();

      expect(find.text("Préparation de l’archive…"), findsOneWidget);

      pending.complete(
        ApiBytesResponse(
          bytes: _archive,
          headers: {'x-backup-summary': jsonEncode(_summaryJson())},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Sauvegarde enregistrée · 1'), findsOneWidget);
      expect(find.textContaining('opérations, 4 comptes.'), findsOneWidget);
      expect(find.textContaining('Dernière sauvegarde le'), findsOneWidget);
      // Let the toast's timer run out so no timer outlives the test.
      await tester.pump(const Duration(seconds: 7));
    });

    testWidgets('⑨ a newer-version file shows the refusal in the card', (
      tester,
    ) async {
      useDesktopSurface(tester);
      files.picked = (name: 'future.bastide', bytes: _archive);
      stubUpload('/backup/inspect', throws: failure('BACKUP_TOO_NEW'));

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settingsBackupRestoreButton')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('settingsBackupRestoreError')),
        findsOneWidget,
      );
      expect(find.textContaining('Restauration impossible.'), findsOneWidget);
      expect(find.textContaining('version plus récente'), findsOneWidget);
      expect(find.byKey(const Key('backupConfirmSummary')), findsNothing);
    });

    testWidgets('⑧ confirms with the file summary, then restores', (
      tester,
    ) async {
      useDesktopSurface(tester);
      files.picked = (name: 'bastide-2026-09-11.bastide', bytes: _archive);
      stubUpload('/backup/inspect');
      stubUpload('/backup/restore');

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settingsBackupRestoreButton')));
      await tester.pumpAndSettle();

      expect(find.text('Restaurer cette sauvegarde ?'), findsOneWidget);
      expect(
        find.text(
          'Les données exportées le 11\u00a0septembre 2026 remplacent toutes vos '
          'données actuelles.',
        ),
        findsOneWidget,
      );
      expect(find.text('bastide-2026-09-11.bastide'), findsOneWidget);
      // No banner any more: the stake is the lead, the comparison the body.
      expect(find.byType(InlineBanner), findsNothing);
      verifyNever(
        () => apiClient.postMultipart(
          '/backup/restore',
          fileField: any(named: 'fileField'),
          fileName: any(named: 'fileName'),
          fileBytes: any(named: 'fileBytes'),
          fields: any(named: 'fields'),
        ),
      );

      await tester.tap(find.byKey(const Key('backupConfirmReplace')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('backupConfirmSummary')), findsNothing);
      expect(find.text('Sauvegarde restaurée'), findsOneWidget);
      await tester.pump(const Duration(seconds: 7));
    });

    testWidgets('a refused restore keeps the modal open with the reason', (
      tester,
    ) async {
      useDesktopSurface(tester);
      files.picked = (name: 'x.bastide', bytes: _archive);
      stubUpload('/backup/inspect');
      stubUpload('/backup/restore', throws: failure('BACKUP_RUN_ACTIVE'));

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settingsBackupRestoreButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('backupConfirmReplace')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('appModalSaveError')), findsOneWidget);
      expect(
        find.textContaining('catégorisation est en cours'),
        findsOneWidget,
      );
    });

    Future<void> openModal(
      WidgetTester tester, {
      Locale locale = const Locale('fr'),
    }) async {
      useDesktopSurface(tester);
      files.picked = (name: 'bastide-2026-09-11.bastide', bytes: _archive);
      stubUpload('/backup/inspect');
      await tester.pumpWidget(wrap(locale: locale));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settingsBackupRestoreButton')));
      await tester.pumpAndSettle();
    }

    String valueOf(WidgetTester tester, String label, int column) {
      final row = find.ancestor(
        of: find.text(label),
        matching: find.byType(Table),
      );
      final table = tester.widget<Table>(row);
      for (final tableRow in table.children) {
        final texts = [
          for (final cell in tableRow.children)
            ...find
                .descendant(
                  of: find.byWidget(cell),
                  matching: find.byType(Text),
                )
                .evaluate()
                .map((e) => (e.widget as Text).data),
        ];
        if (texts.isNotEmpty && texts.first == label) return texts[column]!;
      }
      throw StateError('no row $label');
    }

    testWidgets('compares the backup with the data as it stands', (
      tester,
    ) async {
      await openModal(tester);

      final summary = find.byKey(const Key('backupConfirmSummary'));
      for (final header in ['Sauvegarde', 'Actuel']) {
        expect(
          find.descendant(of: summary, matching: find.text(header)),
          findsOneWidget,
        );
      }
      expect(valueOf(tester, 'Version de l’application', 1), '0.1.0');
      expect(valueOf(tester, 'Version de l’application', 2), '0.2.0');
      expect(valueOf(tester, 'Dernier import', 1), '4\u00a0septembre 2026');
      expect(valueOf(tester, 'Dernier import', 2), '18\u00a0septembre 2026');
      expect(valueOf(tester, 'Transactions', 1), '1\u202f284');
      expect(valueOf(tester, 'Transactions', 2), '1\u202f342');
      expect(valueOf(tester, 'Règles', 1), '30');
      expect(valueOf(tester, 'Règles', 2), '31');
    });

    testWidgets('warns when the backup predates the latest import', (
      tester,
    ) async {
      await openModal(tester);

      expect(find.byKey(const Key('backupConfirmOlder')), findsOneWidget);
      expect(
        find.text(
          'Cette sauvegarde est antérieure à votre dernier import du '
          '18\u00a0septembre 2026.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('says nothing when the backup is as recent as the latest '
        'import', (tester) async {
      when(() => apiClient.get('/database/summary')).thenAnswer(
        (_) async => _currentJson(lastImportAt: '2026-09-04T08:00:00Z'),
      );
      await openModal(tester);

      expect(find.byKey(const Key('backupConfirmOlder')), findsNothing);
    });

    testWidgets('says nothing for a profile that never imported', (
      tester,
    ) async {
      when(
        () => apiClient.get('/database/summary'),
      ).thenAnswer((_) async => _currentJson(lastImportAt: null));
      await openModal(tester);

      expect(find.byKey(const Key('backupConfirmOlder')), findsNothing);
      expect(valueOf(tester, 'Dernier import', 2), '—');
    });

    testWidgets('current data that cannot load offers a retry', (tester) async {
      when(
        () => apiClient.get('/database/summary'),
      ).thenThrow(failure('INTERNAL'));
      await openModal(tester);

      expect(find.byKey(const Key('modalLoadError')), findsOneWidget);
      expect(valueOf(tester, 'Transactions', 2), '—');

      when(
        () => apiClient.get('/database/summary'),
      ).thenAnswer((_) async => _currentJson());
      await tester.tap(find.byKey(const Key('modalLoadErrorRetry')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('modalLoadError')), findsNothing);
      expect(valueOf(tester, 'Transactions', 2), '1\u202f342');
    });

    testWidgets('opens on « Annuler »', (tester) async {
      await openModal(tester);

      final focused = FocusManager.instance.primaryFocus?.context;
      expect(
        focused?.findAncestorWidgetOfExactType<AppModalCancel>(),
        isNotNull,
      );
    });

    testWidgets('« Exporter d’abord » saves without closing, then says so', (
      tester,
    ) async {
      stubExport();
      await openModal(tester);

      await tester.tap(find.byKey(const Key('exportFirstButton')));
      await tester.pumpAndSettle();

      expect(files.written, {'C:/sauvegardes/bastide.bastide': _archive});
      expect(find.text('Restaurer cette sauvegarde ?'), findsOneWidget);
      expect(find.byKey(const Key('exportFirstButton')), findsNothing);
      expect(find.byKey(const Key('modalInPlaceDone')), findsOneWidget);
      expect(find.text('Sauvegarde enregistrée'), findsOneWidget);
      // It stands in for the toast.
      expect(find.textContaining('Sauvegarde enregistrée ·'), findsNothing);
    });

    testWidgets('a cancelled save dialog keeps « Exporter d’abord »', (
      tester,
    ) async {
      files.savePath = null;
      await openModal(tester);

      await tester.tap(find.byKey(const Key('exportFirstButton')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('exportFirstButton')), findsOneWidget);
      expect(find.byKey(const Key('modalInPlaceDone')), findsNothing);
    });

    testWidgets('the modal renders in English', (tester) async {
      await openModal(tester, locale: const Locale('en'));

      expect(find.text('Restore this backup?'), findsOneWidget);
      expect(
        find.text(
          'The data exported on September\u00a011, 2026 replaces all your current '
          'data.',
        ),
        findsOneWidget,
      );
      expect(find.text('Current'), findsOneWidget);
      expect(find.text('Latest import'), findsOneWidget);
      expect(find.text('Export first'), findsOneWidget);
      expect(
        find.text(
          'This backup predates your latest import on September\u00a018, 2026.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders in English', (tester) async {
      useDesktopSurface(tester);
      await tester.pumpWidget(wrap(locale: const Locale('en')));
      await tester.pumpAndSettle();

      expect(find.text('Backup'), findsOneWidget);
      expect(find.text('No backup.'), findsOneWidget);
      expect(find.text('Import a file'), findsOneWidget);
    });
  });
}
