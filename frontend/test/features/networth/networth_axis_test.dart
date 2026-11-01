import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/features/networth/presentation/networth_axis.dart';
import 'package:bastide/features/networth/presentation/networth_series_chart.dart';
import 'package:bastide/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Whether [step] (minor units) is 1, 2, 2.5 or 5 × 10ⁿ major units.
bool _isClean(int step) {
  var mantissa = step / 100;
  while (mantissa >= 10) {
    mantissa /= 10;
  }
  return const [1.0, 2.0, 2.5, 5.0].contains(mantissa);
}

/// Every value strictly inside the scale, on clean, evenly spaced ticks.
void _expectPadded(List<int> values) {
  final axis = networthAxis(values);
  final lowest = values.reduce((a, b) => a < b ? a : b);
  final highest = values.reduce((a, b) => a > b ? a : b);
  final step = (axis.high - axis.low) ~/ 2;
  expect(axis.high, greaterThan(highest), reason: '$axis');
  expect(axis.low, lessThan(lowest), reason: '$axis');
  expect(axis.levels, [axis.low, axis.low + step, axis.high]);
  expect(_isClean(step), isTrue, reason: 'step $step');
  expect(axis.low % step, 0, reason: '$axis');
}

void main() {
  group('networthAxis', () {
    test('a rising series gets air above its peak, on round figures', () {
      // 120 000 € → 143 500 €.
      final values = [12000000, 12850000, 13400000, 14350000];
      _expectPadded(values);
      expect(
        networthAxis(values),
        const NetworthAxis(low: 10000000, high: 15000000),
      );
    });

    test('a peak just under a tick still clears it', () {
      _expectPadded([0, 9990000]);
      expect(networthAxis([0, 9990000]).high, greaterThan(9990000));
    });

    test('a negative series pads below its trough, floors rounding down', () {
      final values = [-4520000, -3810000, -2975000];
      _expectPadded(values);
      expect(networthAxis(values).low, lessThan(-4520000));
    });

    test('a series crossing zero keeps both ends inside', () {
      _expectPadded([-1234500, 250000, 3187600]);
    });

    test('a flat series gets a band around its value', () {
      _expectPadded([5000000, 5000000, 5000000]);
      _expectPadded([-5000000, -5000000]);
    });

    test('a flat zero series still has a non-empty scale', () {
      final axis = networthAxis([0, 0]);
      expect(axis.low, lessThan(0));
      expect(axis.high, greaterThan(0));
      _expectPadded([0, 0]);
    });

    test('a single month is padded like a flat series', () {
      _expectPadded([7342100]);
    });

    test('a tiny range never ticks below one major unit', () {
      final axis = networthAxis([1000, 1050]);
      expect((axis.high - axis.low) ~/ 2, greaterThanOrEqualTo(100));
      _expectPadded([1000, 1050]);
    });
  });

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

    testWidgets('paints a negative series', (tester) async {
      await pump(tester, [-4520000, -3810000, -2975000]);
      expect(tester.takeException(), isNull);
      expect(find.byType(NetworthSeriesPlot), findsOneWidget);
    });
  });
}
