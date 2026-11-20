import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/core/widgets/amount_text.dart';
import 'package:bastide/core/widgets/repere_meter.dart';
import 'package:bastide/features/dashboard/application/dashboard_controller.dart';
import 'package:bastide/features/dashboard/presentation/dashboard_screen.dart';
import 'package:bastide/features/dashboard/presentation/goals_section.dart';
import 'package:bastide/features/dashboard/presentation/recent_activity.dart';
import 'package:bastide/features/goals/application/goals_controller.dart';
import 'package:bastide/features/goals/domain/goal.dart';
import 'package:bastide/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/dashboard_fixtures.dart';
import '../../support/fake_dashboard_controller.dart';
import '../../support/goals_fixtures.dart';

String _money(int amountMinor, {String locale = 'fr'}) =>
    formatAmount(amountMinor: amountMinor, currency: 'EUR', locale: locale);

Widget _wrap({required List<Goal> goals, Locale locale = const Locale('fr')}) {
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
      theme: AppTheme.dark,
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

String _richText(WidgetTester tester, Key key) =>
    tester.widget<Text>(find.byKey(key)).textSpan!.toPlainText();

void main() {
  testWidgets('Objectifs lists four goals beside the recent activity', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(_wrap(goals: specGoals()));
    await tester.pumpAndSettle();

    expect(find.byType(GoalsSection), findsOneWidget);
    for (final id in ['g1', 'g2', 'g3', 'g4']) {
      expect(find.byKey(Key('dashboardGoalRow-$id')), findsOneWidget);
    }
    expect(find.text('Tous les objectifs'), findsOneWidget);

    expect(
      _richText(tester, const Key('dashboardGoalAmounts-g1')),
      '${_money(640000)} / ${_money(1000000)}',
    );
    expect(find.byKey(const Key('dashboardGoalPercent-g1')), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('dashboardGoalPercent-g1')))
          .data,
      contains('64'),
    );

    // The two sections share the row evenly.
    final recent = tester.getSize(find.byType(RecentActivity)).width;
    final goals = tester.getSize(find.byType(GoalsSection)).width;
    expect(recent / goals, closeTo(1.0, 0.02));
  });

  testWidgets('a reached goal fills its repère in done', (tester) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(_wrap(goals: specGoals()));
    await tester.pumpAndSettle();

    RepereMeter meter(String id) =>
        tester.widget<RepereMeter>(find.byKey(Key('dashboardGoalMeter-$id')));
    expect(meter('g3').tone, RepereTone.done);
    expect(meter('g1').tone, RepereTone.normal);
    expect(meter('g1').fraction, closeTo(0.64, 0.001));
    // No mark: the end of the track is the target (`00` §8).
    expect(meter('g1').markFraction, isNull);
  });

  testWidgets('without goals the section is absent and activity takes the '
      'full width', (tester) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(_wrap(goals: const []));
    await tester.pumpAndSettle();

    expect(find.byType(GoalsSection), findsNothing);
    // No shell in this harness: the content is the window less its margins.
    expect(
      tester.getSize(find.byType(RecentActivity)).width,
      closeTo(1440 - 64, 1),
    );
  });

  testWidgets('an archived goal leaves the dashboard', (tester) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        goals: [
          testGoal(id: 'g1'),
          testGoal(id: 'g2', name: 'Voyage Japon'),
        ],
      ),
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

  testWidgets('the section formats its amounts for en', (tester) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(goals: [testGoal()], locale: const Locale('en')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Goals'), findsWidgets);
    expect(find.text('All goals'), findsOneWidget);
    expect(
      _richText(tester, const Key('dashboardGoalAmounts-g1')),
      '${_money(640000, locale: 'en')} / ${_money(1000000, locale: 'en')}',
    );
  });
}
