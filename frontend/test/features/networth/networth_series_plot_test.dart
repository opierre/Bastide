import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/core/theme/tokens.dart';
import 'package:bastide/features/networth/presentation/networth_series_chart.dart';
import 'package:bastide/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NetworthSeriesPlot', () {
    Future<void> pump(WidgetTester tester, List<int> values) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('fr'),
          theme: appDarkTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 240,
              child: NetworthSeriesPlot(
                months: [
                  for (var i = 0; i < values.length; i++) DateTime(2024, i + 1),
                ],
                values: values,
                currency: 'EUR',
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('paints a flat series', (tester) async {
      await pump(tester, [5000000, 5000000, 5000000]);
      expect(tester.takeException(), isNull);
      expect(find.byType(NetworthSeriesPlot), findsOneWidget);
    });

    testWidgets('paints a series crossing zero', (tester) async {
      await pump(tester, [-1250000, 320000, 1875000]);
      expect(tester.takeException(), isNull);
      expect(find.byType(NetworthSeriesPlot), findsOneWidget);
    });

    testWidgets('paints a negative series', (tester) async {
      await pump(tester, [-4520000, -3810000, -2975000]);
      expect(tester.takeException(), isNull);
      expect(find.byType(NetworthSeriesPlot), findsOneWidget);
    });

    testWidgets('draws in the shared curve style', (tester) async {
      await pump(tester, [3200000, 3410000, 3375000]);
      final painter = tester.renderObject(
        find.descendant(
          of: find.byType(NetworthSeriesPlot),
          matching: find.byType(CustomPaint),
        ),
      );
      final radii = <double>[];
      expect(
        painter,
        paints..everything((method, arguments) {
          if (method == #drawCircle &&
              (arguments[2] as Paint).color.toARGB32() ==
                  AppColors.iris.toARGB32()) {
            radii.add(arguments[1] as double);
          }
          return true;
        }),
      );
      expect(radii, [
        AppChart.pointDotRadius,
        AppChart.pointDotRadius,
        AppChart.currentDotRadius,
      ]);
      expect(
        painter,
        paints
          ..path(color: AppColors.iris.withValues(alpha: AppChart.areaAlpha))
          ..path(
            color: AppColors.iris,
            strokeWidth: AppChart.lineStroke,
            style: PaintingStyle.stroke,
          ),
      );
    });
  });
}
