import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/core/theme/tokens.dart';
import 'package:bastide/core/widgets/amount_text.dart';
import 'package:bastide/core/widgets/repere_meter.dart';
import 'package:bastide/features/dashboard/application/dashboard_controller.dart';
import 'package:bastide/features/dashboard/application/dashboard_habits_provider.dart';
import 'package:bastide/features/dashboard/application/upcoming_charges_provider.dart';
import 'package:bastide/features/dashboard/domain/upcoming_charges.dart';
import 'package:bastide/features/dashboard/presentation/dashboard_screen.dart';
import 'package:bastide/features/dashboard/presentation/goals_section.dart';
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

/// One charge still due this month, so « À venir » shares the right half.
UpcomingCharges _oneCharge() => UpcomingCharges(
  through: DateTime(2026, 5, 31),
  totalMinor: -1799,
  due: [
    UpcomingDue(
      seriesId: 's1',
      label: 'Musiq Famille',
      amountMinor: -1799,
      logo: null,
      dueOn: DateTime(2026, 5, 22),
    ),
  ],
  missed: const [],
  currency: 'EUR',
);

Widget _wrap({
  required List<Goal> goals,
  UpcomingCharges? upcoming,
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
            hasTransactions: true,
          ),
        ),
      ),
      dashboardHabitsProvider.overrideWith((ref) async => specHabits()),
      goalsControllerProvider.overrideWith(
        () => FakeGoalsController(initialGoals: goals),
      ),
      upcomingChargesProvider.overrideWith(
        (ref) async => upcoming ?? (throw StateError('offline')),
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

Finder _byKey(String key) => find.byKey(Key(key));

void main() {
  testWidgets('alone on the right half: four 36 px one-line rows', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(_wrap(goals: specGoals()));
    await tester.pumpAndSettle();

    final section = tester.widget<GoalsSection>(find.byType(GoalsSection));
    expect(section.compact, isFalse);
    for (final id in ['g1', 'g2', 'g3', 'g4']) {
      expect(_byKey('dashboardGoalRow-$id'), findsOneWidget);
    }
    expect(find.text('Tous les objectifs'), findsOneWidget);
    expect(
      tester.getSize(_byKey('dashboardGoalRow-g1')).height,
      AppSizes.tableRow,
    );

    expect(
      _richText(tester, const Key('dashboardGoalAmounts-g1')),
      '${_money(640000)} / ${_money(1000000)}',
    );
    expect(
      tester.widget<Text>(_byKey('dashboardGoalPercent-g1')).data,
      contains('64'),
    );
    // One line: the repère, then the amounts, then the percent.
    final row = tester.getRect(_byKey('dashboardGoalRow-g1'));
    final meter = tester.getRect(_byKey('dashboardGoalMeter-g1'));
    final percent = tester.getRect(_byKey('dashboardGoalPercent-g1'));
    final amounts = tester.getRect(_byKey('dashboardGoalAmounts-g1'));
    expect(meter.center.dy, closeTo(row.center.dy, 1));
    expect(amounts.right, lessThan(percent.left));
    expect(meter.right, lessThan(amounts.left));
  });

  testWidgets('beside « À venir »: 48 px rows of two lines', (tester) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(_wrap(goals: specGoals(), upcoming: _oneCharge()));
    await tester.pumpAndSettle();

    final section = tester.widget<GoalsSection>(find.byType(GoalsSection));
    expect(section.compact, isTrue);
    expect(
      tester.getSize(_byKey('dashboardGoalRow-g1')).height,
      AppSizes.tableRowTwoLines,
    );

    final name = tester.getRect(
      find.descendant(
        of: _byKey('dashboardGoalRow-g1'),
        matching: find.text(specGoals().first.name),
      ),
    );
    final percent = tester.getRect(_byKey('dashboardGoalPercent-g1'));
    final meter = tester.getRect(_byKey('dashboardGoalMeter-g1'));
    final amounts = tester.getRect(_byKey('dashboardGoalAmounts-g1'));
    // Line 1: the name, the percent on the right.
    expect(percent.center.dy, closeTo(name.center.dy, 1));
    expect(percent.left, greaterThan(name.left));
    // Line 2: the repère filling the width, the amounts 12 px after it.
    expect(meter.top, greaterThan(name.bottom));
    expect(amounts.center.dy, closeTo(meter.center.dy, 1));
    expect(amounts.left - meter.right, closeTo(AppSpacing.smPlus, 0.5));
    expect(amounts.right, closeTo(percent.right, 0.5));
    expect(
      _richText(tester, const Key('dashboardGoalAmounts-g1')),
      '${_money(640000)} / ${_money(1000000)}',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a reached goal fills its repère in done', (tester) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(_wrap(goals: specGoals()));
    await tester.pumpAndSettle();

    RepereMeter meter(String id) =>
        tester.widget<RepereMeter>(_byKey('dashboardGoalMeter-$id'));
    expect(meter('g3').tone, RepereTone.done);
    expect(meter('g1').tone, RepereTone.normal);
    expect(meter('g1').fraction, closeTo(0.64, 0.001));
    // No mark: the end of the track is the target (`00` §8).
    expect(meter('g1').markFraction, isNull);
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
    expect(_byKey('dashboardGoalRow-g1'), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(DashboardScreen)),
    );
    await container.read(goalsControllerProvider.notifier).archive('g1');
    await tester.pumpAndSettle();

    expect(_byKey('dashboardGoalRow-g1'), findsNothing);
    expect(_byKey('dashboardGoalRow-g2'), findsOneWidget);
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
