import 'package:bastide/core/theme/tokens.dart';
import 'package:bastide/core/widgets/motion/appear_transition.dart';
import 'package:bastide/core/widgets/motion/counting_text.dart';
import 'package:bastide/core/widgets/motion/measure_tween.dart';
import 'package:bastide/core/widgets/motion/sliding_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// [child] in a bare directional box, with or without reduced motion.
Widget frame(Widget child, {bool reduced = false}) => MediaQuery(
  data: MediaQueryData(disableAnimations: reduced),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: Align(alignment: Alignment.topLeft, child: child),
  ),
);

void main() {
  group('AppearTransition', () {
    const box = SizedBox(key: Key('box'), width: 10, height: 10);

    double opacity(WidgetTester tester) => tester
        .widget<FadeTransition>(
          find.ancestor(
            of: find.byKey(const Key('box')),
            matching: find.byType(FadeTransition),
          ),
        )
        .opacity
        .value;

    double rise(WidgetTester tester) =>
        tester.getTopLeft(find.byKey(const Key('box'))).dy;

    Widget appear({
      bool visible = true,
      bool travel = true,
      bool reduced = false,
      VoidCallback? onHidden,
    }) => frame(
      AppearTransition(
        visible: visible,
        travel: travel,
        onHidden: onHidden,
        child: box,
      ),
      reduced: reduced,
    );

    testWidgets('comes in over enter, rising 4 px, and leaves over exit', (
      tester,
    ) async {
      var hidden = 0;
      await tester.pumpWidget(appear(onHidden: () => hidden++));
      expect(opacity(tester), 0);
      expect(rise(tester), AppearTransition.distance);

      await tester.pump(AppMotion.enter ~/ 2);
      expect(opacity(tester), inExclusiveRange(0, 1));
      expect(rise(tester), inExclusiveRange(0, AppearTransition.distance));
      await tester.pump(AppMotion.enter ~/ 2);
      expect(opacity(tester), 1);
      expect(rise(tester), 0);

      await tester.pumpWidget(appear(visible: false, onHidden: () => hidden++));
      await tester.pump(AppMotion.exit ~/ 2);
      expect(opacity(tester), inExclusiveRange(0, 1));
      expect(hidden, 0);
      await tester.pump(AppMotion.exit ~/ 2);
      expect(opacity(tester), 0);
      expect(rise(tester), AppearTransition.distance);
      // The controller reports the end on the frame after its last value.
      await tester.pumpAndSettle();
      expect(hidden, 1);
    });

    testWidgets('without travel it only fades', (tester) async {
      await tester.pumpWidget(appear(travel: false));
      await tester.pump(AppMotion.enter ~/ 2);
      expect(opacity(tester), inExclusiveRange(0, 1));
      expect(rise(tester), 0);
    });

    testWidgets('reduced motion keeps the fade and drops the travel', (
      tester,
    ) async {
      await tester.pumpWidget(appear(reduced: true));
      await tester.pump(AppMotion.enter ~/ 2);
      expect(opacity(tester), inExclusiveRange(0, 1));
      expect(rise(tester), 0);
      await tester.pump(AppMotion.enter ~/ 2);
      expect(opacity(tester), 1);

      await tester.pumpWidget(appear(visible: false, reduced: true));
      await tester.pump(AppMotion.exit);
      expect(opacity(tester), 0);
      expect(rise(tester), 0);
    });

    testWidgets('an interrupted entrance turns back from where it is', (
      tester,
    ) async {
      await tester.pumpWidget(appear());
      await tester.pump(AppMotion.enter ~/ 2);
      final midway = opacity(tester);
      await tester.pumpWidget(appear(visible: false));
      await tester.pump(const Duration(milliseconds: 1));
      expect(opacity(tester), lessThan(midway));
      await tester.pump(AppMotion.exit);
      expect(opacity(tester), 0);
    });

    testWidgets('driven: follows the animation it is given, on the curve', (
      tester,
    ) async {
      final progress = AnimationController(vsync: const TestVSync());
      addTearDown(progress.dispose);
      await tester.pumpWidget(
        frame(AppearTransition.driven(animation: progress, child: box)),
      );
      expect(opacity(tester), 0);
      progress.value = 0.5;
      await tester.pump();
      expect(opacity(tester), AppMotion.curve.transform(0.5));
      expect(
        rise(tester),
        closeTo(
          AppearTransition.distance * (1 - AppMotion.curve.transform(0.5)),
          1e-9,
        ),
      );
      progress.value = 1;
      await tester.pump();
      expect(opacity(tester), 1);
      expect(rise(tester), 0);
    });
  });

  group('MeasureTween', () {
    Widget measure(double value, {bool reduced = false}) => frame(
      MeasureTween<double>(
        value: value,
        builder: (context, shown, _) =>
            SizedBox(key: const Key('bar'), width: shown, height: 4),
      ),
      reduced: reduced,
    );

    double width(WidgetTester tester) =>
        tester.getSize(find.byKey(const Key('bar'))).width;

    testWidgets('first build draws the value without animating', (
      tester,
    ) async {
      await tester.pumpWidget(measure(120));
      expect(width(tester), 120);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('a later change travels on the measure clock', (tester) async {
      await tester.pumpWidget(measure(100));
      await tester.pumpWidget(measure(200));
      expect(width(tester), 100);
      await tester.pump(AppMotion.measure ~/ 2);
      expect(width(tester), inExclusiveRange(100, 200));
      await tester.pump(AppMotion.measure ~/ 2);
      expect(width(tester), 200);
    });

    testWidgets('an interruption lands on the new end value', (tester) async {
      await tester.pumpWidget(measure(100));
      await tester.pumpWidget(measure(200));
      await tester.pump(AppMotion.measure ~/ 2);
      final midway = width(tester);

      await tester.pumpWidget(measure(50));
      // It turns back from where it was, not from either end.
      expect(width(tester), closeTo(midway, 1e-6));
      await tester.pump(AppMotion.measure ~/ 2);
      expect(width(tester), inExclusiveRange(50, midway));
      await tester.pump(AppMotion.measure ~/ 2);
      expect(width(tester), 50);
    });

    testWidgets('reduced motion lands at once', (tester) async {
      await tester.pumpWidget(measure(100, reduced: true));
      await tester.pumpWidget(measure(200, reduced: true));
      expect(width(tester), 200);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('CountingText', () {
    // Invented amounts in minor units, formatted as whole euros.
    String euros(int cents) => '${cents ~/ 100} €';

    Widget figure(int cents, {bool reduced = false}) => frame(
      CountingText(
        value: cents,
        format: euros,
        style: const TextStyle(fontSize: 20),
      ),
      reduced: reduced,
    );

    Text text(WidgetTester tester) => tester.widget<Text>(find.byType(Text));

    testWidgets('first build shows the value, in tabular numerals', (
      tester,
    ) async {
      await tester.pumpWidget(figure(123400));
      expect(find.text('1234 €'), findsOneWidget);
      expect(
        text(tester).style?.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
      expect(text(tester).style?.fontSize, 20);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('counts through whole minor units to the new value', (
      tester,
    ) async {
      final seen = <int>[];
      String record(int cents) {
        seen.add(cents);
        return euros(cents);
      }

      Widget counted(int cents) =>
          frame(CountingText(value: cents, format: record));

      await tester.pumpWidget(counted(10000));
      await tester.pumpWidget(counted(50000));
      await tester.pump(AppMotion.measure ~/ 2);
      final shown = text(tester).data!;
      expect(shown, isNot('100 €'));
      expect(shown, isNot('500 €'));
      await tester.pump(AppMotion.measure ~/ 2);
      expect(find.text('500 €'), findsOneWidget);
      // Every step the formatter saw was an integer between the two ends.
      expect(seen, everyElement(inInclusiveRange(10000, 50000)));
    });

    testWidgets('announces the final value only', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(figure(10000));
      await tester.pumpWidget(figure(50000));
      await tester.pump(AppMotion.measure ~/ 2);
      expect(find.bySemanticsLabel('500 €'), findsOneWidget);
      await tester.pumpAndSettle();
      semantics.dispose();
    });

    testWidgets('reduced motion shows the new value at once', (tester) async {
      await tester.pumpWidget(figure(10000, reduced: true));
      await tester.pumpWidget(figure(50000, reduced: true));
      expect(find.text('500 €'), findsOneWidget);
    });
  });

  group('SlidingIndicator', () {
    // Three slots of 40, 60 and 80 px in a row, so the mark changes size as
    // well as place.
    const widths = [40.0, 60.0, 80.0];
    const color = Color(0xFF3366FF);

    Widget indicator(
      int? selected, {
      bool reduced = false,
      Rect Function(Rect slot)? shape,
    }) => frame(
      SlidingIndicator(
        key: const Key('indicator'),
        selected: selected,
        decoration: const BoxDecoration(color: color),
        shape: shape,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, w) in widths.indexed)
              SlidingIndicatorSlot(
                index: i,
                child: SizedBox(width: w, height: 20),
              ),
          ],
        ),
      ),
      reduced: reduced,
    );

    final box = find.byKey(const Key('indicator'));

    PaintPattern markAt(Rect rect) => paints..rect(rect: rect, color: color);

    testWidgets('first paint draws the mark on the selected slot', (
      tester,
    ) async {
      await tester.pumpWidget(indicator(1));
      expect(box, markAt(const Rect.fromLTWH(40, 0, 60, 20)));
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('no selection paints no mark', (tester) async {
      await tester.pumpWidget(indicator(null));
      expect(box, isNot(paints..rect(color: color)));
    });

    testWidgets('a new selection slides over move', (tester) async {
      await tester.pumpWidget(indicator(0));
      await tester.pumpWidget(indicator(2));
      // The slide starts from the old slot.
      expect(box, markAt(const Rect.fromLTWH(0, 0, 40, 20)));
      await tester.pump(AppMotion.move ~/ 2);
      expect(box, isNot(markAt(const Rect.fromLTWH(0, 0, 40, 20))));
      expect(box, isNot(markAt(const Rect.fromLTWH(100, 0, 80, 20))));
      await tester.pump(AppMotion.move ~/ 2);
      expect(box, markAt(const Rect.fromLTWH(100, 0, 80, 20)));
    });

    testWidgets('an interruption slides on to the newest slot', (tester) async {
      await tester.pumpWidget(indicator(0));
      await tester.pumpWidget(indicator(2));
      await tester.pump(AppMotion.move ~/ 2);
      await tester.pumpWidget(indicator(1));
      await tester.pumpAndSettle();
      expect(box, markAt(const Rect.fromLTWH(40, 0, 60, 20)));
    });

    testWidgets('shape picks the part of the slot the mark covers', (
      tester,
    ) async {
      await tester.pumpWidget(
        indicator(
          2,
          shape: (slot) => Rect.fromLTRB(
            slot.left,
            slot.bottom - 2,
            slot.right,
            slot.bottom,
          ),
        ),
      );
      expect(box, markAt(const Rect.fromLTWH(100, 18, 80, 2)));
    });

    testWidgets('reduced motion jumps', (tester) async {
      await tester.pumpWidget(indicator(0, reduced: true));
      await tester.pumpWidget(indicator(2, reduced: true));
      expect(box, markAt(const Rect.fromLTWH(100, 0, 80, 20)));
      expect(tester.hasRunningAnimations, isFalse);
    });
  });
}
