import 'package:finstride/core/theme/app_theme.dart';
import 'package:finstride/core/widgets/date_field.dart';
import 'package:finstride/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap({
  required TextEditingController controller,
  Locale locale = const Locale('fr'),
  DateTime? firstDate,
  DateTime? lastDate,
}) {
  return MaterialApp(
    locale: locale,
    theme: appDarkTheme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: DateField(
        key: const Key('field'),
        controller: controller,
        firstDate: firstDate ?? DateTime(2000),
        lastDate: lastDate ?? DateTime(2100),
        calendarTooltip: 'Choisir une date',
      ),
    ),
  );
}

void main() {
  testWidgets('the calendar writes the picked day into the field', (
    tester,
  ) async {
    final controller = TextEditingController(text: '14/05/2026');
    await tester.pumpWidget(_wrap(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.calendar_today_outlined));
    await tester.pumpAndSettle();

    // It opens on the date already typed rather than back on today, so a
    // calendar reached for mid-edit lands where the user was.
    expect(find.text('mai 2026'), findsOneWidget);

    await tester.tap(find.text('22'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(controller.text, '22/05/2026');
  });

  testWidgets('cancelling the calendar leaves the field alone', (tester) async {
    final controller = TextEditingController(text: '14/05/2026');
    await tester.pumpWidget(_wrap(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.calendar_today_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('22'));
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();

    expect(controller.text, '14/05/2026');
  });

  testWidgets('the date can still be typed', (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(_wrap(controller: controller));
    await tester.pumpAndSettle();

    // Someone entering a run of allocations knows the date and types it faster
    // than any calendar opens.
    await tester.enterText(find.byKey(const Key('field')), '12/03/2026');
    expect(parseDateInput(controller.text, 'fr'), DateTime(2026, 3, 12));
  });

  testWidgets('the calendar writes the en spelling under en', (tester) async {
    final controller = TextEditingController(text: '5/14/2026');
    await tester.pumpWidget(
      _wrap(controller: controller, locale: const Locale('en')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.calendar_today_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('22'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(controller.text, '5/22/2026');
  });

  testWidgets('takes only a date, and types the separators itself', (
    tester,
  ) async {
    final controller = TextEditingController();
    await tester.pumpWidget(_wrap(controller: controller));
    await tester.pumpAndSettle();

    // Eight digits are a date: the field puts the slashes in as each section
    // fills, so the user never types one.
    await tester.enterText(find.byKey(const Key('field')), '12032026');
    expect(controller.text, '12/03/2026');

    // Anything that is not that shape never reaches the field.
    for (final rejected in ['12 mars', '2026-03-12', 'today', '12/03/20267']) {
      await tester.enterText(find.byKey(const Key('field')), rejected);
      expect(controller.text, '12/03/2026', reason: rejected);
    }
  });

  testWidgets('takes the en shape under en', (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      _wrap(controller: controller, locale: const Locale('en')),
    );
    await tester.pumpAndSettle();

    // A single-digit month closes on the typed separator rather than waiting
    // for a second digit.
    await tester.enterText(find.byKey(const Key('field')), '5/14/2026');
    expect(controller.text, '5/14/2026');
    expect(parseDateInput(controller.text, 'en'), DateTime(2026, 5, 14));
  });

  group('parseDateInput', () {
    test('reads the locale spelling and nothing else', () {
      expect(parseDateInput('14/05/2026', 'fr'), DateTime(2026, 5, 14));
      expect(parseDateInput('5/14/2026', 'en'), DateTime(2026, 5, 14));
      // The French spelling is not the English one, and vice versa.
      expect(parseDateInput('14/05/2026', 'en'), isNull);
    });

    test('is strict rather than rolling an impossible date over', () {
      // `parse` would read this as February 2027; a form that silently books a
      // date the user did not type is worse than one that says it can't read it.
      expect(parseDateInput('32/13/2026', 'fr'), isNull);
      expect(parseDateInput('not a date', 'fr'), isNull);
    });

    test('treats an empty field as no date rather than a bad one', () {
      expect(parseDateInput('', 'fr'), isNull);
      expect(parseDateInput('   ', 'fr'), isNull);
    });
  });
}
