import 'package:bastide/features/placements/domain/placement_timeline.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/placements_fixtures.dart';

void main() {
  test('one point per dated event, from the opening to the end', () {
    final points = placementTimeline(testDetail(), DateTime(2026, 5, 20));

    expect(points.map((p) => p.date), [
      DateTime(2023, 3, 14),
      DateTime(2026, 1, 31),
      DateTime(2026, 4, 5),
      DateTime(2026, 4, 30),
      DateTime(2026, 5, 20),
    ]);
    // Net payments add up movement by movement.
    expect(points.map((p) => p.netPaymentsMinor), [
      2650000,
      2650000,
      2700000,
      2700000,
      2700000,
    ]);
    // The value is unknown before the first declaration, then held flat.
    expect(points.map((p) => p.valueMinor), [
      null,
      3060000,
      3060000,
      3184000,
      3184000,
    ]);
    expect(points.map((p) => p.declared), [false, true, false, true, false]);
  });

  test('a closed placement ends at its closing date', () {
    final detail = testDetail(
      investment: testInvestment(closedOn: DateTime(2026, 4, 10)),
    );

    final points = placementTimeline(detail, DateTime(2026, 5, 20));

    expect(points.last.date, DateTime(2026, 4, 10));
    expect(points.last.valueMinor, 3060000);
  });

  test('without a declared value only net payments are known', () {
    final detail = testDetail(investment: testInvestment(lastValueMinor: null));

    final points = placementTimeline(detail, DateTime(2026, 5, 20));

    expect(points.every((p) => p.valueMinor == null), isTrue);
    expect(points.last.netPaymentsMinor, 2700000);
  });
}
