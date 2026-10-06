import 'package:finstride/core/theme/app_theme.dart';
import 'package:finstride/core/widgets/confidence_gauge.dart';
import 'package:finstride/core/widgets/proposed_category_chip.dart';
import 'package:finstride/features/accounts/application/accounts_controller.dart';
import 'package:finstride/features/accounts/domain/account.dart';
import 'package:finstride/features/categories/domain/category.dart';
import 'package:finstride/features/categorization/application/run_controller.dart';
import 'package:finstride/features/categorization/domain/categorization_run.dart';
import 'package:finstride/features/transactions/application/transactions_controller.dart';
import 'package:finstride/features/transactions/domain/transaction.dart';
import 'package:finstride/features/transactions/presentation/review_queue.dart';
import 'package:finstride/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_accounts_controller.dart';
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

const _electronics = TransactionCategory(
  id: 'c-electronics',
  name: 'category.shopping.electronics',
  kind: 'expense',
  icon: 'devices',
  color: '#64748B',
);

const _catalog = [
  AppCategory(
    id: 'c-electronics',
    userId: null,
    parentId: null,
    name: 'category.shopping.electronics',
    kind: 'expense',
    icon: 'devices',
    color: '#64748B',
    isSystem: true,
  ),
];

/// The frame ⑥ demo row: « CB NOVATECH SAS 12/05 », proposed « Électronique »
/// at 71 %, still `needs_review`.
Transaction _proposed({String id = 't-proposed', double confidence = 0.71}) =>
    Transaction(
      id: id,
      accountId: 'a1',
      bookedDate: DateTime(2026, 5, 12),
      valueDate: null,
      amountMinor: -4990,
      currency: 'EUR',
      descriptionRaw: 'CB NOVATECH SAS 12/05',
      descriptionClean: 'Novatech',
      memo: null,
      merchant: 'Novatech',
      category: _electronics,
      categorizationSource: CategorizationSource.model,
      categorizationConfidence: confidence,
      needsReview: true,
      fitid: null,
      dedupHash: 'hash-proposed',
      createdAt: DateTime.utc(2026, 5, 12),
      updatedAt: DateTime.utc(2026, 5, 12),
    );

/// « VIR RECU M. DUBOIS » — the model had nothing for it.
Transaction _unproposed({String id = 't-none'}) => Transaction(
  id: id,
  accountId: 'a1',
  bookedDate: DateTime(2026, 5, 9),
  valueDate: null,
  amountMinor: 42000,
  currency: 'EUR',
  descriptionRaw: 'VIR RECU M. DUBOIS',
  descriptionClean: 'Virement Dubois',
  memo: null,
  merchant: null,
  category: null,
  categorizationSource: CategorizationSource.uncategorized,
  categorizationConfidence: null,
  needsReview: true,
  fitid: null,
  dedupHash: 'hash-none',
  createdAt: DateTime.utc(2026, 5, 9),
  updatedAt: DateTime.utc(2026, 5, 9),
);

/// A row a deterministic rule already settled. It never reaches the queue in
/// the app, but the widget must not decorate it if it somehow does — rules
/// always win over AI proposals (`docs/design/07` §Phase 2, Rules).
Transaction _ruleRow() => Transaction(
  id: 't-rule',
  accountId: 'a1',
  bookedDate: DateTime(2026, 5, 7),
  valueDate: null,
  amountMinor: -8640,
  currency: 'EUR',
  descriptionRaw: 'CB SNCF CONNECT',
  descriptionClean: 'SNCF Connect',
  memo: null,
  merchant: 'SNCF',
  category: _electronics,
  categorizationSource: CategorizationSource.rule,
  categorizationConfidence: null,
  needsReview: true,
  fitid: null,
  dedupHash: 'hash-rule',
  createdAt: DateTime.utc(2026, 5, 7),
  updatedAt: DateTime.utc(2026, 5, 7),
);

Widget _wrap({
  required FakeTransactionsController controller,
  required AiAvailability availability,
  required int total,
  Locale locale = const Locale('fr'),
}) {
  return ProviderScope(
    overrides: [
      transactionsControllerProvider.overrideWith(() => controller),
      transactionCategoriesProvider.overrideWith((ref) async => _catalog),
      accountsControllerProvider.overrideWith(
        () => FakeAccountsController(initialAccounts: [_account]),
      ),
      aiAvailabilityProvider.overrideWith((ref) async => availability),
    ],
    child: MaterialApp(
      locale: locale,
      theme: appDarkTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ReviewQueue(items: controller.initialPage.items, total: total),
      ),
    ),
  );
}

FakeTransactionsController _controller(List<Transaction> items) =>
    FakeTransactionsController(
      initialPage: TransactionsPage(
        items: items,
        page: 1,
        pageSize: 50,
        total: items.length,
      ),
    );

void _useDesktopSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

const _aiOn = AiAvailability(enabled: true, reachable: true);

void main() {
  testWidgets(
    'a proposed row shows the dashed chip, the gauge and a percentage',
    (tester) async {
      _useDesktopSurface(tester);
      final controller = _controller([_proposed()]);
      await tester.pumpWidget(
        _wrap(controller: controller, availability: _aiOn, total: 1),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ProposedCategoryChip), findsOneWidget);
      expect(find.byType(ConfidenceGauge), findsOneWidget);
      // A percentage, never the raw 0.71 the API returns.
      expect(find.textContaining('71'), findsWidgets);
      expect(find.textContaining('0.71'), findsNothing);
      expect(find.byKey(const Key('reviewRowConfirmButton')), findsOneWidget);
      expect(find.byKey(const Key('reviewRowCorrectButton')), findsOneWidget);
    },
  );

  testWidgets('a rule row is left alone', (tester) async {
    _useDesktopSurface(tester);
    final controller = _controller([_ruleRow()]);
    await tester.pumpWidget(
      _wrap(controller: controller, availability: _aiOn, total: 1),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ProposedCategoryChip), findsNothing);
    expect(find.byType(ConfidenceGauge), findsNothing);
    expect(find.byKey(const Key('reviewRowConfirmButton')), findsNothing);
  });

  testWidgets('a row with no proposal says so and offers the picker', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    final controller = _controller([_unproposed()]);
    await tester.pumpWidget(
      _wrap(controller: controller, availability: _aiOn, total: 1),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('reviewRowNoProposal')), findsOneWidget);
    expect(find.byKey(const Key('reviewRowChooseCategory')), findsOneWidget);
    expect(find.byKey(const Key('reviewRowCategoryChip')), findsOneWidget);
    expect(find.byType(ProposedCategoryChip), findsNothing);
  });

  testWidgets('Confirmer assigns the proposed category', (tester) async {
    _useDesktopSurface(tester);
    final controller = _controller([_proposed()]);
    await tester.pumpWidget(
      _wrap(controller: controller, availability: _aiOn, total: 1),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('reviewRowConfirmButton')));
    await tester.pumpAndSettle();

    expect(controller.updateCategoryCalls, [
      (transactionId: 't-proposed', categoryId: 'c-electronics'),
    ]);
  });

  testWidgets('Corriger opens the category picker', (tester) async {
    _useDesktopSurface(tester);
    final controller = _controller([_proposed()]);
    await tester.pumpWidget(
      _wrap(controller: controller, availability: _aiOn, total: 1),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('reviewRowCorrectButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('categoryPickerList')), findsOneWidget);

    await tester.tap(find.byKey(const Key('categoryPickerItem-c-electronics')));
    await tester.pumpAndSettle();

    expect(controller.updateCategoryCalls, [
      (transactionId: 't-proposed', categoryId: 'c-electronics'),
    ]);
  });

  testWidgets('the header card counts what the model proposed for', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    final controller = _controller([
      _proposed(),
      _proposed(id: 't-2'),
      _unproposed(),
    ]);
    await tester.pumpWidget(
      _wrap(controller: controller, availability: _aiOn, total: 3),
    );
    await tester.pumpAndSettle();

    expect(find.text('3 transactions à vérifier'), findsOneWidget);
    expect(find.textContaining('propose une catégorie pour 2'), findsOneWidget);
  });

  testWidgets('the progress label counts against the session baseline', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    final controller = _controller([_proposed(), _unproposed()]);

    // Four rows were queued when the panel opened; two have been resolved.
    Widget build(int total) =>
        _wrap(controller: controller, availability: _aiOn, total: total);
    await tester.pumpWidget(build(4));
    await tester.pumpAndSettle();
    await tester.pumpWidget(build(2));
    await tester.pumpAndSettle();

    expect(find.textContaining('2/4'), findsOneWidget);
    expect(find.textContaining('50'), findsOneWidget);
  });

  testWidgets(
    'with AI off the queue is the Phase 1 queue plus one invitation',
    (tester) async {
      _useDesktopSurface(tester);
      final controller = _controller([_proposed(), _unproposed()]);
      await tester.pumpWidget(
        _wrap(
          controller: controller,
          availability: AiAvailability.unavailable,
          total: 2,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ProposedCategoryChip), findsNothing);
      expect(find.byType(ConfidenceGauge), findsNothing);
      expect(find.byKey(const Key('reviewRowConfirmButton')), findsNothing);
      expect(find.byKey(const Key('reviewRowCorrectButton')), findsNothing);
      expect(find.byKey(const Key('reviewRowNoProposal')), findsNothing);

      expect(find.byKey(const Key('reviewAiInvitation')), findsOneWidget);
      expect(find.byKey(const Key('reviewAiInvitationLink')), findsOneWidget);
      // Still fully usable: every row keeps its Phase 1 chip and picker.
      expect(find.byKey(const Key('reviewRowCategoryChip')), findsNWidgets(2));
    },
  );

  testWidgets('an opted-in user whose runtime is down sees no AI UI either', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    final controller = _controller([_proposed()]);
    await tester.pumpWidget(
      _wrap(
        controller: controller,
        availability: const AiAvailability(enabled: true, reachable: false),
        total: 1,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ProposedCategoryChip), findsNothing);
    expect(find.byKey(const Key('reviewAiInvitation')), findsOneWidget);
  });

  testWidgets('renders under en with no leftover French', (tester) async {
    _useDesktopSurface(tester);
    final controller = _controller([_proposed(), _unproposed()]);
    await tester.pumpWidget(
      _wrap(
        controller: controller,
        availability: _aiOn,
        total: 2,
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2 transactions to review'), findsOneWidget);
    expect(find.text('Confirm'), findsOneWidget);
    expect(find.text('Correct'), findsOneWidget);
    expect(find.text('— no proposal'), findsOneWidget);
    expect(find.textContaining('Confidence'), findsOneWidget);
    expect(find.textContaining('Confiance'), findsNothing);
  });
}
