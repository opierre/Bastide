import 'package:bastide/core/api/api_client.dart';
import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/core/widgets/primary_button.dart';
import 'package:bastide/features/recurring/application/subscriptions_controller.dart';
import 'package:bastide/features/recurring/data/recurring_repository.dart';
import 'package:bastide/features/recurring/domain/recurring_series.dart';
import 'package:bastide/features/recurring/domain/series_preview.dart';
import 'package:bastide/features/recurring/presentation/mark_recurring_dialog.dart';
import 'package:bastide/features/recurring/presentation/subscriptions_screen.dart';
import 'package:bastide/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/recurring_fixtures.dart';

class MockRecurringRepository extends Mock implements RecurringRepository {}

PreviewTransaction _transaction(String id, int day, {int amount = -999}) =>
    PreviewTransaction(
      id: id,
      bookedDate: DateTime(2026, day, 15),
      amountMinor: amount,
      currency: 'EUR',
      label: 'STREAMCO',
    );

SeriesPreview _preview(
  PreviewConfidence confidence, {
  List<PreviewReason> reasons = const [PreviewReason.occurrences],
  Cadence cadence = Cadence.monthly,
}) => SeriesPreview(
  confidence: confidence,
  reasons: reasons,
  cadence: cadence,
  label: 'STREAMCO',
  expectedAmountMinor: -999,
  currency: 'EUR',
  accountId: 'a1',
  transactions: [
    _transaction('t1', 1),
    _transaction('t2', 2),
    _transaction('t3', 3),
  ],
);

/// Pumps a button that opens the dialog, so its pop and the follow-up
/// navigation run the way they do from a transaction row.
Future<ProviderContainer> _open(
  WidgetTester tester, {
  required MockRecurringRepository repository,
  FakeSubscriptionsController? controller,
  Locale locale = const Locale('fr'),
}) async {
  final container = ProviderContainer(
    // Riverpod's automatic retry would hide the failed-preview state.
    retry: (_, _) => null,
    overrides: [
      recurringRepositoryProvider.overrideWithValue(repository),
      subscriptionsControllerProvider.overrideWith(
        () => controller ?? FakeSubscriptionsController(),
      ),
    ],
  );
  addTearDown(container.dispose);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, _) => Scaffold(
          body: Consumer(
            builder: (context, ref, _) => TextButton(
              key: const Key('open'),
              onPressed: () =>
                  showMarkRecurringDialog(context, ref, transactionId: 't3'),
              child: const Text('open'),
            ),
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
  await tester.tap(find.byKey(const Key('open')));
  await tester.pumpAndSettle();
  return container;
}

void main() {
  late MockRecurringRepository repository;

  setUp(() {
    repository = MockRecurringRepository();
  });

  testWidgets('a high-confidence preview lists every match, all ticked', (
    tester,
  ) async {
    when(() => repository.preview('t3')).thenAnswer(
      (_) async => Proposal(
        _preview(
          PreviewConfidence.high,
          reasons: const [
            PreviewReason.occurrences,
            PreviewReason.cadenceMonthly,
            PreviewReason.amountStable,
          ],
        ),
      ),
    );

    await _open(tester, repository: repository);

    expect(find.text('Confiance élevée'), findsOneWidget);
    expect(find.text('3 opérations trouvées'), findsOneWidget);
    expect(find.text('Rythme mensuel reconnu'), findsOneWidget);
    expect(find.text('Montant stable'), findsOneWidget);
    expect(find.text('Mensuel'), findsOneWidget);
    expect(find.text('3 opérations cochées'), findsOneWidget);
    expect(find.byKey(const Key('markRecurringLowWarning')), findsNothing);
  });

  testWidgets('a medium-confidence preview names what is missing', (
    tester,
  ) async {
    when(() => repository.preview('t3')).thenAnswer(
      (_) async => Proposal(
        _preview(
          PreviewConfidence.medium,
          reasons: const [
            PreviewReason.occurrences,
            PreviewReason.cadenceMonthly,
            PreviewReason.tooFewOccurrences,
          ],
        ),
      ),
    );

    await _open(tester, repository: repository, locale: const Locale('en'));

    expect(find.text('Medium confidence'), findsOneWidget);
    expect(find.text('Fewer than three charges'), findsOneWidget);
    expect(find.byKey(const Key('markRecurringLowWarning')), findsNothing);
  });

  testWidgets('a low-confidence preview warns but still lets the user save', (
    tester,
  ) async {
    when(() => repository.preview('t3')).thenAnswer(
      (_) async => Proposal(
        _preview(
          PreviewConfidence.low,
          reasons: const [PreviewReason.occurrences, PreviewReason.noRhythm],
          cadence: Cadence.irregular,
        ),
      ),
    );
    final controller = FakeSubscriptionsController();

    await _open(tester, repository: repository, controller: controller);

    expect(find.text('Confiance faible'), findsOneWidget);
    expect(find.byKey(const Key('markRecurringLowWarning')), findsOneWidget);
    expect(find.text('Irrégulier'), findsOneWidget);

    await tester.tap(find.byKey(const Key('markRecurringSave')));
    await tester.pumpAndSettle();

    expect(controller.createCalls.single.cadence, Cadence.irregular);
    expect(find.byType(MarkRecurringDialog), findsNothing);
  });

  testWidgets('saving links only the ticked transactions', (tester) async {
    when(
      () => repository.preview('t3'),
    ).thenAnswer((_) async => Proposal(_preview(PreviewConfidence.high)));
    final controller = FakeSubscriptionsController();

    await _open(tester, repository: repository, controller: controller);
    await tester.tap(find.byKey(const Key('markRecurringTick-t2')));
    await tester.pumpAndSettle();

    expect(find.text('2 opérations cochées'), findsOneWidget);

    await tester.tap(find.byKey(const Key('markRecurringSave')));
    await tester.pumpAndSettle();

    expect(controller.createTransactionIds.single, ['t1', 't3']);
    final created = controller.createCalls.single;
    expect(created.label, 'STREAMCO');
    expect(created.accountId, 'a1');
    expect(created.expectedAmountMinor, -999);
  });

  testWidgets('unticking everything disables saving', (tester) async {
    when(
      () => repository.preview('t3'),
    ).thenAnswer((_) async => Proposal(_preview(PreviewConfidence.high)));

    await _open(tester, repository: repository);
    for (final id in ['t1', 't2', 't3']) {
      await tester.tap(find.byKey(Key('markRecurringTick-$id')));
    }
    await tester.pumpAndSettle();

    expect(
      find.text('Cochez au moins une opération pour enregistrer la série.'),
      findsOneWidget,
    );
    final save = tester.widget<PrimaryButton>(
      find.byKey(const Key('markRecurringSave')),
    );
    expect(save.onPressed, isNull);
  });

  testWidgets('a failed save stays open with the reason inline', (
    tester,
  ) async {
    when(
      () => repository.preview('t3'),
    ).thenAnswer((_) async => Proposal(_preview(PreviewConfidence.high)));
    final controller = FakeSubscriptionsController()
      ..errorOnCreate = const ApiFailure(
        code: 'RECURRING_TRANSACTION_LINKED',
        message: 'linked',
      );

    await _open(tester, repository: repository, controller: controller);
    await tester.tap(find.byKey(const Key('markRecurringSave')));
    await tester.pumpAndSettle();

    expect(
      find.text('Certaines opérations appartiennent déjà à une série.'),
      findsOneWidget,
    );
    expect(find.byType(MarkRecurringDialog), findsOneWidget);
  });

  testWidgets('a failed preview offers a retry', (tester) async {
    var calls = 0;
    when(() => repository.preview('t3')).thenAnswer((_) async {
      calls++;
      if (calls == 1) throw Exception('offline');
      return Proposal(_preview(PreviewConfidence.high));
    });

    await _open(tester, repository: repository);
    expect(find.text("Impossible de préparer l'aperçu."), findsOneWidget);

    await tester.tap(find.byKey(const Key('markRecurringRetry')));
    await tester.pumpAndSettle();

    expect(find.text('Confiance élevée'), findsOneWidget);
  });

  testWidgets('a transaction already in a series opens that series', (
    tester,
  ) async {
    when(
      () => repository.preview('t3'),
    ).thenAnswer((_) async => AlreadyInSeries(testSeries(id: 's9')));

    final container = await _open(tester, repository: repository);

    expect(find.byType(MarkRecurringDialog), findsNothing);
    expect(find.text('subscriptions'), findsOneWidget);
    expect(container.read(selectedSeriesProvider), 's9');
  });
}
