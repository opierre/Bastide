import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/core/theme/tokens.dart';
import 'package:bastide/features/dashboard/application/dashboard_band.dart';
import 'package:bastide/features/dashboard/application/dashboard_controller.dart';
import 'package:bastide/features/dashboard/application/dashboard_habits_provider.dart';
import 'package:bastide/features/dashboard/application/upcoming_charges_provider.dart';
import 'package:bastide/features/dashboard/domain/upcoming_charges.dart';
import 'package:bastide/features/dashboard/presentation/dashboard_screen.dart';
import 'package:bastide/features/dashboard/presentation/goals_section.dart';
import 'package:bastide/features/dashboard/presentation/upcoming_charges_section.dart';
import 'package:bastide/features/goals/application/goals_controller.dart';
import 'package:bastide/features/goals/domain/goal.dart';
import 'package:bastide/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/dashboard_fixtures.dart';
import '../../support/fake_dashboard_controller.dart';
import '../../support/goals_fixtures.dart';

/// Two charges still due this month.
UpcomingCharges _upcoming() => UpcomingCharges(
  through: DateTime(2026, 5, 31),
  totalMinor: -3348,
  due: [
    UpcomingDue(
      seriesId: 's1',
      label: 'Streamco',
      amountMinor: -1549,
      logo: null,
      dueOn: DateTime(2026, 5, 15),
    ),
    UpcomingDue(
      seriesId: 's2',
      label: 'Musiq Famille',
      amountMinor: -1799,
      logo: null,
      dueOn: DateTime(2026, 5, 22),
    ),
  ],
  missed: const [],
  currency: 'EUR',
);

/// Nothing left to charge this month.
UpcomingCharges _nothingDue() => UpcomingCharges(
  through: DateTime(2026, 5, 31),
  totalMinor: 0,
  due: const [],
  missed: const [],
  currency: 'EUR',
);

class _Probe extends StatelessWidget {
  const _Probe(this.location);

  final String location;

  @override
  Widget build(BuildContext context) =>
      Text(location, key: const Key('routeProbe'));
}

/// [upcoming] `null` stands for a failed load.
Widget _wrap({
  required List<Goal> goals,
  required UpcomingCharges? upcoming,
  Locale locale = const Locale('fr'),
}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(body: DashboardScreen()),
      ),
      for (final path in ['/subscriptions', '/goals', '/transactions'])
        GoRoute(path: path, builder: (context, state) => _Probe(path)),
    ],
  );
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
    child: MaterialApp.router(
      locale: locale,
      theme: AppTheme.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required List<Goal> goals,
  required UpcomingCharges? upcoming,
  Locale locale = const Locale('fr'),
}) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    _wrap(goals: goals, upcoming: upcoming, locale: locale),
  );
  await tester.pumpAndSettle();
}

Finder _byKey(String key) => find.byKey(Key(key));

/// No shell in this harness: the content is the window less its margins.
const _content = 1440 - 2 * AppSpacing.pageX;
const _half = (_content - AppSpacing.gutter) / 2;
const _quarter = (_half - AppSpacing.gutter) / 2;

void main() {
  group('layout', () {
    test('follows what the side blocks have to show', () {
      final goals = specGoals();
      expect(
        DashboardBand(goals: goals, upcoming: _upcoming()).layout,
        DashboardBandLayout.goalsAndUpcoming,
      );
      expect(
        DashboardBand(goals: goals, upcoming: null).layout,
        DashboardBandLayout.goalsOnly,
      );
      expect(
        DashboardBand(goals: const [], upcoming: _upcoming()).layout,
        DashboardBandLayout.upcomingOnly,
      );
      expect(
        const DashboardBand(goals: [], upcoming: null).layout,
        DashboardBandLayout.habitsOnly,
      );
    });

    test('nothing left to charge hides « À venir »', () async {
      final container = ProviderContainer(
        overrides: [
          goalsControllerProvider.overrideWith(
            () => FakeGoalsController(initialGoals: specGoals()),
          ),
          upcomingChargesProvider.overrideWith((ref) async => _nothingDue()),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(dashboardBandProvider, (_, _) {});
      addTearDown(sub.close);
      await container.read(goalsControllerProvider.future);
      await container.read(upcomingChargesProvider.future);

      final band = container.read(dashboardBandProvider);
      expect(band.upcoming, isNull);
      expect(band.goals, hasLength(4));
      expect(band.layout, DashboardBandLayout.goalsOnly);
    });
  });

  testWidgets(
    'both: habits on the left half, « Objectifs » beside « À venir »',
    (tester) async {
      await _pump(tester, goals: specGoals(), upcoming: _upcoming());

      final habits = tester.getRect(_byKey('dashboardHabits'));
      final goals = tester.getRect(find.byType(GoalsSection));
      final upcoming = tester.getRect(find.byType(UpcomingChargesSection));
      expect(habits.width, closeTo(_half, 1));
      expect(goals.left - habits.right, closeTo(AppSpacing.gutter, 1));
      expect(goals.width, closeTo(_quarter, 1));
      expect(upcoming.left - goals.right, closeTo(AppSpacing.gutter, 1));
      expect(upcoming.width, closeTo(_quarter, 1));
      expect(goals.top, habits.top);
      expect(upcoming.top, habits.top);
      expect(
        tester.widget<GoalsSection>(find.byType(GoalsSection)).compact,
        true,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('no charge left: « Objectifs » takes the right half', (
    tester,
  ) async {
    await _pump(tester, goals: specGoals(), upcoming: _nothingDue());

    expect(find.byType(UpcomingChargesSection), findsNothing);
    final habits = tester.getRect(_byKey('dashboardHabits'));
    final goals = tester.getRect(find.byType(GoalsSection));
    expect(habits.width, closeTo(_half, 1));
    expect(goals.width, closeTo(_half, 1));
    expect(goals.top, habits.top);
    expect(
      tester.widget<GoalsSection>(find.byType(GoalsSection)).compact,
      false,
    );
  });

  testWidgets('no recurring series (a failed load too): « Objectifs » takes '
      'the right half', (tester) async {
    await _pump(tester, goals: specGoals(), upcoming: null);

    expect(find.byType(UpcomingChargesSection), findsNothing);
    expect(tester.getSize(find.byType(GoalsSection)).width, closeTo(_half, 1));
  });

  testWidgets('no active goal: « À venir » takes the right half', (
    tester,
  ) async {
    await _pump(tester, goals: const [], upcoming: _upcoming());

    expect(find.byType(GoalsSection), findsNothing);
    final habits = tester.getRect(_byKey('dashboardHabits'));
    final upcoming = tester.getRect(find.byType(UpcomingChargesSection));
    expect(habits.width, closeTo(_half, 1));
    expect(upcoming.width, closeTo(_half, 1));
    expect(upcoming.top, habits.top);
    // Same 48 px rows.
    expect(
      tester.getSize(_byKey('dashboardUpcomingRow-s1')).height,
      AppSizes.tableRowTwoLines,
    );
  });

  testWidgets('neither: the habits block takes the full width', (tester) async {
    await _pump(tester, goals: const [], upcoming: _nothingDue());

    expect(find.byType(GoalsSection), findsNothing);
    expect(find.byType(UpcomingChargesSection), findsNothing);
    expect(_byKey('dashboardBandRight'), findsNothing);
    expect(
      tester.getSize(_byKey('dashboardHabits')).width,
      closeTo(_content, 1),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('« Activité récente » is gone', (tester) async {
    for (final locale in const [Locale('fr'), Locale('en')]) {
      await _pump(
        tester,
        goals: specGoals(),
        upcoming: _upcoming(),
        locale: locale,
      );
      expect(find.text('Activité récente'), findsNothing);
      expect(find.text('Toutes les transactions'), findsNothing);
      expect(find.text('Recent activity'), findsNothing);
      expect(find.text('All transactions'), findsNothing);
    }
  });

  testWidgets('a goal row opens Objectifs with that goal selected', (
    tester,
  ) async {
    await _pump(tester, goals: specGoals(), upcoming: _upcoming());
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DashboardScreen)),
    );

    await tester.tap(_byKey('dashboardGoalRow-g2'));
    await tester.pumpAndSettle();

    expect(container.read(selectedGoalProvider), 'g2');
    expect(find.text('/goals'), findsOneWidget);
  });

  testWidgets('« Tous les objectifs » opens Objectifs', (tester) async {
    await _pump(tester, goals: specGoals(), upcoming: null);

    await tester.tap(_byKey('dashboardGoalsViewAll'));
    await tester.pumpAndSettle();

    expect(find.text('/goals'), findsOneWidget);
  });
}
