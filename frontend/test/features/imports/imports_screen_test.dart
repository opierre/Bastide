import 'dart:convert';

import 'package:bastide/core/session/current_user_provider.dart';
import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/core/widgets/amount_text.dart';
import 'package:bastide/core/widgets/app_chip.dart';
import 'package:bastide/core/widgets/primary_button.dart';
import 'package:bastide/features/auth/domain/auth_user.dart';
import 'package:bastide/features/accounts/application/accounts_controller.dart';
import 'package:bastide/features/accounts/domain/account.dart';
import 'package:bastide/features/imports/application/imports_controller.dart';
import 'package:bastide/features/imports/domain/import_batch.dart';
import 'package:bastide/features/imports/presentation/imports_screen.dart';
import 'package:bastide/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

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
  int? balanceMismatchMinor,
  DateTime? balanceMismatchAsOf,
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
  balanceMismatchMinor: balanceMismatchMinor,
  balanceMismatchAsOf: balanceMismatchAsOf,
  importedAt: DateTime(2026, 6, 1, 9, 30),
);

/// An OFX statement declaring a Boursorama checking account ending 4567, and
/// the balance that account closed the period at.
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
<LEDGERBAL>
<BALAMT>1234.56
<DTASOF>20260131
</LEDGERBAL>
</STMTRS></STMTTRNRS></BANKMSGSRSV1>
</OFX>
''');

Widget _wrap({
  required FakeImportsController imports,
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
  testWidgets('an OFX file imports in one step and reports its counts', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    final imports = FakeImportsController(importResult: _batch());
    await tester.pumpWidget(
      _wrap(
        imports: imports,
        file: PickedImportFile(name: 'releve.ofx', bytes: _ofxBytes),
      ),
    );
    await tester.pumpAndSettle();

    await _stageFile(tester);
    expect(find.byKey(const Key('importStagedFileName')), findsOneWidget);
    expect(find.text('Importer'), findsOneWidget);

    await tester.tap(find.byKey(const Key('importSubmitButton')));
    await tester.pumpAndSettle();

    expect(imports.importCalls, hasLength(1));

    expect(find.byKey(const Key('importResultCard')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('importResultNewCount'))).data,
      '42',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('importResultDuplicateCount')))
          .data,
      '3',
    );
    // The drop zone resets, ready for the next statement.
    expect(find.byKey(const Key('importStagedFileName')), findsNothing);
  });

  testWidgets('a result that disagrees with the bank shows a warning banner', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    final imports = FakeImportsController(
      importResult: _batch(
        balanceMismatchMinor: 5925,
        balanceMismatchAsOf: DateTime(2024, 2, 29),
      ),
    );
    await tester.pumpWidget(
      _wrap(
        imports: imports,
        file: PickedImportFile(name: 'releve.ofx', bytes: _ofxBytes),
      ),
    );
    await tester.pumpAndSettle();

    await _stageFile(tester);
    await tester.tap(find.byKey(const Key('importSubmitButton')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('importResultBalanceMismatch')),
      findsOneWidget,
    );
    final amount = formatAmount(
      amountMinor: 5925,
      currency: 'EUR',
      locale: 'fr',
      showPositiveSign: true,
    );
    final date = DateFormat.yMd('fr').format(DateTime(2024, 2, 29));
    expect(
      find.text(
        "Le relevé indique un solde à $amount de votre suivi au $date. "
        "Vérifiez un import manquant, ou corrigez le solde d'ouverture du "
        "compte si l'écart persiste.",
      ),
      findsOneWidget,
    );
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
        // The BNP account comes first, so the panel's default selection is the
        // wrong one until the file says otherwise.
        accounts: FakeAccountsController(initialAccounts: [other, _account]),
        file: PickedImportFile(name: 'releve.ofx', bytes: _ofxBytes),
      ),
    );
    await tester.pumpAndSettle();

    await _stageFile(tester);

    expect(
      find.byKey(const Key('importDetectedAccountBanner')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('importSubmitButton')));
    await tester.pumpAndSettle();

    expect(imports.importCalls.single.accountId, 'a1');
  });

  testWidgets('an ambiguous statement asks, and imports into what was picked', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    final imports = FakeImportsController(importResult: _batch());
    final other = Account(
      id: 'a2',
      name: 'Compte joint',
      type: AccountType.checking,
      institution: 'Boursorama',
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
        // Two checking accounts at the bank the statement names, and nothing in
        // the file to separate them — the one case the file can't settle alone.
        accounts: FakeAccountsController(initialAccounts: [_account, other]),
        file: PickedImportFile(name: 'releve.ofx', bytes: _ofxBytes),
      ),
    );
    await tester.pumpAndSettle();

    await _stageFile(tester);

    expect(
      find.byKey(const Key('importAmbiguousAccountBanner')),
      findsOneWidget,
    );
    // Nothing has named a destination, so there is nothing to import yet.
    expect(
      tester
          .widget<PrimaryButton>(find.byKey(const Key('importSubmitButton')))
          .onPressed,
      isNull,
    );

    await tester.tap(find.byKey(const Key('importAmbiguousAccountField')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Compte joint').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('importSubmitButton')));
    await tester.pumpAndSettle();

    expect(imports.importCalls.single.accountId, 'a2');
  });

  testWidgets('the ambiguity picker offers only the accounts the file allows', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    final joint = Account(
      id: 'a2',
      name: 'Compte joint',
      type: AccountType.checking,
      institution: 'Boursorama',
      currency: 'EUR',
      openingBalanceMinor: 0,
      balanceMinor: 0,
      archived: false,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );
    final elsewhere = Account(
      id: 'a3',
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
        imports: FakeImportsController(importResult: _batch()),
        accounts: FakeAccountsController(
          initialAccounts: [_account, joint, elsewhere],
        ),
        file: PickedImportFile(name: 'releve.ofx', bytes: _ofxBytes),
      ),
    );
    await tester.pumpAndSettle();

    await _stageFile(tester);
    await tester.tap(find.byKey(const Key('importAmbiguousAccountField')));
    await tester.pumpAndSettle();

    // The statement is Boursorama's, so the BNP account is not a destination
    // the user should be able to pick by accident.
    expect(find.text('Compte joint'), findsOneWidget);
    expect(find.text('Compte BNP'), findsNothing);
  });

  testWidgets('a file declaring no account falls back to the full list', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    final imports = FakeImportsController(importResult: _batch());
    await tester.pumpWidget(
      _wrap(
        imports: imports,
        accounts: FakeAccountsController(initialAccounts: [_account]),
        // Not a statement at all: nothing can be read out of it, so the panel
        // has to ask rather than leave the user stuck.
        file: const PickedImportFile(name: 'releve.ofx', bytes: [1, 2, 3]),
      ),
    );
    await tester.pumpAndSettle();

    await _stageFile(tester);

    expect(
      find.byKey(const Key('importUnreadableAccountBanner')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<PrimaryButton>(find.byKey(const Key('importSubmitButton')))
          .onPressed,
      isNull,
    );

    await tester.tap(find.byKey(const Key('importUnreadableAccountField')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Compte courant').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('importSubmitButton')));
    await tester.pumpAndSettle();

    expect(imports.importCalls.single.accountId, 'a1');
  });

  testWidgets('a choice made for one statement does not carry to the next', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    final imports = FakeImportsController(importResult: _batch());
    await tester.pumpWidget(
      _wrap(
        imports: imports,
        accounts: FakeAccountsController(initialAccounts: [_account]),
        file: const PickedImportFile(name: 'releve.ofx', bytes: [1, 2, 3]),
      ),
    );
    await tester.pumpAndSettle();

    await _stageFile(tester);
    await tester.tap(find.byKey(const Key('importUnreadableAccountField')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Compte courant').last);
    await tester.pumpAndSettle();

    // Drop a second unreadable file without importing the first.
    await tester.tap(find.byKey(const Key('importRemoveFileButton')));
    await tester.pumpAndSettle();
    await _stageFile(tester);

    // The answer to the previous statement says nothing about this one.
    expect(
      tester
          .widget<PrimaryButton>(find.byKey(const Key('importSubmitButton')))
          .onPressed,
      isNull,
    );
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

    // Nothing left to fill in: the statement declared its balance, so the form
    // submits as it opened.
    await tester.tap(find.byKey(const Key('accountFormSubmitButton')));
    await tester.pumpAndSettle();

    expect(accounts.createCalls.single.institution, 'BOURSORAMA BANQUE');
    expect(accounts.createCalls.single.type, AccountType.checking);
    expect(accounts.createCalls.single.openingBalanceMinor, 123456);
    // The statement's own id is bound to the account, so the next import from
    // it matches on identity rather than on the bank's name.
    expect(accounts.createCalls.single.ofxAccountId, '0001234567');

    // The new account becomes the destination, and the file imports into it.
    expect(
      find.byKey(const Key('importDetectedAccountBanner')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('importSubmitButton')));
    await tester.pumpAndSettle();

    expect(imports.importCalls.single.accountId, 'a1');
  });

  testWidgets('cancelling the offered account leaves it on the banner', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        imports: FakeImportsController(importResult: _batch()),
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
    await tester.tap(
      find.byKey(const Key('importCreateDetectedAccountButton')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('accountFormPrefillNote')), findsOneWidget);
  });

  testWidgets('a user with no accounts is not told to create one first', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        imports: FakeImportsController(),
        accounts: FakeAccountsController(initialAccounts: const []),
        file: PickedImportFile(name: 'releve.ofx', bytes: _ofxBytes),
      ),
    );
    await tester.pumpAndSettle();

    // Dropping a statement is now how an account gets created, so having none
    // yet is not a prerequisite the panel has to nag about.
    expect(find.byKey(const Key('importNoAccountsBanner')), findsNothing);
    expect(find.byKey(const Key('importDropZone')), findsOneWidget);
  });

  testWidgets('the detected-account notice fits a short window', (
    tester,
  ) async {
    // The notice grows the import card, squeezing the history beneath it. On a
    // window this short that used to overflow the empty state's column.
    tester.view.physicalSize = const Size(1280, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _wrap(
        imports: FakeImportsController(),
        accounts: FakeAccountsController(
          initialAccounts: const [],
          createdAccount: _account,
        ),
        file: PickedImportFile(name: 'releve.ofx', bytes: _ofxBytes),
      ),
    );
    await tester.pumpAndSettle();

    await _stageFile(tester);

    expect(find.byKey(const Key('accountFormPrefillNote')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('every history value column is centred under its own header', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        imports: FakeImportsController(initialBatches: [_batch()]),
        file: PickedImportFile(name: 'releve.ofx', bytes: _ofxBytes),
      ),
    );
    await tester.pumpAndSettle();

    void centredUnder(String header, Finder value) {
      expect(
        tester.getRect(value).center.dx,
        closeTo(tester.getRect(find.text(header.toUpperCase())).center.dx, 1),
        reason: '$header column',
      );
    }

    final row = find.byKey(const Key('importBatchRow-b1'));
    Finder inRow(Finder matching) =>
        find.descendant(of: row, matching: matching);

    centredUnder('Format', inRow(find.text('OFX')));
    centredUnder('Importé le', inRow(find.text('01/06/2026')));
    centredUnder('Nouvelles', inRow(find.text('42')));
    centredUnder('Doublons', inRow(find.text('3')));
    // The pill, not its label — the status chip carries a leading glyph, so its text sits
    // right of its own centre by design.
    centredUnder(
      'Statut',
      find.ancestor(
        of: inRow(find.text('Réussi')),
        matching: find.byType(AppChip),
      ),
    );

    // The file column keeps its leading edge: it carries a wrapped name and its notes, which
    // centred would read as misaligned rather than as a value under a header.
    expect(
      tester.getRect(inRow(find.text('releve.ofx'))).left,
      closeTo(tester.getRect(find.text('FICHIER')).left, 1),
    );
  });

  testWidgets('renders under en without missing localized keys', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        imports: FakeImportsController(),
        file: PickedImportFile(name: 'releve.ofx', bytes: _ofxBytes),
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('New import'), findsOneWidget);
    expect(find.text('Drop an OFX or QFX file'), findsOneWidget);
    expect(find.text('No imports yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
