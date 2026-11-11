import 'package:flutter/foundation.dart';

import '../domain/recurring_summary.dart';

/// The columns the subscriptions table can be sorted on.
enum SeriesSortField {
  name,
  amount,
  nextCharge;

  /// The direction a first click on the column picks: names read A to Z, the
  /// biggest charges come first, and the soonest charge comes first — each the
  /// question the user is most likely asking when they reach for that column.
  bool get ascendingByDefault => this != SeriesSortField.amount;
}

/// A sort choice: a column and a direction.
@immutable
class SeriesSort {
  const SeriesSort(this.field, {required this.ascending});

  /// [field] in the direction a first click picks.
  SeriesSort.byDefault(this.field) : ascending = field.ascendingByDefault;

  final SeriesSortField field;
  final bool ascending;

  /// The same column in the other direction.
  SeriesSort get flipped => SeriesSort(field, ascending: !ascending);

  @override
  bool operator ==(Object other) =>
      other is SeriesSort &&
      other.field == field &&
      other.ascending == ascending;

  @override
  int get hashCode => Object.hash(field, ascending);
}

/// [rows] ordered by [sort], or as given when [sort] is `null` (the server's
/// order).
///
/// - **Name** compares case- and accent-insensitively, so « Électricité » files
///   under E rather than after Z.
/// - **Amount** compares magnitudes. Every amount in the table is drawn
///   unsigned (`expectedAmountMinor.abs()`), and an outflow's signed value runs
///   the wrong way for "biggest charge" — −50,00 € sorts below −5,00 €.
/// - **Next charge** uses the date the row shows: the missed date when a charge
///   is overdue, otherwise the expected one. A row with no next charge (a
///   cancelled or archived series) goes last in both directions: it has no
///   place on a timeline, and flipping the order should not bring it to the top.
///
/// Ties fall back to the name, then the id, so the order is stable across
/// reloads.
List<SubscriptionRow> sortSeriesRows(
  List<SubscriptionRow> rows,
  SeriesSort? sort,
) {
  if (sort == null) return rows;
  final sign = sort.ascending ? 1 : -1;

  int byName(SubscriptionRow a, SubscriptionRow b) {
    final byLabel = _sortKey(
      a.series.label,
    ).compareTo(_sortKey(b.series.label));
    return byLabel != 0 ? byLabel : a.series.id.compareTo(b.series.id);
  }

  int compare(SubscriptionRow a, SubscriptionRow b) {
    switch (sort.field) {
      case SeriesSortField.name:
        return sign * byName(a, b);
      case SeriesSortField.amount:
        final byAmount = a.series.expectedAmountMinor.abs().compareTo(
          b.series.expectedAmountMinor.abs(),
        );
        return byAmount != 0 ? sign * byAmount : byName(a, b);
      case SeriesSortField.nextCharge:
        final aDate = a.nextChargeOn;
        final bDate = b.nextChargeOn;
        if (aDate == null && bDate == null) return byName(a, b);
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        final byDate = aDate.compareTo(bDate);
        return byDate != 0 ? sign * byDate : byName(a, b);
    }
  }

  return [...rows]..sort(compare);
}

/// [label] lower-cased with the Latin diacritics French and English labels
/// carry folded away.
String _sortKey(String label) {
  final buffer = StringBuffer();
  for (final char in label.toLowerCase().split('')) {
    buffer.write(_folded[char] ?? char);
  }
  return buffer.toString();
}

const _folded = {
  'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ã': 'a', 'å': 'a', //
  'ç': 'c',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', //
  'î': 'i', 'ï': 'i', 'í': 'i', 'ì': 'i', //
  'ñ': 'n',
  'ô': 'o', 'ö': 'o', 'ó': 'o', 'ò': 'o', 'õ': 'o', //
  'ù': 'u', 'û': 'u', 'ü': 'u', 'ú': 'u', //
  'ÿ': 'y',
  'æ': 'ae', 'œ': 'oe',
};
