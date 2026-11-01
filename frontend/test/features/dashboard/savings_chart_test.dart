import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/core/theme/tokens.dart';
import 'package:bastide/core/widgets/area_line.dart';
import 'package:bastide/features/dashboard/application/dashboard_controller.dart';
import 'package:bastide/features/dashboard/presentation/savings_chart.dart';

/// Invented months: savings, a shortfall, an empty month.
const _values = [12000, 30000, -9000, 0, 6000];

const _chartSize = Size(600, 320);

/// The invented months' mean, as the domain would hand it over.
const _average = 7800;

Future<void> _pump(
  WidgetTester tester,
  SavingsChartView view, {
  int? average,
}) async {
  tester.view.physicalSize = const Size(1000, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: appDarkTheme,
      home: Scaffold(
        body: Center(
          child: SizedBox.fromSize(
            size: _chartSize,
            child: SavingsChart(
              view: view,
              values: _values,
              average: average,
              labels: [for (var i = 0; i < _values.length; i++) 'M$i'],
              valueLabel: (value) => '$value',
              tooltips: [
                for (var i = 0; i < _values.length; i++)
                  TextSpan(text: 'Mois $i\n${_values[i]}'),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Month [index]'s mark in global coordinates, from the chart's own geometry: the plot
/// sits right of the value gutter, inset 4 px top and bottom, over the month axis, on a
/// range with 15 % headroom either side of the extremes.
Offset _mark(WidgetTester tester, int index) {
  final chart = tester.getRect(find.byType(SavingsChart));
  final plot = Rect.fromLTWH(
    chart.left + AreaLine.valueGutter,
    chart.top + 4,
    chart.width - AreaLine.valueGutter,
    chart.height - AreaLine.axisHeight - 8,
  );
  const top = 30000 * 1.15;
  const bottom = -9000 * 1.15;
  return Offset(
    plot.left + plot.width * (index + 0.5) / _values.length,
    plot.bottom - plot.height * ((_values[index] - bottom) / (top - bottom)),
  );
}

Future<TestGesture> _hover(WidgetTester tester, int index) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  addTearDown(gesture.removePointer);
  await gesture.addPointer(location: Offset.zero);
  await _moveTo(tester, gesture, index);
  return gesture;
}

Future<void> _moveTo(
  WidgetTester tester,
  TestGesture gesture,
  int index,
) async {
  // Mid-height in the month's slot, far from its mark: the whole slot is the target.
  final chart = tester.getRect(find.byType(SavingsChart));
  await gesture.moveTo(Offset(_mark(tester, index).dx, chart.center.dy));
  await tester.pump();
}

Rect _tooltip(WidgetTester tester, int index) =>
    tester.getRect(find.byKey(Key('savingsChartTooltip-$index')));

RenderObject _painter(WidgetTester tester) => tester.renderObject(
  find.descendant(
    of: find.byType(SavingsChart),
    matching: find.byType(CustomPaint),
  ),
);

/// Month [index]'s mark in the painter's own coordinates, and the zero line under it.
(Offset, Offset) _localMark(WidgetTester tester, int index) {
  final origin = tester.getTopLeft(find.byType(SavingsChart));
  final mark = _mark(tester, index) - origin;
  final chart = tester.getRect(find.byType(SavingsChart));
  final plotHeight = chart.height - AreaLine.axisHeight - 8;
  const top = 30000 * 1.15;
  const bottom = -9000 * 1.15;
  final zeroY = 4 + plotHeight - plotHeight * ((0 - bottom) / (top - bottom));
  return (mark, Offset(mark.dx, zeroY));
}

final _area = AppColors.iris.withValues(alpha: 0.10);

/// The painter's y for [value], in its own coordinates.
double _localY(WidgetTester tester, num value) {
  final chart = tester.getRect(find.byType(SavingsChart));
  final plotHeight = chart.height - AreaLine.axisHeight - 8;
  const top = 30000 * 1.15;
  const bottom = -9000 * 1.15;
  return 4 + plotHeight - plotHeight * ((value - bottom) / (top - bottom));
}

/// Every dot of the average line the painter drew: a round-capped near-zero
/// [Canvas.drawLine] in [SavingsChart.averageColor].
List<Offset> _averageDots(WidgetTester tester) {
  final dots = <Offset>[];
  expect(
    _painter(tester),
    paints..everything((method, arguments) {
      if (method == #drawLine) {
        final paint = arguments[2] as Paint;
        // By 8-bit value: a [Paint] holds its color in single precision.
        if (paint.color.toARGB32() == SavingsChart.averageColor.toARGB32() &&
            paint.strokeCap == StrokeCap.round) {
          dots.add(arguments[0] as Offset);
        }
      }
      return true;
    }),
  );
  return dots;
}

void main() {
  group('bars', () {
    testWidgets('a saving names itself just over its bar', (tester) async {
      await _pump(tester, SavingsChartView.bars);
      await _hover(tester, 0);

      final tip = _mark(tester, 0);
      final tooltip = _tooltip(tester, 0);
      expect(tooltip.center.dx, moreOrLessEquals(tip.dx, epsilon: 0.5));
      expect(tooltip.bottom, moreOrLessEquals(tip.dy - 8, epsilon: 0.5));
      expect(find.text('Mois 0\n12000', findRichText: true), findsOneWidget);
    });

    testWidgets('the tallest saving clears its tip past the plot', (
      tester,
    ) async {
      await _pump(tester, SavingsChartView.bars);
      await _hover(tester, 1);

      // Little headroom over the tallest bar: the tooltip floats above the chart rather
      // than flipping onto the bar.
      final tooltip = _tooltip(tester, 1);
      expect(tooltip.bottom, moreOrLessEquals(_mark(tester, 1).dy - 8));
      expect(
        tooltip.top,
        lessThan(tester.getRect(find.byType(SavingsChart)).top),
      );
    });

    testWidgets('a shortfall names itself just under its bar', (tester) async {
      await _pump(tester, SavingsChartView.bars);
      await _hover(tester, 2);

      final tip = _mark(tester, 2);
      final tooltip = _tooltip(tester, 2);
      expect(tooltip.center.dx, moreOrLessEquals(tip.dx, epsilon: 0.5));
      expect(tooltip.top, moreOrLessEquals(tip.dy + 8, epsilon: 0.5));
    });

    testWidgets('an empty month names itself over the zero line', (
      tester,
    ) async {
      await _pump(tester, SavingsChartView.bars);
      await _hover(tester, 3);

      expect(
        _tooltip(tester, 3).bottom,
        moreOrLessEquals(_mark(tester, 3).dy - 8, epsilon: 0.5),
      );
    });
  });

  group('line', () {
    testWidgets('the area runs from zero to each point, either side', (
      tester,
    ) async {
      await _pump(tester, SavingsChartView.line);

      // A saving fills up to its point and no higher; a shortfall down to its point and
      // no lower — closed on zero, not on the plot's floor.
      final (saving, savingZero) = _localMark(tester, 1);
      final (shortfall, shortfallZero) = _localMark(tester, 2);
      expect(
        _painter(tester),
        paints..path(
          color: _area,
          includes: [
            Offset.lerp(saving, savingZero, 0.5)!,
            Offset.lerp(shortfall, shortfallZero, 0.5)!,
          ],
          excludes: [
            saving.translate(0, -6),
            shortfall.translate(0, 6),
            savingZero.translate(0, 6),
          ],
        ),
      );
    });

    testWidgets('the bars carry no area', (tester) async {
      await _pump(tester, SavingsChartView.bars);
      expect(_painter(tester), isNot(paints..path(color: _area)));
    });

    testWidgets('a point names itself clear of its hovered dot', (
      tester,
    ) async {
      await _pump(tester, SavingsChartView.line);
      final gesture = await _hover(tester, 4);

      // The hovered dot's 5 px radius and 1.5 px ring, then the gap.
      final dot = _mark(tester, 4);
      final tooltip = _tooltip(tester, 4);
      expect(tooltip.center.dx, moreOrLessEquals(dot.dx, epsilon: 0.5));
      expect(tooltip.bottom, moreOrLessEquals(dot.dy - 6.5 - 8, epsilon: 0.5));

      await _moveTo(tester, gesture, 2);
      final low = _mark(tester, 2);
      expect(
        _tooltip(tester, 2).top,
        moreOrLessEquals(low.dy + 6.5 + 8, epsilon: 0.5),
      );
      expect(find.byKey(const Key('savingsChartTooltip-4')), findsNothing);
    });
  });

  group('average', () {
    for (final view in SavingsChartView.values) {
      testWidgets(
        '${view.name}: a dotted level across the plot at the average',
        (tester) async {
          await _pump(tester, view, average: _average);

          final width = tester.getSize(find.byType(SavingsChart)).width;
          final y = _localY(tester, _average);
          final dots = _averageDots(tester);
          expect(dots.length, greaterThan(20));
          // One level, gutter to edge, spaced as dots rather than a solid rule.
          for (final dot in dots) {
            expect(dot.dy, moreOrLessEquals(y, epsilon: 0.01));
          }
          expect(dots.first.dx, moreOrLessEquals(AreaLine.valueGutter));
          expect(dots.last.dx, greaterThan(width - SavingsChart.averageDotGap));
          expect(
            dots[1].dx - dots[0].dx,
            moreOrLessEquals(SavingsChart.averageDotGap),
          );
        },
      );
    }

    testWidgets('see-through, and drawn over the marks so none hides it', (
      tester,
    ) async {
      await _pump(tester, SavingsChartView.bars, average: _average);

      expect(SavingsChart.averageColor.a, lessThan(1));
      // Every bar paints before the first average dot.
      final calls = <Symbol>[];
      int? firstDot;
      expect(
        _painter(tester),
        paints..everything((method, arguments) {
          if (firstDot == null &&
              method == #drawLine &&
              (arguments[2] as Paint).color.toARGB32() ==
                  SavingsChart.averageColor.toARGB32()) {
            firstDot = calls.length;
          }
          calls.add(method);
          return true;
        }),
      );
      expect(firstDot, isNotNull);
      expect(calls.lastIndexOf(#drawRRect), lessThan(firstDot!));
    });

    testWidgets('no average, no line', (tester) async {
      await _pump(tester, SavingsChartView.line);
      expect(_averageDots(tester), isEmpty);
    });
  });

  testWidgets('leaving the chart takes the tooltip away', (tester) async {
    await _pump(tester, SavingsChartView.bars);
    final gesture = await _hover(tester, 0);
    expect(find.byKey(const Key('savingsChartTooltip-0')), findsOneWidget);

    await gesture.moveTo(const Offset(5, 5));
    await tester.pump();
    expect(find.byKey(const Key('savingsChartTooltip-0')), findsNothing);
  });
}
