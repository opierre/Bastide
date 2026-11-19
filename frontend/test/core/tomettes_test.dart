import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/core/theme/tokens.dart';
import 'package:bastide/core/widgets/tomettes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child, {ThemeData? theme}) => MaterialApp(
    theme: theme ?? AppTheme.dark,
    home: Scaffold(body: SizedBox.expand(child: child)),
  );

  group('pattern', () {
    test('tiles 24.25 x 42 from the origin and covers the area', () {
      final bounds = TomettesPainter.patternFor(
        const Size(100, 100),
      ).getBounds();

      expect(bounds.left, 0);
      expect(bounds.top, 0);
      // Whole tiles: ceil(100 / 24.25) = 5 across, ceil(100 / 42) = 3 down.
      expect(bounds.right, closeTo(5 * 24.25, 1e-9));
      expect(bounds.bottom, 3 * 42);
    });

    test('one tile is the hexagon path of the design system', () {
      final path = TomettesPainter.patternFor(TomettesPainter.tileSize);

      expect(path.getBounds(), Offset.zero & TomettesPainter.tileSize);
      // Points on the strokes: the roof apex, both walls, the floor's vertex,
      // and the stem down to the next row.
      for (final p in [
        const Offset(12.125, 0),
        const Offset(0, 14),
        const Offset(24.25, 14),
        const Offset(12.125, 28),
        const Offset(12.125, 41),
      ]) {
        expect(_nearStroke(path, p), isTrue, reason: '$p');
      }
      expect(_nearStroke(path, const Offset(12.125, 14)), isFalse);
    });
  });

  group('painter', () {
    for (final (name, theme, colors) in [
      ('dark', AppTheme.dark, AppColors.dark),
      ('light', AppTheme.light, AppColors.light),
    ]) {
      testWidgets('$name theme: 1 px stroke in the tomette colour', (
        tester,
      ) async {
        await tester.pumpWidget(host(const Tomettes(), theme: theme));

        expect(
          find.byType(Tomettes),
          paints..path(
            color: colors.tomette,
            style: PaintingStyle.stroke,
            strokeWidth: 1,
          ),
        );
      });
    }

    test('the tomette colour is white or black at 7 %', () {
      expect(AppColors.dark.tomette.a, closeTo(0.07, 0.005));
      expect(AppColors.light.tomette.a, closeTo(0.07, 0.005));
    });

    testWidgets('a fade masks the pattern in a layer; no fade draws it as is', (
      tester,
    ) async {
      for (final fade in [TomettesFade.radial, TomettesFade.vertical]) {
        await tester.pumpWidget(host(Tomettes(fade: fade)));
        expect(
          find.byType(Tomettes),
          paints
            ..something(_saveLayer)
            ..path(style: PaintingStyle.stroke)
            ..rect()
            ..restore(),
          reason: fade.name,
        );
      }

      await tester.pumpWidget(host(const Tomettes(fade: TomettesFade.none)));
      expect(find.byType(Tomettes), isNot(paints..something(_saveLayer)));
    });

    test('repaints only when the colour or the fade changes', () {
      final painter = TomettesPainter(color: AppColors.dark.tomette);

      expect(
        painter.shouldRepaint(TomettesPainter(color: AppColors.dark.tomette)),
        isFalse,
      );
      expect(
        painter.shouldRepaint(TomettesPainter(color: AppColors.light.tomette)),
        isTrue,
      );
      expect(
        painter.shouldRepaint(
          TomettesPainter(
            color: AppColors.dark.tomette,
            fade: TomettesFade.radial,
          ),
        ),
        isTrue,
      );
    });
  });

  testWidgets('decoration only: a tap goes through to what is under it', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Stack(
          children: [
            Center(
              child: TextButton(
                onPressed: () => taps++,
                child: const Text('Under'),
              ),
            ),
            const Positioned.fill(child: Tomettes()),
          ],
        ),
      ),
    );

    await tester.tap(find.text('Under'), warnIfMissed: false);
    expect(taps, 1);
  });
}

bool _saveLayer(Symbol method, List<dynamic> arguments) => method == #saveLayer;

/// Whether [path], stroked 1 px wide, covers [point].
bool _nearStroke(Path path, Offset point) {
  for (final metric in path.computeMetrics()) {
    for (var d = 0.0; d <= metric.length; d += 0.05) {
      final tangent = metric.getTangentForOffset(d);
      if (tangent != null && (tangent.position - point).distance <= 0.5) {
        return true;
      }
    }
  }
  return false;
}
