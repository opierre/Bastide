import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// The value range a chart draws on, and the gridline values inside it. Shared by the
/// charts that plot money ([AreaLine], « Patrimoine net »), so they frame a series alike.
///
/// An axis that starts and ends on the series' own min and max puts those two points on the
/// plot's edges, where they are hardest to read. The range is instead padded by a share of
/// the series' spread on either side, then widened to clean tick values (round steps such
/// as 2, 2.5 or 5 times a power of ten), so each gridline stands for a round figure. A
/// series that stays on one side of zero is never padded across it: a balance that was
/// never negative gets no negative tick.
@immutable
class ChartScale {
  const ChartScale._(this.min, this.max, this.ticks);

  /// The scale for [values] with [intervals] equal gaps between its gridlines.
  ///
  /// No gap is smaller than [minStep]: a chart of minor units passes 100, so no gridline
  /// lands on cents, even for a series that never moves off zero.
  factory ChartScale.of(
    List<num> values, {
    required int intervals,
    num minStep = 1,
  }) {
    final n = math.max(intervals, 1);
    final floor = minStep > 0 ? minStep.toDouble() : 1.0;
    if (values.isEmpty) return ChartScale._(0, n * floor, _ticks(0, floor, n));
    var low = values.fold<num>(values.first, math.min).toDouble();
    var high = values.fold<num>(values.first, math.max).toDouble();

    // A flat series has no spread to pad by, so it borrows one from its own size (or one
    // [minStep] either side of zero) and sits inside the plot like any other.
    final spread = high - low;
    final pad = spread > 0
        ? spread * _headroom
        : (low == 0 ? floor : low.abs() * _headroom);
    final positive = low >= 0 && high > 0;
    final negative = high <= 0 && low < 0;
    low -= pad;
    high += pad;
    if (positive) low = math.max(low, 0);
    if (negative) high = math.min(high, 0);

    var step = _niceAtLeast(math.max((high - low) / n, floor));
    for (var guard = 0; guard < 64; guard++) {
      // A series below zero hangs from its top tick, so rounding never lifts it past zero;
      // anything else stands on its bottom one.
      final double min;
      final double max;
      if (negative) {
        max = (high / step - _epsilon).ceilToDouble() * step;
        min = max - n * step;
      } else {
        min = (low / step + _epsilon).floorToDouble() * step;
        max = min + n * step;
      }
      if (min <= low + _epsilon * step && max >= high - _epsilon * step) {
        return ChartScale._(min, max, _ticks(min, step, n));
      }
      step = _niceAtLeast(step * (1 + 1e-6));
    }
    return ChartScale._(low, high, _ticks(low, (high - low) / n, n));
  }

  /// The value at the bottom of the plot.
  final double min;

  /// The value at the top of the plot.
  final double max;

  /// The value of each gridline, bottom to top: [min] first, [max] last.
  final List<num> ticks;

  /// Share of the series' spread added below its min and above its max.
  static const _headroom = 0.1;

  /// Rounding slack for comparing tick arithmetic done in floating point.
  static const _epsilon = 1e-9;

  /// Where [value] is drawn in [plot].
  double y(num value, Rect plot) =>
      plot.bottom - plot.height * ((value - min) / (max - min));

  @override
  bool operator ==(Object other) =>
      other is ChartScale &&
      other.min == min &&
      other.max == max &&
      listEquals(other.ticks, ticks);

  @override
  int get hashCode => Object.hash(min, max, Object.hashAll(ticks));

  /// The clean step sizes within one power of ten. Finer than the classic 1 / 2 / 5, because
  /// a chart with only two or three gridlines would otherwise round its range far past the
  /// series and squash the line into a band of the plot.
  static const _steps = [
    1.0,
    1.2,
    1.5,
    2.0,
    2.5,
    3.0,
    4.0,
    5.0,
    6.0,
    7.5,
    8.0,
    10.0,
  ];

  /// The smallest clean step (see [_steps]) times a power of ten no smaller than [raw].
  static double _niceAtLeast(double raw) {
    if (raw <= 0 || !raw.isFinite) return 1;
    final magnitude = math
        .pow(10, (math.log(raw) / math.ln10).floorToDouble())
        .toDouble();
    for (final factor in _steps) {
      final step = factor * magnitude;
      // Every factor has at most one decimal, so from tens up the step is whole: snap off
      // the floating-point dust (1.2 × 10⁴ ≠ 12000 exactly).
      if (step >= raw * (1 - _epsilon)) {
        return magnitude >= 10 ? step.roundToDouble() : step;
      }
    }
    return 10 * magnitude;
  }

  /// The [n] + 1 gridline values from [min] up by [step]: whole numbers when the step is,
  /// so a label never reads 2999.9999.
  static List<num> _ticks(double min, double step, int n) {
    final whole = step == step.roundToDouble();
    return [
      for (var i = 0; i <= n; i++)
        whole ? (min + i * step).round() : min + i * step,
    ];
  }
}
