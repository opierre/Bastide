import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/core/widgets/amount_text.dart';
import 'package:bastide/features/accounts/application/accounts_controller.dart';
import 'package:bastide/features/accounts/domain/account.dart';
import 'package:bastide/features/categorization/application/run_controller.dart';
import 'package:bastide/features/categorization/domain/categorization_run.dart';
import 'package:bastide/features/rules/application/rule_preview_controller.dart';
import 'package:bastide/features/rules/domain/rule.dart';
import 'package:bastide/features/transactions/application/transactions_controller.dart';
import 'package:bastide/features/categories/domain/category.dart';
import 'package:bastide/features/transactions/domain/transaction.dart';
import 'package:bastide/features/transactions/presentation/always_categorize_modal.dart';
import 'package:bastide/features/transactions/presentation/transactions_screen.dart';
import 'package:bastide/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_accounts_controller.dart';
import 'package:bastide/features/transactions/presentation/transaction_row.dart';

import '../../support/fake_transactions_controller.dart';

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

Transaction _transaction({
  String id = 't1',
  int amountMinor = -1250,
  bool needsReview = false,
  TransactionCategory? category,
  String? merchant = 'Carrefour',
  String? memo,
}) => Transaction(
  id: id,
  accountId: 'a1',
  bookedDate: DateTime(2026, 5, 14),
  valueDate: null,
  amountMinor: amountMinor,
  currency: 'EUR',
  descriptionRaw: 'CB CARREFOUR MARKET 14/05',
  descriptionClean: 'Carrefour Market',
  memo: memo,
  merchant: merchant,
  category: category,
  categorizationSource: category == null
      ? CategorizationSource.uncategorized
      : CategorizationSource.rule,
  categorizationConfidence: null,
  needsReview: needsReview,
  fitid: null,
  dedupHash: 'hash-1',
  createdAt: DateTime.utc(2026, 5, 14),
  updatedAt: DateTime.utc(2026, 5, 14),
);

const _groceriesCategory = TransactionCategory(
  id: 'c1',
  name: 'category.food.groceries',
  kind: 'expense',
  icon: 'shopping_cart',
  color: '#10B981',
);

Widget _wrap({
  required FakeTransactionsController controller,
  List<AppCategory> categories = const [
    AppCategory(
      id: 'c1',
      userId: null,
      parentId: null,
      name: 'category.food.groceries',
      kind: 'expense',
      icon: 'shopping_cart',
      color: '#10B981',
      isSystem: true,
    ),
  ],
  Locale locale = const Locale('fr'),
}) {
  return ProviderScope(
    overrides: [
      transactionsControllerProvider.overrideWith(() => controller),
      transactionCategoriesProvider.overrideWith((ref) async => categories),
      accountsControllerProvider.overrideWith(
        () => FakeAccountsController(initialAccounts: [_account]),
      ),
      // Rules-only expectations: no opted-in AI, so no stage-2 chrome anywhere —
      // and no health probe leaving the test either.
      aiAvailabilityProvider.overrideWith(
        (ref) async => AiAvailability.unavailable,
      ),
      // The rule modal pre-fills from the sidecar; no widget test reaches one.
      ruleSuggestionProvider.overrideWith(
        (ref, transactionId) async => const RuleSuggestion(
          matchField: RuleMatchField.merchant,
          matchType: RuleMatchType.contains,
          pattern: 'CARREFOUR',
        ),
      ),
    ],
    child: MaterialApp(
      locale: locale,
      theme: appDarkTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: TransactionsScreen()),
    ),
  );
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(TransactionsScreen)));

/// The panel is drawn for the 1440×900 desktop frame the design targets —
/// the default test surface is narrower than the filter bar + row layout.
void _useDesktopSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('renders the row amount, sign and category for the fr locale', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        controller: FakeTransactionsController(
          initialPage: TransactionsPage(
            items: [
              _transaction(amountMinor: -1250, category: _groceriesCategory),
            ],
            page: 1,
            pageSize: 50,
            total: 1,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final expectedAmount = formatAmount(
      amountMinor: -1250,
      currency: 'EUR',
      locale: 'fr',
      showPositiveSign: true,
    );
    expect(find.text(expectedAmount), findsOneWidget);
    expect(find.text('Courses'), findsOneWidget);
  });

  testWidgets('a row with a memo shows it before the account name', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        controller: FakeTransactionsController(
          initialPage: TransactionsPage(
            items: [_transaction(memo: 'Abonnement mensuel')],
            page: 1,
            pageSize: 50,
            total: 1,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Abonnement mensuel · Compte courant'), findsOneWidget);
  });

  testWidgets('a row without a memo keeps the account name alone', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        controller: FakeTransactionsController(
          initialPage: TransactionsPage(
            items: [_transaction()],
            page: 1,
            pageSize: 50,
            total: 1,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Compte courant'), findsOneWidget);
  });

  testWidgets(
    'the category pill holds one column however long the merchant name is',
    (tester) async {
      _useDesktopSurface(tester);
      await tester.pumpWidget(
        _wrap(
          controller: FakeTransactionsController(
            initialPage: TransactionsPage(
              items: [
                _transaction(
                  id: 't1',
                  merchant: 'Carrefour',
                  category: _groceriesCategory,
                ),
                _transaction(
                  id: 't2',
                  merchant: 'Prélèvement mensuel Assurance Habitation Matmut',
                  category: _groceriesCategory,
                ),
              ],
              page: 1,
              pageSize: 50,
              total: 2,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      double pillLeft(String merchant) => tester
          .getRect(
            find.descendant(
              of: find.ancestor(
                of: find.text(merchant),
                matching: find.byType(TransactionRow),
              ),
              matching: find.byKey(const Key('transactionRowCategoryChip')),
            ),
          )
          .left;

      // The label block is tight, so a short merchant no longer pulls its pill left:
      // every row starts its pill at the same x and they read as one column.
      expect(
        pillLeft('Carrefour'),
        pillLeft('Prélèvement mensuel Assurance Habitation Matmut'),
      );
      // …and the long name still gets room to run well past the old 290px cap
      // before it ellipsizes.
      expect(
        tester
            .getSize(
              find.text('Prélèvement mensuel Assurance Habitation Matmut'),
            )
            .width,
        greaterThan(290),
      );
    },
  );

  testWidgets('renders the row amount, sign and category for the en locale', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        controller: FakeTransactionsController(
          initialPage: TransactionsPage(
            items: [
              _transaction(amountMinor: 285000, category: _groceriesCategory),
            ],
            page: 1,
            pageSize: 50,
            total: 1,
          ),
        ),
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();

    final expectedAmount = formatAmount(
      amountMinor: 285000,
      currency: 'EUR',
      locale: 'en',
      showPositiveSign: true,
    );
    expect(find.text(expectedAmount), findsOneWidget);
    expect(find.text('Groceries'), findsOneWidget);
  });

  testWidgets('an uncategorized row shows the dashed uncategorized chip', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        controller: FakeTransactionsController(
          initialPage: TransactionsPage(
            items: [_transaction(category: null)],
            page: 1,
            pageSize: 50,
            total: 1,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Non catégorisé'), findsOneWidget);
  });

  testWidgets(
    'the review queue lets the user resolve an item via the category picker',
    (tester) async {
      _useDesktopSurface(tester);
      final controller = FakeTransactionsController(
        initialPage: TransactionsPage(
          items: [_transaction(id: 't1', category: null, needsReview: true)],
          page: 1,
          pageSize: 50,
          total: 1,
        ),
      );

      await tester.pumpWidget(_wrap(controller: controller));
      await tester.pumpAndSettle();
      _container(
        tester,
      ).read(transactionFiltersProvider.notifier).setNeedsReview(true);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('reviewQueueList')), findsOneWidget);
      expect(find.byKey(const Key('reviewRowCategoryChip')), findsOneWidget);

      await tester.tap(find.byKey(const Key('reviewRowCategoryChip')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('categoryPickerItem-c1')));
      await tester.pumpAndSettle();

      expect(controller.updateCategoryCalls, [
        (transactionId: 't1', categoryId: 'c1'),
      ]);
    },
  );

  testWidgets(
    'the review queue "always categorize" affordance opens the rule modal',
    (tester) async {
      _useDesktopSurface(tester);
      final controller = FakeTransactionsController(
        initialPage: TransactionsPage(
          items: [_transaction(id: 't1', category: null, needsReview: true)],
          page: 1,
          pageSize: 50,
          total: 1,
        ),
      );

      await tester.pumpWidget(_wrap(controller: controller));
      await tester.pumpAndSettle();
      _container(
        tester,
      ).read(transactionFiltersProvider.notifier).setNeedsReview(true);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('reviewRowAlwaysButton')));
      await tester.pump();

      expect(find.byType(AlwaysCategorizeModal), findsOneWidget);
    },
  );

  testWidgets(
    'renders the empty state with no transactions and no active filter',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          controller: FakeTransactionsController(
            initialPage: const TransactionsPage(
              items: [],
              page: 1,
              pageSize: 50,
              total: 0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Aucune transaction pour l\'instant'), findsOneWidget);
      expect(find.byKey(const Key('transactionsList')), findsNothing);
    },
  );

  testWidgets('renders under en without missing localized keys', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        controller: FakeTransactionsController(
          initialPage: const TransactionsPage(
            items: [],
            page: 1,
            pageSize: 50,
            total: 0,
          ),
        ),
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No transactions yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
