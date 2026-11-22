import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/chart_style.dart';
import '../../../core/widgets/chart_tooltip.dart';
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
/// axis, and every charge names its date and amount on hover, in the card every
/// chart uses (see [LineChartTooltip]).
class PriceHistoryChart extends StatefulWidget {
  const PriceHistoryChart({
    super.key,
    required this.series,
    required this.occurrences,
  });

  final RecurringSeries series;

  /// Charges as the detail holds them — newest first. Reversed here so the
  /// curve reads left to right in time.
  final List<SeriesOccurrence> occurrences;

  /// The chart's height in the series detail (`docs/design/10` §3): tall
  /// enough that a one-cent step is still a visible tread.
  static const height = 184.0;

  /// Width reserved left of the plot for the value axis: the app-wide chart
  /// gutter, so this plot starts where every other chart's does. Its labels end
  /// [AppChart.labelGap] short of the plot, as theirs do.
  static const _gutter = AppChart.valueGutter;

  /// Right inset of the plot, so the latest charge's dot sits inside the chart
  /// rather than spilling into the card's padding — the gridlines still run to
  /// the edge, like every other chart's.
  static const _rightInset = AppChart.dotReach;

  /// Height reserved beneath the plot for a date axis whose ticks lie flat.
  static const _dateAxisHeight = AppChart.axisHeight;

  /// Vertical inset, sized to clear the current-point dot.
  static const _inset = AppChart.dotReach;

  /// Clear space kept between two neighbouring date ticks.
  static const _tickGap = 4.0;

  @override
  State<PriceHistoryChart> createState() => _PriceHistoryChartState();
}

class _PriceHistoryChartState extends State<PriceHistoryChart> {
  /// The charge under the pointer — hover ephemera, not chart state.
  int? _hovered;

  RecurringSeries get series => widget.series;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final textTheme = Theme.of(context).textTheme;
    final points = widget.occurrences.reversed.toList();
    // Unsigned: the chart plots what the subscription costs, not a movement on
    // the ledger, so the line climbs when the price climbs.
    final values = [
      for (final point in points) point.amountMinor.abs().toDouble(),
    ];
    final stepIndex = _stepIndex(points);
    final format = seriesAxisDateFormat(locale, [
      for (final point in points) point.bookedDate,
    ]);
    final ticks = [for (final point in points) format(point.bookedDate)];
    final labelStyle = ChartPaints.labelStyle(context);
    final tooltips = [
      for (var i = 0; i < points.length; i++)
        _tooltip(l10n, locale, textTheme, points[i], isStep: i == stepIndex),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final axis = _DateAxis.fit(
          ticks: ticks,
          style: labelStyle,
          textScaler: MediaQuery.textScalerOf(context),
          textDirection: Directionality.of(context),
          plotLeft: PriceHistoryChart._gutter,
          plotRight: size.width - PriceHistoryChart._rightInset,
          width: size.width,
        );
        final plot = _PlotGeometry.of(
          Rect.fromLTRB(
            PriceHistoryChart._gutter,
            PriceHistoryChart._inset,
            size.width - PriceHistoryChart._rightInset,
            size.height - axis.height - PriceHistoryChart._inset,
          ),
          values,
        );

        return Stack(
          // A price too long for the gutter (four figures and more) reaches
          // into the card's padding rather than being cut, as the painted
          // labels of the other charts do.
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _PriceLinePainter(
                    colors: context.colors,
                    plot: plot,
                    stepIndex: stepIndex,
                    hovered: _hovered,
                  ),
                ),
              ),
            ),
            ..._valueLabels(plot, locale, size.width, labelStyle),
            ..._dateLabels(plot, points, ticks, labelStyle, axis, size.width),
            Positioned.fill(
              child: MouseRegion(
                onExit: (_) => setState(() => _hovered = null),
                child: Stack(
                  children: [
                    for (var i = 0; i < points.length; i++)
                      _hoverSlice(
                        plot: plot,
                        index: i,
                        occurrence: points[i],
                        label: tooltips[i].toPlainText(),
                        width: size.width,
                        axisHeight: axis.height,
                      ),
                  ],
                ),
              ),
            ),
            if (_hovered case final hovered? when hovered < points.length)
              Positioned.fill(
                child: LineChartTooltip(
                  cardKey: const Key('seriesPriceTooltip'),
                  message: tooltips[hovered],
                  // The step line's own corners, so the card keeps clear of
                  // the treads and risers actually drawn: charge i is vertex
                  // 2i, the corner before it 2i − 1.
                  points: (_) => _stepVertices(plot),
                  hovered: hovered * 2,
                  pointRadius: AppChart.dotReach,
                  leftBound: PriceHistoryChart._gutter,
                  bottomInset: axis.height,
                ),
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
  List<Widget> _valueLabels(
    _PlotGeometry plot,
    String locale,
    double width,
    TextStyle style,
  ) {
    if (plot.values.isEmpty) return const [];

    Widget label(double value, Key key) => Positioned(
      key: key,
      // Anchored by its end, so the figure stays whole however wide it runs.
      right: width - (PriceHistoryChart._gutter - AppChart.labelGap),
      top: plot.yAt(value),
      // Lifted by half its own height, so the text centres on the value it
      // names.
      child: FractionalTranslation(
        translation: const Offset(0, -0.5),
        child: Text(
          formatAmount(
            amountMinor: value.round(),
            currency: series.currency,
            locale: locale,
          ),
          textAlign: TextAlign.end,
          maxLines: 1,
          softWrap: false,
          style: style,
        ),
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

  /// A date tick under each charge — flat while they fit side by side, turned
  /// on end when they don't, thinned only when even that collides (see
  /// [_DateAxis]).
  List<Widget> _dateLabels(
    _PlotGeometry plot,
    List<SeriesOccurrence> points,
    List<String> ticks,
    TextStyle? style,
    _DateAxis axis,
    double width,
  ) => [
    for (var i = 0; i < points.length; i++)
      if (axis.shows(i))
        Positioned(
          key: Key('seriesDateTick-${points[i].id}'),
          // Clamped to the chart: an edge tick leans inward rather than hanging
          // off the card.
          left: axis.leftOf(i, plot.xAt(i), width),
          width: axis.rotated ? axis.lineHeight : axis.widths[i],
          top: plot.rect.bottom + PriceHistoryChart._inset,
          child: axis.rotated
              // Read bottom to top, the date's end against the plot it names.
              ? RotatedBox(
                  quarterTurns: 3,
                  child: Text(
                    ticks[i],
                    maxLines: 1,
                    softWrap: false,
                    style: style,
                  ),
                )
              : Text(
                  ticks[i],
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  softWrap: false,
                  style: style,
                ),
        ),
  ];

  /// The step line's corners: each charge, and before every charge but the
  /// first the corner where the previous price meets its riser.
  List<Offset> _stepVertices(_PlotGeometry plot) {
    final vertices = <Offset>[];
    for (var i = 0; i < plot.values.length; i++) {
      final y = plot.yAt(plot.values[i]);
      if (i > 0) vertices.add(Offset(plot.xAt(i), vertices.last.dy));
      vertices.add(Offset(plot.xAt(i), y));
    }
    return vertices;
  }

  /// A full-height column over each charge: the point is a few pixels wide, but
  /// the thing worth hovering is the moment in time it stands for. It carries
  /// the card's text as a semantics label, since the card itself only exists
  /// while a pointer hovers.
  Widget _hoverSlice({
    required _PlotGeometry plot,
    required int index,
    required SeriesOccurrence occurrence,
    required String label,
    required double width,
    required double axisHeight,
  }) {
    final sliceWidth = plot.values.length < 2
        ? plot.rect.width
        : plot.rect.width / (plot.values.length - 1);
    final maxLeft = math.max(0.0, width - sliceWidth);

    return Positioned(
      left: (plot.xAt(index) - sliceWidth / 2).clamp(0.0, maxLeft),
      width: sliceWidth,
      top: 0,
      bottom: axisHeight,
      child: MouseRegion(
        key: Key('seriesOccurrence-${occurrence.id}'),
        onEnter: (_) => setState(() => _hovered = index),
        child: Semantics(label: label, child: const SizedBox.expand()),
      ),
    );
  }

  /// The charge's date (tabular) over its signed, colorized amount, and on the
  /// charge that stepped, the change in amber.
  TextSpan _tooltip(
    AppLocalizations l10n,
    String locale,
    TextTheme textTheme,
    SeriesOccurrence occurrence, {
    required bool isStep,
  }) => TextSpan(
    children: [
      TextSpan(
        text: '${seriesDateFormat(locale).format(occurrence.bookedDate)}\n',
        style: tabularNumberStyle(textTheme.labelSmall!),
      ),
      TextSpan(
        // Signed and colorized here, unlike the axis: the tooltip names the
        // transaction itself, money that actually left the account.
        text: formatAmount(
          amountMinor: occurrence.amountMinor,
          currency: occurrence.currency,
          locale: locale,
        ),
        style: tabularNumberStyle(textTheme.bodySmall!).copyWith(
          color: occurrence.amountMinor < 0
              ? context.colors.negative
              : context.colors.positive,
        ),
      ),
      if (isStep && series.previousAmountMinor != null)
        TextSpan(
          text:
              '\n${l10n.subscriptionDetailChange(_money(series.previousAmountMinor!, locale), _money(series.expectedAmountMinor, locale))}',
          style: tabularNumberStyle(
            textTheme.bodySmall!,
          ).copyWith(color: context.colors.warning),
        ),
    ],
  );

  String _money(int amountMinor, String locale) => formatAmount(
    amountMinor: amountMinor.abs(),
    currency: series.currency,
    locale: locale,
  );
}

/// How the date axis gives every charge its tick.
///
/// Flat ticks while each fits beside its neighbours; turned on end — one line
/// height wide instead of a whole date — when they don't; and when even that
/// is too tight, every Nth one, keeping the first and the last. A charge
/// without its date can't be checked at a glance, which is the card's job, so
/// thinning is the last resort rather than the rule.
@immutable
class _DateAxis {
  const _DateAxis({
    required this.widths,
    required this.lineHeight,
    required this.rotated,
    required this.height,
    this.shown,
  });

  factory _DateAxis.fit({
    required List<String> ticks,
    required TextStyle? style,
    required TextScaler textScaler,
    required TextDirection textDirection,
    required double plotLeft,
    required double plotRight,
    required double width,
  }) {
    final sizes = <Size>[];
    for (final tick in ticks) {
      final painter = TextPainter(
        text: TextSpan(text: tick, style: style),
        textDirection: textDirection,
        textScaler: textScaler,
        maxLines: 1,
      )..layout();
      sizes.add(painter.size);
      painter.dispose();
    }
    // Rounded up: a fractional glyph run must not spill out of its box.
    final widths = [for (final size in sizes) size.width.ceilToDouble()];
    final lineHeight = sizes
        .fold(0.0, (high, size) => math.max(high, size.height))
        .ceilToDouble();
    final widest = widths.fold(0.0, math.max);
    final xs = _xs(ticks.length, plotLeft, plotRight);

    final flat = _DateAxis(
      widths: widths,
      lineHeight: lineHeight,
      rotated: false,
      height: math.max(PriceHistoryChart._dateAxisHeight, lineHeight),
    );
    if (flat._fits(xs, width)) return flat;

    final upright = _DateAxis(
      widths: widths,
      lineHeight: lineHeight,
      rotated: true,
      height: widest,
    );
    if (upright._fits(xs, width)) return upright;

    // Even on end they collide: keep every Nth tick, with the smallest N that
    // clears, and always the first and the last so the history's span stays
    // dated. The thinned charges are still dated on hover.
    for (var step = 2; step < ticks.length; step++) {
      final thinned = _DateAxis(
        widths: widths,
        lineHeight: lineHeight,
        rotated: true,
        height: widest,
        shown: _everyNth(ticks.length, step),
      );
      if (thinned._fits(xs, width)) return thinned;
    }
    return _DateAxis(
      widths: widths,
      lineHeight: lineHeight,
      rotated: true,
      height: widest,
      shown: [0, if (ticks.length > 1) ticks.length - 1],
    );
  }

  /// `0, step, 2·step, …` and the last index — the regular tick nearest the
  /// end dropped when it would sit closer than [step] to the last one.
  static List<int> _everyNth(int count, int step) {
    final last = count - 1;
    return [
      for (var i = 0; i < last; i += step)
        if (i == 0 || last - i >= step) i,
      last,
    ];
  }

  /// Each tick's own width when it lies flat.
  final List<double> widths;

  /// The tallest tick's line height — a tick's width once it is turned.
  final double lineHeight;

  /// Whether the ticks are turned on end.
  final bool rotated;

  /// The band the ticks take beneath the plot.
  final double height;

  /// The charges that get a tick, by index — all of them unless the axis had
  /// to be thinned.
  final List<int>? shown;

  /// Whether the charge at [index] gets a tick.
  bool shows(int index) => shown?.contains(index) ?? true;

  double _width(int index) => rotated ? lineHeight : widths[index];

  /// Where the tick under charge [index], centred on [x], starts — clamped
  /// inside `[0, bound]`.
  double leftOf(int index, double x, double bound) {
    final width = _width(index);
    return (x - width / 2).clamp(0.0, math.max(0.0, bound - width));
  }

  /// The charges' x positions on a plot running from [left] to [right] — the
  /// same placement [_PlotGeometry.xAt] gives them.
  static List<double> _xs(int count, double left, double right) => [
    for (var i = 0; i < count; i++)
      count < 2
          ? (left + right) / 2
          : left + (right - left) * (i / (count - 1)),
  ];

  bool _fits(List<double> xs, double bound) {
    final indices = shown ?? [for (var i = 0; i < xs.length; i++) i];
    for (var k = 1; k < indices.length; k++) {
      final previous = indices[k - 1];
      final current = indices[k];
      final previousEnd =
          leftOf(previous, xs[previous], bound) + _width(previous);
      if (leftOf(current, xs[current], bound) - previousEnd <
          PriceHistoryChart._tickGap) {
        return false;
      }
    }
    return true;
  }
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

/// The step line itself, in the shared curve style ([AppChart]): the iris
/// stroke, area, gridlines and dots every line chart draws with, so the
/// subscription's history reads as one family with the rest.
///
/// Deliberately not animated, like every other chart here — the spec allows
/// only the spinner and skeleton keyframes.
class _PriceLinePainter extends CustomPainter {
  /// The active theme's colours.
  final AppColors colors;

  _PriceLinePainter({
    required this.colors,
    required this.plot,
    required this.stepIndex,
    required this.hovered,
  });

  final _PlotGeometry plot;
  final int? stepIndex;
  final int? hovered;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = plot.rect;

    if (plot.values.isEmpty) return;

    // One gridline per value tick: the cheapest and the dearest charge, or the
    // single price when it never moved (see
    // [_PriceHistoryChartState._valueLabels]).
    ChartPaints.grid(
      colors,
      canvas,
      size,
      rect,
      {plot.yAt(plot.maxValue), plot.yAt(plot.minValue)}.toList(),
    );

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

      canvas.drawPath(area, ChartPaints.area(colors.accent));
      canvas.drawPath(line, ChartPaints.stroke(colors.accent));
    }

    final last = points.length - 1;
    final step = stepIndex != null && stepIndex! < points.length
        ? stepIndex
        : null;

    // The charge the price stepped at gets a guide from plot top to bottom,
    // under the dots, in the same amber the increase banner and the list's pill
    // use — the one point on the line the user is being asked to look at.
    if (step != null) {
      canvas.drawLine(
        Offset(points[step].dx, rect.top),
        Offset(points[step].dx, rect.bottom),
        Paint()
          ..color = colors.warning.withValues(alpha: AppChart.changeGuideAlpha)
          ..strokeWidth = AppChart.gridStroke,
      );
    }

    for (var i = 0; i < points.length; i++) {
      final large = i == last || i == step || i == hovered;
      if (!large && points.length > AppChart.dotCeiling) continue;
      ChartPaints.dot(
        colors,
        canvas,
        points[i],
        large ? AppChart.currentDotRadius : AppChart.pointDotRadius,
        i == step ? colors.warning : colors.accent,
      );
    }
  }

  @override
  bool shouldRepaint(_PriceLinePainter oldDelegate) =>
      oldDelegate.colors != colors ||
      oldDelegate.plot != plot ||
      oldDelegate.stepIndex != stepIndex ||
      oldDelegate.hovered != hovered;
}
