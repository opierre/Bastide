import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/core/theme/tokens.dart';
import 'package:bastide/core/widgets/app_button.dart';
import 'package:bastide/core/widgets/repere_meter.dart';
import 'package:bastide/features/accounts/application/accounts_controller.dart';
import 'package:bastide/features/accounts/domain/account.dart';
import 'package:bastide/features/categories/domain/category.dart';
import 'package:bastide/features/categorization/application/run_controller.dart';
import 'package:bastide/features/categorization/domain/categorization_run.dart';
import 'package:bastide/features/transactions/application/transactions_controller.dart';
import 'package:bastide/features/transactions/domain/transaction.dart';
import 'package:bastide/features/transactions/presentation/review_queue.dart';
import 'package:bastide/l10n/app_localizations.dart';
import 'package:flutter/gestures.dart';
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
  color: 'cat0',
);

const _catalog = [
  AppCategory(
    id: 'c-electronics',
    userId: null,
    parentId: null,
    name: 'category.shopping.electronics',
    kind: 'expense',
    icon: 'devices',
    color: 'cat0',
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
/// always win over AI proposals (`docs/design/07` §Amendment — AI proposals, Rules).
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
      theme: AppTheme.dark,
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
  testWidgets('a proposed row shows the category label and its confidence', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    final controller = _controller([_proposed()]);
    await tester.pumpWidget(
      _wrap(controller: controller, availability: _aiOn, total: 1),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('reviewRowProposal')), findsOneWidget);
    expect(find.text('Électronique'), findsOneWidget);
    // A percentage set as text, never the raw 0.71 nor a gauge.
    expect(find.text('confiance 71 %'), findsOneWidget);
    expect(find.textContaining('0.71'), findsNothing);
    expect(find.byKey(const Key('reviewRowConfirmButton')), findsOneWidget);
    expect(find.byKey(const Key('reviewRowCorrectButton')), findsOneWidget);
    expect(find.byKey(const Key('reviewRowAlwaysButton')), findsOneWidget);
    expect(find.text('CB NOVATECH SAS 12/05'), findsOneWidget);
  });

  testWidgets('the raw label is set in Geist Mono', (tester) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        controller: _controller([_proposed()]),
        availability: _aiOn,
        total: 1,
      ),
    );
    await tester.pumpAndSettle();

    final label = tester.widget<Text>(find.byKey(const Key('reviewRowLabel')));
    expect(label.style?.fontFamily, AppFonts.mono);
  });

  testWidgets('a rule row carries no proposal', (tester) async {
    _useDesktopSurface(tester);
    final controller = _controller([_ruleRow()]);
    await tester.pumpWidget(
      _wrap(controller: controller, availability: _aiOn, total: 1),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('reviewRowProposal')), findsNothing);
    expect(find.byKey(const Key('categoryLabelConfidence')), findsNothing);
    expect(find.byKey(const Key('reviewRowConfirmButton')), findsNothing);
    expect(find.byKey(const Key('reviewRowNoProposal')), findsOneWidget);
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

    expect(find.text('Aucune proposition'), findsOneWidget);
    expect(find.byKey(const Key('reviewRowChooseCategory')), findsOneWidget);
    expect(find.byKey(const Key('reviewRowAlwaysButton')), findsOneWidget);
    expect(find.byKey(const Key('reviewRowConfirmButton')), findsNothing);
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

  testWidgets('only the row under the pointer shows Confirmer as primary', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    final controller = _controller([_proposed(), _proposed(id: 't-2')]);
    await tester.pumpWidget(
      _wrap(controller: controller, availability: _aiOn, total: 2),
    );
    await tester.pumpAndSettle();

    List<AppButtonVariant> variants() => tester
        .widgetList<AppButton>(find.byKey(const Key('reviewRowConfirmButton')))
        .map((button) => button.variant)
        .toList();
    expect(variants(), [
      AppButtonVariant.secondary,
      AppButtonVariant.secondary,
    ]);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(
      tester.getCenter(find.byKey(const Key('reviewRow-t-2'))),
    );
    await tester.pumpAndSettle();

    expect(variants(), [AppButtonVariant.secondary, AppButtonVariant.primary]);
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
    expect(find.byKey(const Key('categoryPickerCheck')), findsOneWidget);

    await tester.tap(find.byKey(const Key('categoryPickerItem-c-electronics')));
    await tester.pumpAndSettle();

    expect(controller.updateCategoryCalls, [
      (transactionId: 't-proposed', categoryId: 'c-electronics'),
    ]);
  });

  testWidgets('the Note counts what the model proposed for', (tester) async {
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

    expect(
      find.text(
        'L’IA locale propose une catégorie pour 2 opérations. '
        'Rien n’est classé sans votre accord.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('reviewQueueRunButton')), findsOneWidget);
    expect(find.byKey(const Key('reviewAiInvitation')), findsNothing);
  });

  for (final width in [1440.0, 2560.0]) {
    testWidgets('the run button and its Note hug the row end at $width px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _wrap(
          controller: _controller([_proposed()]),
          availability: _aiOn,
          total: 1,
        ),
      );
      await tester.pumpAndSettle();

      final row = tester.getRect(find.byKey(const Key('reviewProgressRow')));
      final button = tester.getRect(
        find.byKey(const Key('reviewQueueRunButton')),
      );
      final note = tester.getRect(find.byKey(const Key('reviewAiNote')));
      expect(button.right, moreOrLessEquals(row.right));
      expect(note.right, moreOrLessEquals(button.left - AppSpacing.md));
    });
  }

  testWidgets('the progress counts against the session baseline', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    final controller = _controller([_proposed(), _unproposed()]);

    // Four rows were queued when the panel opened; two have been filed.
    Widget build(int total) =>
        _wrap(controller: controller, availability: _aiOn, total: total);
    await tester.pumpWidget(build(4));
    await tester.pumpAndSettle();
    await tester.pumpWidget(build(2));
    await tester.pumpAndSettle();

    expect(find.text('2 sur 4 classées'), findsOneWidget);
    final meter = tester.widget<RepereMeter>(find.byType(RepereMeter));
    expect(meter.fraction, 0.5);
    expect(meter.markFraction, isNull);
  });

  testWidgets(
    'with AI off rows say « Aucune proposition » and one Note invites',
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

      expect(find.byKey(const Key('reviewRowProposal')), findsNothing);
      expect(find.byKey(const Key('reviewRowConfirmButton')), findsNothing);
      expect(find.byKey(const Key('reviewRowNoProposal')), findsNWidgets(2));
      expect(
        find.byKey(const Key('reviewRowChooseCategory')),
        findsNWidgets(2),
      );
      expect(find.byKey(const Key('reviewAiNote')), findsNothing);
      expect(find.byKey(const Key('reviewQueueRunButton')), findsNothing);
      expect(
        find.text(
          'Activez l’IA locale pour classer les opérations que vos règles '
          'n’ont pas reconnues.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('reviewAiInvitationLink')), findsOneWidget);
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

    expect(find.byKey(const Key('reviewRowProposal')), findsNothing);
    expect(find.byKey(const Key('reviewAiInvitation')), findsOneWidget);
  });

  testWidgets('an empty queue says so, with no button', (tester) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(controller: _controller([]), availability: _aiOn, total: 0),
    );
    await tester.pumpAndSettle();

    expect(find.text('Rien à vérifier'), findsOneWidget);
    expect(
      find.text('Toutes vos opérations ont une catégorie.'),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('reviewQueueEmpty')),
        matching: find.byType(AppButton),
      ),
      findsNothing,
    );
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

    expect(find.text('Statement label'), findsOneWidget);
    expect(find.text('Proposal'), findsOneWidget);
    expect(find.text('Confirm'), findsOneWidget);
    expect(find.text('Correct'), findsOneWidget);
    expect(find.text('No proposal'), findsOneWidget);
    expect(find.text('0 of 2 filed'), findsOneWidget);
    expect(find.textContaining('confidence 71'), findsOneWidget);
    expect(find.textContaining('confiance'), findsNothing);
  });
}
