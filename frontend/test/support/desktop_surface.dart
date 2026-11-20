import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Draws the test at the 1440×900 desktop frame the design targets.
void useDesktopSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}
