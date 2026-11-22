import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// `intl` exports a `TextDirection` of its own; the painter needs Flutter's.
import 'package:intl/intl.dart' show DateFormat, NumberFormat;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/app_link.dart';
import '../../../core/widgets/app_segmented.dart';
import '../../../core/widgets/chart_scale.dart';
import '../../../core/widgets/chart_style.dart';
import '../../../core/widgets/chart_tooltip.dart';
import '../../../l10n/app_localizations.dart';
import '../application/networth_controller.dart';
import '../domain/networth_summary.dart';
import 'declared_balances_modal.dart';

/// « Patrimoine net » (`15-synthese.md` §3b): the closed-month series as a
/// line / area over the range picked on its heading line.
///
/// The chart must not look like it knows something it doesn't: a month the
/// API omitted is simply not drawn, and a month whose accounts total the user
/// declared is drawn dashed, never passed off as an imported figure. What is
/// held flat is said in « À savoir », not here.
class NetworthSeriesSection extends ConsumerWidget {
  const NetworthSeriesSection({super.key, required this.summary});

  final NetWorthSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final textTheme = Theme.of(context).textTheme;
    final colors = context.colors;
    final range = ref.watch(networthRangeProvider);
    final series = pointsInRange(summary.series, range);
    final hasDeclared = series.any((point) => point.declared);
    final monthFormat = DateFormat.yMMMM(locale);

    return Column(
      key: const Key('networthSeriesSection'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The heading line (`00` §7): the title, the range it shows, and the
        // segmented control on the right.
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(
            children: [
              Text(l10n.networthSeriesTitle, style: textTheme.titleSmall),
              if (series.isNotEmpty) ...[
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    l10n.networthSeriesRange(
                      monthFormat.format(series.first.month),
                      monthFormat.format(series.last.month),
                    ),
                    key: const Key('networthSeriesRange'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      color: colors.textTertiary,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              AppSegmented<NetworthRange>(
                key: const Key('networthRangeSwitch'),
                value: range,
                onChanged: ref.read(networthRangeProvider.notifier).set,
                // Widest first, so the segments read largest to smallest.
                segments: [
                  AppSegment(
                    key: const Key('networthRangeAll'),
                    value: NetworthRange.all,
                    label: l10n.networthRangeAll,
                  ),
                  AppSegment(
                    key: const Key('networthRangeThreeYears'),
                    value: NetworthRange.threeYears,
                    label: l10n.networthRangeThreeYears,
                  ),
                  AppSegment(
                    key: const Key('networthRangeYear'),
                    value: NetworthRange.year,
                    label: l10n.networthRangeYear,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          height: AppNetworth.chartHeight,
          child: series.isEmpty
              ? Center(
                  child: Text(
                    l10n.networthSeriesEmpty,
                    key: const Key('networthSeriesEmpty'),
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                )
              : NetworthSeriesPlot(
                  key: const Key('networthSeriesPlot'),
                  months: [for (final point in series) point.month],
                  values: [for (final point in series) point.netWorthMinor],
                  declared: [for (final point in series) point.declared],
                  currency: summary.currency,
                ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            if (hasDeclared) ...[
              _LegendEntry(
                key: const Key('networthLegendLedger'),
                label: l10n.networthLegendLedger,
                dashed: false,
              ),
              const SizedBox(width: AppSpacing.md),
              _LegendEntry(
                key: const Key('networthLegendDeclared'),
                label: l10n.networthLegendDeclared,
                dashed: true,
              ),
            ],
            const Spacer(),
            AppLink(
              key: const Key('networthDeclaredOpen'),
              label: l10n.networthDeclaredOpen,
              onTap: () =>
                  showDeclaredBalances(context, currency: summary.currency),
            ),
          ],
        ),
      ],
    );
  }
}

/// One legend item: a short `accent` stroke, solid or dashed, and its label
/// in 12 `textSecondary`.
class _LegendEntry extends StatelessWidget {
  const _LegendEntry({super.key, required this.label, required this.dashed});

  final String label;
  final bool dashed;

  /// The swatch: as long as a dash and a gap twice over, as thick as the line.
  static const _swatch = Size(
    (AppChart.dash + AppChart.dashGap) * 2,
    AppChart.lineStroke,
  );

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: _swatch,
          painter: _StrokeSwatchPainter(
            dashed: dashed,
            color: context.colors.accent,
          ),
        ),
        const SizedBox(width: AppSpacing.xsPlus),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: context.colors.textSecondary),
        ),
      ],
    );
  }
}

class _StrokeSwatchPainter extends CustomPainter {
  _StrokeSwatchPainter({required this.dashed, required this.color});

  final bool dashed;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height / 2)
      ..lineTo(size.width, size.height / 2);
    canvas.drawPath(
      dashed ? ChartPaints.dashed(path) : path,
      _seriesStroke(color),
    );
  }

  @override
  bool shouldRepaint(_StrokeSwatchPainter oldDelegate) =>
      oldDelegate.dashed != dashed || oldDelegate.color != color;
}

/// The series line's stroke, shared by the chart and its legend: the shared
/// curve stroke, butt-capped so a dash ends where the rhythm says.
Paint _seriesStroke(Color color) =>
    ChartPaints.stroke(color)..strokeCap = StrokeCap.butt;

/// The line / area itself (`00` §9, [AppChart]): a 2 px `accent` line over an
/// `accent` 10 % area, a small dot on each month (up to
/// [AppChart.dotCeiling]) and a full-size one on the last, y gridlines on clean
/// ticks around the series (see [ChartScale]), and month labels under the
/// points.
///
/// Points sit on the calendar, not on their index: a month the API omitted
/// leaves its slot empty, and the line breaks there rather than bridging it —
/// a segment across the gap would draw a value nobody measured. A segment
/// touching a declared month is dashed. Over a year, every point keeps its
/// label; past that, labels go to evenly spaced months so they never collide.
///
/// Hovering a month enlarges its point to the last month's dot and names its
/// net worth in a card placed clear of the line, as the account's « Évolution
/// du solde » does — see [LineChartTooltip].
class NetworthSeriesPlot extends StatefulWidget {
  const NetworthSeriesPlot({
    super.key,
    required this.months,
    required this.values,
    required this.currency,
    this.declared = const [],
  });

  /// First day of each month drawn, oldest first — exactly the API's months.
  final List<DateTime> months;

  /// Net worth per month, same length as [months].
  final List<int> values;

  /// Whether each month's accounts total was declared rather than imported;
  /// same length as [months], or empty when none is.
  final List<bool> declared;
  final String currency;

  @override
  State<NetworthSeriesPlot> createState() => _NetworthSeriesPlotState();
}

class _NetworthSeriesPlotState extends State<NetworthSeriesPlot> {
  /// The month under the pointer — hover ephemera, not chart state.
  int? _hovered;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final textTheme = Theme.of(context).textTheme;
    final labelStyle = ChartPaints.painted(
      context,
      ChartPaints.labelStyle(context),
    );
    final months = widget.months;
    final values = widget.values;

    final painter = RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: _SeriesPainter(
          colors: context.colors,
          months: months,
          values: values,
          declared: widget.declared,
          hovered: _hovered,
          monthLabel: DateFormat.MMM(locale).format,
          // Past a year the month alone is ambiguous: « janv. 24 ».
          longMonthLabel: DateFormat('MMM yy', locale).format,
          valueLabel: (minor) => NumberFormat.compactSimpleCurrency(
            locale: locale,
            name: widget.currency,
          ).format(minor / 100).replaceAll('-', '−'),
          labelStyle: labelStyle,
        ),
      ),
    );

    // Built from flex weights rather than measured: the Synthèse lays this card
    // out by its intrinsic size, which a LayoutBuilder cannot report.
    return Stack(
      fit: StackFit.expand,
      children: [
        painter,
        Column(
          children: [
            Expanded(
              child: MouseRegion(
                onExit: (_) => setState(() => _hovered = null),
                child: Row(
                  children: [
                    const SizedBox(width: AppChart.valueGutter),
                    for (final (i, flex) in _bandFlexes(months).indexed)
                      Expanded(
                        flex: flex,
                        child: MouseRegion(
                          key: Key('networthSeriesSlot-$i'),
                          onEnter: (_) => setState(() => _hovered = i),
                          // The card only exists while a pointer hovers, so a
                          // screen reader gets the month's figure on its band.
                          child: Semantics(
                            label: _tooltip(
                              i,
                              l10n,
                              locale,
                              textTheme,
                            ).toPlainText(),
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ),
                    const SizedBox(width: AppChart.dotReach),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppChart.axisHeight),
          ],
        ),
        if (_hovered case final hovered? when hovered < values.length)
          LineChartTooltip(
            cardKey: const Key('networthSeriesTooltip'),
            message: _tooltip(hovered, l10n, locale, textTheme),
            points: (size) => _seriesPoints(size, months, values),
            hovered: hovered,
            // The hovered dot, ring included.
            pointRadius: AppChart.dotReach,
            joinsNext: (i) =>
                _SeriesPainter._index(months[i + 1]) -
                    _SeriesPainter._index(months[i]) ==
                1,
            leftBound: AppChart.valueGutter,
            bottomInset: AppChart.axisHeight,
          ),
      ],
    );
  }

  /// The month and its net worth — neutral, like every net-worth figure — and,
  /// for a declared month, that it was declared: the dash alone is easy to miss
  /// on a single point.
  TextSpan _tooltip(
    int i,
    AppLocalizations l10n,
    String locale,
    TextTheme textTheme,
  ) {
    final month = DateFormat.yMMMM(locale).format(widget.months[i]);
    return TextSpan(
      children: [
        TextSpan(
          text: '${_capitalize(month)}\n',
          style: tabularNumberStyle(textTheme.labelSmall!),
        ),
        TextSpan(
          text: formatAmount(
            amountMinor: widget.values[i],
            currency: widget.currency,
            locale: locale,
          ),
          style: tabularNumberStyle(textTheme.bodySmall!),
        ),
        if (i < widget.declared.length && widget.declared[i])
          TextSpan(
            text: '\n${l10n.networthLegendDeclared}',
            style: textTheme.labelSmall,
          ),
      ],
    );
  }
}

/// The width of each month's hover band, in half-months: a band reaches halfway
/// to its neighbour on either side, so it covers exactly the stretch of line
/// nearer its point than any other — the dot is a few pixels wide, but the thing
/// worth hovering is the month. Whole numbers, so they can be flex weights.
List<int> _bandFlexes(List<DateTime> months) {
  int index(DateTime month) => _SeriesPainter._index(month);
  if (months.length < 2) return [for (final _ in months) 1];
  return [
    for (var i = 0; i < months.length; i++)
      (i == months.length - 1 ? index(months[i]) : index(months[i + 1])) -
          (i == 0 ? index(months[i]) : index(months[i - 1])),
  ];
}

/// Where the plot sits in the chart's box: right of the value gutter, above the
/// month axis, inset by the last month's dot. Shared by the painter and the
/// tooltip, so the card can't drift off the point it names.
Rect _plotRect(Size size) => Rect.fromLTRB(
  AppChart.valueGutter,
  AppChart.dotReach,
  size.width - AppChart.dotReach,
  size.height - AppChart.axisHeight,
);

/// The series' scale: past the highest and lowest months to clean ticks, so
/// neither the peak nor the trough lies on the plot's edge. Same scale as the
/// account balance chart; minor units, so no tick on cents.
ChartScale _seriesScale(List<int> values) =>
    ChartScale.of(values, intervals: 2, minStep: 100);

/// Each month's point in a chart of [size]: on the calendar, not on its index.
List<Offset> _seriesPoints(Size size, List<DateTime> months, List<int> values) {
  final plot = _plotRect(size);
  final scale = _seriesScale(values);
  final first = _SeriesPainter._index(months.first);
  final span = _SeriesPainter._index(months.last) - first;
  return [
    for (var i = 0; i < values.length; i++)
      Offset(
        span == 0
            ? plot.center.dx
            : plot.left +
                  plot.width *
                      ((_SeriesPainter._index(months[i]) - first) / span),
        scale.y(values[i], plot),
      ),
  ];
}

String _capitalize(String value) =>
    value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);

class _SeriesPainter extends CustomPainter {
  /// The active theme's colours.
  final AppColors colors;

  _SeriesPainter({
    required this.colors,
    required this.months,
    required this.values,
    required this.declared,
    required this.hovered,
    required this.monthLabel,
    required this.longMonthLabel,
    required this.valueLabel,
    required this.labelStyle,
  });

  final List<DateTime> months;
  final List<int> values;
  final List<bool> declared;
  final int? hovered;
  final String Function(DateTime) monthLabel;
  final String Function(DateTime) longMonthLabel;
  final String Function(int) valueLabel;
  final TextStyle labelStyle;

  static const _maxLabels = 12;

  static int _index(DateTime month) => month.year * 12 + month.month - 1;

  TextPainter _text(String text) => TextPainter(
    text: TextSpan(text: text, style: labelStyle),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final plot = _plotRect(size);
    if (plot.width <= 0 || plot.height <= 0) return;

    final scale = _seriesScale(values);

    // Gridlines at floor / mid / ceiling, labelled in the gutter.
    ChartPaints.grid(
      colors,
      canvas,
      size,
      plot,
      [for (final level in scale.ticks) scale.y(level, plot)],
      labels: [for (final level in scale.ticks) valueLabel(level.round())],
      style: labelStyle,
    );

    final first = _index(months.first);
    final span = _index(months.last) - first;
    double x(DateTime month) => span == 0
        ? plot.center.dx
        : plot.left + plot.width * ((_index(month) - first) / span);

    final points = _seriesPoints(size, months, values);

    // Contiguous runs of months: the line and its area break at every gap.
    final runs = <List<Offset>>[];
    for (var i = 0; i < points.length; i++) {
      final continues = i > 0 && _index(months[i]) - _index(months[i - 1]) == 1;
      if (continues) {
        runs.last.add(points[i]);
      } else {
        runs.add([points[i]]);
      }
    }

    final area = ChartPaints.area(colors.accent);
    for (final run in runs.where((run) => run.length > 1)) {
      final path = Path()..addPolygon(run, false);
      canvas.drawPath(
        Path.from(path)
          ..lineTo(run.last.dx, plot.bottom)
          ..lineTo(run.first.dx, plot.bottom)
          ..close(),
        area,
      );
    }
    // Segment by segment, so the dashing follows each month's source.
    final solid = Path();
    final dashed = Path();
    for (var i = 1; i < points.length; i++) {
      if (_index(months[i]) - _index(months[i - 1]) != 1) continue;
      final segment = Path()
        ..moveTo(points[i - 1].dx, points[i - 1].dy)
        ..lineTo(points[i].dx, points[i].dy);
      if (_isDeclared(i - 1) || _isDeclared(i)) {
        dashed.addPath(ChartPaints.dashed(segment), Offset.zero);
      } else {
        solid.addPath(segment, Offset.zero);
      }
    }
    canvas.drawPath(solid, ChartPaints.stroke(colors.accent));
    canvas.drawPath(dashed, _seriesStroke(colors.accent));

    // A small dot on every month while they stay few — a lone month between
    // two gaps has no segment, so its dot is all that draws it — and the last
    // month's and the hovered one's at full size.
    final last = points.length - 1;
    for (var i = 0; i < points.length; i++) {
      final large = i == last || i == hovered;
      if (!large && points.length > AppChart.dotCeiling) continue;
      ChartPaints.dot(
        colors,
        canvas,
        points[i],
        large ? AppChart.currentDotRadius : AppChart.pointDotRadius,
        colors.accent,
      );
    }

    // Up to a year: a month label under each point drawn, none under an
    // omitted month. Longer: a label every `stride` calendar months from the
    // first, data or not, so the axis keeps an even rhythm.
    if (span < _maxLabels) {
      for (var i = 0; i < points.length; i++) {
        _paintLabel(canvas, monthLabel(months[i]), points[i].dx, plot.bottom);
      }
    } else {
      final stride = (span / (_maxLabels - 1)).ceil();
      for (var offset = 0; offset <= span; offset += stride) {
        final month = DateTime(months.first.year, months.first.month + offset);
        _paintLabel(canvas, longMonthLabel(month), x(month), plot.bottom);
      }
    }
  }

  bool _isDeclared(int i) => i < declared.length && declared[i];

  void _paintLabel(Canvas canvas, String text, double centerX, double top) {
    final label = _text(text);
    label.paint(canvas, Offset(centerX - label.width / 2, top + 6));
  }

  @override
  bool shouldRepaint(_SeriesPainter oldDelegate) =>
      oldDelegate.colors != colors ||
      !listEquals(oldDelegate.months, months) ||
      !listEquals(oldDelegate.values, values) ||
      !listEquals(oldDelegate.declared, declared) ||
      oldDelegate.hovered != hovered ||
      oldDelegate.labelStyle != labelStyle;
}
