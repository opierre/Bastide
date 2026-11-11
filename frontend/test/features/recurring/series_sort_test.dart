import 'package:bastide/features/recurring/application/series_sort.dart';
import 'package:bastide/features/recurring/domain/recurring_series.dart';
import 'package:bastide/features/recurring/domain/recurring_summary.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/recurring_fixtures.dart';

SubscriptionRow _row(
  String id,
  String label, {
  int amountMinor = -1000,
  DateTime? next,
  SeriesStatus status = SeriesStatus.confirmed,
  bool isArchived = false,
  SeriesSignal? signal,
}) => SubscriptionRow(
  series: testSeries(
    id: id,
    label: label,
    expectedAmountMinor: amountMinor,
    nextExpectedDate: next,
    status: status,
    isArchived: isArchived,
  ),
  signal: signal,
);

List<String> _ids(List<SubscriptionRow> rows) => [
  for (final row in rows) row.series.id,
];

void main() {
  group('sortSeriesRows', () {
    test('no sort keeps the order the rows came in', () {
      final rows = [_row('b', 'Zeta'), _row('a', 'Alpha')];

      expect(_ids(sortSeriesRows(rows, null)), ['b', 'a']);
    });

    test('name sorts case- and accent-insensitively, both ways', () {
      final rows = [
        _row('z', 'zumba club'),
        _row('e', 'Électricité'),
        _row('a', 'Abonnement presse'),
        _row('f', 'Forfait mobile'),
      ];

      expect(
        _ids(
          sortSeriesRows(
            rows,
            const SeriesSort(SeriesSortField.name, ascending: true),
          ),
        ),
        ['a', 'e', 'f', 'z'],
      );
      expect(
        _ids(
          sortSeriesRows(
            rows,
            const SeriesSort(SeriesSortField.name, ascending: false),
          ),
        ),
        ['z', 'f', 'e', 'a'],
      );
    });

    test('amount sorts on the magnitude, not the signed value', () {
      final rows = [
        _row('small', 'Small', amountMinor: -499),
        _row('big', 'Big', amountMinor: -5000),
        _row('income', 'Income', amountMinor: 1200),
      ];

      // Descending is the default: the biggest charge first. A signed sort
      // would put −50,00 € *below* −4,99 €.
      expect(
        _ids(
          sortSeriesRows(rows, SeriesSort.byDefault(SeriesSortField.amount)),
        ),
        ['big', 'income', 'small'],
      );
      expect(
        _ids(
          sortSeriesRows(
            rows,
            const SeriesSort(SeriesSortField.amount, ascending: true),
          ),
        ),
        ['small', 'income', 'big'],
      );
    });

    test('equal amounts fall back to the name', () {
      final rows = [
        _row('2', 'Beta', amountMinor: -1000),
        _row('1', 'Alpha', amountMinor: -1000),
      ];

      expect(
        _ids(
          sortSeriesRows(
            rows,
            const SeriesSort(SeriesSortField.amount, ascending: false),
          ),
        ),
        ['1', '2'],
      );
    });

    test('next charge lists series without one last, in both directions', () {
      final rows = [
        _row('cancelled', 'Cancelled', status: SeriesStatus.cancelled),
        _row('late', 'Late', next: DateTime(2026, 5, 20)),
        _row('soon', 'Soon', next: DateTime(2026, 5, 16)),
        _row('archived', 'Archived', isArchived: true),
        _row('later', 'Later', next: DateTime(2026, 6, 2)),
      ];

      expect(
        _ids(
          sortSeriesRows(
            rows,
            SeriesSort.byDefault(SeriesSortField.nextCharge),
          ),
        ),
        ['soon', 'late', 'later', 'archived', 'cancelled'],
      );
      expect(
        _ids(
          sortSeriesRows(
            rows,
            const SeriesSort(SeriesSortField.nextCharge, ascending: false),
          ),
        ),
        ['later', 'late', 'soon', 'archived', 'cancelled'],
      );
    });

    test('next charge uses the missed date on an overdue row', () {
      final rows = [
        _row('upcoming', 'Upcoming', next: DateTime(2026, 5, 16)),
        _row(
          'overdue',
          'Overdue',
          next: DateTime(2026, 6, 5),
          signal: MissedChargeSignal(
            expectedOn: DateTime(2026, 5, 5),
            daysLate: 9,
          ),
        ),
      ];

      expect(
        _ids(
          sortSeriesRows(
            rows,
            SeriesSort.byDefault(SeriesSortField.nextCharge),
          ),
        ),
        ['overdue', 'upcoming'],
      );
    });
  });

  test('each column starts in the direction its question reads', () {
    expect(SeriesSort.byDefault(SeriesSortField.name).ascending, isTrue);
    expect(SeriesSort.byDefault(SeriesSortField.amount).ascending, isFalse);
    expect(SeriesSort.byDefault(SeriesSortField.nextCharge).ascending, isTrue);
  });
}
