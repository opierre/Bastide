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
    canvas.drawPath(dashed ? dashPath(path) : path, _seriesStroke());
  }

  @override
  bool shouldRepaint(_StrokeSwatchPainter oldDelegate) =>
      oldDelegate.dashed != dashed;
}

/// The series line's stroke, shared by the chart and its legend.
Paint _seriesStroke() => Paint()
  ..color = AppColors.iris
  ..style = PaintingStyle.stroke
  ..strokeWidth = 2
  ..strokeJoin = StrokeJoin.round
  ..strokeCap = StrokeCap.butt;

/// [source] cut into 5 px dashes with 4 px gaps — the dash rhythm of
/// `DashedBorder`, so every dashed line in the app reads the same.
Path dashPath(Path source, {double dash = 5, double gap = 4}) {
  final dashed = Path();
  for (final metric in source.computeMetrics()) {
    for (var start = 0.0; start < metric.length; start += dash + gap) {
      dashed.addPath(metric.extractPath(start, start + dash), Offset.zero);
    }
  }
  return dashed;
}

/// The AreaLine itself: an iris 2 px line over a 10 % iris area, 2.5 px ring
/// dots and a 4 px one on the last month, y gridlines at min / mid / max, and
/// month labels under the points.
///
/// Points sit on the calendar, not on their index: a month the API omitted
/// leaves its slot empty, and the line breaks there rather than bridging it —
/// a segment across the gap would draw a value nobody measured. A segment
/// touching a declared month is dashed. Over a year, every point keeps its
/// label; past that, labels go to evenly spaced months so they never collide.
///
/// Hovering a month rings its point and names its net worth, as the dashboard's
/// « Évolution de l'épargne » does.
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
    final labelStyle = tabularNumberStyle(
      textTheme.labelSmall!,
    ).copyWith(fontWeight: FontWeight.w400, color: AppColors.textSecondary);
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
              child: Row(
                children: [
                  const SizedBox(width: _SeriesPainter._gutter),
                  for (final (i, flex) in _bandFlexes(months).indexed)
                    Expanded(
                      flex: flex,
                      child: MouseRegion(
                        onEnter: (_) => setState(() => _hovered = i),
                        onExit: (_) => setState(() {
                          if (_hovered == i) _hovered = null;
                        }),
                        child: Tooltip(
                          key: Key('networthSeriesTooltip-$i'),
                          richMessage: _tooltip(i, l10n, locale, textTheme),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                  const SizedBox(width: _SeriesPainter._lastDot),
                ],
              ),
            ),
            const SizedBox(height: _SeriesPainter._axis),
          ],
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

  static const _gutter = 56.0;
  static const _axis = 22.0;
  static const _dot = 2.5;
  static const _maxLabels = 12;
  static const _lastDot = 4.0;
  static const _areaAlpha = 0.10;

  /// How far below the lowest month the scale starts, as a share of the
  /// series' range.
  static const _floorHeadroom = 0.12;

  static int _index(DateTime month) => month.year * 12 + month.month - 1;

  TextPainter _text(String text) => TextPainter(
    text: TextSpan(text: text, style: labelStyle),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final plot = Rect.fromLTRB(
      _gutter,
      _lastDot,
      size.width - _lastDot,
      size.height - _axis,
    );
    if (plot.width <= 0 || plot.height <= 0) return;

    final lowest = values.reduce((a, b) => a < b ? a : b);
    final high = values.reduce((a, b) => a > b ? a : b);
    // The scale's floor sits below the lowest month, so that point keeps some
    // air under it instead of lying on the plot's bottom edge.
    final low = lowest - ((high - lowest) * _floorHeadroom).round();
    final range = (high - low).toDouble();

    double y(num value) => range == 0
        ? plot.center.dy
        : plot.bottom - plot.height * ((value - low) / range);

    // Gridlines at min / mid / max, labelled in the gutter.
    final grid = Paint()
      ..color = AppColors.borderSubtle
      ..strokeWidth = 1;
    final levels = range == 0 ? [low] : [low, (low + high) ~/ 2, high];
    for (final level in levels) {
      final lineY = y(level);
      canvas.drawLine(
        Offset(plot.left, lineY),
        Offset(size.width, lineY),
        grid,
      );
      final label = _text(valueLabel(level));
      label.paint(
        canvas,
        Offset(
          plot.left - AppSpacing.sm - label.width,
          lineY - label.height / 2,
        ),
      );
    }

    final first = _index(months.first);
    final span = _index(months.last) - first;
    double x(DateTime month) => span == 0
        ? plot.center.dx
        : plot.left + plot.width * ((_index(month) - first) / span);

    final points = [
      for (var i = 0; i < values.length; i++)
        Offset(x(months[i]), y(values[i])),
    ];

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

    final area = Paint()..color = AppColors.iris.withValues(alpha: _areaAlpha);
    final line = _seriesStroke()..strokeCap = StrokeCap.round;
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
        dashed.addPath(dashPath(segment), Offset.zero);
      } else {
        solid.addPath(segment, Offset.zero);
      }
    }
    canvas.drawPath(solid, line);
    canvas.drawPath(dashed, _seriesStroke());

    // Ring dots on the card's surface; the last month's and the hovered one's
    // are larger.
    final ring = Paint()
      ..color = AppColors.iris
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final hole = Paint()..color = AppColors.surfaceRaised;
    for (var i = 0; i < points.length; i++) {
      final radius = i == points.length - 1 || i == hovered ? _lastDot : _dot;
      canvas.drawCircle(points[i], radius, hole);
      canvas.drawCircle(points[i], radius, ring);
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
