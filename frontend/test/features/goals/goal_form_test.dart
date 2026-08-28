import 'package:finstride/core/session/current_user_provider.dart';
import 'package:finstride/core/theme/app_theme.dart';
import 'package:finstride/features/auth/domain/auth_user.dart';
import 'package:finstride/features/goals/application/goals_controller.dart';
import 'package:finstride/features/goals/domain/goal.dart';
import 'package:finstride/features/goals/presentation/goal_form_modal.dart';
import 'package:finstride/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/goals_fixtures.dart';

/// Records what the form asked the controller to create, without a network.
class _RecordingGoalsController extends FakeGoalsController {
  _RecordingGoalsController() : super(initialGoals: const []);

  final createCalls = <(String, int, DateTime?, String, String)>[];

  @override
  Future<Goal> create({
    required String name,
    required int targetMinor,
    required String icon,
    required String color,
    DateTime? targetDate,
  }) async {
    createCalls.add((name, targetMinor, targetDate, icon, color));
    return testGoal(name: name, targetMinor: targetMinor, progressMinor: 0);
  }
}

Widget _wrap({
  required _RecordingGoalsController controller,
  Locale locale = const Locale('fr'),
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
      theme: appDarkTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: GoalFormModal()),
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
    // one — and a target has no sign to give it.
    await tester.enterText(find.byKey(const Key('goalFormTarget')), '10000');
    await tester.enterText(find.byKey(const Key('goalFormTarget')), '10000abc');
    expect(
      tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const Key('goalFormTarget')),
          matching: find.byType(TextField),
        ),
      ).controller?.text,
      '10000',
    );
    await tester.enterText(find.byKey(const Key('goalFormTarget')), '-5000');
    expect(
      tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const Key('goalFormTarget')),
          matching: find.byType(TextField),
        ),
      ).controller?.text,
      '10000',
    );
  });

  testWidgets('the target date is picked from a calendar', (tester) async {
    final controller = _RecordingGoalsController();
    await tester.pumpWidget(_wrap(controller: controller));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('goalFormName')), 'Voyage Japon');
    await tester.enterText(find.byKey(const Key('goalFormTarget')), '4000');

    await tester.tap(find.byIcon(Icons.calendar_today_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('22'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('goalFormSubmit')));
    await tester.pumpAndSettle();

    // Whatever month the calendar opened on, it is the 22nd that was submitted.
    expect(controller.createCalls.single.$3?.day, 22);
  });

  testWidgets('creating sends the name, the target, the date and the picks', (
    tester,
  ) async {
    final controller = _RecordingGoalsController();
    await tester.pumpWidget(_wrap(controller: controller));
    await tester.pumpAndSettle();

    // A goal has no account, so the form never asks for one.
    expect(find.text('Compte'), findsNothing);

    await tester.enterText(find.byKey(const Key('goalFormName')), 'Voyage Japon');
    await tester.enterText(find.byKey(const Key('goalFormTarget')), '4000');
    await tester.enterText(find.byKey(const Key('goalFormDate')), '30/06/2026');
    await tester.tap(find.byKey(const Key('goalFormIcon-travel')));
    await tester.tap(find.byKey(const Key('goalFormColor-#4FD1E8')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('goalFormSubmit')));
    await tester.pumpAndSettle();

    expect(controller.createCalls, [
      ('Voyage Japon', 400000, DateTime(2026, 6, 30), 'travel', '#4FD1E8'),
    ]);
  });

  testWidgets('the target date is optional and the target must be positive', (
    tester,
  ) async {
    final controller = _RecordingGoalsController();
    await tester.pumpWidget(_wrap(controller: controller));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('goalFormName')), "Fonds d'urgence");
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
    expect(controller.createCalls, [
      ("Fonds d'urgence", 1000000, null, 'flag', '#8B8CF9'),
    ]);
  });

  testWidgets('the form reads its amount in the active locale', (tester) async {
    final controller = _RecordingGoalsController();
    await tester.pumpWidget(
      _wrap(controller: controller, locale: const Locale('en')),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('goalFormName')), 'Emergency fund');
    await tester.enterText(find.byKey(const Key('goalFormTarget')), '10,000.50');
    await tester.enterText(find.byKey(const Key('goalFormDate')), '6/30/2026');
    await tester.tap(find.byKey(const Key('goalFormSubmit')));
    await tester.pumpAndSettle();

    expect(controller.createCalls.single.$2, 1000050);
    expect(controller.createCalls.single.$3, DateTime(2026, 6, 30));
  });
}
