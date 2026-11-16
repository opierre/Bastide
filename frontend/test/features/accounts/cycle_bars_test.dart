import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/features/accounts/presentation/cycle_bars.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _values = [41250, 38900, 45120, 12030];

Future<void> _pump(
  WidgetTester tester, {
  String Function(num value)? valueLabel,
}) => tester.pumpWidget(
  MaterialApp(
    theme: appDarkTheme,
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 600,
          height: 240,
          child: CycleBars(
            values: _values,
            labels: const ['janv.', 'févr.', 'mars', 'avr.'],
            lastInProgress: true,
            valueLabel: valueLabel ?? (value) => 'v$value',
            tooltips: [
              for (var i = 0; i < _values.length; i++)
                TextSpan(text: 'Cycle $i'),
            ],
          ),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('hovering a cycle names it at once, in the shared chart card', (
    tester,
  ) async {
    await _pump(tester);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);
    await gesture.addPointer(location: Offset.zero);
    await gesture.moveTo(
      tester.getCenter(find.byKey(const Key('cycleBarsSlot-2'))),
    );
    await tester.pump();

    // One frame, no Tooltip delay, as on every other chart.
    expect(find.byType(Tooltip), findsNothing);
    final card = find.byKey(const Key('cycleBarsTooltip-2'));
    expect(card, findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.text('Cycle 2')),
      findsOneWidget,
    );

    await gesture.moveTo(Offset.zero);
    await tester.pump();
    expect(card, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('gridlines stand on clean ticks from zero, past the tallest', (
    tester,
  ) async {
    final ticks = <num>[];
    await _pump(
      tester,
      valueLabel: (value) {
        ticks.add(value);
        return '$value';
      },
    );

    expect(ticks, hasLength(3));
    expect(ticks.first, 0);
    expect(ticks.last, greaterThanOrEqualTo(45120));
    // Whole euros: no gridline on cents.
    expect(ticks.every((tick) => tick % 100 == 0), isTrue);
    expect(ticks[2] - ticks[1], ticks[1] - ticks[0]);
  });
}
