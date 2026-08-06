import 'dart:convert';

import 'package:finstride/core/session/current_user_provider.dart';
import 'package:finstride/core/theme/app_theme.dart';
import 'package:finstride/features/auth/domain/auth_user.dart';
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

const _user = AuthUser(
  id: 'u1',
  email: 'ada@example.com',
  displayName: 'Ada',
  locale: 'fr',
  currency: 'EUR',
);

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

/// An OFX statement declaring a Boursorama checking account ending 4567.
final _ofxBytes = utf8.encode('''
<OFX>
<SIGNONMSGSRSV1><SONRS><FI><ORG>BOURSORAMA BANQUE
</FI></SONRS></SIGNONMSGSRSV1>
<BANKMSGSRSV1><STMTTRNRS><STMTRS>
<CURDEF>EUR
<BANKACCTFROM>
<BANKID>40618
<ACCTID>0001234567
<ACCTTYPE>CHECKING
</BANKACCTFROM>
</STMTRS></STMTTRNRS></BANKMSGSRSV1>
</OFX>
''');

Widget _wrap({
  required FakeImportsController imports,
  required FakeCsvTemplatesController templates,
  required PickedImportFile file,
  FakeAccountsController? accounts,
  Locale locale = const Locale('fr'),
}) {
  return ProviderScope(
    overrides: [
      accountsControllerProvider.overrideWith(
        () => accounts ?? FakeAccountsController(initialAccounts: [_account]),
      ),
      currentUserProvider.overrideWithValue(_user),
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

  testWidgets('an OFX file selects the account it declares', (tester) async {
    _useDesktopSurface(tester);
    final imports = FakeImportsController(importResult: _batch());
    final other = Account(
      id: 'a2',
      name: 'Compte BNP',
      type: AccountType.checking,
      institution: 'BNP Paribas',
      currency: 'EUR',
      openingBalanceMinor: 0,
      balanceMinor: 0,
      archived: false,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );
    await tester.pumpWidget(
      _wrap(
        imports: imports,
        templates: FakeCsvTemplatesController(),
        // The BNP account comes first, so the panel's default selection is the
        // wrong one until the file says otherwise.
        accounts: FakeAccountsController(initialAccounts: [other, _account]),
        file: PickedImportFile(name: 'releve.ofx', bytes: _ofxBytes),
      ),
    );
    await tester.pumpAndSettle();

    await _stageFile(tester);

    expect(find.byKey(const Key('importDetectedAccountBanner')), findsOneWidget);

    await tester.tap(find.byKey(const Key('importSubmitButton')));
    await tester.pumpAndSettle();

    expect(imports.importCalls.single.accountId, 'a1');
  });

  testWidgets('an OFX file for an unknown account opens the prefilled form', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    final imports = FakeImportsController(importResult: _batch());
    final accounts = FakeAccountsController(
      initialAccounts: [
        Account(
          id: 'a2',
          name: 'Compte BNP',
          type: AccountType.checking,
          institution: 'BNP Paribas',
          currency: 'EUR',
          openingBalanceMinor: 0,
          balanceMinor: 0,
          archived: false,
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
      ],
      createdAccount: _account,
    );
    await tester.pumpWidget(
      _wrap(
        imports: imports,
        templates: FakeCsvTemplatesController(),
        accounts: accounts,
        file: PickedImportFile(name: 'releve.ofx', bytes: _ofxBytes),
      ),
    );
    await tester.pumpAndSettle();

    await _stageFile(tester);

    // The form opens on its own, carrying what the statement said.
    expect(find.byKey(const Key('accountFormPrefillNote')), findsOneWidget);
    expect(find.text('Courant ••4567'), findsOneWidget);
    expect(find.text('BOURSORAMA BANQUE'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('accountOpeningBalanceField')), '0');
    await tester.tap(find.byKey(const Key('accountFormSubmitButton')));
    await tester.pumpAndSettle();

    expect(accounts.createCalls.single.institution, 'BOURSORAMA BANQUE');
    expect(accounts.createCalls.single.type, AccountType.checking);
    // The statement's own id is bound to the account, so the next import from
    // it matches on identity rather than on the bank's name.
    expect(accounts.createCalls.single.ofxAccountId, '0001234567');

    // The new account becomes the destination, and the file imports into it.
    expect(find.byKey(const Key('importDetectedAccountBanner')), findsOneWidget);
    await tester.tap(find.byKey(const Key('importSubmitButton')));
    await tester.pumpAndSettle();

    expect(imports.importCalls.single.accountId, 'a1');
  });

  testWidgets('cancelling the offered account leaves it on the banner', (tester) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        imports: FakeImportsController(importResult: _batch()),
        templates: FakeCsvTemplatesController(),
        accounts: FakeAccountsController(initialAccounts: const []),
        file: PickedImportFile(name: 'releve.ofx', bytes: _ofxBytes),
      ),
    );
    await tester.pumpAndSettle();

    await _stageFile(tester);
    await tester.tap(find.byKey(const Key('accountFormCancelButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('importUnknownAccountBanner')), findsOneWidget);

    // The offer stays available rather than being lost with the dialog.
    await tester.tap(find.byKey(const Key('importCreateDetectedAccountButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('accountFormPrefillNote')), findsOneWidget);
  });

  testWidgets('a user with no accounts is not told to create one first', (tester) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        imports: FakeImportsController(),
        templates: FakeCsvTemplatesController(),
        accounts: FakeAccountsController(initialAccounts: const []),
        file: const PickedImportFile(name: 'releve.ofx', bytes: [1, 2, 3]),
      ),
    );
    await tester.pumpAndSettle();

    // Dropping a statement is now how an account gets created, so having none
    // yet is not a prerequisite the panel has to nag about.
    expect(find.byKey(const Key('importNoAccountsBanner')), findsNothing);
    expect(find.byKey(const Key('importDropZone')), findsOneWidget);
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
