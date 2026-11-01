import 'dart:math' as math;

import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/core/theme/tokens.dart';
import 'package:bastide/core/widgets/area_line.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap({
  required double height,
  List<InlineSpan>? tooltips,
  String Function(num)? valueLabel,
}) => MaterialApp(
  theme: appDarkTheme,
  home: Scaffold(
    body: Center(
      child: SizedBox(
        height: height,
        width: 400,
        child: AreaLine(
          values: const [1000, 2400, 1800, 3200],
          labels: const ['Févr.', 'Mars', 'Avr.', 'Mai'],
          tooltips: tooltips,
          valueLabel: valueLabel,
        ),
      ),
    ),
  ),
);

/// Whether [box] covers any point of [points] or any stretch of the line
/// joining them, sampled every pixel or so.
bool _touchesLine(Rect box, List<Offset> points) {
  for (var i = 0; i < points.length; i++) {
    if (box.contains(points[i])) return true;
    if (i == 0) continue;
    final a = points[i - 1];
    final b = points[i];
    final steps = (b - a).distance.ceil();
    for (var s = 0; s <= steps; s++) {
      if (box.contains(Offset.lerp(a, b, s / steps)!)) return true;
    }
  }
  return false;
}

void main() {
  testWidgets(
    'draws the plot over its month axis when there is room for both',
    (tester) async {
      await tester.pumpWidget(_wrap(height: 200));
      await tester.pumpAndSettle();

      expect(find.text('Mai'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('gives the axis band up rather than overflowing a short card', (
    tester,
  ) async {
    // Shorter than the 22px axis alone — the case that made the savings card throw a
    // RenderFlex overflow on a small window.
    await tester.pumpWidget(_wrap(height: 16));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(AreaLine)).height, 16);
  });

  testWidgets('each point stands over the centre of its month label', (
    tester,
  ) async {
    // Points used to spread edge to edge while labels sat centred in equal
    // slots, so every month but the middle ones drifted off its label.
    await tester.pumpWidget(_wrap(height: 200));
    await tester.pumpAndSettle();

    final chart = tester.getRect(find.byType(AreaLine));
    const labels = ['Févr.', 'Mars', 'Avr.', 'Mai'];
    for (var i = 0; i < labels.length; i++) {
      expect(
        tester.getCenter(find.text(labels[i])).dx - chart.left,
        closeTo(AreaLine.pointX(i, labels.length, chart.width), 0.01),
      );
    }
  });

  testWidgets('hovering a month shows its tooltip', (tester) async {
    await tester.pumpWidget(
      _wrap(
        height: 200,
        tooltips: const [
          TextSpan(text: 'Février 2026'),
          TextSpan(text: 'Mars 2026'),
          TextSpan(text: 'Avril 2026'),
          TextSpan(text: 'Mai 2026'),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);
    await gesture.addPointer(location: Offset.zero);
    await gesture.moveTo(
      tester.getCenter(find.byKey(const Key('areaLineSlot-2'))),
    );
    await tester.pump();

    expect(find.text('Avril 2026'), findsOneWidget);
    expect(find.text('Mai 2026'), findsNothing);
    expect(tester.takeException(), isNull);

    await gesture.moveTo(Offset.zero);
    await tester.pump();
    expect(find.byKey(const Key('areaLineTooltip')), findsNothing);
  });

  testWidgets('the hover card keeps clear of every point and of the line', (
    tester,
  ) async {
    const tooltips = [
      TextSpan(text: 'Février 2026\n1 000,00 €\n—'),
      TextSpan(text: 'Mars 2026\n2 400,00 €\n+1 400,00 €'),
      TextSpan(text: 'Avril 2026\n1 800,00 €\n−600,00 €'),
      TextSpan(text: 'Mai 2026\n3 200,00 €\n+1 400,00 €'),
    ];
    await tester.pumpWidget(
      _wrap(height: 240, tooltips: tooltips, valueLabel: (v) => 'v$v'),
    );
    await tester.pumpAndSettle();

    final chart = tester.getRect(find.byType(AreaLine));
    // Mirrors the painter: the plot sits right of the gutter, inset by the
    // 5px dot, above the month axis.
    final plot = Rect.fromLTRB(
      chart.left + AreaLine.valueGutter,
      chart.top + 5,
      chart.right,
      chart.bottom - AreaLine.axisHeight - 5,
    );
    const values = [1000, 2400, 1800, 3200];
    final scale = AreaLineScale.of(values, intervals: 4);
    final points = [
      for (var i = 0; i < values.length; i++)
        Offset(
          plot.left + AreaLine.pointX(i, values.length, plot.width),
          scale.y(values[i], plot),
        ),
    ];

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);
    await gesture.addPointer(location: Offset.zero);
    for (var i = 0; i < values.length; i++) {
      await gesture.moveTo(
        tester.getCenter(find.byKey(Key('areaLineSlot-$i'))),
      );
      await tester.pump();

      final card = tester.getRect(find.byKey(const Key('areaLineTooltip')));
      expect(_touchesLine(card, points), isFalse, reason: 'month $i');
      expect(chart.contains(card.topLeft), isTrue);
      expect(
        card.bottom,
        lessThanOrEqualTo(chart.bottom - AreaLine.axisHeight),
      );
    }
    expect(tester.takeException(), isNull);
  });

  group('placeAreaLineTooltip', () {
    const area = Rect.fromLTWH(0, 0, 400, 200);
    const card = Size(120, 56);

    test('sits beside the hovered point, not on it', () {
      const points = [
        Offset(50, 180),
        Offset(150, 120),
        Offset(250, 60),
        Offset(350, 10),
      ];
      final box =
          placeAreaLineTooltip(
            area: area,
            points: points,
            hovered: 3,
            tooltip: card,
          ) &
          card;

      expect(_touchesLine(box, points), isFalse);
      expect(area.contains(box.topLeft), isTrue);
      expect(area.contains(box.bottomRight - const Offset(1, 1)), isTrue);
    });

    test('a zig-zag with no free room still spares the point being read', () {
      // Every spot the card could take touches some segment: it keeps clear
      // of the hovered point and its two neighbouring segments instead.
      const points = [
        Offset(25, 195),
        Offset(75, 5),
        Offset(125, 195),
        Offset(175, 5),
        Offset(225, 195),
        Offset(275, 5),
        Offset(325, 195),
        Offset(375, 5),
      ];
      final box =
          placeAreaLineTooltip(
            area: area,
            points: points,
            hovered: 3,
            tooltip: card,
          ) &
          card;

      expect(_touchesLine(box, points.sublist(2, 5)), isFalse);
    });

    test('keeps off the value gutter when the plot has room', () {
      const points = [Offset(80, 100), Offset(390, 100)];
      final corner = placeAreaLineTooltip(
        area: area,
        points: points,
        hovered: 0,
        tooltip: card,
        leftBound: 56,
      );

      expect(corner.dx, greaterThanOrEqualTo(56));
    });
  });

  testWidgets('a value axis leaves its gutter and keeps points over labels', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(height: 200, valueLabel: (value) => 'v$value'),
    );
    await tester.pumpAndSettle();

    final chart = tester.getRect(find.byType(AreaLine));
    const labels = ['Févr.', 'Mars', 'Avr.', 'Mai'];
    const plotWidth = 400 - AreaLine.valueGutter;
    for (var i = 0; i < labels.length; i++) {
      expect(
        tester.getCenter(find.text(labels[i])).dx - chart.left,
        closeTo(
          AreaLine.valueGutter + AreaLine.pointX(i, labels.length, plotWidth),
          0.01,
        ),
      );
    }
    expect(tester.takeException(), isNull);
  });

  group('AreaLineScale', () {
    /// Whether every tick is a whole multiple of the gap between ticks.
    void expectCleanTicks(AreaLineScale scale, int intervals) {
      expect(scale.ticks, hasLength(intervals + 1));
      expect(scale.ticks.first, scale.min);
      expect(scale.ticks.last, scale.max);
      final step = scale.ticks[1] - scale.ticks[0];
      for (var i = 1; i < scale.ticks.length; i++) {
        expect(scale.ticks[i] - scale.ticks[i - 1], closeTo(step, 1e-9));
      }
      for (final tick in scale.ticks) {
        expect((tick / step - (tick / step).round()).abs(), lessThan(1e-9));
      }
    }

    /// Whether [values] sit strictly inside the scale, clear of both edges.
    void expectHeadroom(AreaLineScale scale, List<num> values) {
      final low = values.fold<num>(values.first, math.min);
      final high = values.fold<num>(values.first, math.max);
      expect(scale.min, lessThan(low));
      expect(scale.max, greaterThan(high));
    }

    test('pads a positive series to clean ticks without going below zero', () {
      const values = [182000, 154500, 197300, 163800];
      final scale = AreaLineScale.of(values, intervals: 2);

      expectHeadroom(scale, values);
      expectCleanTicks(scale, 2);
      expect(scale.min, greaterThanOrEqualTo(0));
      expect(scale.ticks, [150000, 180000, 210000]);
    });

    test('never pads a series that stays above zero across it', () {
      const values = [2000, 95000, 60000];
      final scale = AreaLineScale.of(values, intervals: 2);

      expect(scale.min, 0);
      expect(scale.max, greaterThan(95000));
      expectCleanTicks(scale, 2);
    });

    test('pads a negative series without lifting it past zero', () {
      const values = [-42000, -61500, -38200];
      final scale = AreaLineScale.of(values, intervals: 2);

      expectHeadroom(scale, values);
      expectCleanTicks(scale, 2);
      expect(scale.max, lessThanOrEqualTo(0));
    });

    test('a series crossing zero keeps zero on a gridline', () {
      const values = [120000, -30000, 80000];
      final scale = AreaLineScale.of(values, intervals: 2);

      expectHeadroom(scale, values);
      expectCleanTicks(scale, 2);
      expect(scale.ticks, contains(0));
    });

    test('a flat series sits inside the plot, not on an edge', () {
      for (final value in const [50000, -50000, 0]) {
        final scale = AreaLineScale.of([value, value, value], intervals: 2);

        expectHeadroom(scale, [value]);
        expectCleanTicks(scale, 2);
      }
    });

    test('follows the gridline count it is given', () {
      const values = [1000, 2400, 1800, 3200];
      final scale = AreaLineScale.of(values, intervals: 4);

      expectHeadroom(scale, values);
      expectCleanTicks(scale, 4);
    });
  });

  testWidgets('draws the current point clear of the plot edges', (
    tester,
  ) async {
    // The last value is the series' max, so on an unpadded axis its dot would sit on the
    // top edge; flat and negative series get the same room.
    for (final values in const [
      [154500, 182000, 197300],
      [-61500, -42000, -38200],
      [50000, 50000, 50000],
      [-30000, 120000, 80000, 125000],
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: appDarkTheme,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                height: 200,
                width: 400,
                child: AreaLine(
                  values: values,
                  labels: [for (final _ in values) ''],
                  gridlines: 2,
                  markZero: true,
                  valueLabel: (value) => 'v$value',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final plot = Rect.fromLTRB(
        AreaLine.valueGutter,
        5,
        400,
        200 - AreaLine.axisHeight - 5,
      );
      final scale = AreaLineScale.of(values, intervals: 2);
      final y = scale.y(values.last, plot);
      expect(y, greaterThan(plot.top), reason: '$values');
      expect(y, lessThan(plot.bottom), reason: '$values');
      // The painter rings the current point exactly there.
      expect(
        tester.renderObject(
          find.descendant(
            of: find.byType(AreaLine),
            matching: find.byType(CustomPaint),
          ),
        ),
        paints..circle(y: y, radius: 5),
      );
      expect(tester.takeException(), isNull);
    }
  });

  group('zero baseline', () {
    final overdraft = AppColors.negative.withValues(alpha: 0.10);

    Future<RenderObject> pumpSeries(
      WidgetTester tester,
      List<num> values, {
      bool markZero = true,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: appDarkTheme,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                height: 200,
                width: 400,
                child: AreaLine(
                  values: values,
                  labels: [for (final _ in values) ''],
                  markZero: markZero,
                ),
              ),
            ),
          ),
        ),
      );
      return tester.renderObject(
        find.descendant(
          of: find.byType(AreaLine),
          matching: find.byType(CustomPaint),
        ),
      );
    }

    testWidgets('a series crossing zero tints what lies below it', (
      tester,
    ) async {
      final chart = await pumpSeries(tester, const [120000, -30000, 80000]);

      // The fill above zero comes first, then the overdraft below it.
      expect(
        chart,
        paints
          ..path()
          ..path(color: overdraft),
      );
    });

    testWidgets('a series above zero is drawn as usual', (tester) async {
      final chart = await pumpSeries(tester, const [120000, 30000, 80000]);

      expect(
        chart,
        isNot(
          paints
            ..path()
            ..path(color: overdraft),
        ),
      );
    });

    testWidgets('the dashboard chart opts out of it', (tester) async {
      final chart = await pumpSeries(tester, const [
        120000,
        -30000,
        80000,
      ], markZero: false);

      expect(
        chart,
        isNot(
          paints
            ..path()
            ..path(color: overdraft),
        ),
      );
    });
  });
}
