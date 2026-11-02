import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/core/theme/tokens.dart';
import 'package:bastide/features/recurring/application/subscriptions_controller.dart';
import 'package:bastide/features/recurring/data/recurring_repository.dart';
import 'package:bastide/features/recurring/domain/recurring_series.dart';
import 'package:bastide/features/recurring/domain/series_preview.dart';
import 'package:bastide/features/recurring/presentation/mark_recurring_dialog.dart';
import 'package:bastide/features/recurring/presentation/subscriptions_screen.dart';
import 'package:bastide/features/transactions/domain/transaction.dart';
import 'package:bastide/features/transactions/presentation/transaction_row.dart';
import 'package:bastide/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/recurring_fixtures.dart';

class MockRecurringRepository extends Mock implements RecurringRepository {}

Transaction _transaction({String? recurringSeriesId}) => Transaction(
  id: 't1',
  accountId: 'a1',
  bookedDate: DateTime(2026, 5, 14),
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
  createdAt: DateTime.utc(2026, 5, 14),
  updatedAt: DateTime.utc(2026, 5, 14),
);

final _preview = SeriesPreview(
  confidence: PreviewConfidence.high,
  reasons: const [PreviewReason.occurrences],
  cadence: Cadence.monthly,
  label: 'STREAMCO',
  expectedAmountMinor: -999,
  currency: 'EUR',
  accountId: 'a1',
  transactions: [
    PreviewTransaction(
      id: 't1',
      bookedDate: DateTime(2026, 5, 14),
      amountMinor: -999,
      currency: 'EUR',
      label: 'STREAMCO',
    ),
  ],
);

/// Pumps one row under a router that knows the Abonnements path, so the
/// button's navigation runs the way it does in the app.
Future<ProviderContainer> _pump(
  WidgetTester tester,
  Transaction transaction, {
  MockRecurringRepository? repository,
  Locale locale = const Locale('fr'),
}) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      recurringRepositoryProvider.overrideWithValue(
        repository ?? MockRecurringRepository(),
      ),
      subscriptionsControllerProvider.overrideWith(
        FakeSubscriptionsController.new,
      ),
    ],
  );
  addTearDown(container.dispose);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, _) => Scaffold(
          body: TransactionRow(
            transaction: transaction,
            accountName: 'Compte courant',
          ),
        ),
      ),
      GoRoute(
        path: SubscriptionsScreen.path,
        builder: (context, _) => const Scaffold(body: Text('subscriptions')),
      ),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        locale: locale,
        theme: appDarkTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

IconButton _button(WidgetTester tester, String key) =>
    tester.widget<IconButton>(find.byKey(Key(key)));

void main() {
  testWidgets('an unmarked charge shows the quiet « Marquer » action', (
    tester,
  ) async {
    await _pump(tester, _transaction());

    expect(
      find.byKey(const Key('transactionRowOpenRecurringSeries')),
      findsNothing,
    );
    final button = _button(tester, 'transactionRowMarkRecurring');
    expect(button.color, AppColors.textDisabled);
    expect(button.style, isNull);
    expect(button.tooltip, 'Marquer comme récurrent');
  });

  testWidgets('tapping it on an unmarked charge opens the mark dialog', (
    tester,
  ) async {
    final repository = MockRecurringRepository();
    when(
      () => repository.preview('t1'),
    ).thenAnswer((_) async => Proposal(_preview));

    await _pump(tester, _transaction(), repository: repository);
    await tester.tap(find.byKey(const Key('transactionRowMarkRecurring')));
    await tester.pumpAndSettle();

    expect(find.byType(MarkRecurringDialog), findsOneWidget);
  });

  testWidgets('a charge in a series shows the iris « voir la série » state', (
    tester,
  ) async {
    await _pump(tester, _transaction(recurringSeriesId: 's9'));

    expect(find.byKey(const Key('transactionRowMarkRecurring')), findsNothing);
    final button = _button(tester, 'transactionRowOpenRecurringSeries');
    expect(button.color, AppColors.iris);
    expect(
      button.style?.backgroundColor?.resolve(<WidgetState>{}),
      AppColors.irisSoft,
    );
    expect(button.tooltip, 'Déjà récurrent — voir la série');
  });

  testWidgets('the marked state reads in English too', (tester) async {
    await _pump(
      tester,
      _transaction(recurringSeriesId: 's9'),
      locale: const Locale('en'),
    );

    expect(
      _button(tester, 'transactionRowOpenRecurringSeries').tooltip,
      'Already recurring — view the series',
    );
  });

  testWidgets('tapping it on a charge in a series opens that series', (
    tester,
  ) async {
    final repository = MockRecurringRepository();

    final container = await _pump(
      tester,
      _transaction(recurringSeriesId: 's9'),
      repository: repository,
    );
    await tester.tap(
      find.byKey(const Key('transactionRowOpenRecurringSeries')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MarkRecurringDialog), findsNothing);
    verifyNever(() => repository.preview(any()));
    expect(find.text('subscriptions'), findsOneWidget);
    expect(container.read(selectedSeriesProvider), 's9');
  });
}
