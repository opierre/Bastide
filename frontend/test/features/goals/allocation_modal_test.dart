import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/features/goals/application/goals_controller.dart';
import 'package:bastide/features/goals/presentation/allocation_modal.dart';
import 'package:bastide/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/goals_fixtures.dart';

Widget _wrap({
  required FakeGoalsController controller,
  Locale locale = const Locale('fr'),
  ThemeData? theme,
}) {
  return ProviderScope(
    overrides: [goalsControllerProvider.overrideWith(() => controller)],
    child: MaterialApp(
      locale: locale,
      theme: theme ?? AppTheme.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: AllocationModal(goal: testGoal(name: 'Voyage Japon')),
      ),
    ),
  );
}

void main() {
  for (final (name, theme) in [
    ('dark', AppTheme.dark),
    ('light', AppTheme.light),
  ]) {
    testWidgets('the v6 layout in the $name theme', (tester) async {
      await tester.pumpWidget(
        _wrap(
          controller: FakeGoalsController(initialGoals: const []),
          theme: theme,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nouvelle allocation'), findsOneWidget);
      // The goal's name is the lead: the only context the modal needs.
      expect(
        tester.widget<Text>(find.byKey(const Key('allocationGoalName'))).data,
        'Voyage Japon',
      );
      expect(find.text('Montant'), findsOneWidget);
      expect(find.text('Un montant négatif retire de l’objectif.'), findsOne);
      expect(find.text('Date'), findsOneWidget);
      expect(find.text('Note (facultative)'), findsOneWidget);
      expect(find.text('Ex. Virement mensuel'), findsOneWidget);
      expect(find.text('Annuler'), findsOneWidget);
      expect(find.text('Ajouter'), findsOneWidget);

      // One field per line, the full width of the body.
      final amount = tester.getRect(find.byKey(const Key('allocationAmount')));
      final date = tester.getRect(find.byKey(const Key('allocationDate')));
      final note = tester.getRect(find.byKey(const Key('allocationNote')));
      expect(date.top, greaterThan(amount.bottom));
      expect(note.top, greaterThan(date.bottom));
      expect(date.width, amount.width);
      expect(note.width, amount.width);

      final field = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const Key('allocationAmount')),
          matching: find.byType(TextField),
        ),
      );
      expect(field.textAlign, TextAlign.end);
    });
  }

  testWidgets('a negative amount is a withdrawal on the same ledger', (
    tester,
  ) async {
    final controller = FakeGoalsController(initialGoals: const []);
    await tester.pumpWidget(_wrap(controller: controller));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('allocationAmount')), '-150');
    await tester.enterText(
      find.byKey(const Key('allocationDate')),
      '01/05/2026',
    );
    await tester.enterText(
      find.byKey(const Key('allocationNote')),
      'Billets de train',
    );
    await tester.tap(find.byKey(const Key('allocationSubmit')));
    await tester.pumpAndSettle();

    expect(controller.allocateCalls, [
      ('g1', -15000, DateTime(2026, 5, 1), 'Billets de train'),
    ]);
  });

  testWidgets('an amount of zero is refused', (tester) async {
    final controller = FakeGoalsController(initialGoals: const []);
    await tester.pumpWidget(_wrap(controller: controller));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('allocationAmount')), '0');
    await tester.tap(find.byKey(const Key('allocationSubmit')));
    await tester.pumpAndSettle();

    expect(find.text('Saisissez un montant différent de zéro.'), findsOne);
    expect(controller.allocateCalls, isEmpty);
  });

  testWidgets('cancelling a filled allocation asks before dropping it', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(controller: FakeGoalsController(initialGoals: const [])),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('allocationAmount')), '400');
    await tester.pump();
    await tester.tap(find.byKey(const Key('allocationCancel')));
    await tester.pumpAndSettle();

    expect(find.text('Abandonner les modifications ?'), findsOneWidget);
  });

  testWidgets('English copy', (tester) async {
    await tester.pumpWidget(
      _wrap(
        controller: FakeGoalsController(initialGoals: const []),
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('New allocation'), findsOneWidget);
    expect(find.text('Note (optional)'), findsOneWidget);
    expect(find.text('Add'), findsOneWidget);
  });
}
