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

/// Month [index]'s bar in global coordinates: 22 px wide at most, from zero to its tip.
Rect _bar(WidgetTester tester, int index) {
  final chart = tester.getRect(find.byType(SavingsChart));
  final (_, zero) = _localMark(tester, index);
  final tip = _mark(tester, index);
  final zeroY = chart.top + zero.dy;
  final slot = (chart.width - AreaLine.valueGutter) / _values.length;
  final width = slot * 0.56 < 22 ? slot * 0.56 : 22.0;
  return Rect.fromLTRB(
    tip.dx - width / 2,
    tip.dy < zeroY ? tip.dy : zeroY,
    tip.dx + width / 2,
    tip.dy < zeroY ? zeroY : tip.dy,
  );
}

/// Whether [box] covers any stretch of the line joining [points], sampled
/// every pixel or so.
bool _touchesLine(Rect box, List<Offset> points) {
  for (var i = 1; i < points.length; i++) {
    final a = points[i - 1];
    final b = points[i];
    final steps = (b - a).distance.ceil();
    for (var s = 0; s <= steps; s++) {
      if (box.contains(Offset.lerp(a, b, s / steps)!)) return true;
    }
  }
  return false;
}

/// The card stays in the chart, right of the value gutter and above the
/// month axis.
void _expectInPlot(WidgetTester tester, Rect card) {
  final chart = tester.getRect(find.byType(SavingsChart));
  expect(card.left, greaterThanOrEqualTo(chart.left + AreaLine.valueGutter));
  expect(card.top, greaterThanOrEqualTo(chart.top));
  expect(card.right, lessThanOrEqualTo(chart.right));
  expect(card.bottom, lessThanOrEqualTo(chart.bottom - AreaLine.axisHeight));
}

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
    testWidgets('each month names itself at once, clear of every bar', (
      tester,
    ) async {
      await _pump(tester, SavingsChartView.bars);
      final gesture = await _hover(tester, 0);
      // One frame, no Tooltip delay: the card is there as the pointer lands.
      expect(find.byType(Tooltip), findsNothing);
      expect(find.text('Mois 0\n12000', findRichText: true), findsOneWidget);

      final bars = [for (var i = 0; i < _values.length; i++) _bar(tester, i)];
      for (var i = 0; i < _values.length; i++) {
        if (i > 0) await _moveTo(tester, gesture, i);
        final card = _tooltip(tester, i);
        for (final bar in bars) {
          expect(card.overlaps(bar), isFalse, reason: 'month $i');
        }
        expect(card.contains(_mark(tester, i)), isFalse, reason: 'month $i');
        _expectInPlot(tester, card);
      }
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

    testWidgets('each point names itself clear of its dot and the line', (
      tester,
    ) async {
      await _pump(tester, SavingsChartView.line);
      final gesture = await _hover(tester, 0);

      final points = [
        for (var i = 0; i < _values.length; i++) _mark(tester, i),
      ];
      for (var i = 0; i < _values.length; i++) {
        if (i > 0) await _moveTo(tester, gesture, i);
        final card = _tooltip(tester, i);
        // The hovered dot's 5 px radius and 1.5 px ring.
        expect(
          card.inflate(6.5).contains(points[i]),
          isFalse,
          reason: 'month $i',
        );
        expect(_touchesLine(card, points), isFalse, reason: 'month $i');
        _expectInPlot(tester, card);
      }
      expect(find.byKey(const Key('savingsChartTooltip-0')), findsNothing);
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
