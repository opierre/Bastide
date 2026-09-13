import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/recurring_series.dart';
import 'recurring_labels.dart';

/// What a series has cost over time, drawn rather than listed.
///
/// A price column answers "what did I pay in March"; the question the detail
/// screen is actually asked is "is this getting more expensive", and a shape
/// answers that in one glance where a stack of near-identical amounts does not.
///
/// Drawn as a **step**, not a slope: a subscription costs the same every month
/// until the day it doesn't. Interpolating between two charges would draw a
/// price the user was never billed, which on a screen whose job is to be
/// trusted evidence is worse than a blunter line.
///
/// The literal amounts are not lost — the extremes are labelled on the value
/// axis, and every charge names its date and amount on hover, the same way the
/// dashboard's bars do.
class PriceHistoryChart extends StatelessWidget {
  const PriceHistoryChart({
    super.key,
    required this.series,
    required this.occurrences,
  });

  final RecurringSeries series;

  /// Charges as the detail holds them — newest first. Reversed here so the
  /// curve reads left to right in time.
  final List<SeriesOccurrence> occurrences;

  /// Width reserved for the value axis, and the gap between it and the plot.
  static const _axisWidth = 62.0;
  static const _axisGap = 8.0;

  /// Height reserved beneath the plot for the date axis.
  static const _dateAxisHeight = 20.0;

  /// Vertical inset, sized to clear the current-point dot.
  static const _inset = 6.0;

  /// Above this many charges the per-point dots turn the line into a bead
  /// string; the stroke alone carries the shape from there.
  static const dotCeiling = 24;

  /// Most date ticks the axis prints, however many charges there are.
  static const _maxDateLabels = 5;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final points = occurrences.reversed.toList();
    // Unsigned: the chart plots what the subscription costs, not a movement on
    // the ledger, so the line climbs when the price climbs.
    final values = [
      for (final point in points) point.amountMinor.abs().toDouble(),
    ];
    final stepIndex = _stepIndex(points);

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final plot = _PlotGeometry.of(
          Rect.fromLTRB(
            _axisWidth + _axisGap,
            _inset,
            size.width,
            size.height - _dateAxisHeight - _inset,
          ),
          values,
        );

        return Stack(
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _PriceLinePainter(plot: plot, stepIndex: stepIndex),
                ),
              ),
            ),
            ..._valueLabels(plot, locale),
            ..._dateLabels(context, plot, points, locale),
            for (var i = 0; i < points.length; i++)
              _hoverSlice(
                context: context,
                l10n: l10n,
                locale: locale,
                plot: plot,
                index: i,
                occurrence: points[i],
                isStep: i == stepIndex,
                width: size.width,
              ),
          ],
        );
      },
    );
  }

  /// The charge the recorded price change landed on, or `null` when there was
  /// none — the point the curve steps at.
  int? _stepIndex(List<SeriesOccurrence> points) {
    final changedAt = series.priceChangedAt;
    if (changedAt == null || series.previousAmountMinor == null) return null;
    final index = points.indexWhere(
      (point) =>
          point.bookedDate.year == changedAt.year &&
          point.bookedDate.month == changedAt.month &&
          point.bookedDate.day == changedAt.day,
    );
    return index == -1 ? null : index;
  }

  /// The cheapest and dearest charge, printed at their own height on the line's
  /// left. Two ticks rather than an even scale: the figures that matter here
  /// are the prices actually paid, not round intermediate ones nobody was
  /// billed.
  List<Widget> _valueLabels(_PlotGeometry plot, String locale) {
    if (plot.values.isEmpty) return const [];
    final style = tabularNumberStyle(
      AppTextStyles.helper,
    ).copyWith(color: AppColors.textSecondary);

    Widget label(double value, Key key) => Positioned(
      key: key,
      left: 0,
      width: _axisWidth,
      // Half a line's height, so the text centres on the value it names.
      top: plot.yAt(value) - 8,
      child: Text(
        formatAmount(
          amountMinor: value.round(),
          currency: series.currency,
          locale: locale,
        ),
        textAlign: TextAlign.end,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      ),
    );

    final low = plot.minValue;
    final high = plot.maxValue;
    return [
      label(high, const Key('seriesPriceAxisMax')),
      // A price that never moved has one figure, not a range: printing it twice
      // would invent a spread the series doesn't have.
      if (high != low) label(low, const Key('seriesPriceAxisMin')),
    ];
  }

  /// Date ticks under the plot, thinned to [_maxDateLabels] so a weekly series
  /// doesn't print a year of overlapping dates.
  List<Widget> _dateLabels(
    BuildContext context,
    _PlotGeometry plot,
    List<SeriesOccurrence> points,
    String locale,
  ) {
    if (points.isEmpty) return const [];
    final format = seriesAxisDateFormat(
      locale,
      span: points.last.bookedDate.difference(points.first.bookedDate),
    );
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      fontWeight: FontWeight.w400,
      color: AppColors.textSecondary,
    );
    const slot = 76.0;
    final maxLeft = math.max(0.0, plot.rect.right - slot);

    return [
      for (final i in _tickIndices(points.length))
        Positioned(
          // Clamped to the plot: an edge tick leans inward rather than hanging
          // off the card.
          left: (plot.xAt(i) - slot / 2).clamp(0.0, maxLeft),
          width: slot,
          top: plot.rect.bottom + _inset,
          child: Text(
            format.format(points[i].bookedDate),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
    ];
  }

  static List<int> _tickIndices(int count) {
    if (count <= _maxDateLabels) return [for (var i = 0; i < count; i++) i];
    final step = (count - 1) / (_maxDateLabels - 1);
    return {
      for (var i = 0; i < _maxDateLabels; i++) (i * step).round(),
    }.toList();
  }

  /// A full-height column over each charge: the point is a few pixels wide, but
  /// the thing worth hovering is the moment in time it stands for.
  Widget _hoverSlice({
    required BuildContext context,
    required AppLocalizations l10n,
    required String locale,
    required _PlotGeometry plot,
    required int index,
    required SeriesOccurrence occurrence,
    required bool isStep,
    required double width,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final sliceWidth = plot.values.length < 2
        ? plot.rect.width
        : plot.rect.width / (plot.values.length - 1);
    final maxLeft = math.max(0.0, width - sliceWidth);

    return Positioned(
      left: (plot.xAt(index) - sliceWidth / 2).clamp(0.0, maxLeft),
      width: sliceWidth,
      top: 0,
      bottom: _dateAxisHeight,
      child: Tooltip(
        key: Key('seriesOccurrence-${occurrence.id}'),
        richMessage: TextSpan(
          children: [
            TextSpan(
              text:
                  '${seriesDateFormat(locale).format(occurrence.bookedDate)}\n',
              style: tabularNumberStyle(textTheme.labelSmall!),
            ),
            TextSpan(
              // Signed and colorized here, unlike the axis: the tooltip names
              // the transaction itself, money that actually left the account.
              text: formatAmount(
                amountMinor: occurrence.amountMinor,
                currency: occurrence.currency,
                locale: locale,
              ),
              style: tabularNumberStyle(textTheme.bodySmall!).copyWith(
                color: occurrence.amountMinor < 0
                    ? AppColors.negative
                    : AppColors.positive,
              ),
            ),
            if (isStep && series.previousAmountMinor != null)
              TextSpan(
                text:
                    '\n${l10n.subscriptionDetailChange(_money(series.previousAmountMinor!, locale), _money(series.expectedAmountMinor, locale))}',
                style: tabularNumberStyle(
                  textTheme.bodySmall!,
                ).copyWith(color: AppColors.warning),
              ),
          ],
        ),
        child: const ColoredBox(color: Colors.transparent),
      ),
    );
  }

  String _money(int amountMinor, String locale) => formatAmount(
    amountMinor: amountMinor.abs(),
    currency: series.currency,
    locale: locale,
  );
}

/// Where a value and a charge index land inside the plot. Shared by the painter
/// and the labels stacked over it, so a tick never drifts off the point it
/// names.
@immutable
class _PlotGeometry {
  const _PlotGeometry({
    required this.rect,
    required this.values,
    required this.low,
    required this.high,
  });

  factory _PlotGeometry.of(Rect rect, List<double> values) {
    if (values.isEmpty) {
      return _PlotGeometry(rect: rect, values: values, low: 0, high: 1);
    }
    final min = values.reduce(math.min);
    final max = values.reduce(math.max);
    final span = max - min;
    // Headroom, so the extremes sit inside the plot rather than against its
    // edges. A price that never moved has no span to scale against; the padding
    // is then symmetric around it and the flat line lands mid-plot, which is
    // the honest drawing of "this never changed".
    final pad = span == 0 ? math.max(max.abs() * 0.2, 1) : span * 0.35;
    return _PlotGeometry(
      rect: rect,
      values: values,
      low: min - pad,
      high: max + pad,
    );
  }

  final Rect rect;
  final List<double> values;
  final double low;
  final double high;

  double get minValue => values.reduce(math.min);
  double get maxValue => values.reduce(math.max);

  /// A single charge has no span to spread across; it sits in the middle.
  double xAt(int index) => values.length < 2
      ? rect.center.dx
      : rect.left + rect.width * (index / (values.length - 1));

  double yAt(double value) =>
      rect.bottom - rect.height * ((value - low) / (high - low));

  @override
  bool operator ==(Object other) =>
      other is _PlotGeometry &&
      other.rect == rect &&
      other.low == low &&
      other.high == high &&
      listEquals(other.values, values);

  @override
  int get hashCode => Object.hash(rect, low, high, Object.hashAll(values));
}

/// The step line itself: the same iris stroke over a 16% iris fill the savings
/// area line uses (`docs/design/00` §Components → AreaLine), so the two charts
/// read as one family.
///
/// Deliberately not animated, like every other chart here — the spec allows
/// only the spinner and skeleton keyframes.
class _PriceLinePainter extends CustomPainter {
  _PriceLinePainter({required this.plot, required this.stepIndex});

  final _PlotGeometry plot;
  final int? stepIndex;

  static const _stroke = 2.5;
  static const _dotRadius = 5.0;
  static const _pointRadius = 3.0;
  static const _fillAlpha = 0.16;
  static const _gridlines = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = plot.rect;

    final grid = Paint()
      ..color = AppColors.borderSubtle
      ..strokeWidth = 1;
    for (var i = 0; i <= _gridlines; i++) {
      final y = rect.top + rect.height * (i / _gridlines);
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), grid);
    }

    if (plot.values.isEmpty) return;

    final points = [
      for (var i = 0; i < plot.values.length; i++)
        Offset(plot.xAt(i), plot.yAt(plot.values[i])),
    ];

    if (points.length > 1) {
      // Step-after: the price holds at its level until the next charge, then
      // jumps. The vertical is the price change, drawn as the discontinuity it
      // actually is.
      final line = Path()..moveTo(points.first.dx, points.first.dy);
      for (var i = 1; i < points.length; i++) {
        line
          ..lineTo(points[i].dx, points[i - 1].dy)
          ..lineTo(points[i].dx, points[i].dy);
      }
      final area = Path.from(line)
        ..lineTo(points.last.dx, rect.bottom)
        ..lineTo(points.first.dx, rect.bottom)
        ..close();

      canvas.drawPath(
        area,
        Paint()..color = AppColors.iris.withValues(alpha: _fillAlpha),
      );
      canvas.drawPath(
        line,
        Paint()
          ..color = AppColors.iris
          ..style = PaintingStyle.stroke
          ..strokeWidth = _stroke
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
    }

    if (points.length <= PriceHistoryChart.dotCeiling) {
      for (var i = 0; i < points.length - 1; i++) {
        _dot(canvas, points[i], _pointRadius, AppColors.iris);
      }
    }

    // The charge the price stepped at, in the same amber the increase banner
    // and the list's pill use — the one point on the line the user is being
    // asked to look at.
    if (stepIndex case final step? when step < points.length) {
      canvas.drawLine(
        Offset(points[step].dx, rect.top),
        Offset(points[step].dx, rect.bottom),
        Paint()
          ..color = AppColors.warning.withValues(alpha: 0.35)
          ..strokeWidth = 1,
      );
      _dot(canvas, points[step], _dotRadius, AppColors.warning);
    }

    // The latest charge, ringed in the card's own surface so it reads as
    // sitting on the line rather than as a bead threaded onto it.
    if (stepIndex != points.length - 1) {
      _dot(canvas, points.last, _dotRadius, AppColors.iris);
    }
  }

  void _dot(Canvas canvas, Offset center, double radius, Color color) {
    canvas
      ..drawCircle(center, radius, Paint()..color = AppColors.surfaceRaised)
      ..drawCircle(center, radius - _stroke / 2, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_PriceLinePainter oldDelegate) =>
      oldDelegate.plot != plot || oldDelegate.stepIndex != stepIndex;
}
