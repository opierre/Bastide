import 'package:finstride/core/theme/app_theme.dart';
import 'package:finstride/core/widgets/amount_text.dart';
import 'package:finstride/features/goals/application/goals_controller.dart';
import 'package:finstride/features/goals/domain/goal.dart';
import 'package:finstride/features/goals/domain/goal_allocation.dart';
import 'package:finstride/features/goals/presentation/goals_screen.dart';
import 'package:finstride/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/goals_fixtures.dart';

String _money(int amountMinor, {String locale = 'fr'}) => formatAmount(
  amountMinor: amountMinor,
  currency: 'EUR',
  locale: locale,
  showPositiveSign: true,
);

Widget _wrap({
  required FakeGoalsController controller,
  List<GoalAllocation> allocations = const [],
  String openGoalId = 'g1',
  Locale locale = const Locale('fr'),
}) {
  return ProviderScope(
    overrides: [
      goalsControllerProvider.overrideWith(() => controller),
      goalAllocationsProvider.overrideWith((ref, id) async => allocations),
      selectedGoalProvider.overrideWith(() => _OpenGoal(openGoalId)),
    ],
    child: MaterialApp(
      locale: locale,
      theme: appDarkTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: GoalsScreen()),
    ),
  );
}

/// The panel already showing one goal in detail — the state the grid's card tap
/// puts it in.
class _OpenGoal extends SelectedGoal {
  _OpenGoal(this.goalId);

  final String goalId;

  @override
  String? build() => goalId;
}

void _useDesktopSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('the header shows the ring, the figures and no account', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(controller: FakeGoalsController(initialGoals: [testGoal()])),
    );
    await tester.pumpAndSettle();

    expect(find.text("Fonds d'urgence"), findsOneWidget);
    expect(find.text('64 %'), findsOneWidget);
    expect(find.text('Sans échéance'), findsOneWidget);
    expect(find.textContaining('BNP'), findsNothing);
    expect(
      find.text(
        'Aucune transaction n\'est créée : ces lignes n\'existent que sur '
        "le papier de l'objectif.",
      ),
      findsOneWidget,
    );
  });

  testWidgets('the history is one signed list, and a line can be removed', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    final controller = FakeGoalsController(initialGoals: [testGoal()]);
    await tester.pumpWidget(
      _wrap(
        controller: controller,
        allocations: [
          testAllocation(id: 'al1', allocatedOn: DateTime(2026, 5, 1)),
          testAllocation(
            id: 'al2',
            amountMinor: -15000,
            allocatedOn: DateTime(2026, 3, 12),
            note: 'Réparation voiture',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('01/05/2026'), findsOneWidget);
    expect(find.text(_money(30000)), findsOneWidget);
    // A withdrawal is a negative line in the same list, not a second history.
    expect(find.text(_money(-15000)), findsOneWidget);
    expect(find.text('Réparation voiture'), findsOneWidget);

    await tester.tap(find.byKey(const Key('goalAllocationDelete-al2')));
    await tester.pumpAndSettle();

    expect(controller.deleteAllocationCalls, [('g1', 'al2')]);
  });

  testWidgets(
    'the allocation modal submits a negative amount through one field',
    (tester) async {
      _useDesktopSurface(tester);
      final controller = FakeGoalsController(initialGoals: [testGoal()]);
      await tester.pumpWidget(_wrap(controller: controller));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('goalAllocateButton')));
      await tester.pumpAndSettle();

      // The goal's name is the only context on the modal — no account.
      expect(find.byKey(const Key('allocationGoalName')), findsOneWidget);
      expect(
        find.text('Un montant négatif retire de l\'objectif.'),
        findsOneWidget,
      );

      await tester.enterText(find.byKey(const Key('allocationAmount')), '-150');
      await tester.enterText(
        find.byKey(const Key('allocationDate')),
        '12/03/2026',
      );
      await tester.enterText(
        find.byKey(const Key('allocationNote')),
        'Réparation voiture',
      );
      await tester.tap(find.byKey(const Key('allocationSubmit')));
      await tester.pumpAndSettle();

      expect(controller.allocateCalls, [
        ('g1', -15000, DateTime(2026, 3, 12), 'Réparation voiture'),
      ]);
    },
  );

  testWidgets('archiving is offered from the detail header', (tester) async {
    _useDesktopSurface(tester);
    final controller = FakeGoalsController(initialGoals: [testGoal()]);
    await tester.pumpWidget(_wrap(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('Archiver'), findsOneWidget);
    await tester.tap(find.byKey(const Key('goalArchiveButton')));
    await tester.pumpAndSettle();

    expect(controller.archiveCalls, ['g1']);
  });

  testWidgets('an archived goal offers restore in the same slot', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    final controller = FakeGoalsController(
      initialGoals: [testGoal(id: 'g2')],
      archivedGoals: [
        testGoal(name: 'Vieux projet', status: GoalStatus.archived),
      ],
    );
    await tester.pumpWidget(_wrap(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('Restaurer'), findsOneWidget);
    await tester.tap(find.byKey(const Key('goalArchiveButton')));
    await tester.pumpAndSettle();

    expect(controller.restoreCalls, ['g1']);
  });

  testWidgets(
    'a reached goal keeps its ring green and is not archived for it',
    (tester) async {
      _useDesktopSurface(tester);
      final controller = FakeGoalsController(
        initialGoals: [
          testGoal(progressMinor: 1000000, status: GoalStatus.reached),
        ],
      );
      await tester.pumpWidget(_wrap(controller: controller));
      await tester.pumpAndSettle();

      expect(find.text('100 %'), findsOneWidget);
      // Reaching a target is the rewarding moment, not a filing event: the goal
      // is still on the panel and « Archiver » is still the user's to press.
      expect(find.text('Archiver'), findsOneWidget);
      expect(controller.archiveCalls, isEmpty);
    },
  );
}
