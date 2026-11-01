import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/core/widgets/area_line.dart';
import 'package:bastide/features/dashboard/application/dashboard_controller.dart';
import 'package:bastide/features/dashboard/presentation/savings_chart.dart';

/// Invented months: savings, a shortfall, an empty month.
const _values = [12000, 30000, -9000, 0, 6000];

const _chartSize = Size(600, 320);

Future<void> _pump(WidgetTester tester, SavingsChartView view) async {
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

  testWidgets('leaving the chart takes the tooltip away', (tester) async {
    await _pump(tester, SavingsChartView.bars);
    final gesture = await _hover(tester, 0);
    expect(find.byKey(const Key('savingsChartTooltip-0')), findsOneWidget);

    await gesture.moveTo(const Offset(5, 5));
    await tester.pump();
    expect(find.byKey(const Key('savingsChartTooltip-0')), findsNothing);
  });
}
