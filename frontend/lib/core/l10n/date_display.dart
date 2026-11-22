import 'package:intl/intl.dart';

/// U+00A0, the no-break space of `docs/design/00-design-system.md` §3: between
/// a figure and its unit, and between a day and its month.
const String noBreakSpace = '\u00A0';

/// Joins [figure] and [unit] with a no-break space (« 320 k€ », « 2,2 × »),
/// so a line never breaks between them. Money and percentages keep what
/// `intl` emits instead.
String withUnit(String figure, String unit) => '$figure$noBreakSpace$unit';

/// A date in words whose day never leaves its month at a line break:
/// « 12 mai 2026 », « May 12, 2026 » (`00-design-system.md` §3).
///
/// `DateFormat` writes an ordinary space between the day and the month; this
/// rewrites the locale's own pattern so that space is U+00A0, and leaves the
/// rest (the year, the comma) as the locale has it. Every feature formats its
/// dates in words through here rather than through `DateFormat` directly.
class DayMonthFormat {
  DayMonthFormat._(DateFormat format)
    : _format = DateFormat(_joinDayAndMonth(format.pattern!), format.locale);

  /// « 12 mai 2026 », « May 12, 2026 ».
  DayMonthFormat.yMMMMd(String locale) : this._(DateFormat.yMMMMd(locale));

  /// « 12 mai 2026 », « May 12, 2026 », with the abbreviated month.
  DayMonthFormat.yMMMd(String locale) : this._(DateFormat.yMMMd(locale));

  /// « 12 mai », « May 12 ».
  // Named after the `DateFormat` skeleton it stands in for, like the others.
  // ignore: non_constant_identifier_names
  DayMonthFormat.MMMMd(String locale) : this._(DateFormat.MMMMd(locale));

  /// « 12 mai », « May 12 », with the abbreviated month.
  // ignore: non_constant_identifier_names
  DayMonthFormat.MMMd(String locale) : this._(DateFormat.MMMd(locale));

  /// « 12 »: the day alone, the first end of a range in one month.
  DayMonthFormat.d(String locale) : this._(DateFormat.d(locale));

  final DateFormat _format;

  /// The pattern after the rewrite, for tests and debugging.
  String get pattern => _format.pattern!;

  String format(DateTime date) => _format.format(date);
}

/// A run of day letters and a run of month letters separated by spaces, in
/// either order (`d MMMM`, `MMM d`). Quoted literals never hold either.
final _dayThenMonth = RegExp(r'(d+) +(?=[ML])');
final _monthThenDay = RegExp(r'([ML]+) +(?=d)');

String _joinDayAndMonth(String pattern) => pattern
    .replaceAllMapped(_dayThenMonth, (m) => '${m[1]}$noBreakSpace')
    .replaceAllMapped(_monthThenDay, (m) => '${m[1]}$noBreakSpace');
