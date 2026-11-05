import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/core/theme/tokens.dart';
import 'package:bastide/core/widgets/amount_text.dart';
import 'package:bastide/core/widgets/area_line.dart';
import 'package:bastide/features/recurring/application/subscriptions_controller.dart';
import 'package:bastide/features/recurring/domain/recurring_series.dart';
import 'package:bastide/features/recurring/presentation/price_history_chart.dart';
import 'package:bastide/features/recurring/presentation/series_detail.dart';
import 'package:bastide/l10n/app_localizations.dart';
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

Widget _wrap(SeriesDetail detail, {FakeSubscriptionsController? controller}) {
  return ProviderScope(
    overrides: [
      if (controller != null)
        subscriptionsControllerProvider.overrideWith(() => controller),
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

/// [count] invented charges, [every] apart, newest first — as the detail holds
/// them.
List<SeriesOccurrence> _charges(int count, Duration every) => [
  for (var i = 0; i < count; i++)
    _occurrence(
      id: 'c$i',
      bookedDate: DateTime(2026, 6, 1).subtract(every * i),
      amountMinor: i < count ~/ 2 ? -1299 : -1099,
    ),
];

/// Every charge has its own date tick, left to right in time, and no two ticks
/// overlap.
void _expectEveryChargeDated(WidgetTester tester, int count) {
  for (var i = 0; i < count; i++) {
    expect(find.byKey(Key('seriesDateTick-c$i')), findsOneWidget);
  }
  _expectNoTicksOverlap(tester, count);
}

/// The ticks present, oldest charge first, each clear of the one before it.
void _expectNoTicksOverlap(WidgetTester tester, int count) {
  final rects = [
    for (var i = count - 1; i >= 0; i--)
      if (find.byKey(Key('seriesDateTick-c$i')).evaluate().isNotEmpty)
        tester.getRect(find.byKey(Key('seriesDateTick-c$i'))),
  ];
  for (var i = 1; i < rects.length; i++) {
    expect(
      rects[i].left,
      greaterThan(rects[i - 1].right),
      reason: 'tick $i overlaps the one before it',
    );
  }
}

/// The chart never scrolls sideways: the whole history sits in the card.
void _expectNoScroll(WidgetTester tester) => expect(
  find.descendant(
    of: find.byType(PriceHistoryChart),
    matching: find.byType(Scrollable),
  ),
  findsNothing,
);

Future<void> _pumpHistory(
  WidgetTester tester,
  int count,
  Duration every,
) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    _wrap(
      SeriesDetail(
        series: testSeries(occurrenceCount: count),
        occurrences: _charges(count, every),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _useDesktopSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('a year of monthly charges dates every one of them, flat', (
    tester,
  ) async {
    // Twelve charges used to be thinned to five ticks.
    await _pumpHistory(tester, 12, const Duration(days: 30));

    _expectEveryChargeDated(tester, 12);
    expect(
      find.descendant(
        of: find.byType(PriceHistoryChart),
        matching: find.byType(RotatedBox),
      ),
      findsNothing,
    );
    _expectNoScroll(tester);
  });

  testWidgets('a weekly series too dense for flat dates turns them on end', (
    tester,
  ) async {
    await _pumpHistory(tester, 30, const Duration(days: 7));

    _expectEveryChargeDated(tester, 30);
    expect(
      find.descendant(
        of: find.byType(PriceHistoryChart),
        matching: find.byType(RotatedBox),
      ),
      findsNWidgets(30),
    );
    _expectNoScroll(tester);
  });

  testWidgets('a history too long even for upright dates thins them in place', (
    tester,
  ) async {
    await _pumpHistory(tester, 160, const Duration(days: 7));

    _expectNoScroll(tester);
    _expectNoTicksOverlap(tester, 160);
    // The span stays dated: the oldest and the latest charge keep their tick.
    expect(find.byKey(const Key('seriesDateTick-c159')), findsOneWidget);
    expect(find.byKey(const Key('seriesDateTick-c0')), findsOneWidget);
    final ticks = find.descendant(
      of: find.byType(PriceHistoryChart),
      matching: find.byType(RotatedBox),
    );
    expect(ticks.evaluate().length, inInclusiveRange(2, 159));
    // Over a year, two weekly charges share a month: the day stays on the tick
    // so no two of them read the same.
    final labels = {
      for (final tick in ticks.evaluate())
        tester
            .widget<Text>(
              find.descendant(
                of: find.byWidget(tick.widget),
                matching: find.byType(Text),
              ),
            )
            .data,
    };
    expect(labels, hasLength(ticks.evaluate().length));
  });

  group('archive', () {
    testWidgets('« Archiver » puts a live series away', (tester) async {
      _useDesktopSurface(tester);
      final controller = FakeSubscriptionsController(
        initialSeries: [testSeries()],
      );
      await tester.pumpWidget(
        _wrap(
          SeriesDetail(series: testSeries(), occurrences: const []),
          controller: controller,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('seriesDetailAddCharge')), findsOneWidget);
      final button = find.byKey(const Key('seriesDetailArchive'));
      expect(
        find.descendant(of: button, matching: find.text('Archiver')),
        findsOneWidget,
      );

      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(controller.archiveCalls, ['s1']);
      expect(controller.unarchiveCalls, isEmpty);
    });

    testWidgets('an archived series offers « Désarchiver » and no new charge', (
      tester,
    ) async {
      _useDesktopSurface(tester);
      final controller = FakeSubscriptionsController(
        initialArchived: [testSeries(isArchived: true)],
      );
      await tester.pumpWidget(
        _wrap(
          SeriesDetail(
            series: testSeries(isArchived: true),
            occurrences: const [],
          ),
          controller: controller,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('seriesDetailAddCharge')), findsNothing);
      final button = find.byKey(const Key('seriesDetailArchive'));
      expect(
        find.descendant(of: button, matching: find.text('Désarchiver')),
        findsOneWidget,
      );

      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(controller.unarchiveCalls, ['s1']);
    });
  });

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
            _occurrence(
              id: 'o2',
              bookedDate: DateTime(2026, 3, 15),
              amountMinor: -1349,
            ),
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

  testWidgets('a series created by the user says it is tracked, not detected', (
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
            occurrenceCount: 2,
          ),
          occurrences: [
            _occurrence(
              id: 'o2',
              bookedDate: DateTime(2026, 3, 2),
              amountMinor: -2999,
            ),
            _occurrence(
              id: 'o1',
              bookedDate: DateTime(2025, 12, 15),
              amountMinor: -2999,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('BNP — Compte courant · suivi depuis décembre 2025'),
      findsOneWidget,
    );
    expect(find.byType(PriceHistoryChart), findsOneWidget);
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
            _occurrence(
              id: 'o2',
              bookedDate: DateTime(2026, 3, 15),
              amountMinor: -1549,
            ),
            _occurrence(
              id: 'o3',
              bookedDate: DateTime(2026, 2, 15),
              amountMinor: -1549,
            ),
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

  // The window widths the app is drawn and launched at: the 1440 frame, the
  // runner's 1280 default, and a narrow 1000.
  for (final width in const [1000.0, 1280.0, 1440.0]) {
    group('margins at $width px', () {
      /// The latest charge's dot radius: the plot stops that short of the
      /// chart's right edge so the dot stays inside it.
      const latestDot = 5.0;

      Future<Rect> pumpCharges(
        WidgetTester tester,
        List<SeriesOccurrence> charges,
      ) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          _wrap(SeriesDetail(series: testSeries(), occurrences: charges)),
        );
        await tester.pumpAndSettle();
        return tester.getRect(find.byType(PriceHistoryChart));
      }

      testWidgets('the plot spans the shared chart gutter, edge to edge', (
        tester,
      ) async {
        // One charge: its hover column is the whole plot.
        final chart = await pumpCharges(tester, [
          _occurrence(bookedDate: DateTime(2026, 4, 15), amountMinor: -1549),
        ]);
        final plot = tester.getRect(
          find.byKey(const Key('seriesOccurrence-o1')),
        );

        expect(plot.left, moreOrLessEquals(chart.left + AreaLine.valueGutter));
        expect(plot.right, moreOrLessEquals(chart.right - latestDot));
      });

      testWidgets(
        'the value axis ends a step short of the plot, as elsewhere',
        (tester) async {
          final chart = await pumpCharges(
            tester,
            // Weekly, so each charge's hover column is narrower than the
            // gutter and the oldest one is centred on its point, not clamped.
            _charges(30, const Duration(days: 7)),
          );

          for (final key in ['seriesPriceAxisMax', 'seriesPriceAxisMin']) {
            expect(
              tester.getRect(find.byKey(Key(key))).right,
              moreOrLessEquals(
                chart.left + AreaLine.valueGutter - AppSpacing.sm,
              ),
            );
          }
          // The oldest charge sits on the plot's left edge.
          expect(
            tester.getCenter(find.byKey(const Key('seriesOccurrence-c29'))).dx,
            moreOrLessEquals(chart.left + AreaLine.valueGutter),
          );
        },
      );

      testWidgets('a four-figure price stays whole in the gutter', (
        tester,
      ) async {
        await pumpCharges(tester, [
          _occurrence(bookedDate: DateTime(2026, 4, 15), amountMinor: -123456),
          _occurrence(
            id: 'o2',
            bookedDate: DateTime(2026, 3, 15),
            amountMinor: -120000,
          ),
        ]);

        final label = tester.widget<Text>(
          find.descendant(
            of: find.byKey(const Key('seriesPriceAxisMax')),
            matching: find.byType(Text),
          ),
        );
        expect(label.data, _money(123456));
        expect(label.overflow, isNot(TextOverflow.ellipsis));
        expect(tester.takeException(), isNull);
      });
    });
  }
}
