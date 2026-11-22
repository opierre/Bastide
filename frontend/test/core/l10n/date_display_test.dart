import 'package:bastide/core/l10n/date_display.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// `docs/design/00-design-system.md` §3: a day never leaves its month.
void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr');
    await initializeDateFormatting('en');
  });

  final date = DateTime(2026, 5, 12);

  group('fr', () {
    test('long date', () {
      expect(DayMonthFormat.yMMMMd('fr').format(date), '12\u00A0mai 2026');
    });

    test('abbreviated date', () {
      expect(
        DayMonthFormat.yMMMd('fr').format(DateTime(2026, 4, 30)),
        '30\u00A0avr. 2026',
      );
    });

    test('day and month', () {
      expect(DayMonthFormat.MMMMd('fr').format(date), '12\u00A0mai');
      expect(DayMonthFormat.MMMd('fr').format(date), '12\u00A0mai');
    });

    test('day alone', () {
      expect(DayMonthFormat.d('fr').format(date), '12');
    });
  });

  group('en', () {
    test('long date', () {
      expect(DayMonthFormat.yMMMMd('en').format(date), 'May\u00A012, 2026');
    });

    test('abbreviated date', () {
      expect(
        DayMonthFormat.yMMMd('en').format(DateTime(2026, 9, 3)),
        'Sep\u00A03, 2026',
      );
    });

    test('day and month', () {
      expect(DayMonthFormat.MMMMd('en').format(date), 'May\u00A012');
      expect(DayMonthFormat.MMMd('en').format(date), 'May\u00A012');
    });
  });

  test('no form leaves an ordinary space between the day and the month', () {
    final dayMonth = RegExp(r'\d [^\d\s]|[^\d\s,] \d');
    for (final locale in const ['fr', 'en']) {
      for (final format in [
        DayMonthFormat.yMMMMd(locale),
        DayMonthFormat.yMMMd(locale),
        DayMonthFormat.MMMMd(locale),
        DayMonthFormat.MMMd(locale),
      ]) {
        for (var month = 1; month <= 12; month++) {
          final text = format.format(DateTime(2026, month, 12));
          // The space before the year stays ordinary: strip it first.
          final withoutYear = text.replaceAll(RegExp(r' 2026$'), '');
          expect(dayMonth.hasMatch(withoutYear), isFalse, reason: text);
        }
      }
    }
  });

  test('the check fails on what DateFormat writes', () {
    final dayMonth = RegExp(r'\d [^\d\s]|[^\d\s,] \d');
    expect(dayMonth.hasMatch('12 mai'), isTrue);
    expect(dayMonth.hasMatch('May 12'), isTrue);
  });

  test('withUnit joins a figure and its unit with U+00A0', () {
    expect(withUnit('320', 'k€'), '320\u00A0k€');
    expect(withUnit('2,2', '×'), '2,2\u00A0×');
  });
}
