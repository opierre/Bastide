import 'package:finstride/core/theme/app_theme.dart';
import 'package:finstride/core/widgets/amount_text.dart';
import 'package:finstride/features/accounts/application/accounts_controller.dart';
import 'package:finstride/features/accounts/domain/account.dart';
import 'package:finstride/features/imports/application/imports_controller.dart';
import 'package:finstride/features/imports/domain/import_batch.dart';
import 'package:finstride/features/imports/presentation/import_history.dart';
import 'package:finstride/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import '../../support/fake_accounts_controller.dart';
import '../../support/fake_imports_controllers.dart';

final _account = Account(
  id: 'a1',
  name: 'Compte courant',
  type: AccountType.checking,
  institution: 'BNP Paribas',
  currency: 'EUR',
  openingBalanceMinor: 0,
  balanceMinor: 0,
  archived: false,
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
);

ImportBatch _batch({
  String id = 'b1',
  ImportFormat format = ImportFormat.ofx,
  String fileName = 'releve-mai.ofx',
  int newCount = 42,
  int duplicateCount = 3,
  ImportStatus status = ImportStatus.success,
  String? errorMessage,
  int? balanceMismatchMinor,
  DateTime? balanceMismatchAsOf,
}) => ImportBatch(
  id: id,
  accountId: 'a1',
  sourceFormat: format,
  fileName: fileName,
  fileHash: 'hash-$id',
  periodStart: DateTime(2026, 5, 1),
  periodEnd: DateTime(2026, 5, 31),
  transactionCount: newCount + duplicateCount,
  newCount: newCount,
  duplicateCount: duplicateCount,
  status: status,
  errorMessage: errorMessage,
  balanceMismatchMinor: balanceMismatchMinor,
  balanceMismatchAsOf: balanceMismatchAsOf,
  importedAt: DateTime(2026, 6, 1, 9, 30),
);

Widget _wrap({
  required FakeImportsController controller,
  Locale locale = const Locale('fr'),
}) {
  return ProviderScope(
    overrides: [
      importsControllerProvider.overrideWith(() => controller),
      accountsControllerProvider.overrideWith(
        () => FakeAccountsController(initialAccounts: [_account]),
      ),
    ],
    child: MaterialApp(
      locale: locale,
      theme: appDarkTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // The panel gives the history the remaining height; the test pins one so
      // the card's Expanded has something to fill.
      home: const Scaffold(body: SizedBox(height: 640, child: ImportHistory())),
    ),
  );
}

void main() {
  testWidgets('renders a batch with fr-formatted dates and counts', (tester) async {
    await tester.pumpWidget(
      _wrap(controller: FakeImportsController(initialBatches: [_batch()])),
    );
    await tester.pumpAndSettle();

    final dates = DateFormat.yMd('fr');
    expect(find.text('releve-mai.ofx'), findsOneWidget);
    expect(find.text('OFX'), findsOneWidget);
    expect(find.text(dates.format(DateTime(2026, 6, 1, 9, 30))), findsOneWidget);
    expect(
      find.text(
        '${dates.format(DateTime(2026, 5, 1))} – ${dates.format(DateTime(2026, 5, 31))}',
      ),
      findsOneWidget,
    );
    expect(find.text(NumberFormat.decimalPattern('fr').format(42)), findsOneWidget);
    expect(find.text('Réussi'), findsOneWidget);
  });

  testWidgets('renders the same batch with en-formatted dates', (tester) async {
    await tester.pumpWidget(
      _wrap(
        controller: FakeImportsController(initialBatches: [_batch()]),
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();

    final dates = DateFormat.yMd('en');
    expect(find.text(dates.format(DateTime(2026, 6, 1, 9, 30))), findsOneWidget);
    expect(
      find.text(
        '${dates.format(DateTime(2026, 5, 1))} – ${dates.format(DateTime(2026, 5, 31))}',
      ),
      findsOneWidget,
    );
    expect(find.text('Succeeded'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a re-import shows its duplicates as a note under the file name', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        controller: FakeImportsController(
          initialBatches: [_batch(newCount: 0, duplicateCount: 45)],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('importBatchDuplicateNote-b1')), findsOneWidget);
    expect(find.text('45 opérations déjà présentes, ignorées'), findsOneWidget);
  });

  testWidgets('a batch that disagrees with the bank shows the gap as a note', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        controller: FakeImportsController(
          initialBatches: [
            _batch(
              balanceMismatchMinor: 5925,
              balanceMismatchAsOf: DateTime(2024, 2, 29),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('importBatchMismatchNote-b1')), findsOneWidget);
    final amount = formatAmount(
      amountMinor: 5925,
      currency: 'EUR',
      locale: 'fr',
      showPositiveSign: true,
    );
    final date = DateFormat.yMd('fr').format(DateTime(2024, 2, 29));
    expect(find.text('Écart de $amount avec le solde de la banque au $date.'), findsOneWidget);
  });

  testWidgets('a failed batch states nothing was changed and shows the reason', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        controller: FakeImportsController(
          initialBatches: [
            _batch(
              format: ImportFormat.csv,
              fileName: 'export.csv',
              newCount: 0,
              duplicateCount: 0,
              status: ImportStatus.failed,
              errorMessage: "Column 'Montant' not found in header",
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('importBatchFailureNote-b1')), findsOneWidget);
    expect(find.text("Le fichier n'a pas pu être lu — rien n'a été modifié."), findsOneWidget);
    expect(find.text("Column 'Montant' not found in header"), findsOneWidget);
    expect(find.text('Échec'), findsOneWidget);
    expect(find.text('CSV'), findsOneWidget);
  });

  testWidgets('renders the empty state when nothing has been imported', (tester) async {
    await tester.pumpWidget(_wrap(controller: FakeImportsController()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('importHistoryEmpty')), findsOneWidget);
    expect(find.text('Aucun import pour l\'instant'), findsOneWidget);
    expect(find.byKey(const Key('importHistoryList')), findsNothing);
  });

  testWidgets('renders the empty state in en', (tester) async {
    await tester.pumpWidget(
      _wrap(controller: FakeImportsController(), locale: const Locale('en')),
    );
    await tester.pumpAndSettle();

    expect(find.text('No imports yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
