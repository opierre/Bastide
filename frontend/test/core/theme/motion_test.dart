import 'package:bastide/core/theme/motion.dart';
import 'package:bastide/core/theme/tokens.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the tokens of `00` §13', () {
    expect(AppMotion.enter, const Duration(milliseconds: 120));
    expect(AppMotion.exit, const Duration(milliseconds: 80));
    expect(AppMotion.toggle, const Duration(milliseconds: 120));
    expect(AppMotion.move, const Duration(milliseconds: 180));
    expect(AppMotion.measure, const Duration(milliseconds: 320));
    expect(AppMotion.shimmer, const Duration(milliseconds: 1600));
    expect(AppMotion.curve, const Cubic(0.25, 1, 0.5, 1));
    expect(AppMotion.exit, lessThan(AppMotion.enter));
  });

  test('full motion: every kind on its token, travel kept, pulse on', () {
    const spec = MotionSpec();
    expect(spec.duration(MotionKind.appear), AppMotion.enter);
    expect(spec.duration(MotionKind.leave), AppMotion.exit);
    expect(spec.duration(MotionKind.toggle), AppMotion.toggle);
    expect(spec.duration(MotionKind.move), AppMotion.move);
    expect(spec.duration(MotionKind.measure), AppMotion.measure);
    expect(spec.curve, AppMotion.curve);
    expect(spec.travel(4), 4);
    expect(spec.pulses, isTrue);
  });

  test('reduced motion: fades stay; travel, growth and counting are 0', () {
    const spec = MotionSpec(reduced: true);
    expect(spec.duration(MotionKind.appear), AppMotion.enter);
    expect(spec.duration(MotionKind.leave), AppMotion.exit);
    expect(spec.duration(MotionKind.toggle), Duration.zero);
    expect(spec.duration(MotionKind.move), Duration.zero);
    expect(spec.duration(MotionKind.measure), Duration.zero);
    expect(spec.travel(4), 0);
    expect(spec.pulses, isFalse);
  });

  testWidgets('of(context) follows the platform setting', (tester) async {
    late MotionSpec spec;
    Widget probe(bool reduced) => MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: Builder(
        builder: (context) {
          spec = MotionSpec.of(context);
          return const SizedBox();
        },
      ),
    );
    await tester.pumpWidget(probe(false));
    expect(spec, const MotionSpec());
    await tester.pumpWidget(probe(true));
    expect(spec, const MotionSpec(reduced: true));
  });
}
