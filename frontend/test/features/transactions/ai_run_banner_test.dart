import 'package:finstride/core/theme/app_theme.dart';
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

Transaction _row(String id) => Transaction(
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
  category: null,
  categorizationSource: CategorizationSource.uncategorized,
  categorizationConfidence: null,
  needsReview: true,
  fitid: null,
  dedupHash: 'hash-$id',
  createdAt: DateTime.utc(2026, 5, 12),
  updatedAt: DateTime.utc(2026, 5, 12),
);

CategorizationRun _run({
  required RunStatus status,
  int total = 213,
  int processed = 84,
  int assigned = 61,
  int deferred = 23,
  int failed = 0,
}) => CategorizationRun(
  id: 'run-1',
  accountId: null,
  importBatchId: null,
  trigger: RunTrigger.manual,
  status: status,
  modelTag: 'gemma-4-e4b',
  totalCount: total,
  processedCount: processed,
  assignedCount: assigned,
  deferredCount: deferred,
  failedCount: failed,
  errorMessage: null,
  startedAt: DateTime.utc(2026, 5, 14, 10),
  finishedAt: null,
  createdAt: DateTime.utc(2026, 5, 14, 10),
);

/// A run controller that never talks to a sidecar: it holds whatever state the
/// test seeded and records the calls the banner makes.
class FakeRunController extends RunController {
  FakeRunController(this.initial);

  final RunState initial;

  int cancelCalls = 0;
  int startCalls = 0;
  String? lastAccountId;

  @override
  RunState build() => initial;

  @override
  Future<void> start({String? accountId, RunScope scope = RunScope.pending}) async {
    startCalls++;
    lastAccountId = accountId;
  }

  @override
  Future<void> cancel() async {
    cancelCalls++;
    state = state.copyWith(run: _run(status: RunStatus.cancelled));
  }

  @override
  void dismissBanner() => state = state.copyWith(isBannerDismissed: true);
}

const _catalog = <AppCategory>[];
const _aiOn = AiAvailability(enabled: true, reachable: true);

Widget _wrap({
  required FakeRunController run,
  AiAvailability availability = _aiOn,
  Locale locale = const Locale('fr'),
}) {
  final controller = FakeTransactionsController(
    initialPage: TransactionsPage(
      items: [_row('t1'), _row('t2')],
      page: 1,
      pageSize: 50,
      total: 2,
    ),
  );

  return ProviderScope(
    overrides: [
      transactionsControllerProvider.overrideWith(() => controller),
      transactionCategoriesProvider.overrideWith((ref) async => _catalog),
      accountsControllerProvider.overrideWith(
        () => FakeAccountsController(initialAccounts: [_account]),
      ),
      aiAvailabilityProvider.overrideWith((ref) async => availability),
      runControllerProvider.overrideWith(() => run),
    ],
    child: MaterialApp(
      locale: locale,
      theme: appDarkTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ReviewQueue(items: [_row('t1'), _row('t2')], total: 2),
      ),
    ),
  );
}

void _useDesktopSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('the running banner replaces the header card', (tester) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(run: FakeRunController(RunState(run: _run(status: RunStatus.running)))),
    );
    await tester.pump();

    expect(find.byKey(const Key('aiRunBanner')), findsOneWidget);
    expect(find.byKey(const Key('reviewQueueHeaderCard')), findsNothing);
    expect(
      find.text('Catégorisation en cours — 84 sur 213 transactions'),
      findsOneWidget,
    );
    expect(
      find.text('61 classées · 23 à vérifier · le panneau reste utilisable'),
      findsOneWidget,
    );

    // Nothing blocks: the list is still there, and a row still opens its
    // picker while the run is in flight.
    expect(find.byKey(const Key('reviewQueueList')), findsOneWidget);
    await tester.tap(find.byKey(const Key('reviewRowCategoryChip')).first);
    // Pumped rather than settled: the banner's spinner never stops, so
    // `pumpAndSettle` has nothing to settle to while a run is in flight.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('categoryPickerSearchField')), findsOneWidget);
  });

  testWidgets('the header card is restored once the run ends', (tester) async {
    _useDesktopSurface(tester);
    final run = FakeRunController(RunState(run: _run(status: RunStatus.running)));
    await tester.pumpWidget(_wrap(run: run));
    await tester.pump();

    await tester.tap(find.byKey(const Key('aiRunBannerCancel')));
    await tester.pumpAndSettle();

    expect(run.cancelCalls, 1);
    expect(find.byKey(const Key('aiRunBanner')), findsNothing);
    expect(find.byKey(const Key('reviewQueueHeaderCard')), findsOneWidget);
  });

  testWidgets('the start action asks for a run over the filtered account', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    final run = FakeRunController(const RunState());
    await tester.pumpWidget(_wrap(run: run));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('reviewQueueRunButton')));
    await tester.pumpAndSettle();

    expect(run.startCalls, 1);
  });

  testWidgets('a partial run reports what it could not analyse, dismissibly', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    final run = FakeRunController(
      RunState(run: _run(status: RunStatus.partial, processed: 213, failed: 12)),
    );
    await tester.pumpWidget(_wrap(run: run));
    await tester.pump();

    expect(
      find.text("Catégorisation terminée — 12 transactions n'ont pas pu être analysées."),
      findsOneWidget,
    );
    expect(find.byKey(const Key('aiRunBannerAction')), findsOneWidget);
    // A report, not a wall: the queue is right there underneath it.
    expect(find.byKey(const Key('reviewQueueList')), findsOneWidget);

    await tester.tap(find.byKey(const Key('aiRunBannerDismiss')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('aiRunPartialBanner')), findsNothing);
  });

  testWidgets('a failed run reports plainly and blocks nothing', (tester) async {
    _useDesktopSurface(tester);
    final run = FakeRunController(
      RunState(run: _run(status: RunStatus.failed, processed: 0, assigned: 0)),
    );
    await tester.pumpWidget(_wrap(run: run));
    await tester.pump();

    expect(find.byKey(const Key('aiRunFailedBanner')), findsOneWidget);
    expect(find.text("La catégorisation n'a pas pu s'exécuter."), findsOneWidget);
    expect(find.byKey(const Key('reviewQueueList')), findsOneWidget);
  });

  testWidgets('a run that succeeded says nothing at all', (tester) async {
    _useDesktopSurface(tester);
    final run = FakeRunController(
      RunState(run: _run(status: RunStatus.success, processed: 213, deferred: 0)),
    );
    await tester.pumpWidget(_wrap(run: run));
    await tester.pump();

    expect(find.byKey(const Key('aiRunPartialBanner')), findsNothing);
    expect(find.byKey(const Key('aiRunFailedBanner')), findsNothing);
    expect(find.byKey(const Key('reviewQueueHeaderCard')), findsOneWidget);
  });

  testWidgets('a start that failed is reported without touching the queue', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    final run = FakeRunController(const RunState(error: 'boom'));
    await tester.pumpWidget(_wrap(run: run));
    await tester.pump();

    expect(find.byKey(const Key('reviewRunError')), findsOneWidget);
    expect(find.byKey(const Key('reviewQueueHeaderCard')), findsOneWidget);
    expect(find.byKey(const Key('reviewQueueList')), findsOneWidget);
  });

  testWidgets('with AI off there is no run control at all', (tester) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        run: FakeRunController(const RunState()),
        availability: AiAvailability.unavailable,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('reviewQueueRunButton')), findsNothing);
  });

  testWidgets('renders under en with no leftover French', (tester) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        run: FakeRunController(RunState(run: _run(status: RunStatus.running))),
        locale: const Locale('en'),
      ),
    );
    await tester.pump();

    expect(find.text('Categorizing — 84 of 213 transactions'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.textContaining('Catégorisation'), findsNothing);
  });
}
