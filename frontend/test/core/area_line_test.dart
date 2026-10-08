import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/core/widgets/area_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap({required double height}) => MaterialApp(
  theme: appDarkTheme,
  home: Scaffold(
    body: Center(
      child: SizedBox(
        height: height,
        width: 400,
        child: const AreaLine(
          values: [1000, 2400, 1800, 3200],
          labels: ['Févr.', 'Mars', 'Avr.', 'Mai'],
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
}
