import 'package:bastide/core/widgets/chart_tooltip.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'chart_test_utils.dart';

void main() {
  group('placeChartTooltip', () {
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
          placeChartTooltip(
            area: area,
            points: points,
            hovered: 3,
            tooltip: card,
            pointRadius: 5,
          ) &
          card;

      expect(touchesLine(box, points), isFalse);
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
          placeChartTooltip(
            area: area,
            points: points,
            hovered: 3,
            tooltip: card,
            pointRadius: 5,
          ) &
          card;

      expect(touchesLine(box, points.sublist(2, 5)), isFalse);
    });

    test('keeps off the value gutter when the plot has room', () {
      const points = [Offset(80, 100), Offset(390, 100)];
      final corner = placeChartTooltip(
        area: area,
        points: points,
        hovered: 0,
        tooltip: card,
        pointRadius: 5,
        leftBound: 56,
      );

      expect(corner.dx, greaterThanOrEqualTo(56));
    });

    test('bars are kept clear of like the line', () {
      // No line joins bars; the card keeps off each of them instead.
      const tips = [Offset(50, 40), Offset(150, 20), Offset(250, 60)];
      final bars = [
        for (final tip in tips)
          Rect.fromLTRB(tip.dx - 11, tip.dy, tip.dx + 11, 200),
      ];
      final box =
          placeChartTooltip(
            area: area,
            points: tips,
            hovered: 1,
            tooltip: card,
            pointRadius: 0,
            joinsNext: (_) => false,
            marks: bars,
          ) &
          card;

      for (final bar in bars) {
        expect(box.overlaps(bar), isFalse);
      }
    });

    test('a break in the line leaves its gap free for the card', () {
      // Too short for the card to clear a line across it: once the line
      // breaks after the hovered point, the gap is where the card goes.
      const strip = Rect.fromLTWH(0, 0, 400, 60);
      const points = [Offset(20, 30), Offset(200, 30), Offset(380, 30)];
      final box =
          placeChartTooltip(
            area: strip,
            points: points,
            hovered: 1,
            tooltip: card,
            pointRadius: 5,
            joinsNext: (i) => i != 1,
          ) &
          card;

      expect(box.left, greaterThan(points[1].dx));
      expect(touchesLine(box, points.sublist(0, 2)), isFalse);
    });
  });
}
