import 'dart:async';

import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/core/widgets/amount_text.dart';
import 'package:bastide/core/widgets/app_table.dart';
import 'package:bastide/features/accounts/application/accounts_controller.dart';
import 'package:bastide/features/accounts/domain/account.dart';
import 'package:bastide/features/imports/application/imports_controller.dart';
import 'package:bastide/features/imports/domain/import_batch.dart';
import 'package:bastide/features/imports/presentation/import_history.dart';
import 'package:bastide/features/transactions/application/transactions_controller.dart';
import 'package:bastide/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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
  DateTime? periodStart,
}) => ImportBatch(
  id: id,
  accountId: 'a1',
  sourceFormat: format,
  fileName: fileName,
  fileHash: 'hash-$id',
  periodStart: periodStart ?? DateTime(2026, 5, 1),
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

/// A history controller that never finishes loading.
class _LoadingImportsController extends FakeImportsController {
  @override
  Future<List<ImportBatch>> build() => Completer<List<ImportBatch>>().future;
}

Widget _wrap({
  required FakeImportsController controller,
  Locale locale = const Locale('fr'),
  ThemeData? theme,
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
      theme: theme ?? AppTheme.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // The panel gives the history the remaining height; the test pins one so
      // the table's Expanded has something to fill.
      home: const Scaffold(body: SizedBox(height: 640, child: ImportHistory())),
    ),
  );
}

/// The history at its width in the 1440 × 900 frame, beside the sidebar.
void _useDesktopSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440 - 224 - 64, 640);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('renders the spec columns and a batch in fr', (tester) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(controller: FakeImportsController(initialBatches: [_batch()])),
    );
    await tester.pumpAndSettle();

    expect(find.text('Historique'), findsOneWidget);
    for (final header in [
      'Fichier',
      'Compte',
      'Importé le',
      'Période couverte',
      'Nouvelles',
      'Doublons',
      'Résultat',
    ]) {
      expect(find.text(header), findsOneWidget, reason: header);
    }
    // No format badge and no uppercase headers in v2.
    expect(find.text('OFX'), findsNothing);
    expect(find.text('FICHIER'), findsNothing);

    final row = find.byKey(const Key('importBatchRow-b1'));
    Finder inRow(Finder f) => find.descendant(of: row, matching: f);
    expect(inRow(find.text('releve-mai.ofx')), findsOneWidget);
    expect(inRow(find.text('Compte courant')), findsOneWidget);
    expect(
      inRow(find.text(DateFormat.yMMMd('fr').format(DateTime(2026, 6, 1)))),
      findsOneWidget,
    );
    expect(
      inRow(
        find.text(
          '1 – ${DateFormat.yMMMd('fr').format(DateTime(2026, 5, 31))}',
        ),
      ),
      findsOneWidget,
    );
    expect(inRow(find.text('42')), findsOneWidget);
    expect(inRow(find.text('Réussi')), findsOneWidget);
  });

  testWidgets('numeric columns sit at the right edge of their cell', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(controller: FakeImportsController(initialBatches: [_batch()])),
    );
    await tester.pumpAndSettle();

    final row = find.byKey(const Key('importBatchRow-b1'));
    Finder inRow(Finder f) => find.descendant(of: row, matching: f);
    // Right-aligned under their right-aligned headers.
    expect(
      tester.getRect(inRow(find.text('42'))).right,
      closeTo(tester.getRect(find.text('Nouvelles')).right, 1),
    );
    expect(
      tester.getRect(inRow(find.text('Réussi'))).right,
      closeTo(tester.getRect(find.text('Résultat')).right, 1),
    );
  });

  testWidgets('renders the same batch with en dates and words', (tester) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        controller: FakeImportsController(initialBatches: [_batch()]),
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('History'), findsOneWidget);
    expect(
      find.text(DateFormat.yMMMd('en').format(DateTime(2026, 6, 1))),
      findsOneWidget,
    );
    expect(find.text('Succeeded'), findsOneWidget);
    expect(find.text('Result'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a period across months names the start month', (tester) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        controller: FakeImportsController(
          initialBatches: [_batch(periodStart: DateTime(2026, 1, 1))],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final fr = DateFormat.MMMd('fr').format(DateTime(2026, 1, 1));
    final end = DateFormat.yMMMd('fr').format(DateTime(2026, 5, 31));
    expect(find.text('$fr – $end'), findsOneWidget);
  });

  testWidgets('a re-import shows its duplicates as a note on a taller row', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        controller: FakeImportsController(
          initialBatches: [
            _batch(newCount: 0, duplicateCount: 6),
            _batch(id: 'b2', duplicateCount: 0),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('importBatchDuplicateNote-b1')),
      findsOneWidget,
    );
    expect(
      find.text('6 opérations déjà présentes ont été ignorées.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<AppTableRow>(find.byKey(const Key('importBatchRow-b1')))
          .twoLines,
      isTrue,
    );
    expect(
      tester
          .widget<AppTableRow>(find.byKey(const Key('importBatchRow-b2')))
          .twoLines,
      isFalse,
    );
  });

  testWidgets('a balance mismatch adds « Écart de solde » to the result', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        controller: FakeImportsController(
          initialBatches: [
            _batch(
              status: ImportStatus.partial,
              balanceMismatchMinor: 5925,
              balanceMismatchAsOf: DateTime(2026, 5, 31),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('importBatchMismatch-b1')), findsOneWidget);
    expect(find.text('Écart de solde'), findsOneWidget);
    expect(find.text('Partiel'), findsOneWidget);
    final amount = formatAmount(
      amountMinor: 5925,
      currency: 'EUR',
      locale: 'fr',
      showPositiveSign: true,
    );
    final date = DateFormat.yMd('fr').format(DateTime(2026, 5, 31));
    final tooltip = tester.widget<Tooltip>(
      find.ancestor(
        of: find.byKey(const Key('importBatchMismatch-b1')),
        matching: find.byType(Tooltip),
      ),
    );
    expect(
      tooltip.message,
      'Écart de $amount avec le solde de la banque au $date.',
    );
  });

  testWidgets('a failed batch states nothing was changed and opens nothing', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        controller: FakeImportsController(
          initialBatches: [
            _batch(
              format: ImportFormat.qfx,
              fileName: 'export.qfx',
              newCount: 0,
              duplicateCount: 0,
              status: ImportStatus.failed,
              errorMessage: 'No <STMTTRN> records found',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('importBatchFailureNote-b1')), findsOneWidget);
    expect(
      find.text('Fichier illisible. Rien n’a été modifié.'),
      findsOneWidget,
    );
    expect(find.text('Échec'), findsOneWidget);
    // No account and no period for a file that wrote nothing.
    expect(find.text('—'), findsNWidgets(2));
    // The parser's reason stays a hover away.
    final tooltip = tester.widget<Tooltip>(
      find.ancestor(
        of: find.byKey(const Key('importBatchFailureNote-b1')),
        matching: find.byType(Tooltip),
      ),
    );
    expect(tooltip.message, 'No <STMTTRN> records found');
    final row = tester.widget<AppTableRow>(
      find.byKey(const Key('importBatchRow-b1')),
    );
    expect(row.onTap, isNull);
  });

  testWidgets('a row opens Transactions on exactly what its import added', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    late ProviderContainer container;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Consumer(
            builder: (context, ref, _) {
              container = ProviderScope.containerOf(context);
              return const Scaffold(
                body: SizedBox(height: 640, child: ImportHistory()),
              );
            },
          ),
        ),
        GoRoute(
          path: '/transactions',
          builder: (_, _) => const Scaffold(body: Text('transactions')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          importsControllerProvider.overrideWith(
            () => FakeImportsController(initialBatches: [_batch()]),
          ),
          accountsControllerProvider.overrideWith(
            () => FakeAccountsController(initialAccounts: [_account]),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('fr'),
          theme: AppTheme.dark,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('importBatchRow-b1')));
    await tester.pumpAndSettle();

    expect(find.text('transactions'), findsOneWidget);
    final filters = container.read(transactionFiltersProvider);
    expect(filters.importBatch?.id, 'b1');
    expect(filters.importBatch?.fileName, _batch().fileName);
    expect(filters.accountId, 'a1');
    // The import alone decides the rows: no period narrows them further.
    expect(filters.dateFrom, isNull);
    expect(filters.dateTo, isNull);
  });

  testWidgets('loads as the table silhouette', (tester) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(_wrap(controller: _LoadingImportsController()));
    await tester.pump();

    expect(find.byKey(const Key('importHistoryLoading')), findsOneWidget);
    expect(find.text('Fichier'), findsOneWidget);
  });

  testWidgets('renders the empty state when nothing has been imported', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(_wrap(controller: FakeImportsController()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('importHistoryEmpty')), findsOneWidget);
    expect(find.text('Aucun import'), findsOneWidget);
    expect(
      find.text(
        'Déposez un relevé ci-dessus : vos opérations apparaîtront ici.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('importHistoryList')), findsNothing);
    // No button: the drop target is right above.
    expect(find.byType(ButtonStyleButton), findsNothing);
  });

  testWidgets('renders the empty state in en and the light theme', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        controller: FakeImportsController(),
        locale: const Locale('en'),
        theme: AppTheme.light,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No imports'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
