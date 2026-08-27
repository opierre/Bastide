import 'package:finstride/core/api/api_client.dart';
import 'package:finstride/core/theme/app_theme.dart';
import 'package:finstride/core/widgets/amount_text.dart';
import 'package:finstride/core/widgets/status_pill.dart';
import 'package:finstride/features/categories/domain/category.dart';
import 'package:finstride/features/recurring/application/subscriptions_controller.dart';
import 'package:finstride/features/recurring/domain/recurring_series.dart';
import 'package:finstride/features/recurring/domain/recurring_summary.dart';
import 'package:finstride/features/recurring/presentation/subscriptions_screen.dart';
import 'package:finstride/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_categories_controller.dart';
import '../../support/recurring_fixtures.dart';

/// The panel's own money formatting, so the expectations can't drift from the
/// locale's separators (French uses a narrow no-break space before « € »).
String _money(int amountMinor, {String locale = 'fr'}) =>
    formatAmount(amountMinor: amountMinor, currency: 'EUR', locale: locale);

Widget _wrap({
  required FakeSubscriptionsController controller,
  Locale locale = const Locale('fr'),
  List<AppCategory> categories = const [],
  List<SeriesAccount> accounts = const [],
}) {
  return ProviderScope(
    overrides: [
      subscriptionsControllerProvider.overrideWith(() => controller),
      subscriptionCategoriesProvider.overrideWith((ref) => categories),
      subscriptionAccountsProvider.overrideWith((ref) => accounts),
    ],
    child: MaterialApp(
      locale: locale,
      theme: appDarkTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: SubscriptionsScreen()),
    ),
  );
}

/// The panel is drawn for the 1440×900 desktop frame the design targets — the
/// table runs to a 230 px Statut column and needs the width it was drawn at.
void _useDesktopSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('a healthy row renders cadence, a neutral amount and the next date', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        controller: FakeSubscriptionsController(
          initialSeries: [testSeries()],
          summary: testSummary(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mensuel'), findsOneWidget);
    expect(find.text('15/05/2026'), findsOneWidget);

    // Unsigned and in the primary ink: an expected charge is not a ledger
    // entry, so the money rule's red would state something false about it.
    final amount = tester.widget<AmountText>(find.byKey(const Key('seriesAmount-s1')));
    expect(amount.amountMinor, 1549);
    expect(amount.colorize, isFalse);
    expect(find.text(_money(1549)), findsOneWidget);

    // Nothing is wrong with this subscription, so the Statut cell is empty.
    expect(find.byType(StatusPill), findsNothing);
  });

  testWidgets('a price increase and a missed charge render as amber pills', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        controller: FakeSubscriptionsController(
          initialSeries: [
            testSeries(),
            testSeries(id: 's2', label: 'Basic-Fit', expectedAmountMinor: -2999),
          ],
          summary: testSummary(
            activeCount: 2,
            priceIncreases: [
              PriceIncrease(
                seriesId: 's1',
                deltaMinor: -200,
                changedAt: DateTime(2026, 4, 15),
              ),
            ],
            missed: [
              MissedCharge(
                seriesId: 's2',
                expectedOn: DateTime(2026, 5, 5),
                daysLate: 9,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final pills = tester.widgetList<StatusPill>(find.byType(StatusPill)).toList();
    expect(pills, hasLength(2));
    expect(pills.every((pill) => pill.tone == StatusPillTone.warning), isTrue);
    expect(
      find.text('Augmentation · ${_money(1349)} → ${_money(1549)}'),
      findsOneWidget,
    );
    expect(find.text('Prélèvement manquant · 9 jours de retard'), findsOneWidget);

    // The overdue row states what was expected instead of printing a past date
    // under a "next charge" header.
    expect(find.byKey(const Key('seriesNextExpected-s2')), findsOneWidget);
    expect(find.text('attendu le 05/05/2026'), findsOneWidget);
  });

  testWidgets('a cancelled row dims, drops its next date, and takes a gray pill', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        controller: FakeSubscriptionsController(
          initialSeries: [testSeries(label: 'Canal+', status: SeriesStatus.cancelled)],
          summary: testSummary(activeCount: 0, cancelledCount: 1),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final opacity = tester.widget<Opacity>(
      find.descendant(
        of: find.byKey(const Key('seriesRow-s1')),
        matching: find.byType(Opacity),
      ),
    );
    expect(opacity.opacity, 0.55);

    expect(
      tester.widget<StatusPill>(find.byType(StatusPill)).tone,
      StatusPillTone.neutral,
    );
    expect(find.text('Résilié · dernier prélèvement 15/04/2026'), findsOneWidget);
    expect(find.text('15/05/2026'), findsNothing);
  });

  testWidgets('the kebab offers only the transitions the current status allows', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        controller: FakeSubscriptionsController(
          initialSeries: [testSeries(status: SeriesStatus.confirmed)],
          summary: testSummary(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('seriesMenu-s1')));
    await tester.pumpAndSettle();

    // confirmed → cancelled | dismissed. Confirming again is not a transition
    // the lifecycle has, so the menu must not offer it.
    expect(find.byKey(const Key('seriesActionCancel-s1')), findsOneWidget);
    expect(find.byKey(const Key('seriesActionDismiss-s1')), findsOneWidget);
    expect(find.byKey(const Key('seriesActionConfirm-s1')), findsNothing);
    expect(find.byKey(const Key('seriesActionEdit-s1')), findsOneWidget);
  });

  testWidgets('a lifecycle action patches the series and refreshes the row', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    final controller = FakeSubscriptionsController(
      initialSeries: [testSeries()],
      summary: testSummary(),
    );
    await tester.pumpWidget(_wrap(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('seriesMenu-s1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('seriesActionConfirm-s1')));
    await tester.pumpAndSettle();

    expect(controller.statusCalls, [('s1', SeriesStatus.confirmed)]);
  });

  testWidgets('a refused transition shows a message and keeps the list', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    final controller = FakeSubscriptionsController(
      initialSeries: [testSeries()],
      summary: testSummary(),
    )..errorOnStatusChange = const ApiFailure(
      code: 'RECURRING_INVALID_TRANSITION',
      message: 'nope',
    );
    await tester.pumpWidget(_wrap(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('seriesMenu-s1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('seriesActionConfirm-s1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('subscriptionsActionError')), findsOneWidget);
    expect(
      find.text("Ce changement de statut n'est pas possible pour cet abonnement."),
      findsOneWidget,
    );
    expect(find.byKey(const Key('seriesRow-s1')), findsOneWidget);
  });

  testWidgets('the summary cards read straight from the summary payload', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        controller: FakeSubscriptionsController(
          initialSeries: [testSeries()],
          summary: testSummary(
            monthlyTotalMinor: -21208,
            activeCount: 8,
            cancelledCount: 1,
            cadenceCounts: {
              Cadence.weekly: 0,
              Cadence.monthly: 6,
              Cadence.quarterly: 1,
              Cadence.yearly: 1,
              Cadence.irregular: 0,
            },
            nextCharge: NextCharge(
              seriesId: 's1',
              label: 'Netflix',
              amountMinor: -1549,
              dueOn: DateTime.now().add(const Duration(days: 1)),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(_money(21208)), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
    expect(find.text('6 mensuels · 1 trimestriel · 1 annuel — 1 résilié'), findsOneWidget);
    expect(find.text('Netflix — demain'), findsOneWidget);
    expect(
      find.textContaining('Charges trimestrielles et annuelles ramenées au mois.'),
      findsOneWidget,
    );
    expect(find.textContaining('1 abonnement résilié exclu.'), findsOneWidget);
  });

  testWidgets('the empty state explains the three-repeat rule and offers imports', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(_wrap(controller: FakeSubscriptionsController()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('subscriptionsEmptyState')), findsOneWidget);
    expect(find.text('Aucun abonnement détecté pour l\'instant'), findsOneWidget);
    expect(
      find.textContaining("un prélèvement s'est répété trois fois"),
      findsOneWidget,
    );
    expect(find.byKey(const Key('subscriptionsEmptyImportsButton')), findsOneWidget);
    expect(find.text('Aller aux imports'), findsOneWidget);
  });

  testWidgets('a failed load offers a retry rather than an empty panel', (tester) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        controller: FakeSubscriptionsController(
          loadError: const ApiFailure(code: 'UNKNOWN_ERROR', message: 'boom'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('subscriptionsErrorText')), findsOneWidget);
    expect(find.byKey(const Key('subscriptionsRetryButton')), findsOneWidget);
  });

  testWidgets('the panel renders in English with the strings frame ⑤ pins', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        locale: const Locale('en'),
        controller: FakeSubscriptionsController(
          initialSeries: [
            testSeries(),
            testSeries(id: 's2', label: 'Basic-Fit', expectedAmountMinor: -2999),
            testSeries(id: 's3', label: 'Canal+', status: SeriesStatus.cancelled),
          ],
          summary: testSummary(
            activeCount: 2,
            cancelledCount: 1,
            missed: [
              MissedCharge(
                seriesId: 's2',
                expectedOn: DateTime(2026, 5, 5),
                daysLate: 9,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Monthly'), findsNWidgets(3));
    expect(find.text('Missed charge · 9 days late'), findsOneWidget);
    expect(find.textContaining('Cancelled · last charge'), findsOneWidget);
    // Netflix and the cancelled Canal+ share a price in this fixture.
    expect(find.text(_money(1549, locale: 'en')), findsNWidgets(2));
    expect(find.text('Monthly burden'.toUpperCase()), findsOneWidget);
  });

  testWidgets('a row wears its category chip', (tester) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        controller: FakeSubscriptionsController(
          initialSeries: [testSeries(categoryId: 'leisure')],
          summary: testSummary(),
        ),
        categories: [testCategory(id: 'leisure', name: 'category.leisure')],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Loisirs'), findsOneWidget);
  });
}
