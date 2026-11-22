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

  group('ChartScale.signedBars', () {
    /// Whether the ticks are evenly spaced clean multiples of their step,
    /// inside the scale, zero among them.
    void expectTicksInside(ChartScale scale) {
      expect(scale.ticks, contains(0));
      expect(scale.ticks.first, greaterThanOrEqualTo(scale.min));
      expect(scale.ticks.last, lessThanOrEqualTo(scale.max));
      final step = scale.ticks[1] - scale.ticks[0];
      for (var i = 1; i < scale.ticks.length; i++) {
        expect(scale.ticks[i] - scale.ticks[i - 1], closeTo(step, 1e-9));
      }
    }

    test('fits a window that crosses zero to its own min and max, plus a '
        'margin on each side', () {
      const values = [-5000, 120000, 80000, 95000];
      final scale = ChartScale.signedBars(values, intervals: 4, minStep: 100);

      // A tenth of the 125 000 spread below the deepest bar and above the
      // tallest one.
      expect(scale.min, -17500);
      expect(scale.max, 132500);
      expect(scale.min < 0 && scale.max > 0, isTrue, reason: 'zero line');
      expectTicksInside(scale);
      expect(scale.ticks, [0, 40000, 80000, 120000]);
    });

    test('is not widened to whole steps, so a small negative month does not '
        'claim a large band', () {
      const values = [-5000, 120000, 80000, 95000];
      final fitted = ChartScale.signedBars(values, intervals: 4);
      final padded = ChartScale.of([...values, 0], intervals: 4);

      expect(fitted.max - fitted.min, lessThan(padded.max - padded.min));
      // The negative band is the deepest bar plus its margin, nothing more.
      expect(-fitted.min / (fitted.max - fitted.min), lessThan(0.15));
    });

    test('a window above zero stands on zero with headroom on top only', () {
      const values = [90000, 150000, 120000];
      final scale = ChartScale.signedBars(values, intervals: 4, minStep: 100);

      expect(scale.min, 0);
      expect(scale.max, 165000);
      expectTicksInside(scale);
    });

    test('a window below zero hangs from zero with room underneath only', () {
      const values = [-30000, -12000, -45000];
      final scale = ChartScale.signedBars(values, intervals: 4, minStep: 100);

      expect(scale.max, 0);
      expect(scale.min, -49500);
      expectTicksInside(scale);
    });

    test('the bars fill the plot whatever the window', () {
      for (final values in const [
        [1200, 1500, 1350],
        [-80000, 2000, -1000],
        [700000, -650000, 10000],
      ]) {
        final scale = ChartScale.signedBars(values, intervals: 4);
        final low = math.min(values.reduce(math.min), 0);
        final high = math.max(values.reduce(math.max), 0);
        expect((high - low) / (scale.max - scale.min), greaterThan(0.8));
        expectTicksInside(scale);
      }
    });

    test('keeps ticks off cents and frames an all-zero window', () {
      final small = ChartScale.signedBars(
        const [30, -20],
        intervals: 4,
        minStep: 100,
      );
      expect(small.ticks, [0]);

      final zero = ChartScale.signedBars(
        const [0, 0],
        intervals: 2,
        minStep: 100,
      );
      expect(zero.ticks, [-100, 0, 100]);

      final empty = ChartScale.signedBars(const [], intervals: 4, minStep: 100);
      expect(empty.max, greaterThan(empty.min));
    });
  });
}
