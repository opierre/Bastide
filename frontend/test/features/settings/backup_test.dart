import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:finstride/core/api/api_client.dart';
import 'package:finstride/core/api/api_client_provider.dart';
import 'package:finstride/core/theme/app_theme.dart';
import 'package:finstride/features/settings/application/backup_controller.dart';
import 'package:finstride/features/settings/application/settings_controller.dart';
import 'package:finstride/features/settings/domain/backup.dart';
import 'package:finstride/features/settings/presentation/backup_card.dart';
import 'package:finstride/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

/// Stands in for the platform file dialogs.
class FakeBackupFiles implements BackupFiles {
  String? savePath = 'C:/sauvegardes/finstride';
  ({String name, Uint8List bytes})? picked;
  final written = <String, Uint8List>{};

  @override
  Future<String?> chooseSaveLocation(String suggestedName) async => savePath;

  @override
  Future<void> write(String path, Uint8List bytes) async => written[path] = bytes;

  @override
  Future<({String name, Uint8List bytes})?> pick() async => picked;
}

final _exportedAt = DateTime.utc(2026, 9, 11, 12, 32);

Map<String, dynamic> _summaryJson({int transactions = 1284, int accounts = 4}) => {
  'format_version': 1,
  'app_version': '0.1.0',
  'exported_at': _exportedAt.toIso8601String(),
  'currency': 'EUR',
  'counts': {
    'accounts': accounts,
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

Map<String, dynamic> _settingsJson({String? lastBackupAt}) => {
  'ai_enabled': false,
  'inference_base_url': 'http://127.0.0.1:11434/v1',
  'model_tag': null,
  'confidence_threshold': 0.8,
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
    when(() => apiClient.get('/settings')).thenAnswer((_) async => _settingsJson());
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

    BackupController controller() => container.read(backupControllerProvider.notifier);

    test('export writes the archive where the user chose and records the time', () async {
      stubExport();
      await container.read(settingsControllerProvider.future);

      final summary = await controller().export();

      expect(summary?.counts.transactions, 1284);
      expect(files.written, {'C:/sauvegardes/finstride.finstride': _archive});
      expect(
        container.read(settingsControllerProvider).value?.settings.lastBackupAt,
        _exportedAt,
      );
      expect(container.read(backupControllerProvider).isExporting, isFalse);
    });

    test('cancelling the save dialog builds nothing', () async {
      files.savePath = null;

      expect(await controller().export(), isNull);
      verifyNever(() => apiClient.postForBytes(any()));
    });

    test('a file from a newer version is refused before the modal', () async {
      files.picked = (name: 'future.finstride', bytes: _archive);
      stubUpload('/backup/inspect', throws: failure('BACKUP_TOO_NEW'));

      expect(await controller().pickForRestore(), isNull);
      expect(container.read(backupControllerProvider).restoreFailure, BackupFailure.tooNew);
    });

    test('a readable file comes back with its summary, and clears a past refusal', () async {
      files.picked = (name: 'future.finstride', bytes: _archive);
      stubUpload('/backup/inspect', throws: failure('BACKUP_INVALID'));
      await controller().pickForRestore();
      stubUpload('/backup/inspect');

      final pending = await controller().pickForRestore();

      expect(pending?.fileName, 'future.finstride');
      expect(pending?.summary.counts.accounts, 4);
      expect(container.read(backupControllerProvider).restoreFailure, isNull);
    });

    test('a refused restore surfaces as a typed failure', () async {
      stubUpload('/backup/restore', throws: failure('BACKUP_CONFLICT'));
      final pending = PendingRestore(
        fileName: 'x.finstride',
        bytes: _archive,
        summary: BackupSummary.fromJson(_summaryJson()),
      );

      expect(
        () => controller().restore(pending),
        throwsA(
          isA<BackupException>().having((e) => e.failure, 'failure', BackupFailure.conflict),
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
        theme: appDarkTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: SingleChildScrollView(child: SizedBox(width: 640, child: BackupCard())),
        ),
      ),
    );

    testWidgets('⑤ idle shows the last backup in local time', (tester) async {
      when(
        () => apiClient.get('/settings'),
      ).thenAnswer((_) async => _settingsJson(lastBackupAt: '2026-09-11T12:32:00Z'));

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      final local = _exportedAt.toLocal();
      final expected =
          'Dernière sauvegarde : ${DateFormat.yMd('fr').format(local)} '
          'à ${DateFormat.Hm('fr').format(local)}';
      expect(find.text(expected), findsOneWidget);
      expect(find.byKey(const Key('settingsBackupPrivacy')), findsOneWidget);
      expect(find.byKey(const Key('settingsBackupRestoreError')), findsNothing);
    });

    testWidgets('says so when there has never been a backup', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.text("Aucune sauvegarde pour l'instant."), findsOneWidget);
    });

    testWidgets('⑥ then ⑦: preparing caption, then the toast with counts', (tester) async {
      final pending = Completer<ApiBytesResponse>();
      when(() => apiClient.postForBytes('/backup/export')).thenAnswer((_) => pending.future);

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settingsBackupExportButton')));
      await tester.pump();

      expect(find.text("Préparation de l'archive…"), findsOneWidget);

      pending.complete(
        ApiBytesResponse(
          bytes: _archive,
          headers: {'x-backup-summary': jsonEncode(_summaryJson())},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Sauvegarde enregistrée — 1'), findsOneWidget);
      expect(find.textContaining('transactions, 4 comptes.'), findsOneWidget);
      expect(find.textContaining('Dernière sauvegarde :'), findsOneWidget);
      // Let the toast's timer run out so no timer outlives the test.
      await tester.pump(const Duration(seconds: 7));
    });

    testWidgets('⑨ a newer-version file shows the refusal in the card', (tester) async {
      files.picked = (name: 'future.finstride', bytes: _archive);
      stubUpload('/backup/inspect', throws: failure('BACKUP_TOO_NEW'));

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settingsBackupRestoreButton')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('settingsBackupRestoreError')), findsOneWidget);
      expect(find.textContaining('Restauration impossible.'), findsOneWidget);
      expect(find.textContaining('version plus récente'), findsOneWidget);
      expect(find.byKey(const Key('backupConfirmSummary')), findsNothing);
    });

    testWidgets('⑧ confirms with the file summary, then restores', (tester) async {
      files.picked = (name: 'finstride-2026-09-11.finstride', bytes: _archive);
      stubUpload('/backup/inspect');
      stubUpload('/backup/restore');

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settingsBackupRestoreButton')));
      await tester.pumpAndSettle();

      expect(find.text('Restaurer cette sauvegarde ?'), findsOneWidget);
      expect(find.textContaining('finstride-2026-09-11.finstride'), findsOneWidget);
      expect(find.text('0.1.0'), findsOneWidget);
      expect(find.text('30'), findsOneWidget);
      expect(find.byKey(const Key('backupConfirmWarning')), findsOneWidget);
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

    testWidgets('a refused restore keeps the modal open with the reason', (tester) async {
      files.picked = (name: 'x.finstride', bytes: _archive);
      stubUpload('/backup/inspect');
      stubUpload('/backup/restore', throws: failure('BACKUP_RUN_ACTIVE'));

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settingsBackupRestoreButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('backupConfirmReplace')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('backupConfirmError')), findsOneWidget);
      expect(find.textContaining('catégorisation est en cours'), findsOneWidget);
    });

    testWidgets('renders in English', (tester) async {
      await tester.pumpWidget(wrap(locale: const Locale('en')));
      await tester.pumpAndSettle();

      expect(find.text('Backup & restore'), findsOneWidget);
      expect(find.text('No backup yet.'), findsOneWidget);
      expect(find.text('Import a file…'), findsOneWidget);
    });
  });
}
