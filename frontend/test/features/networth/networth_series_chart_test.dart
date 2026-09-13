import 'package:finstride/core/theme/app_theme.dart';
import 'package:finstride/features/networth/application/networth_controller.dart';
import 'package:finstride/features/networth/domain/networth_summary.dart';
import 'package:finstride/features/networth/presentation/networth_screen.dart';
import 'package:finstride/features/networth/presentation/networth_series_chart.dart';
import 'package:finstride/features/properties/application/properties_controller.dart';
import 'package:finstride/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/networth_fixtures.dart';
import '../../support/properties_fixtures.dart';

Widget _wrap(NetWorthSummary summary, {Locale locale = const Locale('fr')}) {
  return ProviderScope(
    overrides: [
      networthControllerProvider.overrideWith(
        () => FakeNetworthController(summary: summary),
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
}
