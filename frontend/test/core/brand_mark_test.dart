import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/core/widgets/brand_mark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    theme: appDarkTheme,
    home: Scaffold(body: Center(child: child)),
  );

  // 16 is the smallest app-icon size and draws the small-size glyph; 30 is the
  // sidebar mark, still under the switch to the main glyph at 32.
  for (final size in [16.0, 30.0]) {
    testWidgets('the mark renders at ${size.toInt()} px without overflow', (
      tester,
    ) async {
      await tester.pumpWidget(host(BrandMark(size: size)));

      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(BrandMark)), Size(size, size));
    });
  }

  testWidgets('the sidebar lockup renders without overflow', (tester) async {
    await tester.pumpWidget(
      host(const SizedBox(width: 200, child: BrandLockup.sidebar())),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Bastide'), findsOneWidget);
  });
}
