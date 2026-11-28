import 'package:bastide/core/l10n/date_display.dart';
import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/core/theme/tokens.dart';
import 'package:bastide/core/widgets/amount_text.dart';
import 'package:bastide/core/widgets/status_text.dart';
import 'package:bastide/features/dashboard/application/dashboard_controller.dart';
import 'package:bastide/features/dashboard/application/upcoming_charges_provider.dart';
import 'package:bastide/features/dashboard/domain/upcoming_charges.dart';
import 'package:bastide/features/dashboard/presentation/dashboard_screen.dart';
import 'package:bastide/features/dashboard/presentation/goals_section.dart';
import 'package:bastide/features/dashboard/presentation/upcoming_charges_section.dart';
import 'package:bastide/features/goals/application/goals_controller.dart';
import 'package:bastide/features/goals/domain/goal.dart';
import 'package:bastide/features/recurring/application/subscriptions_controller.dart';
import 'package:bastide/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../support/dashboard_fixtures.dart';
import '../../support/fake_dashboard_controller.dart';
import '../../support/goals_fixtures.dart';

const _nbsp = noBreakSpace;

/// Two charges still due, the first one up by 2,00 €, and one missed.
UpcomingCharges _upcoming({
  List<UpcomingDue>? due,
  List<UpcomingMissed>? missed,
}) {
  final dueRows =
      due ??
      [
        UpcomingDue(
          seriesId: 's1',
          label: 'Streamco',
          amountMinor: -1549,
          logo: null,
          dueOn: DateTime(2026, 5, 15),
          priceIncreaseMinor: -200,
        ),
        UpcomingDue(
          seriesId: 's2',
          label: 'Musiq Famille',
          amountMinor: -1799,
          logo: null,
          dueOn: DateTime(2026, 5, 22),
        ),
      ];
  return UpcomingCharges(
    through: DateTime(2026, 5, 31),
    totalMinor: dueRows.fold(0, (sum, row) => sum + row.amountMinor),
    due: dueRows,
    missed:
        missed ??
        [
          UpcomingMissed(
            seriesId: 's3',
            label: 'Forme Club',
            amountMinor: -2999,
            logo: null,
            expectedOn: DateTime(2026, 5, 5),
          ),
        ],
    currency: 'EUR',
  );
}

class _Probe extends StatelessWidget {
  const _Probe(this.location);

  final String location;

  @override
  Widget build(BuildContext context) =>
      Text(location, key: const Key('routeProbe'));
}

Widget _wrap({
  required UpcomingCharges? upcoming,
  List<Goal> goals = const [],
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
            recent: specRecent(),
          ),
        ),
      ),
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
  required UpcomingCharges? upcoming,
  List<Goal> goals = const [],
  Locale locale = const Locale('fr'),
}) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    _wrap(upcoming: upcoming, goals: goals, locale: locale),
  );
  await tester.pumpAndSettle();
}

Finder _byKey(String key) => find.byKey(Key(key));

String _money(int minor, {String locale = 'fr'}) =>
    formatAmount(amountMinor: minor, currency: 'EUR', locale: locale);

String _statusLabel(WidgetTester tester, String key) =>
    tester.widget<StatusText>(_byKey(key)).label;

void main() {
  testWidgets('heading reads the month end and the total without the missed '
      'charge', (tester) async {
    await _pump(tester, upcoming: _upcoming());

    expect(find.text('À venir d’ici le 31${_nbsp}mai'), findsOneWidget);
    // −15,49 € − 17,99 €: the missed −29,99 € stays out.
    expect(
      tester.widget<Text>(_byKey('dashboardUpcomingTotal')).data,
      _money(-3348),
    );
    expect(find.text('Tous les abonnements'), findsOneWidget);
  });

  testWidgets('a plain due charge shows its date in textTertiary', (
    tester,
  ) async {
    await _pump(tester, upcoming: _upcoming());

    final date = tester.widget<Text>(_byKey('dashboardUpcomingDate-s2'));
    expect(date.data, '22${_nbsp}mai');
    expect(date.style?.color, AppColors.dark.textTertiary);
    final amount = tester.widget<Text>(_byKey('dashboardUpcomingAmount-s2'));
    expect(amount.data, _money(-1799));
    // `text`, not sign-coloured.
    expect(amount.style, isNull);
  });

  testWidgets('a price rise says so in warning status text, unsigned', (
    tester,
  ) async {
    await _pump(tester, upcoming: _upcoming());

    final rise = tester.widget<StatusText>(_byKey('dashboardUpcomingRise-s1'));
    expect(rise.tone, StatusTone.warning);
    expect(rise.icon, LucideIcons300.trendingUp);
    expect(rise.label, '15${_nbsp}mai · hausse de ${_money(200)}');
    expect(
      tester.widget<Text>(_byKey('dashboardUpcomingAmount-s1')).data,
      _money(-1549),
    );
  });

  testWidgets('a missed charge comes last, dimmed, with its expected date', (
    tester,
  ) async {
    await _pump(tester, upcoming: _upcoming());

    final missed = tester.widget<StatusText>(
      _byKey('dashboardUpcomingMissed-s3'),
    );
    expect(missed.tone, StatusTone.warning);
    expect(missed.icon, LucideIcons300.clockAlert);
    expect(missed.label, 'Attendu le 5${_nbsp}mai');
    final amount = tester.widget<Text>(_byKey('dashboardUpcomingAmount-s3'));
    expect(amount.data, _money(-2999));
    expect(amount.style?.color, AppColors.dark.textTertiary);

    final ys = [
      for (final id in ['s1', 's2', 's3'])
        tester.getTopLeft(_byKey('dashboardUpcomingRow-$id')).dy,
    ];
    expect(ys[0], lessThan(ys[1]));
    expect(ys[1], lessThan(ys[2]));
    expect(tester.getSize(_byKey('dashboardUpcomingRow-s1')).height, 48);
  });

  testWidgets('reads in English', (tester) async {
    await _pump(tester, upcoming: _upcoming(), locale: const Locale('en'));

    expect(find.text('Due by May${_nbsp}31'), findsOneWidget);
    expect(
      tester.widget<Text>(_byKey('dashboardUpcomingTotal')).data,
      _money(-3348, locale: 'en'),
    );
    expect(
      _statusLabel(tester, 'dashboardUpcomingRise-s1'),
      'May${_nbsp}15 · up ${_money(200, locale: 'en')}',
    );
    expect(
      _statusLabel(tester, 'dashboardUpcomingMissed-s3'),
      'Expected on May${_nbsp}5',
    );
    expect(find.text('All subscriptions'), findsOneWidget);
  });

  testWidgets('sits right of the goals, on the right edge of the band', (
    tester,
  ) async {
    await _pump(tester, upcoming: _upcoming(), goals: specGoals());

    final goals = tester.getRect(find.byType(GoalsSection));
    final upcoming = tester.getRect(find.byType(UpcomingChargesSection));
    expect(upcoming.left, greaterThan(goals.right));
    expect(upcoming.top, goals.top);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a row opens its series in Abonnements', (tester) async {
    await _pump(tester, upcoming: _upcoming());
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DashboardScreen)),
    );

    await tester.tap(_byKey('dashboardUpcomingRow-s2'));
    await tester.pumpAndSettle();

    expect(container.read(selectedSeriesProvider), 's2');
    expect(find.text('/subscriptions'), findsOneWidget);
  });

  testWidgets('« Tous les abonnements » opens Abonnements', (tester) async {
    await _pump(tester, upcoming: _upcoming());

    await tester.tap(_byKey('dashboardUpcomingViewAll'));
    await tester.pumpAndSettle();

    expect(find.text('/subscriptions'), findsOneWidget);
  });

  testWidgets('hidden when nothing is left to charge, or on a failed load', (
    tester,
  ) async {
    await _pump(
      tester,
      upcoming: _upcoming(due: const [], missed: const []),
    );
    expect(find.byType(UpcomingChargesSection), findsNothing);

    await _pump(tester, upcoming: null);
    expect(find.byType(UpcomingChargesSection), findsNothing);
  });

  testWidgets('shows at most four rows', (tester) async {
    await _pump(
      tester,
      upcoming: _upcoming(
        due: [
          for (var day = 10; day < 16; day++)
            UpcomingDue(
              seriesId: 'd$day',
              label: 'Série $day',
              amountMinor: -500,
              logo: null,
              dueOn: DateTime(2026, 5, day),
            ),
        ],
        missed: const [],
      ),
    );

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(
              'dashboardUpcomingRow-',
            ),
      ),
      findsNWidgets(UpcomingCharges.maxRows),
    );
    // The total still counts the six.
    expect(
      tester.widget<Text>(_byKey('dashboardUpcomingTotal')).data,
      _money(-3000),
    );
  });
}
