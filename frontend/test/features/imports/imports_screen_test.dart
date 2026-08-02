import 'package:finstride/core/theme/app_theme.dart';
import 'package:finstride/features/accounts/application/accounts_controller.dart';
import 'package:finstride/features/accounts/domain/account.dart';
import 'package:finstride/features/imports/application/imports_controller.dart';
import 'package:finstride/features/imports/domain/csv_template.dart';
import 'package:finstride/features/imports/domain/import_batch.dart';
import 'package:finstride/features/imports/presentation/imports_screen.dart';
import 'package:finstride/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_accounts_controller.dart';
import '../../support/fake_imports_controllers.dart';

/// Hands the panel a fixed file instead of opening the native dialog.
class FakeImportFilePicker extends ImportFilePicker {
  const FakeImportFilePicker(this.file);

  final PickedImportFile file;

  @override
  Future<PickedImportFile?> pick() async => file;
}

final _account = Account(
  id: 'a1',
  name: 'Compte courant',
  type: AccountType.checking,
  institution: 'Boursorama',
  currency: 'EUR',
  openingBalanceMinor: 0,
  balanceMinor: 0,
  archived: false,
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
);

ImportBatch _batch({
  ImportFormat format = ImportFormat.ofx,
  String fileName = 'releve.ofx',
  int newCount = 42,
  int duplicateCount = 3,
}) => ImportBatch(
  id: 'b1',
  accountId: 'a1',
  sourceFormat: format,
  fileName: fileName,
  fileHash: 'hash-1',
  periodStart: DateTime(2026, 5, 1),
  periodEnd: DateTime(2026, 5, 31),
  transactionCount: newCount + duplicateCount,
  newCount: newCount,
  duplicateCount: duplicateCount,
  status: ImportStatus.success,
  errorMessage: null,
  importedAt: DateTime(2026, 6, 1, 9, 30),
);

final _savedTemplate = CsvTemplate(
  id: 't1',
  draft: const CsvTemplateDraft(bankName: 'Boursorama'),
  createdAt: DateTime.utc(2026, 5, 1),
);

Widget _wrap({
  required FakeImportsController imports,
  required FakeCsvTemplatesController templates,
  required PickedImportFile file,
  Locale locale = const Locale('fr'),
}) {
  return ProviderScope(
    overrides: [
      accountsControllerProvider.overrideWith(
        () => FakeAccountsController(initialAccounts: [_account]),
      ),
      importsControllerProvider.overrideWith(() => imports),
      csvTemplatesControllerProvider.overrideWith(() => templates),
      importFilePickerProvider.overrideWithValue(FakeImportFilePicker(file)),
    ],
    child: MaterialApp(
      locale: locale,
      theme: appDarkTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: ImportsScreen()),
    ),
  );
}

/// The panel is drawn for the 1440×900 desktop frame the design targets.
void _useDesktopSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> _stageFile(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('importDropZone')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('an OFX file imports in one step and reports its counts', (tester) async {
    _useDesktopSurface(tester);
    final imports = FakeImportsController(importResult: _batch());
    await tester.pumpWidget(
      _wrap(
        imports: imports,
        templates: FakeCsvTemplatesController(),
        file: const PickedImportFile(name: 'releve.ofx', bytes: [1, 2, 3]),
      ),
    );
    await tester.pumpAndSettle();

    await _stageFile(tester);
    expect(find.byKey(const Key('importStagedFileName')), findsOneWidget);
    // No wizard is offered for a self-describing format.
    expect(find.text('Importer'), findsOneWidget);

    await tester.tap(find.byKey(const Key('importSubmitButton')));
    await tester.pumpAndSettle();

    expect(imports.importCalls, hasLength(1));
    expect(imports.importCalls.single.csvTemplateId, isNull);

    expect(find.byKey(const Key('importResultCard')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('importResultNewCount'))).data,
      '42',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('importResultDuplicateCount'))).data,
      '3',
    );
    // The drop zone resets, ready for the next statement.
    expect(find.byKey(const Key('importStagedFileName')), findsNothing);
  });

  testWidgets('a CSV reuses the saved template for that bank without the wizard', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    final imports = FakeImportsController(
      importResult: _batch(format: ImportFormat.csv, fileName: 'export.csv'),
    );
    await tester.pumpWidget(
      _wrap(
        imports: imports,
        templates: FakeCsvTemplatesController(initialTemplates: [_savedTemplate]),
        file: const PickedImportFile(name: 'export.csv', bytes: [1, 2, 3]),
      ),
    );
    await tester.pumpAndSettle();

    await _stageFile(tester);

    expect(find.byKey(const Key('importTemplateReuseBanner')), findsOneWidget);
    expect(find.byKey(const Key('importReconfigureButton')), findsOneWidget);

    await tester.tap(find.byKey(const Key('importSubmitButton')));
    await tester.pumpAndSettle();

    expect(imports.importCalls.single.csvTemplateId, 't1');
    expect(find.byKey(const Key('importResultCard')), findsOneWidget);
  });

  testWidgets('a CSV with no saved template opens the mapping wizard', (tester) async {
    _useDesktopSurface(tester);
    final imports = FakeImportsController(importResult: _batch());
    await tester.pumpWidget(
      _wrap(
        imports: imports,
        templates: FakeCsvTemplatesController(),
        file: const PickedImportFile(name: 'export.csv', bytes: [1, 2, 3]),
      ),
    );
    await tester.pumpAndSettle();

    await _stageFile(tester);
    expect(find.byKey(const Key('importTemplateReuseBanner')), findsNothing);

    await tester.tap(find.byKey(const Key('importSubmitButton')));
    await tester.pumpAndSettle();

    expect(find.text('Assistant CSV'), findsOneWidget);
    // Nothing is imported until the wizard is confirmed.
    expect(imports.importCalls, isEmpty);
  });

  testWidgets('renders under en without missing localized keys', (tester) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        imports: FakeImportsController(),
        templates: FakeCsvTemplatesController(),
        file: const PickedImportFile(name: 'releve.ofx', bytes: [1, 2, 3]),
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('New import'), findsOneWidget);
    expect(find.text('Drop an OFX, QFX or CSV file'), findsOneWidget);
    expect(find.text('No imports yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
