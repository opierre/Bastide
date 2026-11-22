import 'package:bastide/core/theme/tokens.dart';
import 'package:bastide/core/widgets/chart_frame.dart';
import 'package:bastide/core/widgets/chart_scale.dart';
import 'package:bastide/core/widgets/line_area_chart.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'chart_test_utils.dart';
import 'host.dart';

const _values = [1000, 2400, 1800, 3200];
const _labels = ['févr.', 'mars', 'avr.', 'mai'];

Widget _chart({
  required double height,
  List<num> values = _values,
  List<String> labels = _labels,
  List<InlineSpan>? tooltips,
  String Function(num)? valueLabel,
}) => SizedBox(
  height: height,
  width: 400,
  child: LineAreaChart(
    values: values,
    labels: labels,
    tooltips: tooltips,
    valueLabel: valueLabel,
  ),
);

/// The plot inside [chart], as the frame lays it out: right of the value
/// gutter, inset by the current dot, above the category axis.
ChartGeometry _geometry(Rect chart, List<num> values, {double gutter = 0}) =>
    ChartGeometry(
      plot: Rect.fromLTRB(
        chart.left + gutter,
        chart.top + AppChart.dotReach,
        chart.right,
        chart.bottom - AppChart.axisHeight - AppChart.dotReach,
      ),
      scale: ChartScale.of(values, intervals: 4),
      count: values.length,
    );

void main() {
  testWidgets('gives the axis band up rather than overflowing a short box', (
    tester,
  ) async {
    // Shorter than the 22 px axis alone.
    await pumpHost(tester, _chart(height: 16));

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(LineAreaChart)).height, 16);
  });

  testWidgets('each point stands over the centre of its label', (tester) async {
    for (final gutter in [0.0, AppChart.valueGutter]) {
      await pumpHost(
        tester,
        _chart(height: 200, valueLabel: gutter == 0 ? null : (v) => 'v$v'),
      );

      final chart = tester.getRect(find.byType(LineAreaChart));
      final g = _geometry(chart, _values, gutter: gutter);
      for (var i = 0; i < _labels.length; i++) {
        expect(
          tester.getCenter(find.text(_labels[i])).dx,
          closeTo(g.x(i), 0.01),
          reason: 'gutter $gutter, label $i',
        );
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('hovering a period shows its tooltip', (tester) async {
    await pumpHost(
      tester,
      _chart(
        height: 200,
        tooltips: const [
          TextSpan(text: 'Février 2026'),
          TextSpan(text: 'Mars 2026'),
          TextSpan(text: 'Avril 2026'),
          TextSpan(text: 'Mai 2026'),
        ],
      ),
    );

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);
    await gesture.addPointer(location: Offset.zero);
    await gesture.moveTo(
      tester.getCenter(find.byKey(const Key('lineAreaSlot-2'))),
    );
    await tester.pump();

    expect(find.text('Avril 2026'), findsOneWidget);
    expect(find.text('Mai 2026'), findsNothing);

    await gesture.moveTo(Offset.zero);
    await tester.pump();
    expect(find.byKey(const Key('lineAreaTooltip')), findsNothing);
  });

  testWidgets('the hover card keeps clear of every point and of the line', (
    tester,
  ) async {
    const tooltips = [
      TextSpan(text: 'Février 2026\n1 000,00 €'),
      TextSpan(text: 'Mars 2026\n2 400,00 €'),
      TextSpan(text: 'Avril 2026\n1 800,00 €'),
      TextSpan(text: 'Mai 2026\n3 200,00 €'),
    ];
    await pumpHost(
      tester,
      _chart(height: 240, tooltips: tooltips, valueLabel: (v) => 'v$v'),
    );

    final chart = tester.getRect(find.byType(LineAreaChart));
    final g = _geometry(chart, _values, gutter: AppChart.valueGutter);
    final points = [
      for (var i = 0; i < _values.length; i++) Offset(g.x(i), g.y(_values[i])),
    ];

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);
    await gesture.addPointer(location: Offset.zero);
    for (var i = 0; i < _values.length; i++) {
      await gesture.moveTo(
        tester.getCenter(find.byKey(Key('lineAreaSlot-$i'))),
      );
      await tester.pump();

      final card = tester.getRect(find.byKey(const Key('lineAreaTooltip')));
      expect(touchesLine(card, points), isFalse, reason: 'period $i');
      expect(chart.contains(card.topLeft), isTrue);
      expect(
        card.bottom,
        lessThanOrEqualTo(chart.bottom - AppChart.axisHeight),
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('draws the current point clear of the plot edges', (
    tester,
  ) async {
    // The last value is the series' max, so on an unpadded axis its dot
    // would sit on the top edge; flat and negative series get the same room.
    for (final values in const [
      [154500, 182000, 197300],
      [-61500, -42000, -38200],
      [50000, 50000, 50000],
      [-30000, 120000, 80000, 125000],
    ]) {
      await pumpHost(
        tester,
        _chart(
          height: 200,
          values: values,
          labels: [for (final _ in values) ''],
          valueLabel: (v) => 'v$v',
        ),
      );

      // In the painter's own coordinates, with the chart at the origin.
      final g = _geometry(
        Rect.fromLTWH(0, 0, 400, 200),
        values,
        gutter: AppChart.valueGutter,
      );
      final y = g.y(values.last);
      expect(y, greaterThan(g.plot.top), reason: '$values');
      expect(y, lessThan(g.plot.bottom), reason: '$values');
      expect(
        tester.renderObject(
          find
              .descendant(
                of: find.byType(LineAreaChart),
                matching: find.byType(CustomPaint),
              )
              .first,
        ),
        paints..something(
          (method, arguments) =>
              method == #drawCircle &&
              ((arguments[0] as Offset).dy - y).abs() < 0.01 &&
              arguments[1] == AppChart.currentDotRadius,
        ),
      );
      expect(tester.takeException(), isNull);
    }
  });
}
