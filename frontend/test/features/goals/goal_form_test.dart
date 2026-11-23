import 'dart:typed_data';

import 'package:bastide/core/session/current_user_provider.dart';
import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/features/auth/domain/auth_user.dart';
import 'package:bastide/features/goals/application/goals_controller.dart';
import 'package:bastide/features/goals/domain/goal.dart';
import 'package:bastide/features/goals/presentation/goal_form_modal.dart';
import 'package:bastide/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/goals_fixtures.dart';

/// Records what the form asked the controller to create, without a network.
class _RecordingGoalsController extends FakeGoalsController {
  _RecordingGoalsController() : super(initialGoals: const []);

  final createCalls = <(String, int, DateTime?)>[];

  @override
  Future<Goal> create({
    required String name,
    required int targetMinor,
    DateTime? targetDate,
    Uint8List? image,
  }) async {
    createCalls.add((name, targetMinor, targetDate));
    return testGoal(name: name, targetMinor: targetMinor, progressMinor: 0);
  }
}

Widget _wrap({
  required _RecordingGoalsController controller,
  Locale locale = const Locale('fr'),
  Goal? initial,
}) {
  return ProviderScope(
    overrides: [
      goalsControllerProvider.overrideWith(() => controller),
      currentUserProvider.overrideWithValue(
        const AuthUser(
          id: 'u1',
          email: 'chloe@example.com',
          displayName: 'Chloé Dubois',
          locale: 'fr',
          currency: 'EUR',
        ),
      ),
    ],
    child: MaterialApp(
      locale: locale,
      theme: AppTheme.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: GoalFormModal(initial: initial)),
    ),
  );
}

void main() {
  testWidgets('the target field carries the currency and takes digits only', (
    tester,
  ) async {
    final controller = _RecordingGoalsController();
    await tester.pumpWidget(_wrap(controller: controller));
    await tester.pumpAndSettle();

    final target = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('goalFormTarget')),
        matching: find.byType(TextField),
      ),
    );
    expect(target.decoration?.suffixText, 'EUR');

    // The field can only ever hold an amount, so it never has to say it wanted
    // one — and a target has no sign to give it. What it does hold is grouped
    // as it is typed, the way every other amount in the app is printed.
    await tester.enterText(find.byKey(const Key('goalFormTarget')), '10000');
    await tester.enterText(find.byKey(const Key('goalFormTarget')), '10000abc');
    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: find.byKey(const Key('goalFormTarget')),
              matching: find.byType(TextField),
            ),
          )
          .controller
          ?.text,
      '10\u202F000',
    );
    await tester.enterText(find.byKey(const Key('goalFormTarget')), '-5000');
    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: find.byKey(const Key('goalFormTarget')),
              matching: find.byType(TextField),
            ),
          )
          .controller
          ?.text,
      '10\u202F000',
    );
  });

  testWidgets('the deadline month is picked from a calendar', (tester) async {
    final controller = _RecordingGoalsController();
    await tester.pumpWidget(_wrap(controller: controller));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('goalFormName')),
      'Voyage Japon',
    );
    await tester.enterText(find.byKey(const Key('goalFormTarget')), '4000');

    await tester.tap(find.byIcon(LucideIcons300.calendar));
    await tester.pumpAndSettle();
    // The calendar opens on its years: a deadline is chosen by year first.
    await tester.tap(find.text('2030'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('22'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    final month = DateTime.now().month;
    expect(
      find.text('${month.toString().padLeft(2, '0')}/2030'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('goalFormSubmit')));
    await tester.pumpAndSettle();

    // Only the month is kept: the day picked is not one the panel shows.
    expect(controller.createCalls.single.$3, DateTime(2030, month));
  });

  testWidgets('creating sends the name, the target and the date', (
    tester,
  ) async {
    final controller = _RecordingGoalsController();
    await tester.pumpWidget(_wrap(controller: controller));
    await tester.pumpAndSettle();

    // A goal has no account, so the form never asks for one.
    expect(find.text('Compte'), findsNothing);

    await tester.enterText(
      find.byKey(const Key('goalFormName')),
      'Voyage Japon',
    );
    await tester.enterText(find.byKey(const Key('goalFormTarget')), '4000');
    await tester.enterText(find.byKey(const Key('goalFormDate')), '06/2026');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('goalFormSubmit')));
    await tester.pumpAndSettle();

    expect(controller.createCalls, [
      ('Voyage Japon', 400000, DateTime(2026, 6)),
    ]);
  });

  testWidgets('the target date is optional and the target must be positive', (
    tester,
  ) async {
    final controller = _RecordingGoalsController();
    await tester.pumpWidget(_wrap(controller: controller));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('goalFormName')),
      "Fonds d'urgence",
    );
    await tester.enterText(find.byKey(const Key('goalFormTarget')), '0');
    await tester.enterText(find.byKey(const Key('goalFormDate')), '');
    await tester.tap(find.byKey(const Key('goalFormSubmit')));
    await tester.pumpAndSettle();

    expect(find.text('Saisissez un montant supérieur à zéro.'), findsOneWidget);
    expect(controller.createCalls, isEmpty);

    await tester.enterText(find.byKey(const Key('goalFormTarget')), '10000');
    await tester.tap(find.byKey(const Key('goalFormSubmit')));
    await tester.pumpAndSettle();

    // No date is a goal with no deadline, not a validation failure.
    expect(controller.createCalls, [("Fonds d'urgence", 1000000, null)]);
  });

  testWidgets('the form reads its amount in the active locale', (tester) async {
    final controller = _RecordingGoalsController();
    await tester.pumpWidget(
      _wrap(controller: controller, locale: const Locale('en')),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('goalFormName')),
      'Emergency fund',
    );
    await tester.enterText(
      find.byKey(const Key('goalFormTarget')),
      '10,000.50',
    );
    await tester.enterText(find.byKey(const Key('goalFormDate')), '06/2026');
    await tester.tap(find.byKey(const Key('goalFormSubmit')));
    await tester.pumpAndSettle();

    expect(controller.createCalls.single.$2, 1000050);
    expect(controller.createCalls.single.$3, DateTime(2026, 6));
  });

  testWidgets('the v6 layout: optional fields say so in their label', (
    tester,
  ) async {
    final controller = _RecordingGoalsController();
    await tester.pumpWidget(_wrap(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('Nouvel objectif'), findsOneWidget);
    expect(find.text('Échéance (facultative)'), findsOneWidget);
    expect(find.text('Image (facultative)'), findsOneWidget);
    expect(find.text('Facultative'), findsNothing);
    expect(find.text('Annuler'), findsOneWidget);
    expect(find.text('Enregistrer'), findsOneWidget);
    // No picture yet: nothing to take back.
    expect(find.byKey(const Key('goalFormImageRemove')), findsNothing);
    expect(find.byIcon(LucideIcons300.image), findsOneWidget);

    // Montant cible and Échéance side by side, aligned by their input.
    final target = tester.getRect(find.byKey(const Key('goalFormTarget')));
    final date = tester.getRect(find.byKey(const Key('goalFormDate')));
    expect(target.top, date.top);
    expect(target.right, lessThan(date.left));

    // The target reads right-aligned, like every amount.
    final field = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('goalFormTarget')),
        matching: find.byType(TextField),
      ),
    );
    expect(field.textAlign, TextAlign.end);
  });

  testWidgets('a deadline that is not a month is refused', (tester) async {
    final controller = _RecordingGoalsController();
    await tester.pumpWidget(_wrap(controller: controller));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('goalFormName')), 'Vélo');
    await tester.enterText(find.byKey(const Key('goalFormTarget')), '900');
    await tester.enterText(find.byKey(const Key('goalFormDate')), '13/2026');
    await tester.tap(find.byKey(const Key('goalFormSubmit')));
    await tester.pumpAndSettle();

    expect(find.text('Saisissez un mois au format MM/AAAA.'), findsOneWidget);
    expect(controller.createCalls, isEmpty);
  });

  testWidgets('editing loads the deadline as a month', (tester) async {
    final controller = _RecordingGoalsController();
    await tester.pumpWidget(
      _wrap(
        controller: controller,
        initial: testGoal(targetDate: DateTime(2028, 6, 30)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Modifier l’objectif'), findsOneWidget);
    expect(find.text('06/2028'), findsOneWidget);
  });

  testWidgets('the edit modal has no « Supprimer »', (tester) async {
    // Deleting a goal is the inspector's trash tool button.
    await tester.pumpWidget(
      _wrap(controller: _RecordingGoalsController(), initial: testGoal()),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('goalFormModal')), findsOneWidget);
    expect(find.text('Supprimer'), findsNothing);
  });

  testWidgets('cancelling a filled form asks before dropping it', (
    tester,
  ) async {
    final controller = _RecordingGoalsController();
    await tester.pumpWidget(_wrap(controller: controller));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('goalFormName')), 'Vélo');
    await tester.pump();
    await tester.tap(find.byKey(const Key('goalFormCancel')));
    await tester.pumpAndSettle();

    expect(find.text('Abandonner les modifications ?'), findsOneWidget);
  });
}
