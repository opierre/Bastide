import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/features/recurring/application/subscriptions_controller.dart';
import 'package:bastide/features/recurring/data/recurring_repository.dart';
import 'package:bastide/features/recurring/domain/recurring_series.dart';
import 'package:bastide/features/recurring/domain/series_preview.dart';
import 'package:bastide/features/recurring/presentation/add_charges_dialog.dart';
import 'package:bastide/features/recurring/presentation/series_detail.dart';
import 'package:bastide/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/recurring_fixtures.dart';

class MockRecurringRepository extends Mock implements RecurringRepository {}

PreviewTransaction _charge(
  String id,
  int month, {
  String label = 'PAYPAL *STREAMCO',
  String accountId = 'a1',
}) => PreviewTransaction(
  id: id,
  bookedDate: DateTime(2026, month, 15),
  amountMinor: -999,
  currency: 'EUR',
  label: label,
  accountId: accountId,
);

CandidatePage _page(
  List<PreviewTransaction> items, {
  int? total,
  int page = 1,
}) => CandidatePage(
  items: items,
  page: page,
  pageSize: 50,
  total: total ?? items.length,
);

Future<void> _pumpDetail(
  WidgetTester tester, {
  required MockRecurringRepository repository,
  FakeSubscriptionsController? controller,
  RecurringSeries? series,
  Locale locale = const Locale('fr'),
}) async {
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        recurringRepositoryProvider.overrideWithValue(repository),
        subscriptionsControllerProvider.overrideWith(
          () => controller ?? FakeSubscriptionsController(),
        ),
        seriesDetailProvider.overrideWith(
          (ref, id) => SeriesDetail(
            series: series ?? testSeries(id: 's1', label: 'Streamco'),
            occurrences: const [],
          ),
        ),
        subscriptionAccountsProvider.overrideWith(
          (ref) => const [
            SeriesAccount(
              id: 'a1',
              name: 'Compte courant',
              institution: 'BNP',
              currency: 'EUR',
            ),
            SeriesAccount(
              id: 'a2',
              name: 'Compte joint',
              institution: 'Revolut',
              currency: 'EUR',
            ),
          ],
        ),
        subscriptionCategoriesProvider.overrideWith((ref) => []),
      ],
      child: MaterialApp(
        locale: locale,
        theme: appDarkTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: SeriesDetailView(seriesId: 's1')),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openPicker(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('seriesDetailAddCharge')));
  await tester.pumpAndSettle();
}

void main() {
  late MockRecurringRepository repository;

  setUp(() {
    repository = MockRecurringRepository();
    when(
      () => repository.candidates(
        's1',
        query: any(named: 'query'),
        page: any(named: 'page'),
      ),
    ).thenAnswer(
      (_) async => _page([
        _charge('c3', 5),
        _charge('c1', 3),
        _charge('c2', 4, label: 'CB BOULANGERIE DU PORT', accountId: 'a2'),
      ]),
    );
  });

  testWidgets('the picker adds the selected charges and closes', (
    tester,
  ) async {
    final controller = FakeSubscriptionsController();

    await _pumpDetail(tester, repository: repository, controller: controller);
    await _openPicker(tester);

    expect(find.text('Ajouter à « Streamco »'), findsOneWidget);
    expect(find.text('Revolut — Compte joint'), findsOneWidget);

    await tester.tap(find.byKey(const Key('chargePickerTick-c3')));
    await tester.tap(find.byKey(const Key('chargePickerTick-c1')));
    await tester.pumpAndSettle();

    expect(find.text('Ajouter 2 opérations'), findsOneWidget);

    await tester.tap(find.byKey(const Key('chargePickerSave')));
    await tester.pumpAndSettle();

    final (seriesId, ids) = controller.attachCalls.single;
    expect(seriesId, 's1');
    // Oldest first, whatever order they were ticked in.
    expect(ids, ['c1', 'c3']);
    expect(find.byType(AddChargesDialog), findsNothing);
  });

  testWidgets('nothing ticked, nothing to add', (tester) async {
    final controller = FakeSubscriptionsController();

    await _pumpDetail(tester, repository: repository, controller: controller);
    await _openPicker(tester);
    await tester.tap(find.byKey(const Key('chargePickerSave')));
    await tester.pumpAndSettle();

    expect(controller.attachCalls, isEmpty);
    expect(find.byType(AddChargesDialog), findsOneWidget);
  });

  testWidgets('the search asks the server, and keeps the ticks', (
    tester,
  ) async {
    when(
      () => repository.candidates(
        's1',
        query: 'boul',
        page: any(named: 'page'),
      ),
    ).thenAnswer(
      (_) async => _page([
        _charge('c2', 4, label: 'CB BOULANGERIE DU PORT', accountId: 'a2'),
      ]),
    );
    final controller = FakeSubscriptionsController();

    await _pumpDetail(tester, repository: repository, controller: controller);
    await _openPicker(tester);
    await tester.tap(find.byKey(const Key('chargePickerTick-c3')));
    await tester.enterText(find.byKey(const Key('chargePickerSearch')), 'boul');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('chargePickerTick-c3')), findsNothing);
    expect(find.byKey(const Key('chargePickerTick-c2')), findsOneWidget);

    await tester.tap(find.byKey(const Key('chargePickerTick-c2')));
    await tester.tap(find.byKey(const Key('chargePickerSave')));
    await tester.pumpAndSettle();

    expect(controller.attachCalls.single.$2, ['c2', 'c3']);
  });

  testWidgets('« Afficher plus » appends the next page', (tester) async {
    when(
      () => repository.candidates('s1', query: any(named: 'query'), page: 1),
    ).thenAnswer((_) async => _page([_charge('c3', 5)], total: 2));
    when(
      () => repository.candidates('s1', query: any(named: 'query'), page: 2),
    ).thenAnswer((_) async => _page([_charge('c1', 3)], total: 2, page: 2));

    await _pumpDetail(tester, repository: repository);
    await _openPicker(tester);
    await tester.tap(find.byKey(const Key('chargePickerLoadMore')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('chargePickerTick-c3')), findsOneWidget);
    expect(find.byKey(const Key('chargePickerTick-c1')), findsOneWidget);
    expect(find.byKey(const Key('chargePickerLoadMore')), findsNothing);
  });

  testWidgets('no candidate says so', (tester) async {
    when(
      () => repository.candidates(
        's1',
        query: any(named: 'query'),
        page: any(named: 'page'),
      ),
    ).thenAnswer((_) async => _page(const []));

    await _pumpDetail(
      tester,
      repository: repository,
      locale: const Locale('en'),
    );
    await _openPicker(tester);

    expect(find.text('Add to “Streamco”'), findsOneWidget);
    expect(
      find.text('Nothing to add: every expense already belongs to a series.'),
      findsOneWidget,
    );
  });

  testWidgets('a failed load offers a retry', (tester) async {
    var calls = 0;
    when(
      () => repository.candidates(
        's1',
        query: any(named: 'query'),
        page: any(named: 'page'),
      ),
    ).thenAnswer((_) async {
      calls++;
      if (calls == 1) throw Exception('offline');
      return _page([_charge('c1', 3)]);
    });

    await _pumpDetail(tester, repository: repository);
    await _openPicker(tester);

    expect(find.text('Impossible de charger les opérations.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('chargePickerRetry')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('chargePickerTick-c1')), findsOneWidget);
  });

  testWidgets('a dismissed series offers no picker', (tester) async {
    await _pumpDetail(
      tester,
      repository: repository,
      series: testSeries(id: 's1', status: SeriesStatus.dismissed),
    );

    expect(find.byKey(const Key('seriesDetailAddCharge')), findsNothing);
  });
}
