import 'dart:math' as math;

import 'package:bastide/core/widgets/chart_scale.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChartScale', () {
    /// Whether every tick is a whole multiple of the gap between ticks.
    void expectCleanTicks(ChartScale scale, int intervals) {
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
    void expectHeadroom(ChartScale scale, List<num> values) {
      final low = values.fold<num>(values.first, math.min);
      final high = values.fold<num>(values.first, math.max);
      expect(scale.min, lessThan(low));
      expect(scale.max, greaterThan(high));
    }

    test('pads a positive series to clean ticks without going below zero', () {
      const values = [182000, 154500, 197300, 163800];
      final scale = ChartScale.of(values, intervals: 2);

      expectHeadroom(scale, values);
      expectCleanTicks(scale, 2);
      expect(scale.min, greaterThanOrEqualTo(0));
      expect(scale.ticks, [150000, 180000, 210000]);
    });

    test('never pads a series that stays above zero across it', () {
      const values = [2000, 95000, 60000];
      final scale = ChartScale.of(values, intervals: 2);

      expect(scale.min, 0);
      expect(scale.max, greaterThan(95000));
      expectCleanTicks(scale, 2);
    });

    test('pads a negative series without lifting it past zero', () {
      const values = [-42000, -61500, -38200];
      final scale = ChartScale.of(values, intervals: 2);

      expectHeadroom(scale, values);
      expectCleanTicks(scale, 2);
      expect(scale.max, lessThanOrEqualTo(0));
    });

    test('a series crossing zero keeps zero on a gridline', () {
      const values = [120000, -30000, 80000];
      final scale = ChartScale.of(values, intervals: 2);

      expectHeadroom(scale, values);
      expectCleanTicks(scale, 2);
      expect(scale.ticks, contains(0));
    });

    test('a flat series sits inside the plot, not on an edge', () {
      for (final value in const [50000, -50000, 0]) {
        final scale = ChartScale.of([value, value, value], intervals: 2);

        expectHeadroom(scale, [value]);
        expectCleanTicks(scale, 2);
      }
    });

    test('follows the gridline count it is given', () {
      const values = [1000, 2400, 1800, 3200];
      final scale = ChartScale.of(values, intervals: 4);

      expectHeadroom(scale, values);
      expectCleanTicks(scale, 4);
    });
    test(
      'a minimum step keeps ticks off cents, even for an all-zero series',
      () {
        final zero = ChartScale.of(const [0, 0, 0], intervals: 2, minStep: 100);
        expect(zero.ticks, [-100, 0, 100]);

        const small = [1203, 1207, 1205];
        final scale = ChartScale.of(small, intervals: 2, minStep: 100);
        expectHeadroom(scale, small);
        expectCleanTicks(scale, 2);
        expect(scale.ticks[1] - scale.ticks[0], greaterThanOrEqualTo(100));
      },
    );
  });
}
