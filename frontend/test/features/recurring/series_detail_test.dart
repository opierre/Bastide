import 'package:finstride/core/theme/app_theme.dart';
import 'package:finstride/core/widgets/amount_text.dart';
import 'package:finstride/features/recurring/application/subscriptions_controller.dart';
import 'package:finstride/features/recurring/domain/recurring_series.dart';
import 'package:finstride/features/recurring/presentation/series_detail.dart';
import 'package:finstride/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/recurring_fixtures.dart';

String _money(int amountMinor) =>
    formatAmount(amountMinor: amountMinor, currency: 'EUR', locale: 'fr');

SeriesOccurrence _occurrence({
  String id = 'o1',
  required DateTime bookedDate,
  required int amountMinor,
}) => SeriesOccurrence(
  id: id,
  transactionId: 't-$id',
  bookedDate: bookedDate,
  amountMinor: amountMinor,
  currency: 'EUR',
);

Widget _wrap(SeriesDetail detail) {
  return ProviderScope(
    overrides: [
      seriesDetailProvider.overrideWith((ref, id) => detail),
      subscriptionAccountsProvider.overrideWith(
        (ref) => [
          const SeriesAccount(
            id: 'a1',
            name: 'Compte courant',
            institution: 'BNP',
            currency: 'EUR',
          ),
        ],
      ),
      subscriptionCategoriesProvider.overrideWith((ref) => []),
    ],
    child: MaterialApp(
      locale: const Locale('fr'),
      theme: appDarkTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: SeriesDetailView(seriesId: 's1')),
    ),
  );
}

String _axisLabel(WidgetTester tester, String key) => tester
    .widget<Text>(
      find.descendant(of: find.byKey(Key(key)), matching: find.byType(Text)),
    )
    .data!;

void main() {
  testWidgets('the detail states the increase with what it costs over a year', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _wrap(
        SeriesDetail(
          series: testSeries(
            priceChangeMinor: -200,
            priceChangedAt: DateTime(2026, 4, 15),
          ),
          occurrences: [
            _occurrence(bookedDate: DateTime(2026, 4, 15), amountMinor: -1549),
            _occurrence(id: 'o2', bookedDate: DateTime(2026, 3, 15), amountMinor: -1349),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('seriesIncreaseBanner')), findsOneWidget);
    expect(
      find.text(
        'Augmentation : ${_money(1349)} → ${_money(1549)} le 15/04/2026 '
        '— soit +${_money(2400)} par an.',
      ),
      findsOneWidget,
    );

    // The evidence is on the screen that asks the user to trust the deduction —
    // drawn as a curve, one hoverable point per charge, with the charge that
    // stepped up named by the amber legend.
    expect(find.byKey(const Key('seriesOccurrence-o1')), findsOneWidget);
    expect(find.byKey(const Key('seriesOccurrence-o2')), findsOneWidget);
    expect(find.byKey(const Key('seriesOccurrenceChange-o1')), findsOneWidget);
    expect(find.byKey(const Key('seriesOccurrenceChange-o2')), findsNothing);

    // The literal prices are not lost with the column: the curve's extremes
    // are labelled, unsigned, on the value axis.
    expect(_axisLabel(tester, 'seriesPriceAxisMax'), _money(1549));
    expect(_axisLabel(tester, 'seriesPriceAxisMin'), _money(1349));

    // The account the series belongs to, and where it came from.
    expect(
      find.text('BNP — Compte courant · détecté depuis décembre 2025'),
      findsOneWidget,
    );
  });

  testWidgets('a declared series says it is tracked, not detected, and has no history', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _wrap(
        SeriesDetail(
          series: testSeries(
            label: 'Basic-Fit',
            isManual: true,
            cadence: Cadence.irregular,
            occurrenceCount: 0,
          ),
          occurrences: const [],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('BNP — Compte courant · suivi depuis décembre 2025'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('seriesHistoryEmpty')), findsOneWidget);
    expect(find.byKey(const Key('seriesIncreaseBanner')), findsNothing);
    expect(find.text('Irrégulier'), findsOneWidget);
  });

  testWidgets('a price that never moved draws one flat level, not a range', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _wrap(
        SeriesDetail(
          series: testSeries(),
          occurrences: [
            _occurrence(bookedDate: DateTime(2026, 4, 15), amountMinor: -1549),
            _occurrence(id: 'o2', bookedDate: DateTime(2026, 3, 15), amountMinor: -1549),
            _occurrence(id: 'o3', bookedDate: DateTime(2026, 2, 15), amountMinor: -1549),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    // One price, so one tick: a second label would invent a spread the series
    // doesn't have.
    expect(_axisLabel(tester, 'seriesPriceAxisMax'), _money(1549));
    expect(find.byKey(const Key('seriesPriceAxisMin')), findsNothing);
    expect(find.byKey(const Key('seriesOccurrence-o3')), findsOneWidget);
    expect(find.byKey(const Key('seriesOccurrenceChange-o1')), findsNothing);
  });
}
