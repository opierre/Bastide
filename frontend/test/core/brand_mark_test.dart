import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/core/theme/tokens.dart';
import 'package:bastide/core/widgets/brand_mark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child, {ThemeData? theme}) => MaterialApp(
    theme: theme ?? AppTheme.dark,
    home: Scaffold(body: Center(child: child)),
  );

  // 16 is the minimum, 20 the sidebar and auth mark, 44 À propos, 64 the
  // startup screen. All draw the same geometry.
  for (final size in [16.0, 20.0, 44.0, 64.0]) {
    testWidgets('the mark renders at ${size.toInt()} px', (tester) async {
      await tester.pumpWidget(host(BrandMark(size: size)));

      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(BrandMark)), Size(size, size));
      expect(
        find.byType(BrandMark),
        paints
          ..rrect(rrect: _tile(size))
          ..rrect(rrect: _cell(size, 4.5, 4.5)),
      );
    });
  }

  for (final (name, theme, colors) in [
    ('dark', AppTheme.dark, AppColors.dark),
    ('light', AppTheme.light, AppColors.light),
  ]) {
    testWidgets('$name theme: tile primary, squares onPrimary, centre accent', (
      tester,
    ) async {
      await tester.pumpWidget(host(const BrandMark(), theme: theme));

      // Row by row: three squares, then the middle row's first square, the
      // centre, and the four after it.
      expect(
        find.byType(BrandMark),
        paints
          ..rrect(color: colors.primary)
          ..rrect(color: colors.onPrimary)
          ..rrect(color: colors.onPrimary)
          ..rrect(color: colors.onPrimary)
          ..rrect(color: colors.onPrimary)
          ..rrect(color: colors.accent, rrect: _cell(20, 10, 10))
          ..rrect(color: colors.onPrimary)
          ..rrect(color: colors.onPrimary)
          ..rrect(color: colors.onPrimary)
          ..rrect(color: colors.onPrimary),
      );
    });
  }

  test('a theme switch repaints the mark', () {
    PlanMarkPainter painter(AppColors c) =>
        PlanMarkPainter(tile: c.primary, glyph: c.onPrimary, accent: c.accent);

    expect(
      painter(AppColors.dark).shouldRepaint(painter(AppColors.dark)),
      isFalse,
    );
    expect(
      painter(AppColors.light).shouldRepaint(painter(AppColors.dark)),
      isTrue,
    );
  });

  for (final (name, lockup) in [
    ('sidebar', const BrandLockup.sidebar()),
    ('login', const BrandLockup.login()),
    ('register', const BrandLockup.register()),
    ('about', const BrandLockup.about()),
  ]) {
    testWidgets('the $name lockup renders without overflow', (tester) async {
      await tester.pumpWidget(host(SizedBox(width: 200, child: lockup)));

      expect(tester.takeException(), isNull);
      expect(find.text('Bastide'), findsOneWidget);
      final style = tester.widget<Text>(find.text('Bastide')).style!;
      expect(style.fontWeight, FontWeight.w600);
      expect(style.letterSpacing, closeTo(-0.02 * style.fontSize!, 1e-9));
    });
  }

  testWidgets('the sidebar lockup is a 20 px mark and a 14 px name', (
    tester,
  ) async {
    await tester.pumpWidget(host(const BrandLockup.sidebar()));

    expect(tester.getSize(find.byType(BrandMark)), const Size.square(20));
    expect(tester.widget<Text>(find.text('Bastide')).style!.fontSize, 14);
  });
}

RRect _tile(double size) => RRect.fromRectAndRadius(
  Offset.zero & Size.square(size),
  Radius.circular(5.3 * size / 24),
);

RRect _cell(double size, double x, double y) {
  final unit = size / 24;
  return RRect.fromRectAndRadius(
    Rect.fromLTWH(x * unit, y * unit, 4 * unit, 4 * unit),
    Radius.circular(0.8 * unit),
  );
}
