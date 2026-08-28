import 'package:finstride/core/theme/app_theme.dart';
import 'package:finstride/core/widgets/amount_text.dart';
import 'package:finstride/features/dashboard/application/dashboard_controller.dart';
import 'package:finstride/features/dashboard/presentation/dashboard_screen.dart';
import 'package:finstride/features/dashboard/presentation/income_vs_expense.dart';
import 'package:finstride/features/dashboard/presentation/recent_activity.dart';
import 'package:finstride/features/goals/application/goals_controller.dart';
import 'package:finstride/features/goals/domain/goal.dart';
import 'package:finstride/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/dashboard_fixtures.dart';
import '../../support/fake_dashboard_controller.dart';
import '../../support/goals_fixtures.dart';

String _money(int amountMinor, {String locale = 'fr'}) =>
    formatAmount(amountMinor: amountMinor, currency: 'EUR', locale: locale);

Widget _wrap({
  required List<Goal> goals,
  Locale locale = const Locale('fr'),
}) {
  return ProviderScope(
    overrides: [
      dashboardControllerProvider.overrideWith(
        () => FakeDashboardController(
          initialState: DashboardState(
            month: DateTime(2026, 5),
            summary: specSummary(),
            trends: specTrends(),
            recent: specRecent(),
          ),
        ),
      ),
      goalsControllerProvider.overrideWith(
        () => FakeGoalsController(initialGoals: goals),
      ),
    ],
    child: MaterialApp(
      locale: locale,
      theme: appDarkTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: DashboardScreen()),
    ),
  );
}

void _useDesktopSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('row 3 gains the Objectifs card with the top three goals', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(_wrap(goals: specGoals()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dashboardGoalsCard')), findsOneWidget);
    expect(find.byKey(const Key('dashboardGoalRow-g1')), findsOneWidget);
    expect(find.byKey(const Key('dashboardGoalRow-g2')), findsOneWidget);
    expect(find.byKey(const Key('dashboardGoalRow-g3')), findsOneWidget);
    // Only three — the fourth goal of the grid stays on the panel.
    expect(find.byKey(const Key('dashboardGoalRow-g4')), findsNothing);

    expect(
      find.text('${_money(640000)} / ${_money(1000000)}'),
      findsOneWidget,
    );
    // A reached goal shows the badge in place of the amounts.
    expect(find.byKey(const Key('dashboardGoalReached-g3')), findsOneWidget);
    expect(find.byKey(const Key('dashboardGoalAmounts-g3')), findsNothing);

    // The two Phase 1 cards keep their content beside it.
    expect(find.byType(IncomeVsExpenseChart), findsOneWidget);
    expect(find.byType(RecentActivityCard), findsOneWidget);
  });

  testWidgets('the card is absent entirely when there are no goals', (tester) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(_wrap(goals: const []));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dashboardGoalsCard')), findsNothing);
    // Row 3 falls back to its two Phase 1 cards rather than holding a column
    // open for something the user hasn't created.
    expect(find.byType(IncomeVsExpenseChart), findsOneWidget);
    expect(find.byType(RecentActivityCard), findsOneWidget);
  });

  testWidgets('an archived goal leaves the dashboard card', (tester) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(goals: [testGoal(id: 'g1'), testGoal(id: 'g2', name: 'Voyage Japon')]),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dashboardGoalRow-g1')), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(DashboardScreen)),
    );
    await container.read(goalsControllerProvider.notifier).archive('g1');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dashboardGoalRow-g1')), findsNothing);
    expect(find.byKey(const Key('dashboardGoalRow-g2')), findsOneWidget);
  });

  testWidgets('the card formats its amounts for en', (tester) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(goals: [testGoal()], locale: const Locale('en')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Goals'), findsWidgets);
    expect(find.text('View all'), findsOneWidget);
    expect(
      find.text(
        '${_money(640000, locale: 'en')} / ${_money(1000000, locale: 'en')}',
      ),
      findsOneWidget,
    );
  });
}
