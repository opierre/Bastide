import 'package:bastide/core/api/api_client.dart';
import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/features/networth/application/networth_controller.dart';
import 'package:bastide/features/networth/domain/networth_summary.dart';
import 'package:bastide/features/networth/presentation/declared_balances_modal.dart';
import 'package:bastide/features/networth/presentation/networth_screen.dart';
import 'package:bastide/features/networth/presentation/networth_series_chart.dart';
import 'package:bastide/features/properties/application/properties_controller.dart';
import 'package:bastide/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/networth_fixtures.dart';
import '../../support/properties_fixtures.dart';

Widget _wrap(
  NetWorthSummary summary, {
  Locale locale = const Locale('fr'),
  FakeDeclaredBalancesController? declared,
}) {
  return ProviderScope(
    overrides: [
      networthControllerProvider.overrideWith(
        () => FakeNetworthController(summary: summary),
      ),
      declaredBalancesControllerProvider.overrideWith(
        () => declared ?? FakeDeclaredBalancesController(),
      ),
      propertiesControllerProvider.overrideWith(
        () => FakePropertiesController(
          initialProperties: [testProperty(), testStudio()],
        ),
      ),
    ],
    child: MaterialApp(
      locale: locale,
      theme: appDarkTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: NetworthScreen()),
    ),
  );
}

void _useDesktopSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

String? _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(Key(key))).data;

void main() {
  testWidgets('the series draws the API months with their range', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(_wrap(testNetworthSummary()));
    await tester.pumpAndSettle();

    final plot = tester.widget<NetworthSeriesPlot>(
      find.byKey(const Key('networthSeriesPlot')),
    );
    expect(plot.months, hasLength(12));
    expect(plot.values.last, 28267079);
    expect(_text(tester, 'networthSeriesRange'), 'juin 2025 → mai 2026');
  });

  testWidgets('a month the API omitted is absent, never plotted as zero', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    final withGap = [
      for (final point in frameSeries())
        if (point.month != DateTime(2026, 3)) point,
    ];
    await tester.pumpWidget(_wrap(testNetworthSummary(series: withGap)));
    await tester.pumpAndSettle();

    final plot = tester.widget<NetworthSeriesPlot>(
      find.byKey(const Key('networthSeriesPlot')),
    );
    expect(plot.months, hasLength(11));
    expect(plot.months, isNot(contains(DateTime(2026, 3))));
    expect(plot.values, hasLength(11));
    expect(plot.values, isNot(contains(0)));
  });

  testWidgets('the caveat names the oldest valuation when values are flat', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(_wrap(testNetworthSummary()));
    await tester.pumpAndSettle();

    expect(
      _text(tester, 'networthSeriesCaveatText'),
      'Les biens sont maintenus à leur valeur déclarée (estimation la plus '
      'ancienne : 12/01/2026) : seuls les comptes et les crédits bougent '
      'd\'un mois à l\'autre. Les mois sans donnée sont simplement absents.',
    );
  });

  testWidgets('the caveat reads in English too', (tester) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(testNetworthSummary(), locale: const Locale('en')),
    );
    await tester.pumpAndSettle();

    expect(_text(tester, 'networthSeriesCaveatText'), contains('1/12/2026'));
    expect(_text(tester, 'networthSeriesRange'), 'June 2025 → May 2026');
  });

  testWidgets('no flat property values, no caveat', (tester) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(_wrap(testNoPropertySummary()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('networthSeriesPlot')), findsOneWidget);
    expect(find.byKey(const Key('networthSeriesCaveat')), findsNothing);
  });

  testWidgets('an empty series says so instead of drawing a flat line', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(testNetworthSummary(series: const [], monthDeltaMinor: null)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('networthSeriesEmpty')), findsOneWidget);
    expect(find.byKey(const Key('networthSeriesPlot')), findsNothing);
    expect(find.byKey(const Key('networthSeriesRange')), findsNothing);
  });

  group('range', () {
    NetworthSeriesPlot plot(WidgetTester tester) =>
        tester.widget<NetworthSeriesPlot>(
          find.byKey(const Key('networthSeriesPlot')),
        );

    testWidgets('opens on 12 months and widens to the whole history', (
      tester,
    ) async {
      _useDesktopSurface(tester);
      await tester.pumpWidget(_wrap(testNetworthSummary(series: longSeries())));
      await tester.pumpAndSettle();

      expect(plot(tester).months, hasLength(12));
      expect(_text(tester, 'networthSeriesRange'), 'juin 2025 → mai 2026');

      await tester.tap(find.byKey(const Key('networthRangeThreeYears')));
      await tester.pumpAndSettle();
      expect(plot(tester).months, hasLength(30));
      expect(_text(tester, 'networthSeriesRange'), 'décembre 2023 → mai 2026');

      await tester.tap(find.byKey(const Key('networthRangeAll')));
      await tester.pumpAndSettle();
      expect(plot(tester).months, hasLength(30));
    });

    testWidgets('declared months are flagged for the dashed line', (
      tester,
    ) async {
      _useDesktopSurface(tester);
      await tester.pumpWidget(_wrap(testNetworthSummary(series: longSeries())));
      await tester.pumpAndSettle();

      // The last 12 months are all imported: no legend to explain a dash.
      expect(plot(tester).declared, everyElement(isFalse));
      expect(find.byKey(const Key('networthLegendDeclared')), findsNothing);

      await tester.tap(find.byKey(const Key('networthRangeAll')));
      await tester.pumpAndSettle();
      expect(plot(tester).declared.where((flag) => flag), hasLength(18));
      expect(find.text('Montants déclarés'), findsOneWidget);
      expect(find.text('Comptes importés'), findsOneWidget);
    });

    testWidgets('the controls read in English too', (tester) async {
      _useDesktopSurface(tester);
      await tester.pumpWidget(
        _wrap(
          testNetworthSummary(series: longSeries()),
          locale: const Locale('en'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('networthRangeAll')));
      await tester.pumpAndSettle();

      expect(find.text('12 months'), findsOneWidget);
      expect(find.text('3 years'), findsOneWidget);
      expect(find.text('Declared totals'), findsOneWidget);
      expect(find.text('Declared history'), findsOneWidget);
    });
  });

  group('declared history', () {
    final entries = [
      DeclaredBalance(
        month: DateTime(2024, 11),
        amountMinor: -15000,
        currency: 'EUR',
        superseded: false,
      ),
      DeclaredBalance(
        month: DateTime(2025, 6),
        amountMinor: 812345,
        currency: 'EUR',
        superseded: true,
      ),
    ];

    Future<FakeDeclaredBalancesController> open(
      WidgetTester tester, {
      Object? writeError,
      Locale locale = const Locale('fr'),
    }) async {
      _useDesktopSurface(tester);
      final declared = FakeDeclaredBalancesController(
        entries: entries,
        writeError: writeError,
      );
      await tester.pumpWidget(
        _wrap(testNetworthSummary(), declared: declared, locale: locale),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('networthDeclaredOpen')));
      await tester.pumpAndSettle();
      return declared;
    }

    List<String> rowKeys(WidgetTester tester) => [
      for (final widget in tester.widgetList(find.byType(Container)))
        if (widget.key case ValueKey<String>(
          :final value,
        ) when value.startsWith('declaredRow-'))
          value,
    ];

    testWidgets('lists the totals newest first, the covered one chipped', (
      tester,
    ) async {
      await open(tester);

      expect(rowKeys(tester), ['declaredRow-06/2025', 'declaredRow-11/2024']);
      expect(
        find.byKey(const Key('declaredSuperseded-06/2025')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('declaredSuperseded-11/2024')), findsNothing);
      expect(find.text('juin 2025'), findsOneWidget);
      expect(find.text('Couvert par vos imports'), findsOneWidget);
    });

    testWidgets('saves a month and its total, negative allowed', (
      tester,
    ) async {
      final declared = await open(tester);

      await tester.enterText(find.byKey(const Key('declaredMonth')), '03/2025');
      await tester.enterText(
        find.byKey(const Key('declaredAmount')),
        '-1234,56',
      );
      await tester.tap(find.byKey(const Key('declaredSave')));
      await tester.pumpAndSettle();

      expect(declared.declaredWrites, [(DateTime(2025, 3), -123456)]);
      expect(find.byKey(const Key('declaredRow-03/2025')), findsOneWidget);
    });

    testWidgets('a malformed or running month never reaches the API', (
      tester,
    ) async {
      final declared = await open(tester);

      await tester.enterText(find.byKey(const Key('declaredMonth')), '13/2025');
      await tester.enterText(find.byKey(const Key('declaredAmount')), '100');
      await tester.tap(find.byKey(const Key('declaredSave')));
      await tester.pumpAndSettle();
      expect(find.text('Saisissez un mois au format MM/AAAA.'), findsOneWidget);

      final now = DateTime.now();
      await tester.enterText(
        find.byKey(const Key('declaredMonth')),
        formatMonthInput(DateTime(now.year, now.month)),
      );
      await tester.tap(find.byKey(const Key('declaredSave')));
      await tester.pumpAndSettle();
      expect(
        find.text('Seul un mois terminé peut être déclaré.'),
        findsOneWidget,
      );
      expect(declared.declaredWrites, isEmpty);
    });

    testWidgets('a server refusal of the month shows under the field', (
      tester,
    ) async {
      await open(
        tester,
        writeError: const ApiFailure(
          code: 'DECLARED_MONTH_NOT_CLOSED',
          message: 'no',
        ),
      );

      await tester.enterText(find.byKey(const Key('declaredMonth')), '03/2025');
      await tester.enterText(find.byKey(const Key('declaredAmount')), '100');
      await tester.tap(find.byKey(const Key('declaredSave')));
      await tester.pumpAndSettle();

      expect(
        find.text('Seul un mois terminé peut être déclaré.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('declaredError')), findsNothing);
    });

    testWidgets('edit loads a month into the form, delete removes it', (
      tester,
    ) async {
      final declared = await open(tester);

      await tester.tap(find.byKey(const Key('declaredEdit-11/2024')));
      await tester.pump();
      expect(find.text('11/2024'), findsOneWidget);

      await tester.tap(find.byKey(const Key('declaredDelete-11/2024')));
      await tester.pumpAndSettle();
      expect(declared.removed, [DateTime(2024, 11)]);
      expect(find.byKey(const Key('declaredRow-11/2024')), findsNothing);
    });

    testWidgets('reads in English', (tester) async {
      await open(tester, locale: const Locale('en'));

      expect(find.text('June 2025'), findsOneWidget);
      expect(find.text('Covered by your imports'), findsOneWidget);
      expect(find.text('Accounts total'), findsOneWidget);
    });
  });
}
