import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// The Y scale of « Patrimoine net »: a floor and a ceiling, in minor units,
/// with the midpoint between them as the third gridline.
@immutable
class NetworthAxis {
  const NetworthAxis({required this.low, required this.high});

  final int low;
  final int high;

  /// The three gridlines, bottom to top. Each one is a clean multiple of the
  /// step, since the step is half the span.
  List<int> get levels => [low, (low + high) ~/ 2, high];

  @override
  bool operator ==(Object other) =>
      other is NetworthAxis && other.low == low && other.high == high;

  @override
  int get hashCode => Object.hash(low, high);

  @override
  String toString() => 'NetworthAxis($low, $high)';
}

/// Air kept above the highest month and below the lowest, as a share of the
/// series' range, before rounding out to clean ticks.
const _headroom = 0.08;

/// The smallest step: one major unit (100 minor), so no gridline lands on cents.
const _minStep = 100;

/// The scale for [values], which must not be empty.
///
/// The range is padded by [_headroom] on both sides, then widened to two equal
/// steps of 1, 2, 2.5 or 5 × 10ⁿ major units, both bounds on a multiple of the
/// step. So the peak and the trough always sit strictly inside the plot, and
/// all three gridlines read as round figures. A flat series gets a band around
/// its value instead of a zero-height scale.
NetworthAxis networthAxis(List<int> values) {
  assert(values.isNotEmpty, 'networthAxis needs at least one value');
  final lowest = values.reduce((a, b) => a < b ? a : b);
  final highest = values.reduce((a, b) => a > b ? a : b);
  final range = highest - lowest;
  // A flat series has no range to pad by: borrow a share of its magnitude.
  final pad = range == 0
      ? math.max(_minStep, (lowest.abs() * _headroom).ceil())
      : (range * _headroom).ceil();
  final paddedLow = lowest - pad;
  final paddedHigh = highest + pad;

  var step = _niceAtLeast(((paddedHigh - paddedLow) / 2).ceil());
  while (true) {
    final low = _floorTo(paddedLow, step);
    final high = low + 2 * step;
    if (high >= paddedHigh) return NetworthAxis(low: low, high: high);
    // Flooring the bottom cost too much span: take the next clean step.
    step = _niceAtLeast(step + 1);
  }
}

/// The smallest clean step (1, 2, 2.5 or 5 × 10ⁿ major units) ≥ [minimum].
int _niceAtLeast(int minimum) {
  var magnitude = _minStep;
  while (true) {
    for (final factor in const [10, 20, 25, 50]) {
      final step = magnitude * factor ~/ 10;
      if (step >= minimum) return step;
    }
    magnitude *= 10;
  }
}

/// [value] rounded down to a multiple of [step], negatives included (`~/`
/// truncates toward zero, which would round a negative floor up).
int _floorTo(int value, int step) {
  final quotient = value ~/ step;
  return (quotient * step > value ? quotient - 1 : quotient) * step;
}
