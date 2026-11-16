import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// `intl` exports a `TextDirection` of its own; the painter needs Flutter's.
import 'package:intl/intl.dart' show DateFormat, NumberFormat;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_segmented.dart';
import '../../../core/widgets/chart_scale.dart';
import '../../../core/widgets/chart_style.dart';
import '../../../core/widgets/chart_tooltip.dart';
import '../../../core/widgets/date_field.dart';
import '../../../l10n/app_localizations.dart';
import '../application/networth_controller.dart';
import '../domain/networth_summary.dart';
import 'declared_balances_modal.dart';
import 'networth_summary_card.dart';

/// « Patrimoine net » (`15-synthese.md` §Row 2): the closed-month series as an
/// AreaLine over the range picked in its header, carrying its caveat inline.
///
/// The chart must not look like it knows something it doesn't: a property has
/// one declared value, so the banner says values are held flat and names the
/// oldest estimate; a month the API omitted is simply not drawn; and a month
/// whose accounts total the user declared is drawn dashed, never passed off as
/// an imported figure.
class NetworthSeriesCard extends ConsumerWidget {
  const NetworthSeriesCard({super.key, required this.summary});

  final NetWorthSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final textTheme = Theme.of(context).textTheme;
    final range = ref.watch(networthRangeProvider);
    final series = pointsInRange(summary.series, range);
    final hasDeclared = series.any((point) => point.declared);
    final monthFormat = networthMonthFormat(locale);
    final oldest = summary.valuedOnOldest;

    return AppCard(
      key: const Key('networthSeriesCard'),
      padding: const EdgeInsets.symmetric(
        horizontal: 22,
        vertical: AppSpacing.cardPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.networthSeriesTitle,
                      style: textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.networthSeriesSubtitle,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // The range caption is centred on the switch it describes,
              // not top-aligned with the title column beside them.
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (series.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(
                        right: AppSpacing.sm + AppSpacing.xs,
                      ),
                      child: Text(
                        l10n.networthSeriesRange(
                          monthFormat.format(series.first.month),
                          monthFormat.format(series.last.month),
                        ),
                        key: const Key('networthSeriesRange'),
                        style: AppTextStyles.helper,
                      ),
                    ),
                  SizedBox(
                    width: 216,
                    child: AppSegmented<NetworthRange>(
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
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: series.isEmpty
                ? Center(
                    child: Text(
                      l10n.networthSeriesEmpty,
                      key: const Key('networthSeriesEmpty'),
                      textAlign: TextAlign.center,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
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
              TextButton(
                key: const Key('networthDeclaredOpen'),
                onPressed: () =>
                    showDeclaredBalances(context, currency: summary.currency),
                child: Text(l10n.networthDeclaredOpen),
              ),
            ],
          ),
          if (summary.propertyValuesHeldFlat && oldest != null) ...[
            const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
            _CaveatBanner(
              message: l10n.networthSeriesCaveat(
                appDateFormat(locale).format(oldest),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The info InlineBanner under the chart: blue at 9 % with a 30 % border and
/// the info glyph, its text in the primary ink (`15-synthese.md` §Row 2) — a
/// statement about the data, not an alert.
class _CaveatBanner extends StatelessWidget {
  const _CaveatBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('networthSeriesCaveat'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + AppSpacing.xs,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 15,
            color: AppColors.info,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              key: const Key('networthSeriesCaveatText'),
              style: AppTextStyles.helper.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One legend item: a short iris stroke, solid or dashed, and its label.
class _LegendEntry extends StatelessWidget {
  const _LegendEntry({super.key, required this.label, required this.dashed});

  final String label;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: const Size(18, 2),
          painter: _StrokeSwatchPainter(dashed: dashed),
        ),
        const SizedBox(width: AppSpacing.xs + 2),
        Text(label, style: AppTextStyles.helper),
      ],
    );
  }
}

class _StrokeSwatchPainter extends CustomPainter {
  _StrokeSwatchPainter({required this.dashed});

  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height / 2)
      ..lineTo(size.width, size.height / 2);
    canvas.drawPath(dashed ? ChartPaints.dashed(path) : path, _seriesStroke());
  }

  @override
  bool shouldRepaint(_StrokeSwatchPainter oldDelegate) =>
      oldDelegate.dashed != dashed;
}

/// The series line's stroke, shared by the chart and its legend: the shared
/// curve stroke, butt-capped so a dash ends where the rhythm says.
Paint _seriesStroke() =>
    ChartPaints.stroke(AppColors.iris)..strokeCap = StrokeCap.butt;

/// The AreaLine itself, in the shared curve style ([AppChart]): an iris 2.5 px
/// line over a 16 % iris area, a small dot on each month (up to
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
    final labelStyle = ChartPaints.labelStyle(textTheme);
    final months = widget.months;
    final values = widget.values;

    final painter = RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: _SeriesPainter(
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
  _SeriesPainter({
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

    final area = ChartPaints.area(AppColors.iris);
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
    canvas.drawPath(solid, ChartPaints.stroke(AppColors.iris));
    canvas.drawPath(dashed, _seriesStroke());

    // A small dot on every month while they stay few — a lone month between
    // two gaps has no segment, so its dot is all that draws it — and the last
    // month's and the hovered one's at full size.
    final last = points.length - 1;
    for (var i = 0; i < points.length; i++) {
      final large = i == last || i == hovered;
      if (!large && points.length > AppChart.dotCeiling) continue;
      ChartPaints.dot(
        canvas,
        points[i],
        large ? AppChart.currentDotRadius : AppChart.pointDotRadius,
        AppColors.iris,
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
      !listEquals(oldDelegate.months, months) ||
      !listEquals(oldDelegate.values, values) ||
      !listEquals(oldDelegate.declared, declared) ||
      oldDelegate.hovered != hovered ||
      oldDelegate.labelStyle != labelStyle;
}
