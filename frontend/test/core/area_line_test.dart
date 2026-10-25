import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/core/widgets/area_line.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap({required double height, List<InlineSpan>? tooltips}) =>
    MaterialApp(
      theme: appDarkTheme,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            height: height,
            width: 400,
            child: AreaLine(
              values: const [1000, 2400, 1800, 3200],
              labels: const ['Févr.', 'Mars', 'Avr.', 'Mai'],
              tooltips: tooltips,
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets(
    'draws the plot over its month axis when there is room for both',
    (tester) async {
      await tester.pumpWidget(_wrap(height: 200));
      await tester.pumpAndSettle();

      expect(find.text('Mai'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('gives the axis band up rather than overflowing a short card', (
    tester,
  ) async {
    // Shorter than the 22px axis alone — the case that made the savings card throw a
    // RenderFlex overflow on a small window.
    await tester.pumpWidget(_wrap(height: 16));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(AreaLine)).height, 16);
  });

  testWidgets('each point stands over the centre of its month label', (
    tester,
  ) async {
    // Points used to spread edge to edge while labels sat centred in equal
    // slots, so every month but the middle ones drifted off its label.
    await tester.pumpWidget(_wrap(height: 200));
    await tester.pumpAndSettle();

    final chart = tester.getRect(find.byType(AreaLine));
    const labels = ['Févr.', 'Mars', 'Avr.', 'Mai'];
    for (var i = 0; i < labels.length; i++) {
      expect(
        tester.getCenter(find.text(labels[i])).dx - chart.left,
        closeTo(AreaLine.pointX(i, labels.length, chart.width), 0.01),
      );
    }
  });

  testWidgets('hovering a month shows its tooltip', (tester) async {
    await tester.pumpWidget(
      _wrap(
        height: 200,
        tooltips: const [
          TextSpan(text: 'Février 2026'),
          TextSpan(text: 'Mars 2026'),
          TextSpan(text: 'Avril 2026'),
          TextSpan(text: 'Mai 2026'),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);
    await gesture.addPointer(location: Offset.zero);
    await gesture.moveTo(
      tester.getCenter(find.byKey(const Key('areaLineTooltip-2'))),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Avril 2026'), findsOneWidget);
    expect(find.text('Mai 2026'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
