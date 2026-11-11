import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/core/theme/tokens.dart';
import 'package:bastide/features/accounts/application/account_detail_controller.dart';
import 'package:bastide/features/accounts/application/accounts_controller.dart';
import 'package:bastide/features/accounts/application/settlement_rule_controller.dart';
import 'package:bastide/features/accounts/domain/settlement_rule.dart';
import 'package:bastide/features/accounts/presentation/account_detail_screen.dart';
import 'package:bastide/features/categorization/application/run_controller.dart';
import 'package:bastide/features/categorization/domain/categorization_run.dart';
import 'package:bastide/features/recurring/application/subscriptions_controller.dart';
import 'package:bastide/features/recurring/data/recurring_repository.dart';
import 'package:bastide/features/recurring/domain/recurring_series.dart';
import 'package:bastide/features/recurring/domain/series_preview.dart';
import 'package:bastide/features/transactions/application/transactions_controller.dart';
import 'package:bastide/features/transactions/data/transactions_repository.dart';
import 'package:bastide/features/transactions/domain/transaction.dart';
import 'package:bastide/features/transactions/presentation/transactions_screen.dart';
import 'package:bastide/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_accounts_controller.dart';
import '../../support/recurring_fixtures.dart';
import '../accounts/account_overview_fixtures.dart';

class MockRecurringRepository extends Mock implements RecurringRepository {}

/// Serves one charge, linked to the series [FakeSubscriptionsController]
/// creates once a save went through — the way the server answers the reload.
class _FakeTransactionsRepository extends Fake
    implements TransactionsRepository {
  _FakeTransactionsRepository(this._subscriptions);

  final FakeSubscriptionsController _subscriptions;

  @override
  Future<TransactionsPage> list({
    String? accountId,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? categoryId,
    bool? needsReview,
    String? q,
    int page = 1,
    bool includeLinkedCards = false,
  }) async => TransactionsPage(
    items: [
      _transaction(
        _subscriptions.createCalls.isEmpty
            ? null
            : _subscriptions.createCalls.last.id,
      ),
    ],
    page: 1,
    pageSize: 50,
    total: 1,
  );
}

Transaction _transaction(String? recurringSeriesId) => Transaction(
  id: 't1',
  accountId: 'acc-1',
  bookedDate: DateTime(2026, 10, 29),
  valueDate: null,
  amountMinor: -999,
  currency: 'EUR',
  descriptionRaw: 'PRLV STREAMCO',
  descriptionClean: 'STREAMCO',
  memo: null,
  merchant: 'STREAMCO',
  category: null,
  categorizationSource: CategorizationSource.uncategorized,
  categorizationConfidence: null,
  needsReview: false,
  fitid: null,
  dedupHash: 'hash-1',
  recurringSeriesId: recurringSeriesId,
  createdAt: DateTime.utc(2026, 10, 30),
  updatedAt: DateTime.utc(2026, 10, 30),
);

final _preview = SeriesPreview(
  confidence: PreviewConfidence.high,
  reasons: const [PreviewReason.occurrences],
  cadence: Cadence.monthly,
  label: 'STREAMCO',
  expectedAmountMinor: -999,
  currency: 'EUR',
  accountId: 'acc-1',
  transactions: [
    PreviewTransaction(
      id: 't1',
      bookedDate: DateTime(2026, 10, 29),
      amountMinor: -999,
      currency: 'EUR',
      label: 'STREAMCO',
    ),
  ],
);

Future<void> _pump(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(1440, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final subscriptions = FakeSubscriptionsController();
  final recurring = MockRecurringRepository();
  when(() => recurring.preview('t1')).thenAnswer((_) async {
    return Proposal(_preview);
  });
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        transactionsRepositoryProvider.overrideWithValue(
          _FakeTransactionsRepository(subscriptions),
        ),
        recurringRepositoryProvider.overrideWithValue(recurring),
        subscriptionsControllerProvider.overrideWith(() => subscriptions),
        accountsControllerProvider.overrideWith(
          () => FakeAccountsController(
            initialAccounts: [
              accountFrom(accountJson()),
              accountFrom(
                accountJson(
                  id: 'card-2',
                  name: 'Carte Business',
                  type: 'deferred_card',
                  settlementAccountId: 'acc-1',
                ),
              ),
            ],
          ),
        ),
        accountOverviewProvider.overrideWith(
          (ref, id) async => overviewFrom(checkingOverviewJson()),
        ),
        settlementRuleProvider(
          'card-2',
        ).overrideWith((ref) async => const SettlementRuleState()),
        transactionCategoriesProvider.overrideWith((ref) async => const []),
        aiAvailabilityProvider.overrideWith(
          (ref) async => AiAvailability.unavailable,
        ),
      ],
      child: MaterialApp(
        locale: const Locale('fr'),
        theme: appDarkTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: home),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Marks the charge through the dialog, as a user would.
Future<void> _mark(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('transactionRowMarkRecurring')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('markRecurringSave')));
  await tester.pumpAndSettle();
}

void _expectMarked(WidgetTester tester) {
  expect(find.byKey(const Key('transactionRowMarkRecurring')), findsNothing);
  final button = tester.widget<IconButton>(
    find.byKey(const Key('transactionRowOpenRecurringSeries')),
  );
  expect(button.color, AppColors.iris);
}

void main() {
  for (final (name, home) in [
    ('account detail', const AccountDetailScreen(accountId: 'acc-1')),
    ('the Transactions panel', const TransactionsScreen()),
  ]) {
    testWidgets('marking a charge from $name turns its button violet', (
      tester,
    ) async {
      await _pump(tester, home);
      expect(
        find.byKey(const Key('transactionRowMarkRecurring')),
        findsOneWidget,
      );

      await _mark(tester);

      _expectMarked(tester);
      // The toast confirming the save withdraws on its own timer.
      await tester.pump(const Duration(seconds: 7));
      await tester.pumpAndSettle();
    });
  }
}
