import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/core/theme/tokens.dart';
import 'package:bastide/core/widgets/repere_meter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'host.dart';

const dark = AppColors.dark;

Widget meter({
  double fraction = 0.4,
  RepereTone tone = RepereTone.normal,
  double? mark,
  String? label,
}) => SizedBox(
  width: 200,
  child: RepereMeter(
    fraction: fraction,
    tone: tone,
    markFraction: mark,
    markLabel: label,
  ),
);

/// The painted track, read off its painter's paint calls.
Rect trackOf(WidgetTester tester) =>
    tester.getRect(find.byKey(const Key('repereTrack')));

void main() {
  testWidgets('a meter without a mark is the 4 px track alone', (tester) async {
    await pumpHost(tester, meter());
    expect(trackOf(tester).height, RepereMeter.trackHeight);
    expect(tester.getSize(find.byType(RepereMeter)).height, 4);
  });

  testWidgets('each tone fills in its own colour', (tester) async {
    final expected = {
      RepereTone.normal: dark.accent,
      RepereTone.over: dark.warning,
      RepereTone.done: dark.positive,
      RepereTone.muted: dark.textTertiary,
    };
    for (final MapEntry(key: tone, value: colour) in expected.entries) {
      await pumpHost(tester, meter(tone: tone));
      final painter = find.byKey(const Key('repereTrack'));
      expect(
        painter,
        paints
          ..rrect(color: dark.lineStrong)
          ..rrect(color: colour),
        reason: '$tone',
      );
    }
  });

  testWidgets('the fill is drawn to the value and clamps at the track end', (
    tester,
  ) async {
    await pumpHost(tester, meter(fraction: 0.25));
    var painter = find.byKey(const Key('repereTrack'));
    expect(
      painter,
      paints
        ..rrect()
        ..rrect(
          rrect: RRect.fromRectAndRadius(
            const Rect.fromLTWH(0, 0, 50, 4),
            const Radius.circular(AppRadii.bar),
          ),
        ),
    );

    await pumpHost(tester, meter(fraction: 1.6));
    await tester.pumpAndSettle();
    painter = find.byKey(const Key('repereTrack'));
    expect(
      painter,
      paints
        ..rrect()
        ..rrect(
          rrect: RRect.fromRectAndRadius(
            const Rect.fromLTWH(0, 0, 200, 4),
            const Radius.circular(AppRadii.bar),
          ),
        ),
    );
  });

  testWidgets('a mark is a 2 × 12 text bar with its label above, the meter '
      'reserving 18 px over the track', (tester) async {
    await pumpHost(tester, meter(mark: 0.5, label: 'repère HCSF 35 %'));
    final painter = find.byKey(const Key('repereTrack'));
    expect(
      painter,
      paints
        ..rrect()
        ..rrect()
        ..rect(
          rect: Rect.fromCenter(
            center: const Offset(100, 6),
            width: 2,
            height: 12,
          ),
          color: dark.text,
        ),
    );

    final meterTop = tester.getTopLeft(find.byType(RepereMeter)).dy;
    final band = trackOf(tester);
    // The track sits 18 px down; the 12 px mark band is centred on it.
    expect(band.top + (12 - 4) / 2 - meterTop, RepereMeter.markReserve);

    final label = tester.getRect(find.byKey(const Key('repereMarkLabel')));
    final left = tester.getTopLeft(find.byType(RepereMeter)).dx;
    expect(label.center.dx - left, closeTo(100, 0.5));
    expect(band.top + 4 - label.bottom, closeTo(5, 0.01));
    final style = tester.widget<Text>(find.text('repère HCSF 35 %')).style!;
    expect(style.fontSize, 11);
    expect(style.color, dark.textSecondary);
  });

  testWidgets('a label near the end stays inside the meter', (tester) async {
    await pumpHost(tester, meter(mark: 1, label: 'objectif 20 %'));
    final label = tester.getRect(find.byKey(const Key('repereMarkLabel')));
    expect(
      label.right,
      lessThanOrEqualTo(tester.getRect(find.byType(RepereMeter)).right),
    );
  });

  /// The fill's width as painted now.
  PaintPattern fillOf(double width, {double top = 0}) => paints
    ..rrect()
    ..rrect(
      rrect: RRect.fromRectAndRadius(
        Rect.fromLTWH(0, top, width, 4),
        const Radius.circular(AppRadii.bar),
      ),
    );

  testWidgets('first paint draws the fill at its value; a change moves it '
      'over 240 ms', (tester) async {
    final track = find.byKey(const Key('repereTrack'));
    await pumpHost(tester, meter(fraction: 0.2));
    expect(track, fillOf(40));

    await pumpHost(tester, meter(fraction: 0.8));
    await tester.pump(AppMotion.meter ~/ 2);
    expect(track, isNot(fillOf(40)));
    expect(track, isNot(fillOf(160)));
    await tester.pump(AppMotion.meter);
    expect(track, fillOf(160));
  });

  testWidgets('reduced motion jumps straight to the new value', (tester) async {
    Widget reduced(double fraction) => MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: meter(fraction: fraction),
    );
    await pumpHost(tester, reduced(0.2));
    await pumpHost(tester, reduced(0.8));
    await tester.pump();
    expect(find.byKey(const Key('repereTrack')), fillOf(160));
  });

  testWidgets('follows the light theme', (tester) async {
    await pumpHost(tester, meter(), theme: AppTheme.light);
    final painter = find.byKey(const Key('repereTrack'));
    expect(
      painter,
      paints
        ..rrect(color: AppColors.light.lineStrong)
        ..rrect(color: AppColors.light.accent),
    );
  });
}
