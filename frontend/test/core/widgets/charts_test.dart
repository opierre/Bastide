import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/core/theme/tokens.dart';
import 'package:bastide/core/widgets/bar_charts.dart';
import 'package:bastide/core/widgets/chart_container.dart';
import 'package:bastide/core/widgets/chart_frame.dart';
import 'package:bastide/core/widgets/chart_scale.dart';
import 'package:bastide/core/widgets/chart_style.dart';
import 'package:bastide/core/widgets/line_area_chart.dart';
import 'package:bastide/core/widgets/step_line_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'host.dart';

const dark = AppColors.dark;
const months = ['janv.', 'févr.', 'mars', 'avr.'];

Widget sized(Widget chart) => SizedBox(width: 480, height: 240, child: chart);

String euros(num v) => '${v ~/ 100} €';

/// The frame's five gridlines (four intervals), in `line`.
PaintPattern gridlines() => paints
  ..line(color: dark.line)
  ..line(color: dark.line)
  ..line(color: dark.line)
  ..line(color: dark.line)
  ..line(color: dark.line);

/// A plot 100 px tall over [width], on a 0–100 scale.
ChartGeometry geometry({required double width, required int count}) =>
    ChartGeometry(
      plot: Rect.fromLTWH(0, 0, width, 100),
      scale: ChartScale.of(const [0, 100], intervals: 4),
      count: count,
    );

/// The chart's own painter: the [CustomPaint] under its [RepaintBoundary].
Finder plotOf(Type chart) => find
    .descendant(of: find.byType(chart), matching: find.byType(CustomPaint))
    .first;

void main() {
  group('SignedBarChart', () {
    testWidgets('positive bars in positive, negative in negative, a solid '
        'lineStrong zero line between them', (tester) async {
      await pumpHost(
        tester,
        sized(
          const SignedBarChart(
            values: [12000, -4000, 8000, 3000],
            labels: months,
            minStep: 100,
            valueLabel: euros,
          ),
        ),
      );
      // The axis fits the bars (−56 € to 136 €), so its gridlines are the
      // four 50 € multiples inside it, zero among them.
      expect(
        plotOf(SignedBarChart),
        paints
          ..line(color: dark.line)
          ..line(color: dark.line)
          ..line(color: dark.line)
          ..line(color: dark.line)
          ..line(color: dark.lineStrong, strokeWidth: 1)
          ..rrect(color: dark.positive)
          ..rrect(color: dark.negative)
          ..rrect(color: dark.positive)
          ..rrect(color: dark.positive),
      );
      for (final label in months) {
        expect(find.text(label), findsOneWidget);
      }
    });

    test('a bar is at most 18 px wide, centred in its period', () {
      final g = geometry(width: 400, count: 2);
      final bar = SignedBarChart.barRect(g, 1, 50);
      expect(bar.width, AppChart.barMaxWidth);
      expect(bar.center.dx, 300);
      expect(bar.bottom, g.y(0));
      // A narrow period gives its bar 60 % of its width.
      expect(
        SignedBarChart.barRect(geometry(width: 100, count: 10), 0, 50).width,
        closeTo(6, 1e-9),
      );
    });

    testWidgets('a provisional period is hatched in its own colour', (
      tester,
    ) async {
      await pumpHost(
        tester,
        sized(
          const SignedBarChart(
            values: [12000, 3000],
            labels: ['avr.', 'mai'],
            provisional: {1},
            minStep: 100,
          ),
        ),
      );
      expect(
        plotOf(SignedBarChart),
        paints
          ..rrect(color: dark.positive)
          // Hatch lines, 1.5 px, then the 1 px outline.
          ..line(color: dark.positive, strokeWidth: AppChart.hatchStroke)
          ..path(color: dark.positive, strokeWidth: AppChart.hatchOutline),
      );
    });

    testWidgets('hovering a period shows its card at once', (tester) async {
      await pumpHost(
        tester,
        sized(
          const SignedBarChart(
            values: [12000, -4000],
            labels: ['avr.', 'mai'],
            tooltips: [
              TextSpan(text: 'avr. +120 €'),
              TextSpan(text: 'mai −40 €'),
            ],
          ),
        ),
      );
      expect(find.byKey(const Key('signedBarTooltip')), findsNothing);
      await hover(tester, find.byKey(const Key('signedBarSlot-1')));
      expect(find.byKey(const Key('signedBarTooltip')), findsOneWidget);
      expect(find.text('mai −40 €'), findsOneWidget);
    });
  });

  group('StackedBarChart', () {
    testWidgets('capital in accent below, interest in textTertiary above', (
      tester,
    ) async {
      await pumpHost(
        tester,
        sized(
          const StackedBarChart(
            base: [80000, 82000],
            top: [20000, 18000],
            labels: ['2026', '2027'],
            minStep: 100,
          ),
        ),
      );
      expect(
        plotOf(StackedBarChart),
        paints
          ..rrect(color: dark.accent)
          ..rrect(color: dark.textTertiary)
          ..rrect(color: dark.accent)
          ..rrect(color: dark.textTertiary),
      );
    });

    test('the two segments sit 2 px apart', () {
      final (lower, upper) = StackedBarChart.segments(
        geometry(width: 400, count: 2),
        0,
        60,
        30,
      );
      expect(lower.top - upper.bottom, AppChart.stackGap);
    });
  });

  group('StepLineChart', () {
    testWidgets('an accent step line over its area; a change takes a warning '
        'guide and dot', (tester) async {
      await pumpHost(
        tester,
        sized(
          const StepLineChart(values: [999, 999, 1199, 1199], labels: months),
        ),
      );
      final guide = dark.warning.withValues(alpha: AppChart.changeGuideAlpha);
      expect(
        plotOf(StepLineChart),
        gridlines()
          ..line(color: guide, strokeWidth: 1)
          ..path(color: dark.accent.withValues(alpha: AppChart.areaAlpha))
          ..path(color: dark.accent, strokeWidth: AppChart.lineStroke)
          // Each dot sits on a bg ring.
          ..circle(color: dark.bg)
          ..circle(color: dark.accent, radius: AppChart.pointDotRadius)
          ..circle(color: dark.bg)
          ..circle(color: dark.accent, radius: AppChart.pointDotRadius)
          ..circle(color: dark.bg)
          ..circle(color: dark.warning, radius: AppChart.pointDotRadius),
      );
      expect(StepLineChart.changes(const [999, 999, 1199, 1199]), [2]);
    });

    testWidgets('a second series is a 1.5 px textTertiary step line', (
      tester,
    ) async {
      await pumpHost(
        tester,
        sized(
          const StepLineChart(
            values: [100, 120, 140, 150],
            secondValues: [100, 110, 120, 130],
            labels: months,
          ),
        ),
      );
      expect(
        plotOf(StepLineChart),
        paints..path(
          color: dark.textTertiary,
          strokeWidth: AppChart.secondLineStroke,
        ),
      );
    });
  });

  group('LineAreaChart', () {
    testWidgets('an accent line over its 10 % area, a dot per point and a '
        'larger one on the last', (tester) async {
      await pumpHost(
        tester,
        sized(
          const LineAreaChart(values: [100, 120, 110, 150], labels: months),
        ),
      );
      expect(
        plotOf(LineAreaChart),
        gridlines()
          ..path(color: dark.accent.withValues(alpha: AppChart.areaAlpha))
          ..path(color: dark.accent, strokeWidth: AppChart.lineStroke)
          ..circle(color: dark.bg)
          ..circle(color: dark.accent, radius: AppChart.pointDotRadius)
          ..circle(color: dark.bg)
          ..circle(color: dark.accent, radius: AppChart.pointDotRadius)
          ..circle(color: dark.bg)
          ..circle(color: dark.accent, radius: AppChart.pointDotRadius)
          ..circle(color: dark.bg)
          ..circle(color: dark.accent, radius: AppChart.currentDotRadius),
      );
      expect(
        plotOf(LineAreaChart),
        isNot(paints..line(color: dark.lineStrong)),
      );
    });

    testWidgets('a series crossing zero draws the zero line and a negative '
        'area under it', (tester) async {
      await pumpHost(
        tester,
        sized(
          const LineAreaChart(
            values: [12000, -4000, 8000, 3000],
            labels: months,
          ),
        ),
      );
      expect(LineAreaChart.crossesZero(const [1, -1]), isTrue);
      expect(LineAreaChart.crossesZero(const [1, 2]), isFalse);
      expect(
        plotOf(LineAreaChart),
        gridlines()
          ..line(color: dark.lineStrong, strokeWidth: 1)
          ..path(color: dark.accent.withValues(alpha: AppChart.areaAlpha))
          ..path(
            color: dark.negative.withValues(alpha: AppChart.negativeAreaAlpha),
          )
          ..path(color: dark.accent, strokeWidth: AppChart.lineStroke),
      );
    });

    testWidgets('past 24 points only the last keeps its dot', (tester) async {
      await pumpHost(
        tester,
        sized(
          LineAreaChart(
            values: [for (var i = 0; i < 30; i++) i * 10],
            labels: [for (var i = 0; i < 30; i++) ''],
          ),
        ),
      );
      expect(
        plotOf(LineAreaChart),
        isNot(
          paints..circle(color: dark.accent, radius: AppChart.pointDotRadius),
        ),
      );
    });
  });

  testWidgets('a chart section has a heading and no box', (tester) async {
    await pumpHost(
      tester,
      sized(
        const ChartContainer(
          title: 'Épargne mensuelle',
          trailing: Text('Légende'),
          child: SizedBox.expand(),
        ),
      ),
    );
    expect(find.text('Épargne mensuelle'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ChartContainer),
        matching: find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration! as BoxDecoration).border != null,
        ),
      ),
      findsNothing,
    );
  });

  testWidgets('hatching sweeps the region in 45° lines', (tester) async {
    await pumpHost(
      tester,
      CustomPaint(
        key: const Key('hatch'),
        size: const Size(20, 20),
        painter: _HatchProbe(dark.accent),
      ),
    );
    expect(
      find.byKey(const Key('hatch')),
      paints
        ..line(
          p1: const Offset(-20, 20),
          p2: const Offset(0, 0),
          color: dark.accent,
        )
        ..line(p1: const Offset(-15, 20), p2: const Offset(5, 0)),
    );
  });

  testWidgets('charts follow the light theme', (tester) async {
    await pumpHost(
      tester,
      sized(const SignedBarChart(values: [100, -50], labels: ['a', 'b'])),
      theme: AppTheme.light,
    );
    expect(
      plotOf(SignedBarChart),
      paints
        ..rrect(color: AppColors.light.positive)
        ..rrect(color: AppColors.light.negative),
    );
  });
}

class _HatchProbe extends CustomPainter {
  const _HatchProbe(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) =>
      ChartPaints.hatch(canvas, Path()..addRect(Offset.zero & size), color);

  @override
  bool shouldRepaint(_HatchProbe oldDelegate) => false;
}
