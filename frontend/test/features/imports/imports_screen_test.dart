import 'dart:async';
import 'dart:convert';

import 'package:bastide/core/session/current_user_provider.dart';
import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/core/widgets/amount_text.dart';
import 'package:bastide/core/widgets/app_table.dart';
import 'package:bastide/core/widgets/primary_button.dart';
import 'package:bastide/features/accounts/application/accounts_controller.dart';
import 'package:bastide/features/accounts/application/settlement_rule_controller.dart';
import 'package:bastide/features/accounts/domain/account.dart';
import 'package:bastide/features/accounts/domain/card_settlement_status.dart';
import 'package:bastide/features/auth/domain/auth_user.dart';
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
  String id = 'b1',
  String accountId = 'a1',
  ImportFormat format = ImportFormat.ofx,
  String fileName = 'releve.ofx',
  int newCount = 42,
  int duplicateCount = 3,
  int? balanceMismatchMinor,
  DateTime? balanceMismatchAsOf,
}) => ImportBatch(
  id: id,
  accountId: accountId,
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

/// A card statement: a `CCACCTFROM` block, which carries no `ACCTTYPE`.
final _cardOfxBytes = utf8.encode('''
<OFX>
<SIGNONMSGSRSV1><SONRS><FI><ORG>BOURSORAMA BANQUE
</FI></SONRS></SIGNONMSGSRSV1>
<CREDITCARDMSGSRSV1><CCSTMTTRNRS><CCSTMTRS>
<CURDEF>EUR
<CCACCTFROM>
<ACCTID>5555444433339876
</CCACCTFROM>
<LEDGERBAL>
<BALAMT>-452.10
<DTASOF>20260131
</LEDGERBAL>
</CCSTMTRS></CCSTMTTRNRS></CREDITCARDMSGSRSV1>
</OFX>
''');

Widget _wrap({
  required FakeImportsController imports,
  required PickedImportFile file,
  FakeAccountsController? accounts,
  Locale locale = const Locale('fr'),
  ThemeData? theme,
  List<CardSettlementIssue> settlements = const [],
}) {
  return ProviderScope(
    overrides: [
      accountsControllerProvider.overrideWith(
        () => accounts ?? FakeAccountsController(initialAccounts: [_account]),
      ),
      currentUserProvider.overrideWithValue(_user),
      importsControllerProvider.overrideWith(() => imports),
      importFilePickerProvider.overrideWithValue(FakeImportFilePicker(file)),
      cardSettlementStatusProvider.overrideWith((ref) async => settlements),
    ],
    child: MaterialApp(
      locale: locale,
      theme: theme ?? AppTheme.dark,
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

/// The line of the single checking statement in [_ofxBytes].
const _statement = '0001234567';
const _submit = Key('importSubmitButton-$_statement');

/// An OFX document whose statement declares no account number.
final _noAccountOfxBytes = utf8.encode('''
<OFX>
<BANKMSGSRSV1><STMTTRNRS><STMTRS>
<CURDEF>EUR
</STMTRS></STMTTRNRS></BANKMSGSRSV1>
</OFX>
''');

VoidCallback? _onPressed(WidgetTester tester, Key key) => switch (tester.widget(
  find.byKey(key),
)) {
  PrimaryButton(:final onPressed) || AppButton(:final onPressed) => onPressed,
  final other => throw StateError('not a button: $other'),
};

/// Lets the toast and the history highlight run out, so no timer outlives
/// the test.
Future<void> _settleTimers(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

Future<void> _stageFile(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('importDropZone')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('an OFX file imports in one step and confirms with a toast', (
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
    expect(
      find.byKey(const Key('importStagedFileName-$_statement')),
      findsOneWidget,
    );
    // The drop target stays, ready for the next statement.
    expect(find.byKey(const Key('importDropZone')), findsOneWidget);

    await tester.tap(find.byKey(_submit));
    await tester.pump();
    await tester.pump();

    expect(imports.importCalls, hasLength(1));
    expect(find.byKey(const Key('appToast')), findsOneWidget);
    expect(
      find.text('42 nouvelles opérations · 3 doublons ignorés'),
      findsOneWidget,
    );
    // The line leaves and the batch tops the history, highlighted.
    expect(
      find.byKey(const Key('importStagedFileName-$_statement')),
      findsNothing,
    );
    final row = find.byKey(const Key('importBatchRow-b1'));
    expect(tester.widget<AppTableRow>(row).selected, isTrue);

    await _settleTimers(tester);
    expect(tester.widget<AppTableRow>(row).selected, isFalse);
    expect(find.byKey(const Key('appToast')), findsNothing);
  });

  testWidgets('a failed import is confirmed as changing nothing', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    final failed = ImportBatch(
      id: 'b9',
      accountId: 'a1',
      sourceFormat: ImportFormat.ofx,
      fileName: 'releve.ofx',
      fileHash: 'hash-9',
      periodStart: DateTime(2026, 5, 1),
      periodEnd: DateTime(2026, 5, 31),
      transactionCount: 0,
      newCount: 0,
      duplicateCount: 0,
      status: ImportStatus.failed,
      errorMessage: 'bad header',
      balanceMismatchMinor: null,
      balanceMismatchAsOf: null,
      importedAt: DateTime(2026, 6, 1, 9, 30),
    );
    await tester.pumpWidget(
      _wrap(
        imports: FakeImportsController(importResult: failed),
        file: PickedImportFile(name: 'releve.ofx', bytes: _ofxBytes),
      ),
    );
    await tester.pumpAndSettle();
    await _stageFile(tester);
    await tester.tap(find.byKey(_submit));
    await tester.pump();
    await tester.pump();

    final toast = find.byKey(const Key('appToast'));
    expect(
      find.descendant(
        of: toast,
        matching: find.text('Fichier illisible. Rien n’a été modifié.'),
      ),
      findsOneWidget,
    );
    await _settleTimers(tester);
  });

  testWidgets('while importing, the line shows the spinner and stays', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    final gate = Completer<void>();
    await tester.pumpWidget(
      _wrap(
        imports: FakeImportsController(
          importResult: _batch(),
          gate: gate.future,
        ),
        file: PickedImportFile(name: 'releve.ofx', bytes: _ofxBytes),
      ),
    );
    await tester.pumpAndSettle();
    await _stageFile(tester);
    await tester.tap(find.byKey(_submit));
    await tester.pump();

    expect(find.byKey(const Key('appButtonSpinner')), findsOneWidget);
    expect(find.text('Import…'), findsOneWidget);
    expect(
      _onPressed(tester, const Key('importRemoveFileButton-$_statement')),
      isNull,
    );

    gate.complete();
    await tester.pump();
    await tester.pump();
    await _settleTimers(tester);
  });

  testWidgets('an import that throws keeps the line and says why', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        imports: FakeImportsController(errorOnImport: Exception('offline')),
        file: PickedImportFile(name: 'releve.ofx', bytes: _ofxBytes),
      ),
    );
    await tester.pumpAndSettle();
    await _stageFile(tester);
    await tester.tap(find.byKey(_submit));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('importErrorBanner')), findsOneWidget);
    expect(
      find.byKey(const Key('importStatementLine-$_statement')),
      findsOneWidget,
    );
  });

  testWidgets('a recognised account is named on its line', (tester) async {
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
        // The BNP account comes first, so a "first account" default would be
        // the wrong one until the file says otherwise.
        accounts: FakeAccountsController(initialAccounts: [other, _account]),
        file: PickedImportFile(name: 'releve.ofx', bytes: _ofxBytes),
      ),
    );
    await tester.pumpAndSettle();

    await _stageFile(tester);

    final line = find.byKey(const Key('importStatementLine-$_statement'));
    expect(
      find.byKey(const Key('importDetectedAccountBanner-$_statement')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: line, matching: find.text('Compte reconnu')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: line, matching: find.text('Compte courant')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(_submit));
    await tester.pump();
    await tester.pump();

    expect(imports.importCalls.single.accountId, 'a1');
    await _settleTimers(tester);
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
      find.byKey(const Key('importAmbiguousAccountBanner-$_statement')),
      findsOneWidget,
    );
    expect(find.text('Plusieurs comptes correspondent'), findsOneWidget);
    // Nothing has named a destination, so there is nothing to import yet.
    expect(_onPressed(tester, _submit), isNull);

    await tester.tap(
      find.byKey(const Key('importAmbiguousAccountField-$_statement')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Compte joint').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(_submit));
    await tester.pump();
    await tester.pump();

    expect(imports.importCalls.single.accountId, 'a2');
    await _settleTimers(tester);
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
    await tester.tap(
      find.byKey(const Key('importAmbiguousAccountField-$_statement')),
    );
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
        file: PickedImportFile(name: 'releve.ofx', bytes: _noAccountOfxBytes),
      ),
    );
    await tester.pumpAndSettle();

    await _stageFile(tester);

    expect(
      find.byKey(const Key('importUnreadableAccountBanner')),
      findsOneWidget,
    );
    expect(find.text('Aucun compte indiqué'), findsOneWidget);
    expect(_onPressed(tester, const Key('importSubmitButton')), isNull);

    await tester.tap(find.byKey(const Key('importUnreadableAccountField')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Compte courant').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('importSubmitButton')));
    await tester.pump();
    await tester.pump();

    expect(imports.importCalls.single.accountId, 'a1');
    await _settleTimers(tester);
  });

  testWidgets('a file that is not a statement can only be removed', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        imports: FakeImportsController(),
        file: const PickedImportFile(name: 'releve.ofx', bytes: [1, 2, 3]),
      ),
    );
    await tester.pumpAndSettle();
    await _stageFile(tester);

    expect(find.byKey(const Key('importUnreadableFileBanner')), findsOneWidget);
    expect(
      find.text('Fichier illisible. Rien n’a été modifié.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('importSubmitButton')), findsNothing);

    await tester.tap(find.byKey(const Key('importRemoveFileButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('importStatementLine')), findsNothing);
  });

  testWidgets('a CSV is reported as a format the panel does not take', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        imports: FakeImportsController(),
        file: PickedImportFile(
          name: 'export.csv',
          bytes: utf8.encode('date;montant\n2026-05-01;-12.40\n'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _stageFile(tester);

    expect(find.text('Format non pris en charge.'), findsOneWidget);
    expect(find.byKey(const Key('importSubmitButton')), findsNothing);
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
        file: PickedImportFile(name: 'releve.ofx', bytes: _noAccountOfxBytes),
      ),
    );
    await tester.pumpAndSettle();

    await _stageFile(tester);
    await tester.tap(find.byKey(const Key('importUnreadableAccountField')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Compte courant').last);
    await tester.pumpAndSettle();

    // Remove it and select the same kind of file again without importing.
    await tester.tap(find.byKey(const Key('importRemoveFileButton')));
    await tester.pumpAndSettle();
    await _stageFile(tester);

    // The answer to the previous statement says nothing about this one.
    expect(_onPressed(tester, const Key('importSubmitButton')), isNull);
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
    expect(accounts.createCalls.single.ofxAccountId, _statement);

    // The new account becomes the destination, and the file imports into it.
    expect(
      find.byKey(const Key('importDetectedAccountBanner-$_statement')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(_submit));
    await tester.pump();
    await tester.pump();

    expect(imports.importCalls.single.accountId, 'a1');
    await _settleTimers(tester);
  });

  testWidgets('a card statement proposes a deferred-debit card', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    final imports = FakeImportsController(importResult: _batch());
    // The user's one account, at another bank: not the card's, but the only
    // account the card can be paid from.
    final lcl = Account(
      id: 'lcl',
      name: 'Courant',
      type: AccountType.checking,
      institution: 'LCL',
      currency: 'EUR',
      openingBalanceMinor: 0,
      balanceMinor: 0,
      archived: false,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );
    final accounts = FakeAccountsController(
      initialAccounts: [lcl],
      createdAccount: _account,
    );
    await tester.pumpWidget(
      _wrap(
        imports: imports,
        accounts: accounts,
        file: PickedImportFile(name: 'carte.ofx', bytes: _cardOfxBytes),
      ),
    );
    await tester.pumpAndSettle();

    await _stageFile(tester);

    // Named for what it is, not for an answer the user hasn't given yet.
    expect(find.text('Carte ••9876'), findsOneWidget);
    expect(find.byKey(const Key('accountCardDebitField')), findsOneWidget);

    await tester.tap(find.byKey(const Key('accountFormSubmitButton')));
    await tester.pumpAndSettle();

    expect(accounts.createCalls.single.type, AccountType.deferredCard);
    expect(accounts.createCalls.single.openingBalanceMinor, -45210);
    expect(accounts.createCalls.single.ofxAccountId, '5555444433339876');
    expect(accounts.createCalls.single.settlementAccountId, 'lcl');
  });

  testWidgets('cancelling the offered account leaves it on the line', (
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

    expect(
      find.byKey(const Key('importUnknownAccountBanner-$_statement')),
      findsOneWidget,
    );
    expect(
      find.text('Compte inconnu : BOURSORAMA BANQUE ••4567'),
      findsOneWidget,
    );
    expect(_onPressed(tester, _submit), isNull);

    // The offer stays available rather than being lost with the dialog.
    await tester.tap(
      find.byKey(const Key('importCreateDetectedAccountButton-$_statement')),
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

    // Dropping a statement is how an account gets created, so having none
    // yet is not a prerequisite the panel has to nag about.
    expect(find.byKey(const Key('importNoAccountsBanner')), findsNothing);
    expect(find.byKey(const Key('importDropZone')), findsOneWidget);
    expect(find.text('Déposez un relevé OFX ou QFX'), findsOneWidget);
    expect(find.text('Parcourir'), findsOneWidget);
  });

  testWidgets('the detected-account line fits a short window', (tester) async {
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

  for (final (name, theme) in [
    ('dark', AppTheme.dark),
    ('light', AppTheme.light),
  ]) {
    for (final width in [1440.0 - 224, 1440.0 - 56]) {
      testWidgets(
        'lays out in the $name theme in a ${width.toInt()} px panel',
        (tester) async {
          // The content region at 1440 × 900, beside the expanded and the
          // collapsed sidebar, under the 48 px title bar.
          tester.view.physicalSize = Size(width, 900 - 48);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);
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
          await tester.pumpWidget(
            _wrap(
              imports: FakeImportsController(
                initialBatches: [
                  _batch(),
                  _batch(
                    id: 'b2',
                    balanceMismatchMinor: -1250,
                    balanceMismatchAsOf: DateTime(2026, 5, 31),
                  ),
                ],
              ),
              theme: theme,
              accounts: FakeAccountsController(
                initialAccounts: [_account, joint],
              ),
              file: PickedImportFile(
                name: 'releve-mai-2026.ofx',
                bytes: _ofxBytes,
              ),
            ),
          );
          await tester.pumpAndSettle();
          await _stageFile(tester);

          expect(
            find.byKey(const Key('importAmbiguousAccountField-$_statement')),
            findsOneWidget,
          );
          expect(find.byKey(const Key('importBatchRow-b2')), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

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

    expect(find.text('Drop an OFX or QFX statement'), findsOneWidget);
    expect(find.text('Browse'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('No imports'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a multi-account file shows and imports one line per statement', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    final imports = FakeImportsController(
      importResults: [
        _batch(id: 'b1', accountId: 'a1', newCount: 2, duplicateCount: 0),
        _batch(id: 'b2', accountId: 'a2', newCount: 1, duplicateCount: 1),
      ],
    );
    await tester.pumpWidget(
      _wrap(
        imports: imports,
        accounts: FakeAccountsController(
          initialAccounts: [
            _bound(_account, _statement),
            _bound(_savings, '0007654321'),
          ],
        ),
        file: PickedImportFile(name: 'releve.ofx', bytes: _multiOfxBytes),
      ),
    );
    await tester.pumpAndSettle();

    await _stageFile(tester);
    expect(
      find.byKey(const Key('importDetectedAccountBanner-$_statement')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('importDetectedAccountBanner-0007654321')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(_submit));
    await tester.pump();
    await tester.pump();
    // The other statement stays staged until it is imported in turn.
    expect(
      find.byKey(const Key('importStatementLine-0007654321')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('importSubmitButton-0007654321')));
    await tester.pump();
    await tester.pump();

    expect(
      imports.importCalls.map((call) => (call.accountId, call.statement)),
      [('a1', _statement), ('a2', '0007654321')],
    );
    expect(
      find.byKey(const Key('importStatementLine-0007654321')),
      findsNothing,
    );
    await _settleTimers(tester);
  });

  testWidgets('« Importer tout » imports every statement in one click', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    final imports = FakeImportsController(
      importResults: [
        _batch(id: 'b1', accountId: 'a1', newCount: 2, duplicateCount: 0),
        _batch(id: 'b2', accountId: 'a2', newCount: 1, duplicateCount: 1),
      ],
    );
    await tester.pumpWidget(
      _wrap(
        imports: imports,
        accounts: FakeAccountsController(
          initialAccounts: [
            _bound(_account, _statement),
            _bound(_savings, '0007654321'),
          ],
        ),
        file: PickedImportFile(name: 'releve.ofx', bytes: _multiOfxBytes),
      ),
    );
    await tester.pumpAndSettle();
    await _stageFile(tester);

    // « Importer tout » takes the primary; each line keeps its own action.
    final importAll = find.byKey(const Key('importAllButton'));
    expect(importAll, findsOneWidget);
    expect(find.text('Importer tout'), findsOneWidget);
    expect(
      tester.widget<AppButton>(find.byKey(_submit)).variant,
      AppButtonVariant.secondary,
    );

    await tester.tap(importAll);
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(
      imports.importCalls.map((call) => (call.accountId, call.statement)),
      [('a1', _statement), ('a2', '0007654321')],
    );
    expect(
      find.byKey(const Key('importStatementLine-$_statement')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('importStatementLine-0007654321')),
      findsNothing,
    );
    expect(importAll, findsNothing);
    // One toast for the whole run, with the counts summed.
    expect(
      find.text('3 nouvelles opérations · 1 doublon ignoré'),
      findsOneWidget,
    );
    await _settleTimers(tester);
  });

  testWidgets('« Importer tout » leaves statements still waiting on a choice', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    final imports = FakeImportsController(importResult: _batch());
    // Only the checking statement is bound; the savings one finds two
    // Boursorama candidates and has to ask.
    final other = Account(
      id: 'a3',
      name: 'Livret bis',
      type: AccountType.savings,
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
        accounts: FakeAccountsController(
          initialAccounts: [_bound(_account, _statement), _savings, other],
        ),
        file: PickedImportFile(name: 'releve.ofx', bytes: _multiOfxBytes),
      ),
    );
    await tester.pumpAndSettle();
    await _stageFile(tester);
    expect(
      find.byKey(const Key('importAmbiguousAccountBanner-0007654321')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('importAllButton')));
    await tester.pump();
    await tester.pump();

    expect(imports.importCalls.map((call) => call.statement), [_statement]);
    expect(
      find.byKey(const Key('importStatementLine-0007654321')),
      findsOneWidget,
    );
    // One line left: « Importer tout » goes, and the line's own button takes
    // the primary back, waiting for the answer.
    expect(find.byKey(const Key('importAllButton')), findsNothing);
    final remaining = tester.widget<AppButton>(
      find.byKey(const Key('importSubmitButton-0007654321')),
    );
    expect(remaining.variant, AppButtonVariant.primary);
    expect(remaining.onPressed, isNull);
    await _settleTimers(tester);
  });

  testWidgets('a single-statement file has no « Importer tout »', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        imports: FakeImportsController(importResult: _batch()),
        accounts: FakeAccountsController(
          initialAccounts: [_bound(_account, _statement)],
        ),
        file: PickedImportFile(name: 'releve.ofx', bytes: _ofxBytes),
      ),
    );
    await tester.pumpAndSettle();
    await _stageFile(tester);

    expect(find.byKey(const Key('importAllButton')), findsNothing);
    expect(
      tester.widget<AppButton>(find.byKey(_submit)).variant,
      AppButtonVariant.primary,
    );
  });

  testWidgets('two statements may not be sent to the same account', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    final imports = FakeImportsController(importResult: _batch());
    // Neither statement is bound and a single Boursorama account fits both
    // guesses — so the panel asks for each rather than guessing.
    final only = Account(
      id: 'a1',
      name: 'Compte unique',
      type: AccountType.other,
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
        accounts: FakeAccountsController(initialAccounts: [only]),
        file: PickedImportFile(name: 'releve.ofx', bytes: _multiOfxBytes),
      ),
    );
    await tester.pumpAndSettle();
    await _stageFile(tester);

    for (final statement in [_statement, '0007654321']) {
      await tester.tap(
        find.byKey(Key('importAmbiguousAccountField-$statement')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Compte unique').last);
      await tester.pumpAndSettle();
    }

    for (final statement in [_statement, '0007654321']) {
      expect(
        find.byKey(Key('importSharedDestinationBanner-$statement')),
        findsOneWidget,
      );
      expect(_onPressed(tester, Key('importSubmitButton-$statement')), isNull);
    }
    expect(
      find.text(
        'Deux relevés vont vers le même compte. Choisissez une destination '
        'différente.',
      ),
      findsNWidgets(2),
    );
  });

  testWidgets('a card without its rule is flagged with the fix', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    final card = Account(
      id: 'c1',
      name: 'Carte Visa',
      type: AccountType.deferredCard,
      institution: 'Boursorama',
      currency: 'EUR',
      settlementAccountId: 'a1',
      openingBalanceMinor: 0,
      balanceMinor: 0,
      archived: false,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );
    await tester.pumpWidget(
      _wrap(
        imports: FakeImportsController(importResult: _batch()),
        accounts: FakeAccountsController(initialAccounts: [_account, card]),
        file: PickedImportFile(name: 'releve.ofx', bytes: _ofxBytes),
        settlements: const [
          CardSettlementIssue(
            accountId: 'c1',
            kind: CardSettlementIssueKind.noRule,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await _stageFile(tester);
    await tester.tap(find.byKey(_submit));
    await tester.pump();
    await tester.pump();

    expect(
      find.text(
        'Le prélèvement mensuel de Carte Visa compte comme une dépense, en '
        'plus des achats de la carte : créez sa règle de prélèvement.',
      ),
      findsOneWidget,
    );
    expect(find.text('Créer la règle'), findsOneWidget);
    await _settleTimers(tester);
  });

  testWidgets('card purchases no debit matched are flagged', (tester) async {
    _useDesktopSurface(tester);
    final card = Account(
      id: 'c1',
      name: 'Carte Visa',
      type: AccountType.deferredCard,
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
        imports: FakeImportsController(importResult: _batch()),
        accounts: FakeAccountsController(initialAccounts: [_account, card]),
        file: PickedImportFile(name: 'releve.ofx', bytes: _ofxBytes),
        settlements: [
          CardSettlementIssue(
            accountId: 'c1',
            kind: CardSettlementIssueKind.unsettled,
            amountMinor: -49210,
            count: 3,
            since: DateTime(2026, 1, 5),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await _stageFile(tester);
    await tester.tap(find.byKey(_submit));
    await tester.pump();
    await tester.pump();

    final amount = formatAmount(
      amountMinor: 49210,
      currency: 'EUR',
      locale: 'fr',
    );
    final date = DateFormat.yMd('fr').format(DateTime(2026, 1, 5));
    expect(
      find.text(
        '3 achats de Carte Visa ($amount) attendent leur prélèvement depuis '
        'le $date : la règle de la carte ne reconnaît peut-être plus le '
        'libellé de la banque.',
      ),
      findsOneWidget,
    );
    expect(find.text('Vérifier la règle'), findsOneWidget);
    await _settleTimers(tester);
  });
}

final _savings = Account(
  id: 'a2',
  name: 'Livret',
  type: AccountType.savings,
  institution: 'Boursorama',
  currency: 'EUR',
  openingBalanceMinor: 0,
  balanceMinor: 0,
  archived: false,
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
);

/// [account], bound to the statement whose `ACCTID` is [ofxAccountId].
Account _bound(Account account, String ofxAccountId) => Account(
  id: account.id,
  name: account.name,
  type: account.type,
  institution: account.institution,
  ofxAccountId: ofxAccountId,
  currency: account.currency,
  openingBalanceMinor: account.openingBalanceMinor,
  balanceMinor: account.balanceMinor,
  archived: account.archived,
  createdAt: account.createdAt,
  updatedAt: account.updatedAt,
);

/// One Boursorama customer's checking and savings statements in a single file.
final _multiOfxBytes = utf8.encode('''
<OFX>
<SIGNONMSGSRSV1><SONRS><FI><ORG>BOURSORAMA BANQUE
</FI></SONRS></SIGNONMSGSRSV1>
<BANKMSGSRSV1>
<STMTTRNRS><STMTRS>
<CURDEF>EUR
<BANKACCTFROM>
<BANKID>40618
<ACCTID>0001234567
<ACCTTYPE>CHECKING
</BANKACCTFROM>
</STMTRS></STMTTRNRS>
<STMTTRNRS><STMTRS>
<CURDEF>EUR
<BANKACCTFROM>
<BANKID>40618
<ACCTID>0007654321
<ACCTTYPE>SAVINGS
</BANKACCTFROM>
</STMTRS></STMTTRNRS>
</BANKMSGSRSV1>
</OFX>
''');
