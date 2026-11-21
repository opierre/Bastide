import 'dart:async';

import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/core/theme/tokens.dart';
import 'package:bastide/core/widgets/amount_text.dart';
import 'package:bastide/core/widgets/app_table.dart';
import 'package:bastide/features/accounts/application/accounts_controller.dart';
import 'package:bastide/features/accounts/domain/account.dart';
import 'package:bastide/features/categories/domain/category.dart';
import 'package:bastide/features/categorization/application/run_controller.dart';
import 'package:bastide/features/categorization/domain/categorization_run.dart';
import 'package:bastide/features/rules/application/rule_preview_controller.dart';
import 'package:bastide/features/rules/domain/rule.dart';
import 'package:bastide/features/transactions/application/review_count_provider.dart';
import 'package:bastide/features/transactions/application/transaction_selection.dart';
import 'package:bastide/features/transactions/application/transactions_controller.dart';
import 'package:bastide/features/transactions/domain/transaction.dart';
import 'package:bastide/features/transactions/presentation/review_queue.dart';
import 'package:bastide/features/transactions/presentation/transactions_screen.dart';
import 'package:bastide/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_accounts_controller.dart';
import '../../support/fake_transactions_controller.dart';

// Every name, amount and date below is invented.

final _account = Account(
  id: 'a1',
  name: 'Compte courant',
  type: AccountType.checking,
  institution: 'Banque Exemple',
  currency: 'EUR',
  openingBalanceMinor: 0,
  balanceMinor: 0,
  archived: false,
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
);

const _insurance = TransactionCategory(
  id: 'c-insurance',
  name: 'Assurance habitation',
  kind: 'expense',
  icon: 'home',
  color: 'cat1',
);

const _catalog = [
  AppCategory(
    id: 'c-home',
    userId: null,
    parentId: null,
    name: 'category.housing',
    kind: 'expense',
    icon: 'home',
    color: 'cat1',
    isSystem: true,
  ),
  AppCategory(
    id: 'c-insurance',
    userId: 'u1',
    parentId: 'c-home',
    name: 'Assurance habitation',
    kind: 'expense',
    icon: 'home',
    color: 'cat1',
    isSystem: false,
  ),
];

Transaction _transaction({
  String id = 't1',
  DateTime? bookedDate,
  int amountMinor = -18_744,
  String? merchant = 'Mutuelle Exemple',
  String descriptionRaw = 'PRLV SEPA ASSUR EXEMPLE',
  TransactionCategory? category = _insurance,
  CategorizationSource source = CategorizationSource.rule,
  double? confidence,
  bool needsReview = false,
}) => Transaction(
  id: id,
  accountId: 'a1',
  bookedDate: bookedDate ?? DateTime(2026, 5, 11),
  valueDate: null,
  amountMinor: amountMinor,
  currency: 'EUR',
  descriptionRaw: descriptionRaw,
  descriptionClean: descriptionRaw,
  memo: null,
  merchant: merchant,
  category: category,
  categorizationSource: source,
  categorizationConfidence: confidence,
  needsReview: needsReview,
  fitid: null,
  dedupHash: 'hash-$id',
  createdAt: DateTime.utc(2026, 5, 11),
  updatedAt: DateTime.utc(2026, 5, 11),
);

TransactionsPage _page(List<Transaction> items, {int? net, int? total}) =>
    TransactionsPage(
      items: items,
      page: 1,
      pageSize: 50,
      total: total ?? items.length,
      netMinor: net,
    );

final _details = TransactionContext(
  importBatchId: 'b1',
  importFileName: 'releve-mai.ofx',
  rule: const TransactionRuleRef(id: 'r1', pattern: 'ASSUR EXEMPLE'),
  series: TransactionSeriesRef(
    id: 's1',
    cadence: 'yearly',
    nextExpectedDate: DateTime(2026, 11, 21),
  ),
  sameMerchant: [
    SameMerchantOperation(
      id: 't-old',
      bookedDate: DateTime(2025, 11, 21),
      amountMinor: -17_990,
      currency: 'EUR',
    ),
  ],
);

Widget _wrap({
  required FakeTransactionsController controller,
  int reviewCount = 0,
  TransactionContext? details,
  Locale locale = const Locale('fr'),
  ThemeData? theme,
}) {
  return ProviderScope(
    overrides: [
      transactionsControllerProvider.overrideWith(() => controller),
      transactionCategoriesProvider.overrideWith((ref) async => _catalog),
      accountsControllerProvider.overrideWith(
        () => FakeAccountsController(initialAccounts: [_account]),
      ),
      reviewCountProvider.overrideWith((ref) async => reviewCount),
      transactionContextProvider.overrideWith(
        (ref, id) async => details ?? _details,
      ),
      aiAvailabilityProvider.overrideWith(
        (ref) async => AiAvailability.unavailable,
      ),
      ruleSuggestionProvider.overrideWith(
        (ref, transactionId) async => const RuleSuggestion(
          matchField: RuleMatchField.descriptionClean,
          matchType: RuleMatchType.contains,
          pattern: 'ASSUR',
        ),
      ),
    ],
    child: MaterialApp(
      locale: locale,
      theme: theme ?? AppTheme.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: TransactionsScreen()),
    ),
  );
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(TransactionsScreen)));

/// The 1440 × 900 frame the design targets, less the 224 px sidebar.
void _useDesktopSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1216, 852);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> _pump(
  WidgetTester tester, {
  List<Transaction>? items,
  int? net,
  int reviewCount = 0,
  TransactionContext? details,
  Locale locale = const Locale('fr'),
  ThemeData? theme,
  FakeTransactionsController? controller,
}) async {
  _useDesktopSurface(tester);
  await tester.pumpWidget(
    _wrap(
      controller:
          controller ??
          FakeTransactionsController(
            initialPage: _page(items ?? [_transaction()], net: net),
          ),
      reviewCount: reviewCount,
      details: details,
      locale: locale,
      theme: theme,
    ),
  );
  await tester.pumpAndSettle();
}

/// Taps the row's name, clear of the category label (which opens the picker).
Future<void> _select(WidgetTester tester, String id) async {
  await tester.tapAt(
    tester.getTopLeft(find.byKey(Key('transactionRow-$id'))) +
        const Offset(AppSpacing.pageX + AppSpacing.xl, AppSizes.tableRow / 2),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('tabs', () {
    testWidgets('« Toutes » and « À vérifier » with its count', (tester) async {
      await _pump(tester, reviewCount: 12);

      expect(find.text('Toutes'), findsOneWidget);
      expect(
        find.textContaining('À vérifier 12', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('the count is hidden at 0', (tester) async {
      await _pump(tester);

      expect(
        find.textContaining('À vérifier', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('À vérifier 0', findRichText: true),
        findsNothing,
      );
    });

    testWidgets('« À vérifier » opens the review queue', (tester) async {
      await _pump(tester, reviewCount: 1);

      await tester.tap(find.byKey(const Key('appTab-1')));
      await tester.pumpAndSettle();

      expect(
        _container(tester).read(transactionFiltersProvider).isReviewTab,
        true,
      );
      expect(find.byType(ReviewQueue), findsOneWidget);
      expect(find.byKey(const Key('transactionsListPane')), findsNothing);
    });
  });

  group('list pane', () {
    testWidgets('groups rows by day, newest first', (tester) async {
      await _pump(
        tester,
        items: [
          _transaction(id: 't1', bookedDate: DateTime(2026, 5, 14)),
          _transaction(id: 't2', bookedDate: DateTime(2026, 5, 14)),
          _transaction(id: 't3', bookedDate: DateTime(2026, 5, 9)),
        ],
      );

      final groups = tester
          .widgetList<AppTableGroupRow>(find.byType(AppTableGroupRow))
          .map((row) => row.label)
          .toList();
      expect(groups, ['14 mai 2026', '9 mai 2026']);
      expect(
        tester.getTopLeft(find.byKey(const Key('transactionRow-t2'))).dy,
        lessThan(
          tester.getTopLeft(find.byKey(const Key('transactionRow-t3'))).dy,
        ),
      );
    });

    testWidgets('a row shows the name, the top-level category and the amount', (
      tester,
    ) async {
      await _pump(tester);

      expect(find.text('Mutuelle Exemple'), findsOneWidget);
      // Top level only in the list: the subcategory waits for the inspector.
      final row = find.byKey(const Key('transactionRow-t1'));
      expect(
        find.descendant(of: row, matching: find.text('Logement')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: row,
          matching: find.textContaining('Assurance', findRichText: true),
        ),
        findsNothing,
      );
      final amount = tester.widget<Text>(
        find.descendant(of: row, matching: find.byType(Text)).last,
      );
      expect(amount.data, '−187,44 €');
      expect(amount.style?.color, AppColors.dark.negative);
    });

    testWidgets('a label no rule named is mono beside the « ? » monogram', (
      tester,
    ) async {
      await _pump(
        tester,
        items: [_transaction(merchant: null, descriptionRaw: 'CB XYZ 0512')],
      );

      final name = tester.widget<Text>(
        find.byKey(const Key('transactionRowName')),
      );
      expect(name.data, 'CB XYZ 0512');
      expect(name.style?.fontFamily, AppFonts.mono);
      expect(
        find.descendant(
          of: find.byKey(const Key('transactionRow-t1')),
          matching: find.text('?'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the filter row ends on the count and the signed net', (
      tester,
    ) async {
      await _pump(
        tester,
        items: [
          _transaction(id: 't1'),
          _transaction(id: 't2', amountMinor: 250_000),
        ],
        net: 231_256,
      );

      expect(find.text('2 opérations · net '), findsOneWidget);
      final net = tester.widget<AmountText>(
        find.byKey(const Key('transactionsNet')),
      );
      expect(net.amountMinor, 231_256);
      expect(net.showPositiveSign, isTrue);
      expect(find.text('+2 312,56 €'), findsOneWidget);
    });

    testWidgets('the pager reads « 1 – 2 sur 2 » and cannot move', (
      tester,
    ) async {
      await _pump(
        tester,
        items: [
          _transaction(id: 't1'),
          _transaction(id: 't2'),
        ],
      );

      expect(find.text('1 – 2 sur 2'), findsOneWidget);
      expect(find.byTooltip('Page précédente'), findsNothing);
      expect(find.bySemanticsLabel('Page précédente'), findsOneWidget);
    });

    testWidgets('« Tous les comptes » lifts a picked account', (tester) async {
      await _pump(tester);
      final select = find.byKey(const Key('transactionsAccountFilter'));

      await tester.tap(select);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Compte courant').last);
      await tester.pumpAndSettle();
      expect(
        _container(tester).read(transactionFiltersProvider).accountId,
        'a1',
      );

      await tester.tap(select);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tous les comptes').last);
      await tester.pumpAndSettle();
      expect(
        _container(tester).read(transactionFiltersProvider).accountId,
        isNull,
      );
    });

    testWidgets('the category filter lists main categories only', (
      tester,
    ) async {
      await _pump(tester);

      await tester.tap(find.byKey(const Key('transactionsCategoryFilter')));
      await tester.pumpAndSettle();

      expect(find.text('Toutes les catégories'), findsWidgets);
      expect(find.text('Logement'), findsWidgets);
      expect(find.text('Assurance habitation'), findsNothing);
    });

    testWidgets('the period select names a range compactly', (tester) async {
      await _pump(tester);
      _container(tester)
          .read(transactionFiltersProvider.notifier)
          .setDateRange(DateTime(2026, 5, 1), DateTime(2026, 5, 31));
      await tester.pumpAndSettle();

      expect(find.text('1 – 31 mai 2026'), findsOneWidget);
    });

    testWidgets('no row for the filters offers to clear them', (tester) async {
      await _pump(tester, items: []);
      // A filter is what tells « none of these » from « none at all ».
      _container(
        tester,
      ).read(transactionFiltersProvider.notifier).setQuery('x');
      await tester.pumpAndSettle();

      expect(find.text('Aucune opération pour ces filtres.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('transactionsClearFilters')));
      await tester.pumpAndSettle();

      expect(
        _container(tester).read(transactionFiltersProvider).hasListFilter,
        isFalse,
      );
    });

    testWidgets('the import filter names its file and lifts on « x »', (
      tester,
    ) async {
      await _pump(tester);
      _container(tester)
          .read(transactionFiltersProvider.notifier)
          .showImport(
            const ImportBatchFilter(id: 'b1', fileName: 'releve-mai.ofx'),
            accountId: 'a1',
          );
      await tester.pumpAndSettle();

      expect(find.text('Import : releve-mai.ofx'), findsOneWidget);
      await tester.tap(find.byKey(const Key('transactionsImportFilterRemove')));
      await tester.pumpAndSettle();

      final filters = _container(tester).read(transactionFiltersProvider);
      expect(filters.importBatch, isNull);
      expect(filters.accountId, 'a1');
    });

    testWidgets('tapping the category opens the picker, which applies', (
      tester,
    ) async {
      final controller = FakeTransactionsController(
        initialPage: _page([_transaction(category: null)]),
      );
      await _pump(tester, controller: controller);

      await tester.tap(find.byKey(const Key('transactionRowCategory')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('categoryPickerSearchField')),
        findsOneWidget,
      );
      expect(find.text('Changer de catégorie'), findsOneWidget);
      // Categories and their subcategories, each a category label.
      expect(
        find.byKey(const Key('categoryPickerItem-c-insurance')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('categoryPickerItem-c-insurance')));
      await tester.pumpAndSettle();

      expect(controller.updateCategoryCalls, [
        (transactionId: 't1', categoryId: 'c-insurance'),
      ]);
      expect(find.byKey(const Key('categoryPickerSearchField')), findsNothing);
    });
  });

  group('selection and keyboard', () {
    testWidgets('nothing selected: the inspector shows its note', (
      tester,
    ) async {
      await _pump(tester);

      expect(
        find.text('Sélectionnez une opération pour voir son détail.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('transactionInspector')), findsNothing);
    });

    testWidgets('the selected row takes accentSoft', (tester) async {
      await _pump(tester);

      await _select(tester, 't1');

      final row = tester.widget<AppTableRow>(
        find.descendant(
          of: find.byKey(const Key('transactionRow-t1')),
          matching: find.byType(AppTableRow),
        ),
      );
      expect(row.selected, isTrue);
      expect(find.byKey(const Key('transactionInspector')), findsOneWidget);
    });

    testWidgets('↑ ↓ move the selection and C opens the picker', (
      tester,
    ) async {
      await _pump(
        tester,
        items: [
          _transaction(id: 't1'),
          _transaction(id: 't2'),
          _transaction(id: 't3'),
        ],
      );
      await _select(tester, 't1');

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(_container(tester).read(selectedTransactionProvider), 't2');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(_container(tester).read(selectedTransactionProvider), 't1');

      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('categoryPickerSearchField')),
        findsOneWidget,
      );
    });
  });

  group('inspector', () {
    testWidgets('the header, the amount and the key/value list', (
      tester,
    ) async {
      await _pump(tester);
      await _select(tester, 't1');

      final inspector = find.byKey(const Key('transactionInspector'));
      Finder inside(Finder finder) =>
          find.descendant(of: inspector, matching: finder);
      expect(inside(find.text('Mutuelle Exemple')), findsOneWidget);
      expect(inside(find.text('PRLV SEPA ASSUR EXEMPLE')), findsOneWidget);
      final amount = tester.widget<AmountText>(
        find.byKey(const Key('transactionInspectorAmount')),
      );
      expect(amount.amountMinor, -18_744);
      expect(amount.style?.fontSize, 28);
      expect(inside(find.text('11 mai 2026')), findsOneWidget);
      expect(inside(find.text('Compte courant')), findsOneWidget);
      // The full category label: the subcategory after « › ».
      expect(
        inside(find.textContaining('Assurance habitation', findRichText: true)),
        findsOneWidget,
      );
      expect(inside(find.text('règle « ASSUR EXEMPLE »')), findsOneWidget);
      expect(inside(find.text('releve-mai.ofx')), findsOneWidget);
    });

    testWidgets('classed by the AI: the confidence as text', (tester) async {
      await _pump(
        tester,
        items: [
          _transaction(source: CategorizationSource.model, confidence: 0.78),
        ],
      );
      await _select(tester, 't1');

      expect(find.text('IA locale, confiance 78 %'), findsOneWidget);
    });

    testWidgets('classed by the user, or not at all', (tester) async {
      await _pump(
        tester,
        items: [
          _transaction(id: 't1', source: CategorizationSource.user),
          _transaction(
            id: 't2',
            category: null,
            source: CategorizationSource.uncategorized,
          ),
        ],
      );

      await _select(tester, 't1');
      expect(find.text('vous'), findsOneWidget);
      await _select(tester, 't2');
      expect(find.text('non classée'), findsOneWidget);
    });

    testWidgets('a recurring charge shows its series', (tester) async {
      await _pump(tester);
      await _select(tester, 't1');

      expect(find.text('Paiement récurrent'), findsOneWidget);
      expect(find.text('Annuel · prochain le 21 nov. 2026'), findsOneWidget);
      expect(
        find.byKey(const Key('transactionInspectorViewSeries')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('transactionInspectorMarkRecurring')),
        findsNothing,
      );
    });

    testWidgets('a charge in no series offers « Marquer comme récurrent »', (
      tester,
    ) async {
      await _pump(
        tester,
        details: const TransactionContext(
          importBatchId: 'b1',
          importFileName: 'releve-mai.ofx',
          rule: null,
          series: null,
          sameMerchant: [],
        ),
      );
      await _select(tester, 't1');

      expect(
        find.byKey(const Key('transactionInspectorMarkRecurring')),
        findsOneWidget,
      );
      expect(find.text('Aucune opération antérieure.'), findsOneWidget);
      // No rule filed it: the action creates one.
      expect(
        find.byKey(const Key('transactionInspectorCreateRule')),
        findsOneWidget,
      );
      expect(find.text('Créer une règle'), findsOneWidget);
    });

    testWidgets('an inflow has no recurring action', (tester) async {
      await _pump(
        tester,
        items: [_transaction(amountMinor: 250_000)],
        details: const TransactionContext(
          importBatchId: 'b1',
          importFileName: null,
          rule: null,
          series: null,
          sameMerchant: [],
        ),
      );
      await _select(tester, 't1');

      expect(
        find.byKey(const Key('transactionInspectorMarkRecurring')),
        findsNothing,
      );
    });

    testWidgets('« Même marchand » lists earlier operations', (tester) async {
      await _pump(tester);
      await _select(tester, 't1');

      expect(find.text('Même marchand'), findsOneWidget);
      final row = find.byKey(
        const Key('transactionInspectorSameMerchant-t-old'),
      );
      expect(
        find.descendant(of: row, matching: find.text('21 nov. 2025')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.text('−179,90 €')),
        findsOneWidget,
      );
    });

    testWidgets('a rule-filed row offers « Modifier la règle »', (
      tester,
    ) async {
      await _pump(tester);
      await _select(tester, 't1');

      expect(find.text('Modifier la règle'), findsOneWidget);
      expect(
        find.byKey(const Key('transactionInspectorCreateRule')),
        findsNothing,
      );
    });

    testWidgets('a context that fails to load says so', (tester) async {
      _useDesktopSurface(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            transactionsControllerProvider.overrideWith(
              () => FakeTransactionsController(
                initialPage: _page([_transaction()]),
              ),
            ),
            transactionCategoriesProvider.overrideWith((ref) async => _catalog),
            accountsControllerProvider.overrideWith(
              () => FakeAccountsController(initialAccounts: [_account]),
            ),
            reviewCountProvider.overrideWith((ref) async => 0),
            transactionContextProvider.overrideWith(
              (ref, id) async => throw StateError('offline'),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('fr'),
            theme: AppTheme.dark,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: TransactionsScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _select(tester, 't1');

      expect(
        find.text('Ce détail n’a pas pu être chargé. Rien n’a été modifié.'),
        findsOneWidget,
      );
    });
  });

  group('states', () {
    testWidgets('no transaction at all: the empty state, no tabs', (
      tester,
    ) async {
      await _pump(tester, items: []);

      expect(find.text('Aucune transaction'), findsOneWidget);
      expect(
        find.text('Importez un relevé pour voir vos opérations ici.'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('transactionsGoToImportsButton')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('transactionsTabs')), findsNothing);
    });

    testWidgets('loading draws the silhouette', (tester) async {
      _useDesktopSurface(tester);
      await tester.pumpWidget(_wrap(controller: _NeverLoadingController()));
      await tester.pump();

      expect(
        find.byKey(const Key('transactionsLoadingIndicator')),
        findsOneWidget,
      );
    });

    testWidgets('both themes render the list and the inspector', (
      tester,
    ) async {
      await _pump(tester, theme: AppTheme.light);
      await _select(tester, 't1');

      final amount = tester.widget<Text>(
        find
            .descendant(
              of: find.byKey(const Key('transactionRow-t1')),
              matching: find.byType(Text),
            )
            .last,
      );
      expect(amount.style?.color, AppColors.light.negative);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders in English', (tester) async {
      await _pump(tester, locale: const Locale('en'), reviewCount: 3);
      await _select(tester, 't1');

      expect(find.text('All'), findsOneWidget);
      expect(
        find.textContaining('To review 3', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('Operation'), findsOneWidget);
      expect(find.text('Filed by'), findsOneWidget);
      expect(find.text('Same merchant'), findsOneWidget);
      expect(find.text('rule “ASSUR EXEMPLE”'), findsOneWidget);
      expect(find.textContaining('opération'), findsNothing);
    });
  });
}

/// A controller whose page never arrives, to hold the loading state.
class _NeverLoadingController extends FakeTransactionsController {
  _NeverLoadingController() : super(initialPage: _page(const []));

  @override
  Future<TransactionsPage> build() => Completer<TransactionsPage>().future;
}
