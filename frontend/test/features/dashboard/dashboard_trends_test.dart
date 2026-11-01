import 'package:bastide/features/dashboard/domain/dashboard_trends.dart';
import 'package:flutter_test/flutter_test.dart';

/// A trends value whose savings series is [saved], one invented month each, oldest first.
DashboardTrends _trends(List<int> saved) => DashboardTrends(
  monthlySeries: const [],
  savingsSeries: [
    for (var i = 0; i < saved.length; i++)
      SavingsPoint(month: DateTime(2025, 1 + i), savedMinor: saved[i]),
  ],
  currency: 'EUR',
);

void main() {
  group('averageSavedMinor', () {
    test('averages a full year of months, shortfalls included', () {
      final trends = _trends([
        10000,
        20000,
        -6000,
        0,
        15000,
        5000,
        8000,
        12000,
        -3000,
        9000,
        11000,
        13000,
      ]);
      expect(trends.averageWindow, hasLength(12));
      // 94000 / 12 = 7833.33… → 7833.
      expect(trends.averageSavedMinor, 7833);
    });

    test('averages only the months there are for a newer user', () {
      final trends = _trends([12000, -3000, 6000]);
      expect(trends.averageWindow, hasLength(3));
      expect(trends.averageSavedMinor, 5000);
    });

    test('keeps to the last twelve months when given more', () {
      // The oldest month is far out of line: were it counted, the mean would jump.
      final trends = _trends([1000000, for (var i = 0; i < 12; i++) 2400]);
      expect(trends.averageWindow, hasLength(12));
      expect(trends.averageWindow.first.month, DateTime(2025, 2));
      expect(trends.averageSavedMinor, 2400);
    });

    test('is zero with no history', () {
      expect(_trends([]).averageWindow, isEmpty);
      expect(_trends([]).averageSavedMinor, 0);
    });

    test('rounds to the nearest minor unit, halves away from zero', () {
      expect(_trends([1, 2]).averageSavedMinor, 2); // 1.5 → 2
      expect(_trends([-1, -2]).averageSavedMinor, -2); // −1.5 → −2
      expect(_trends([10, 10, 11]).averageSavedMinor, 10); // 10.33 → 10
      expect(_trends([10, 11, 11]).averageSavedMinor, 11); // 10.67 → 11
      expect(_trends([-10, -11, -11]).averageSavedMinor, -11); // −10.67 → −11
      expect(_trends([-10, -10, -11]).averageSavedMinor, -10); // −10.33 → −10
    });

    test('stays an exact integer on totals a double would blur', () {
      // 2^53 + 1 per month: a double total would round it off.
      const big = 9007199254740993;
      expect(_trends([big, big]).averageSavedMinor, big);
    });
  });
}
