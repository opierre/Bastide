import 'package:finstride/core/theme/app_theme.dart';
import 'package:finstride/core/widgets/money_field.dart';
import 'package:finstride/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap({
  required TextEditingController controller,
  String currency = 'EUR',
  bool allowNegative = false,
  Locale locale = const Locale('fr'),
}) {
  return MaterialApp(
    locale: locale,
    theme: appDarkTheme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: MoneyField(
        key: const Key('field'),
        controller: controller,
        currency: currency,
        allowNegative: allowNegative,
      ),
    ),
  );
}

void main() {
  group('the field', () {
    testWidgets('prints the currency as a suffix inside the line edit', (
      tester,
    ) async {
      final controller = TextEditingController();
      await tester.pumpWidget(_wrap(controller: controller));
      await tester.pumpAndSettle();

      // Inside the field, not a labelled row of its own: the code is the unit
      // the figure is denominated in, never a value the form is asking for.
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.decoration?.suffixText, 'EUR');
    });

    testWidgets('prints no suffix before the profile currency is known', (
      tester,
    ) async {
      final controller = TextEditingController();
      await tester.pumpWidget(_wrap(controller: controller, currency: ''));
      await tester.pumpAndSettle();

      expect(
        tester.widget<TextField>(find.byType(TextField)).decoration?.suffixText,
        isNull,
      );
    });

    testWidgets('takes digits and the locale separators, refuses the rest', (
      tester,
    ) async {
      final controller = TextEditingController();
      await tester.pumpWidget(_wrap(controller: controller));
      await tester.pumpAndSettle();

      // However the thousands were spaced on the way in, they come back in the
      // locale's own grouping — the narrow no-break space French prints.
      await tester.enterText(find.byKey(const Key('field')), '10 000,50');
      expect(controller.text, '10\u202F000,50');

      // Letters, currency glyphs and arithmetic never reach the field.
      await tester.enterText(find.byKey(const Key('field')), 'abc');
      expect(controller.text, '10\u202F000,50');
      await tester.enterText(find.byKey(const Key('field')), '10€');
      expect(controller.text, '10\u202F000,50');
      await tester.enterText(find.byKey(const Key('field')), '1+2');
      expect(controller.text, '10\u202F000,50');
      // And not a second decimal separator.
      await tester.enterText(find.byKey(const Key('field')), '1,50,2');
      expect(controller.text, '10\u202F000,50');
    });

    testWidgets('groups the thousands as the amount is typed', (tester) async {
      final french = TextEditingController();
      await tester.pumpWidget(_wrap(controller: french));
      await tester.pumpAndSettle();

      // Typed bare, printed the way the same figure prints on a card or in the
      // transactions feed.
      await tester.enterText(find.byKey(const Key('field')), '1500000');
      expect(french.text, '1\u202F500\u202F000');
      // The decimals stay as typed — only the integer part is grouped.
      await tester.enterText(find.byKey(const Key('field')), '4000,5');
      expect(french.text, '4\u202F000,5');

      final english = TextEditingController();
      await tester.pumpWidget(
        _wrap(controller: english, locale: const Locale('en')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('field')), '1500000.50');
      expect(english.text, '1,500,000.50');
    });

    testWidgets('refuses a minus unless the amount is a signed one', (tester) async {
      final positive = TextEditingController();
      await tester.pumpWidget(_wrap(controller: positive));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('field')), '-150');
      expect(positive.text, isEmpty);

      final signed = TextEditingController();
      await tester.pumpWidget(
        _wrap(controller: signed, allowNegative: true),
      );
      await tester.pumpAndSettle();
      // The minus is the whole withdrawal mechanism on a goal allocation.
      await tester.enterText(find.byKey(const Key('field')), '-150');
      expect(signed.text, '-150');
      // Still only at the front: « 1-5 » is not an amount.
      await tester.enterText(find.byKey(const Key('field')), '1-5');
      expect(signed.text, '-150');
    });

    testWidgets('lets a half-typed amount through as it is being typed', (
      tester,
    ) async {
      final controller = TextEditingController();
      await tester.pumpWidget(_wrap(controller: controller, allowNegative: true));
      await tester.pumpAndSettle();

      // A formatter that rejected these would make the field impossible to type
      // into forwards; whether they are usable is the validator's question.
      for (final partial in ['-', '1', '1,', '1,5']) {
        await tester.enterText(find.byKey(const Key('field')), partial);
        expect(controller.text, partial);
      }
    });
  });

  group('parseMoneyMinor', () {
    test('reads the French spelling, however the space was typed', () {
      expect(parseMoneyMinor('10 000,50', 'fr'), 1000050);
      // U+00A0 and U+202F — what a paste from elsewhere in the app carries.
      expect(parseMoneyMinor('10\u00A0000,50', 'fr'), 1000050);
      expect(parseMoneyMinor('10\u202F000,50', 'fr'), 1000050);
      expect(parseMoneyMinor('4000', 'fr'), 400000);
    });

    test('reads the English spelling', () {
      expect(parseMoneyMinor('10,000.50', 'en'), 1000050);
      expect(parseMoneyMinor('4000', 'en'), 400000);
    });

    test('rounds to the minor unit rather than truncating', () {
      expect(parseMoneyMinor('1,005', 'fr'), 100);
      expect(parseMoneyMinor('0,999', 'fr'), 100);
    });

    test('refuses what is not an amount', () {
      expect(parseMoneyMinor('', 'fr'), isNull);
      expect(parseMoneyMinor('   ', 'fr'), isNull);
      expect(parseMoneyMinor('abc', 'fr'), isNull);
      expect(parseMoneyMinor(',', 'fr'), isNull);
    });

    test('refuses a negative unless the caller allows one', () {
      expect(parseMoneyMinor('-150', 'fr'), isNull);
      expect(parseMoneyMinor('-150', 'fr', allowNegative: true), -15000);
    });
  });

  group('formatMoneyInput', () {
    test('round-trips through the parser in both locales', () {
      for (final locale in ['fr', 'en']) {
        final text = formatMoneyInput(1000050, locale);
        expect(parseMoneyMinor(text, locale), 1000050, reason: locale);
      }
    });
  });
}
