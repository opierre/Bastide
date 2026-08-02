import 'package:finstride/core/api/api_client.dart';
import 'package:finstride/core/theme/app_theme.dart';
import 'package:finstride/features/imports/application/imports_controller.dart';
import 'package:finstride/features/imports/domain/csv_template.dart';
import 'package:finstride/features/imports/domain/import_batch.dart';
import 'package:finstride/features/imports/presentation/csv_mapping_wizard.dart';
import 'package:finstride/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import '../../support/fake_imports_controllers.dart';

const _file = PickedImportFile(name: 'export.csv', bytes: [1, 2, 3]);

final _batch = ImportBatch(
  id: 'b1',
  accountId: 'a1',
  sourceFormat: ImportFormat.csv,
  fileName: 'export.csv',
  fileHash: 'hash-1',
  periodStart: DateTime(2026, 5, 1),
  periodEnd: DateTime(2026, 5, 31),
  transactionCount: 57,
  newCount: 57,
  duplicateCount: 0,
  status: ImportStatus.success,
  errorMessage: null,
  importedAt: DateTime(2026, 6, 1, 9, 30),
);

final _previewRows = [
  CsvPreviewRow(
    bookedDate: DateTime(2026, 5, 4),
    valueDate: null,
    amountMinor: -4250,
    descriptionRaw: 'CARREFOUR MARKET',
  ),
  CsvPreviewRow(
    bookedDate: DateTime(2026, 5, 5),
    valueDate: null,
    amountMinor: 250000,
    descriptionRaw: 'VIREMENT SALAIRE',
  ),
];

Widget _wrap({
  required FakeImportsController imports,
  required FakeCsvTemplatesController templates,
  Locale locale = const Locale('fr'),
}) {
  return ProviderScope(
    overrides: [
      importsControllerProvider.overrideWith(() => imports),
      csvTemplatesControllerProvider.overrideWith(() => templates),
    ],
    child: MaterialApp(
      locale: locale,
      theme: appDarkTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(
        body: CsvMappingWizard(
          accountId: 'a1',
          institution: 'Boursorama',
          file: _file,
          currency: 'EUR',
        ),
      ),
    ),
  );
}

/// Walks the wizard to its second step and fills the three columns a signed
/// layout needs, then lets the preview debounce elapse.
Future<void> _mapSignedColumns(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('csvWizardNextButton')));
  await tester.pumpAndSettle();

  await tester.enterText(
    find.byKey(const Key('csvWizardColumn-booked_date')),
    'Date operation',
  );
  await tester.enterText(find.byKey(const Key('csvWizardColumn-description')), 'Libelle');
  await tester.enterText(find.byKey(const Key('csvWizardColumn-amount')), 'Montant');
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('opens on the format step with French bank defaults', (tester) async {
    await tester.pumpWidget(
      _wrap(imports: FakeImportsController(), templates: FakeCsvTemplatesController()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Assistant CSV'), findsOneWidget);
    expect(find.text('Point-virgule ( ; )'), findsOneWidget);
    expect(find.text('Latin-1 (ISO-8859-1)'), findsOneWidget);
    expect(find.text('dd/MM/yyyy'), findsOneWidget);
    // The bank name is seeded from the account's institution.
    expect(find.widgetWithText(TextFormField, 'Boursorama'), findsOneWidget);
    // Nothing can be confirmed from the format step.
    expect(find.byKey(const Key('csvWizardConfirmButton')), findsNothing);
  });

  testWidgets('holds the preview back until the required columns are mapped', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        imports: FakeImportsController(previewRows: _previewRows),
        templates: FakeCsvTemplatesController(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('csvWizardNextButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('csvWizardPreviewPlaceholder')), findsOneWidget);
    expect(find.byKey(const Key('csvWizardPreviewTable')), findsNothing);
  });

  testWidgets('renders the live preview parsed by the backend', (tester) async {
    final imports = FakeImportsController(previewRows: _previewRows);
    await tester.pumpWidget(
      _wrap(imports: imports, templates: FakeCsvTemplatesController()),
    );
    await tester.pumpAndSettle();
    await _mapSignedColumns(tester);

    expect(find.byKey(const Key('csvWizardPreviewTable')), findsOneWidget);
    expect(find.text('CARREFOUR MARKET'), findsOneWidget);
    expect(find.text('VIREMENT SALAIRE'), findsOneWidget);

    // Amounts stay integer minor units end to end and render signed, in the
    // active locale.
    final money = NumberFormat.currency(locale: 'fr', name: 'EUR');
    expect(find.text(money.format(42.50).replaceAll('-', '−')), findsNothing);
    expect(find.text('−${money.format(42.50)}'), findsOneWidget);
    expect(find.text('+${money.format(2500.00)}'), findsOneWidget);

    // The draft that went to the backend carries the mapping and the defaults.
    final draft = imports.previewCalls.last;
    expect(draft.columnMap['booked_date'], 'Date operation');
    expect(draft.columnMap['amount'], 'Montant');
    expect(draft.delimiter, ';');
    expect(draft.decimalSeparator, ',');
    expect(draft.amountStrategy, AmountStrategy.signed);
  });

  testWidgets('a mapping the file rejects is caught before any import', (tester) async {
    final imports = FakeImportsController(
      errorOnPreview: const ApiFailure(
        code: 'CSV_TEMPLATE_INVALID',
        message: "Column 'Montant' not found in header",
      ),
    );
    await tester.pumpWidget(
      _wrap(imports: imports, templates: FakeCsvTemplatesController()),
    );
    await tester.pumpAndSettle();
    await _mapSignedColumns(tester);

    expect(find.byKey(const Key('csvWizardPreviewError')), findsOneWidget);
    expect(
      find.text("Ce paramétrage ne correspond pas au fichier — ajustez les colonnes ci-dessus."),
      findsOneWidget,
    );
    // The parser's own detail is kept, since it names the offending column.
    expect(find.text("Column 'Montant' not found in header"), findsOneWidget);

    // Confirm stays unavailable, so nothing reaches the import endpoint.
    await tester.tap(find.byKey(const Key('csvWizardConfirmButton')));
    await tester.pumpAndSettle();
    expect(imports.importCalls, isEmpty);
  });

  testWidgets('confirming saves the template and imports with it', (tester) async {
    final imports = FakeImportsController(
      previewRows: _previewRows,
      importResult: _batch,
    );
    final templates = FakeCsvTemplatesController();
    await tester.pumpWidget(_wrap(imports: imports, templates: templates));
    await tester.pumpAndSettle();
    await _mapSignedColumns(tester);

    await tester.tap(find.byKey(const Key('csvWizardConfirmButton')));
    await tester.pumpAndSettle();

    // The mapping is saved first: the import endpoint identifies a CSV by its
    // template id, so the template has to exist before the upload.
    expect(templates.createCalls, hasLength(1));
    expect(templates.createCalls.single.bankName, 'Boursorama');
    expect(imports.importCalls, hasLength(1));
    expect(imports.importCalls.single.csvTemplateId, 't-new');
    expect(imports.importCalls.single.accountId, 'a1');
  });

  testWidgets('the debit/credit layout asks for both columns instead of one amount', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(imports: FakeImportsController(), templates: FakeCsvTemplatesController()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Débit / Crédit'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('csvWizardNextButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('csvWizardColumn-debit')), findsOneWidget);
    expect(find.byKey(const Key('csvWizardColumn-credit')), findsOneWidget);
    expect(find.byKey(const Key('csvWizardColumn-amount')), findsNothing);
  });

  testWidgets('renders under en without missing localized keys', (tester) async {
    await tester.pumpWidget(
      _wrap(
        imports: FakeImportsController(previewRows: _previewRows),
        templates: FakeCsvTemplatesController(),
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('CSV wizard'), findsOneWidget);
    expect(find.text('Semicolon ( ; )'), findsOneWidget);

    await _mapSignedColumns(tester);

    expect(find.byKey(const Key('csvWizardPreviewTable')), findsOneWidget);
    final money = NumberFormat.currency(locale: 'en', name: 'EUR');
    expect(find.text('−${money.format(42.50)}'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
