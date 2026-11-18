import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/l10n/app_localizations.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps [child] centred in a themed, localized app, dark by default.
Future<void> pumpHost(
  WidgetTester tester,
  Widget child, {
  ThemeData? theme,
  Locale locale = const Locale('fr'),
}) async {
  await tester.pumpWidget(host(child, theme: theme, locale: locale));
}

Widget host(
  Widget child, {
  ThemeData? theme,
  Locale locale = const Locale('fr'),
}) => MaterialApp(
  theme: theme ?? AppTheme.dark,
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: Center(child: child)),
);

/// The [BoxDecoration] of the [Container] or [DecoratedBox] found by [finder].
BoxDecoration decorationOf(WidgetTester tester, Finder finder) {
  final widget = tester.widget(finder);
  if (widget is Container) return widget.decoration! as BoxDecoration;
  if (widget is DecoratedBox) return widget.decoration as BoxDecoration;
  throw ArgumentError('$widget has no decoration');
}

/// The first [BoxDecoration] painted under [finder] whose colour is set.
BoxDecoration firstDecorationUnder(WidgetTester tester, Finder finder) {
  final boxes = find.descendant(
    of: finder,
    matching: find.byWidgetPredicate(
      (w) =>
          (w is Container && w.decoration is BoxDecoration) ||
          (w is DecoratedBox && w.decoration is BoxDecoration),
    ),
  );
  return decorationOf(tester, boxes.first);
}

/// The opacity of the nearest [Opacity] above [finder].
double opacityAbove(WidgetTester tester, Finder finder) => tester
    .widget<Opacity>(
      find.ancestor(of: finder, matching: find.byType(Opacity)).first,
    )
    .opacity;

/// Moves a mouse pointer onto [finder].
Future<TestGesture> hover(WidgetTester tester, Finder finder) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer(location: Offset.zero);
  addTearDown(gesture.removePointer);
  await gesture.moveTo(tester.getCenter(finder));
  await tester.pump();
  return gesture;
}
