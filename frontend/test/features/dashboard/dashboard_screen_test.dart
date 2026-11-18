import 'package:bastide/core/navigation/sidebar_controller.dart';
import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/core/theme/tokens.dart';
import 'package:bastide/core/widgets/amount_text.dart';
import 'package:bastide/core/widgets/app_card.dart';
import 'package:bastide/core/widgets/app_shell.dart';
import 'package:bastide/core/widgets/category_label.dart';
import 'package:bastide/core/widgets/primary_button.dart';
import 'package:bastide/core/widgets/repere_meter.dart';
import 'package:bastide/core/widgets/state_views.dart';
import 'package:bastide/features/dashboard/application/dashboard_controller.dart';
import 'package:bastide/features/dashboard/domain/dashboard_summary.dart';
import 'package:bastide/features/dashboard/domain/dashboard_trends.dart';
import 'package:bastide/features/dashboard/presentation/category_breakdown.dart';
import 'package:bastide/features/dashboard/presentation/dashboard_screen.dart';
import 'package:bastide/features/dashboard/presentation/income_vs_expense.dart';
import 'package:bastide/features/dashboard/presentation/kpi_strip.dart';
import 'package:bastide/features/dashboard/presentation/recent_activity.dart';
import 'package:bastide/features/dashboard/presentation/savings_chart.dart';
import 'package:bastide/features/dashboard/presentation/savings_trend.dart';
import 'package:bastide/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/dashboard_fixtures.dart';
import '../../support/fake_dashboard_controller.dart';

DashboardState _state({
  DashboardSummary? summary,
  List<RecentTransaction>? recent,
}) => DashboardState(
  month: DateTime(2026, 5),
  summary: summary ?? specSummary(),
  trends: specTrends(),
  recent: recent ?? specRecent(),
);

Widget _wrap({
  required DashboardState state,
  Locale locale = const Locale('fr'),
}) {
  return ProviderScope(
    overrides: [
      dashboardControllerProvider.overrideWith(
        () => FakeDashboardController(initialState: state),
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

/// The panel is drawn for the 1440×900 desktop frame the design targets.
void _useDesktopSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  // --- row 1: the KPI strip --------------------------------------------------------------

  Finder kpi(String id) => find.byKey(Key('dashboardKpi-$id'));

  Text deltaText(WidgetTester tester, String id) =>
      tester.widget<Text>(find.byKey(Key('dashboardKpiDelta-$id')));

  Icon trendIcon(WidgetTester tester, String id) => tester.widget<Icon>(
    find.descendant(
      of: find.byKey(Key('dashboardKpiTrend-$id')),
      matching: find.byType(Icon),
    ),
  );

  Finder byKey(String key) => find.byKey(Key(key));

  testWidgets(
    'row 1 is one card: savings rate, net, income, expenses, left to right',
    (tester) async {
      _useDesktopSurface(tester);
      await tester.pumpWidget(_wrap(state: _state()));
      await tester.pumpAndSettle();

      expect(find.byType(KpiStrip), findsOneWidget);
      // The skeleton's row 1 is drawn at this measured height.
      expect(tester.getSize(find.byType(KpiStrip)).height, 153);
      // One plate, not four.
      expect(
        find.descendant(
          of: find.byType(KpiStrip),
          matching: find.byType(AppCard),
        ),
        findsOneWidget,
      );

      final xs = [
        for (final id in ['savings', 'net', 'income', 'expense'])
          tester.getTopLeft(kpi(id)).dx,
      ];
      for (var i = 1; i < xs.length; i++) {
        expect(xs[i], greaterThan(xs[i - 1]));
      }

      // The savings column is the wider one; the other three share the rest evenly.
      final savingsWidth = tester.getSize(kpi('savings')).width;
      final netWidth = tester.getSize(kpi('net')).width;
      expect(tester.getSize(kpi('income')).width, closeTo(netWidth, 0.5));
      expect(tester.getSize(kpi('expense')).width, closeTo(netWidth, 0.5));
      expect(savingsWidth / netWidth, closeTo(1.35, 0.01));
    },
  );

  testWidgets(
    'the figure columns show signed amounts and their fr trend lines',
    (tester) async {
      _useDesktopSurface(tester);
      await tester.pumpWidget(_wrap(state: _state()));
      await tester.pumpAndSettle();

      String amount(int minor) => formatAmount(
        amountMinor: minor,
        currency: 'EUR',
        locale: 'fr',
        showPositiveSign: true,
      );

      expect(
        find.descendant(of: kpi('income'), matching: find.text(amount(285000))),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: kpi('expense'),
          matching: find.text(amount(-221435)),
        ),
        findsOneWidget,
      );
      final net = find.descendant(
        of: kpi('net'),
        matching: find.text(amount(63565)),
      );
      expect(net, findsOneWidget);
      // Net is the strip's one colorized figure.
      expect(tester.widget<Text>(net).style?.color, AppColors.dark.positive);

      expect(find.text('REVENUS'), findsOneWidget);
      expect(find.text('DÉPENSES'), findsOneWidget);
      expect(find.text('NET'), findsOneWidget);
      // Every figure column compares against the previous month.
      expect(find.text('vs avril'), findsNWidgets(3));
      expect(deltaText(tester, 'income').data, formatRatioPct(0.021, 'fr'));
      expect(deltaText(tester, 'expense').data, formatRatioPct(0.048, 'fr'));
      // The arrow carries the direction, so the percentage itself is unsigned.
      expect(deltaText(tester, 'net').data, formatRatioPct(0.061, 'fr'));
    },
  );

  testWidgets(
    'each trend arrow points with its delta and is colored by good or bad news',
    (tester) async {
      _useDesktopSurface(tester);
      await tester.pumpWidget(_wrap(state: _state()));
      await tester.pumpAndSettle();

      // Income up: green, up.
      expect(trendIcon(tester, 'income').icon, Icons.arrow_upward_rounded);
      expect(trendIcon(tester, 'income').color, AppColors.dark.positive);
      expect(deltaText(tester, 'income').style?.color, AppColors.dark.positive);
      // Net down: red, down.
      expect(trendIcon(tester, 'net').icon, Icons.arrow_downward_rounded);
      expect(trendIcon(tester, 'net').color, AppColors.dark.negative);
      expect(deltaText(tester, 'net').style?.color, AppColors.dark.negative);
      // Expenses up: inverted, so a rise is red.
      expect(trendIcon(tester, 'expense').icon, Icons.arrow_upward_rounded);
      expect(trendIcon(tester, 'expense').color, AppColors.dark.negative);
      expect(
        deltaText(tester, 'expense').style?.color,
        AppColors.dark.negative,
      );
    },
  );

  testWidgets('expenses that fell read green, still pointing down', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        state: _state(
          summary: specSummary(
            expenseDeltaPct: -4.6,
            incomeDeltaPct: -1.2,
            netDeltaPct: 0,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(trendIcon(tester, 'expense').icon, Icons.arrow_downward_rounded);
    expect(deltaText(tester, 'expense').style?.color, AppColors.dark.positive);
    expect(trendIcon(tester, 'income').icon, Icons.arrow_downward_rounded);
    expect(deltaText(tester, 'income').style?.color, AppColors.dark.negative);
    // A flat month is neither good nor bad news.
    expect(trendIcon(tester, 'net').icon, Icons.remove_rounded);
    expect(deltaText(tester, 'net').style?.color, AppColors.dark.textSecondary);
  });

  testWidgets(
    'the savings column: rate, bar toward the goal, and the reached line',
    (tester) async {
      _useDesktopSurface(tester);
      await tester.pumpWidget(_wrap(state: _state()));
      await tester.pumpAndSettle();

      expect(find.text('TAUX D\'ÉPARGNE'), findsOneWidget);
      expect(
        tester.widget<Text>(byKey('dashboardSavingsRateValue')).data,
        formatRatioPct(0.223, 'fr'),
      );
      // The ring is gone; a bar toward the goal replaces it, full once the goal is met.
      expect(find.byType(CircularProgressIndicator), findsNothing);
      final bar = tester.widget<RepereMeter>(byKey('dashboardSavingsGoalBar'));
      expect(bar.fraction, 1.0);

      // « ✓ Objectif 20 % atteint · +1,9 pt »
      final goal = formatRatioPct(0.20, 'fr', decimalDigits: 0);
      expect(byKey('dashboardSavingsGoalReachedIcon'), findsOneWidget);
      final goalText = tester.widget<Text>(byKey('dashboardSavingsGoalText'));
      expect(goalText.data, 'Objectif $goal atteint');
      expect(goalText.style?.color, AppColors.dark.positive);
      final delta = tester.widget<Text>(byKey('dashboardSavingsDelta'));
      expect(delta.data, '+1,9 pt');
      expect(delta.style?.color, AppColors.dark.positive);

      // The check leads the line, the delta closes it.
      final checkX = tester
          .getTopLeft(byKey('dashboardSavingsGoalReachedIcon'))
          .dx;
      final textX = tester.getTopLeft(byKey('dashboardSavingsGoalText')).dx;
      final deltaX = tester.getTopLeft(byKey('dashboardSavingsDelta')).dx;
      expect(checkX, lessThan(textX));
      expect(deltaX, greaterThan(textX));
    },
  );

  testWidgets(
    'a goal not yet met reads as progress: partial bar, no check, falling delta in red',
    (tester) async {
      _useDesktopSurface(tester);
      await tester.pumpWidget(
        _wrap(
          state: _state(
            summary: specSummary(savingsRate: 0.118, savingsRateDeltaPct: -0.4),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final bar = tester.widget<RepereMeter>(byKey('dashboardSavingsGoalBar'));
      expect(bar.fraction, closeTo(0.59, 0.0001));
      expect(byKey('dashboardSavingsGoalReachedIcon'), findsNothing);
      final goal = formatRatioPct(0.20, 'fr', decimalDigits: 0);
      final goalText = tester.widget<Text>(byKey('dashboardSavingsGoalText'));
      expect(goalText.data, 'Objectif $goal en cours');
      expect(goalText.style?.color, AppColors.dark.textSecondary);
      final delta = tester.widget<Text>(byKey('dashboardSavingsDelta'));
      expect(delta.data, '−0,4 pt');
      expect(delta.style?.color, AppColors.dark.negative);
    },
  );

  testWidgets('renders the KPI strip in en', (tester) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(_wrap(state: _state(), locale: const Locale('en')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: kpi('income'),
        matching: find.text(
          formatAmount(
            amountMinor: 285000,
            currency: 'EUR',
            locale: 'en',
            showPositiveSign: true,
          ),
        ),
      ),
      findsOneWidget,
    );
    expect(find.text('SAVINGS RATE'), findsOneWidget);
    expect(find.text('INCOME'), findsOneWidget);
    expect(find.text('EXPENSES'), findsOneWidget);
    expect(find.text('vs April'), findsNWidgets(3));
    // English writes its percentages without the French space.
    expect(deltaText(tester, 'income').data, '2.1%');
    expect(
      tester.widget<Text>(byKey('dashboardSavingsRateValue')).data,
      '22.3%',
    );
    expect(
      tester.widget<Text>(byKey('dashboardSavingsGoalText')).data,
      'Goal 20% reached',
    );
    expect(tester.takeException(), isNull);
  });

  // --- row 2: donut + savings line -------------------------------------------------------

  testWidgets('the donut legend lists the spec\'s seven categories in descending order', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(_wrap(state: _state()));
    await tester.pumpAndSettle();

    const expected = [
      'Logement',
      'Alimentation',
      // The spec's table calls this row « Autres ». That is the *hue bucket*'s name
      // (`docs/design/00` §Category hues); the system category actually carrying that hue is
      // seeded as « Divers » (`backend/app/core/seed.py`), which is what the app renders.
      'Divers',
      'Transport',
      'Loisirs',
      'Abonnements',
      'Santé',
    ];
    for (final name in expected) {
      expect(
        find.text(name),
        findsOneWidget,
        reason: '$name missing from the legend',
      );
    }

    // Descending by amount, top to bottom — the donut is drawn in the same order.
    final tops = [
      for (final name in expected) tester.getTopLeft(find.text(name)).dy,
    ];
    for (var i = 1; i < tops.length; i++) {
      expect(
        tops[i],
        greaterThan(tops[i - 1]),
        reason: '${expected[i]} is out of order',
      );
    }

    // Shares carry one decimal — rounding to whole percent would collapse the tail.
    expect(find.text('42,9 %'), findsOneWidget);
    expect(find.text('2,8 %'), findsOneWidget);
  });

  testWidgets(
    'the donut is drawn at the spec\'s r80 / stroke 24 and centres the total',
    (tester) async {
      _useDesktopSurface(tester);
      await tester.pumpWidget(_wrap(state: _state()));
      await tester.pumpAndSettle();

      expect(CategoryDonut.radius, 80);
      expect(CategoryDonut.stroke, 24);
      expect(CategoryDonut.gap, 3);
      expect(tester.getSize(find.byType(CategoryDonut)), const Size(212, 212));

      // The centre is the month's expense total as a neutral figure, over its caption.
      expect(
        find.text(
          formatAmount(amountMinor: 221435, currency: 'EUR', locale: 'fr'),
        ),
        findsOneWidget,
      );
      expect(find.text('dépensés'), findsOneWidget);
      expect(find.text('Mai 2026 · 7 catégories'), findsOneWidget);
    },
  );

  testWidgets(
    'the savings chart draws each month on its own, headed by the monthly average',
    (tester) async {
      _useDesktopSurface(tester);
      await tester.pumpWidget(_wrap(state: _state()));
      await tester.pumpAndSettle();

      expect(find.text('Évolution de l\'épargne'), findsOneWidget);
      expect(find.text('Épargne mensuelle · 12 mois'), findsOneWidget);
      expect(find.text('en moyenne par mois'), findsOneWidget);
      // The mean of the fixture's twelve months, signed as a movement.
      expect(
        find.descendant(
          of: find.byKey(const Key('dashboardAverageSaved')),
          matching: find.text(
            formatAmount(
              amountMinor: 29917,
              currency: 'EUR',
              locale: 'fr',
              showPositiveSign: true,
            ),
          ),
        ),
        findsOneWidget,
      );

      // Twelve bars, each the month's own net — not a running total — so a month that
      // spent more than it earned stays negative.
      final bars = tester.widget<SavingsChart>(find.byType(SavingsChart));
      expect(bars.values, hasLength(12));
      expect(bars.values[1], 18050);
      expect(bars.values[2], -32500);
      expect(bars.values.last, 63565);
      expect(bars.labels.first, 'Juin');
      expect(bars.labels.last, 'Mai');
    },
  );

  testWidgets(
    'the savings chart switches between bars and a line of the same months',
    (tester) async {
      _useDesktopSurface(tester);
      await tester.pumpWidget(_wrap(state: _state()));
      await tester.pumpAndSettle();

      SavingsChart chart() =>
          tester.widget<SavingsChart>(find.byType(SavingsChart));

      // Bars until the user asks otherwise.
      expect(find.text('Barres'), findsOneWidget);
      expect(find.text('Courbe'), findsOneWidget);
      expect(chart().view, SavingsChartView.bars);
      final bars = chart();

      await tester.tap(find.byKey(const Key('savingsViewLine')));
      await tester.pumpAndSettle();
      final line = chart();
      expect(line.view, SavingsChartView.line);
      // The same series either way: only the marks change.
      expect(line.values, bars.values);
      expect(line.labels, bars.labels);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('savingsViewBars')));
      await tester.pumpAndSettle();
      expect(chart().view, SavingsChartView.bars);
    },
  );

  for (final (locale, caption, lastMonth) in [
    ('fr', 'en moyenne par mois', 'Mai 2026'),
    ('en', 'on average per month', 'May 2026'),
  ]) {
    testWidgets(
      '$locale: both views draw the 12-month average, named by legend, not tooltip',
      (tester) async {
        _useDesktopSurface(tester);
        await tester.pumpWidget(_wrap(state: _state(), locale: Locale(locale)));
        await tester.pumpAndSettle();

        final average = formatAmount(
          amountMinor: 29917,
          currency: 'EUR',
          locale: locale,
          showPositiveSign: true,
        );
        SavingsChart chart() =>
            tester.widget<SavingsChart>(find.byType(SavingsChart));

        // The headline's caption doubles as the line's legend.
        final legend = find.byKey(const Key('savingsAverageSwatch'));
        expect(legend, findsOneWidget);
        expect(
          tester.getCenter(legend).dy,
          moreOrLessEquals(tester.getCenter(find.text(caption)).dy, epsilon: 1),
        );

        for (final view in [SavingsChartView.line, SavingsChartView.bars]) {
          await tester.tap(
            find.byKey(
              Key(
                view == SavingsChartView.line
                    ? 'savingsViewLine'
                    : 'savingsViewBars',
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(chart().view, view);
          expect(chart().average, 29917);
          // Hovering a month names that month and its amount, nothing more: the
          // average is the dotted line and the headline, not a tooltip line.
          final tooltips = chart().tooltips!;
          final values = chart().values;
          for (var i = 0; i < tooltips.length; i++) {
            final text = tooltips[i].toPlainText();
            expect(text.split('\n'), hasLength(2));
            expect(
              text,
              endsWith(
                formatAmount(
                  amountMinor: values[i],
                  currency: 'EUR',
                  locale: locale,
                  showPositiveSign: true,
                ),
              ),
            );
            expect(text, isNot(contains(average)));
          }
          final lastAmount = formatAmount(
            amountMinor: 63565,
            currency: 'EUR',
            locale: locale,
            showPositiveSign: true,
          );
          expect(tooltips.last.toPlainText(), '$lastMonth\n$lastAmount');
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('a user with no history gets no average line', (tester) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        state: DashboardState(
          month: DateTime(2026, 5),
          summary: specSummary(),
          trends: emptyTrends(),
          recent: specRecent(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<SavingsChart>(find.byType(SavingsChart)).average,
      isNull,
    );
  });

  testWidgets('the savings view outlives the dashboard for the session', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    final container = ProviderContainer(
      overrides: [
        dashboardControllerProvider.overrideWith(
          () => FakeDashboardController(initialState: _state()),
        ),
      ],
    );
    addTearDown(container.dispose);
    Widget app(Widget home) => UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('fr'),
        theme: AppTheme.dark,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: home),
      ),
    );

    await tester.pumpWidget(app(const DashboardScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('savingsViewLine')));
    await tester.pumpAndSettle();

    // Leave the panel, then come back: the line is still chosen.
    await tester.pumpWidget(app(const SizedBox.shrink()));
    await tester.pumpAndSettle();
    expect(find.byType(SavingsChart), findsNothing);
    await tester.pumpWidget(app(const DashboardScreen()));
    await tester.pumpAndSettle();
    expect(
      tester.widget<SavingsChart>(find.byType(SavingsChart)).view,
      SavingsChartView.line,
    );
  });

  testWidgets(
    'the savings view switch speaks English and fits a narrow window',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _wrap(state: _state(), locale: const Locale('en')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bars'), findsOneWidget);
      expect(find.text('Line'), findsOneWidget);
      await tester.tap(find.byKey(const Key('savingsViewLine')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // French runs longer; the card's header must still hold at this width.
      await tester.pumpWidget(_wrap(state: _state()));
      await tester.pumpAndSettle();
      expect(find.text("Évolution de l'épargne"), findsOneWidget);
      expect(find.text('Courbe'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('the donut shrinks with the window instead of crowding its card', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_wrap(state: _state()));
    await tester.pumpAndSettle();

    // The chart section has no card padding since v2, so the window is shorter here.
    // A fixed 212 ring in a card this short would either overflow it or squeeze the legend
    // out; the donut is the part that gives way.
    final donut = tester.getSize(find.byType(CategoryDonut));
    expect(donut.width, lessThan(CategoryDonut.size));
    expect(donut.width, donut.height);
    expect(donut.width, greaterThanOrEqualTo(96.0));
    expect(
      donut.height,
      lessThanOrEqualTo(
        tester.getSize(find.byType(CategoryBreakdownChart)).height,
      ),
    );

    // The legend keeps its figures — shrinking the donut is what buys them the room.
    expect(find.text('Logement'), findsOneWidget);
    expect(find.text('42,9 %'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('row 2 splits 1 / 1.35, at the same height as row 3', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(_wrap(state: _state()));
    await tester.pumpAndSettle();

    final donutCard = tester.getSize(find.byType(CategoryBreakdownChart));
    final savingsCard = tester.getSize(find.byType(SavingsTrendChart));

    expect(donutCard.height, savingsCard.height);
    expect(savingsCard.width / donutCard.width, closeTo(1.35, 0.01));

    // The two chart rows share the height left under the stat grid, so they read as one
    // block. The spec's 322px is measured against its own frame; what has to hold at any
    // viewport is that row 3 matches row 2.
    expect(
      tester.getSize(find.byType(IncomeVsExpenseChart)).height,
      donutCard.height,
    );
    expect(
      tester.getSize(find.byType(RecentActivityCard)).height,
      donutCard.height,
    );
  });

  // --- row 3: bars + recent activity -----------------------------------------------------

  testWidgets('the bars carry the spec\'s four months with nets colored by sign', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(_wrap(state: _state()));
    await tester.pumpAndSettle();

    expect(find.text('Revenus vs dépenses'), findsOneWidget);
    expect(find.text('4 derniers mois'), findsOneWidget);

    // One 44px column per month, in order. Scoped to the chart: the savings line's axis
    // beside it labels the same months.
    final bars = find.byType(IncomeVsExpenseChart);
    expect(bars, findsOneWidget);
    for (final month in ['Févr.', 'Mars', 'Avr.', 'Mai']) {
      expect(
        find.descendant(of: bars, matching: find.text(month)),
        findsOneWidget,
        reason: '$month missing from the bars',
      );
    }
    expect(tester.getSize(find.byType(MonthBar).first).width, 44);

    // Février's net is negative and red; the other three are positive and green.
    Finder net(int minor) => find.descendant(
      of: bars,
      matching: find.text(
        formatAmount(
          amountMinor: minor,
          currency: 'EUR',
          locale: 'fr',
          showPositiveSign: true,
        ),
      ),
    );
    expect(
      tester.widget<Text>(net(-11840)).style?.color,
      AppColors.dark.negative,
    );
    for (final minor in [54020, 73710, 63565]) {
      expect(
        tester.widget<Text>(net(minor)).style?.color,
        AppColors.dark.positive,
      );
    }
  });

  testWidgets(
    'each month draws its income and expense bars side by side on one baseline',
    (tester) async {
      _useDesktopSurface(tester);
      await tester.pumpWidget(_wrap(state: _state()));
      await tester.pumpAndSettle();

      Finder barOf(String kind, int month) =>
          find.byKey(Key('dashboard${kind}Bar-2026-$month'));
      Rect bar(String kind, int month) => tester.getRect(barOf(kind, month));
      Color? color(String kind, int month) {
        final box = tester.widget<Container>(
          find.descendant(
            of: barOf(kind, month),
            matching: find.byType(Container),
          ),
        );
        return (box.decoration! as BoxDecoration).color;
      }

      // Avril: 2 850,00 € in, 2 112,90 € out.
      final aprilIncome = bar('Income', 4);
      final heightPerMinor = aprilIncome.height / 285000;

      for (final month in [2, 3, 4, 5]) {
        final income = bar('Income', month);
        final expense = bar('Expense', month);

        // Next to each other, income first, never stacked or overlapping.
        expect(income.right, lessThan(expense.left), reason: 'month $month');
        expect(expense.left - income.right, closeTo(MonthBar.pairGap, 0.01));
        // Rising from one zero baseline shared by every month.
        expect(income.bottom, closeTo(expense.bottom, 0.01));
        expect(
          income.bottom,
          closeTo(aprilIncome.bottom, 0.01),
          reason: 'month $month',
        );
        expect(color('Income', month), AppColors.dark.positive);
        expect(color('Expense', month), AppColors.dark.negative);
      }

      // One scale across all months: heights are proportional to the amounts.
      expect(bar('Expense', 4).height, closeTo(211290 * heightPerMinor, 0.5));
      expect(bar('Expense', 2).height, closeTo(296840 * heightPerMinor, 0.5));
      // Février's expense is the period's largest figure, so it is the tallest bar.
      expect(bar('Expense', 2).height, greaterThan(aprilIncome.height));
    },
  );

  testWidgets(
    'the current month\'s bar label is primary, earlier months recede',
    (tester) async {
      _useDesktopSurface(tester);
      await tester.pumpWidget(_wrap(state: _state()));
      await tester.pumpAndSettle();

      final bars = find.byType(IncomeVsExpenseChart);
      Text label(String month) => tester.widget<Text>(
        find.descendant(of: bars, matching: find.text(month)),
      );

      expect(label('Mai').style?.color, AppColors.dark.text);
      for (final month in ['Févr.', 'Mars', 'Avr.']) {
        expect(label(month).style?.color, AppColors.dark.textSecondary);
      }
    },
  );

  testWidgets('hovering a bar names that month\'s income and expense', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(_wrap(state: _state()));
    await tester.pumpAndSettle();

    final tooltip = tester.widget<Tooltip>(
      find.byKey(const Key('dashboardBarTooltip-2026-5')),
    );
    final spans = (tooltip.richMessage! as TextSpan).children!.cast<TextSpan>();
    final text = spans.map((span) => span.text).join();

    expect(text, contains('Revenus'));
    expect(text, contains('Dépenses'));
    expect(
      text,
      contains(
        formatAmount(
          amountMinor: 285000,
          currency: 'EUR',
          locale: 'fr',
          showPositiveSign: true,
        ),
      ),
    );
    expect(
      text,
      contains(
        formatAmount(amountMinor: -221435, currency: 'EUR', locale: 'fr'),
      ),
    );
  });

  testWidgets(
    'the activity list is the compact variant: no chip, amount over date',
    (tester) async {
      _useDesktopSurface(tester);
      await tester.pumpWidget(_wrap(state: _state()));
      await tester.pumpAndSettle();

      expect(find.text('Activité récente'), findsOneWidget);
      expect(find.byType(CompactTransactionRow), findsNWidgets(4));
      // The compact variant deliberately drops the category chip the 52px row carries.
      expect(find.byType(CategoryLabel), findsNothing);

      for (final row in [
        'Carrefour',
        'Novatech SARL',
        'SNCF Connect',
        'Free Mobile',
      ]) {
        expect(find.text(row), findsOneWidget);
      }
      expect(find.text('BNP — Compte courant'), findsNWidgets(3));
      expect(find.text('Revolut'), findsOneWidget);

      // Amount sits above its date in the right column.
      final amount = tester.getTopLeft(
        find.text(
          formatAmount(
            amountMinor: -8642,
            currency: 'EUR',
            locale: 'fr',
            showPositiveSign: true,
          ),
        ),
      );
      final date = tester.getTopLeft(find.text('14/05/2026'));
      expect(amount.dy, lessThan(date.dy));
      expect(amount.dx, closeTo(date.dx, 24));

      expect(
        find.byKey(const Key('dashboardViewAllTransactions')),
        findsOneWidget,
      );
    },
  );

  testWidgets('the view-all link rides the card title, at its trailing edge', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(_wrap(state: _state()));
    await tester.pumpAndSettle();

    final link = tester.getRect(
      find.byKey(const Key('dashboardViewAllTransactions')),
    );
    final title = tester.getRect(find.text('Activité récente'));
    final card = tester.getRect(find.byType(RecentActivityCard));
    final firstRow = tester.getRect(find.byType(CompactTransactionRow).first);

    // Level with the title, on the far side of the card, and above the list rather than
    // under it — a link pinned below a variable number of rows has no fixed line to sit on.
    expect(link.center.dy, closeTo(title.center.dy, 4));
    expect(link.right, closeTo(card.right - AppSpacing.cardPadding, 1));
    expect(link.left, greaterThan(title.right));
    expect(link.bottom, lessThanOrEqualTo(firstRow.top));
  });

  testWidgets('the activity list fills the height row 3 gives it', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    // Twice as many transactions as the frame can show, so the count is decided by the card
    // rather than by the fixture's length.
    final doubled = [
      ...specRecent(),
      for (final transaction in specRecent())
        RecentTransaction(
          id: '${transaction.id}-bis',
          label: transaction.label,
          accountLabel: transaction.accountLabel,
          bookedDate: transaction.bookedDate,
          amountMinor: transaction.amountMinor,
          currency: transaction.currency,
        ),
    ];
    await tester.pumpWidget(_wrap(state: _state(recent: doubled)));
    await tester.pumpAndSettle();

    final rows = find.byType(CompactTransactionRow);
    expect(rows, findsWidgets);

    final card = tester.getRect(find.byType(RecentActivityCard));
    final first = tester.getRect(rows.first);
    final last = tester.getRect(rows.last);

    // Rows are contiguous and reach the card's padded bottom edge, and none is drawn shorter
    // than the spec's 48 or more than a quarter over it.
    expect(first.height, greaterThanOrEqualTo(CompactTransactionRow.rowHeight));
    expect(
      first.height,
      lessThanOrEqualTo(CompactTransactionRow.rowHeight * 1.25),
    );
    expect(last.bottom, closeTo(card.bottom - AppSpacing.cardPadding, 1));
  });

  testWidgets('every named counterparty gets its initials on the neutral '
      'monogram', (tester) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(_wrap(state: _state()));
    await tester.pumpAndSettle();

    // Monograms are always neutral (`00` §7), so no brand list decides
    // between initials and « ? »: a named row shows its initials, one letter
    // per word, so « Novatech SARL » reads NS.
    expect(find.text('CA'), findsOneWidget);
    expect(find.text('NS'), findsOneWidget);
    expect(find.text('SC'), findsOneWidget);
    expect(find.text('FM'), findsOneWidget);
    expect(find.text('?'), findsNothing);
  });

  // --- states ------------------------------------------------------------------------------

  testWidgets(
    'renders the encouraging empty state with a CTA when there is no data',
    (tester) async {
      _useDesktopSurface(tester);
      await tester.pumpWidget(
        _wrap(
          state: DashboardState(
            month: DateTime(2026, 5),
            summary: specSummary(
              incomeMinor: 0,
              expenseMinor: 0,
              netMinor: 0,
              byCategory: const [],
            ),
            trends: emptyTrends(),
            recent: const [],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Importez un relevé pour donner vie à votre argent'),
        findsOneWidget,
      );
      // The reassurance answers the doubt the CTA creates — the user has just been asked to
      // hand over a bank statement.
      expect(
        find.text(
          'Tout reste sur cet ordinateur — rien n\'est envoyé en ligne.',
        ),
        findsOneWidget,
      );
      // One *primary* CTA, per the EmptyState spec.
      expect(
        find.byKey(const Key('dashboardGoToImportsButton')),
        findsOneWidget,
      );
      expect(find.byType(PrimaryButton), findsOneWidget);

      // Nothing else is on screen: the empty state replaces the whole panel.
      expect(find.byType(KpiStrip), findsNothing);
      expect(find.byType(CategoryDonut), findsNothing);
      expect(find.byType(IncomeVsExpenseChart), findsNothing);
    },
  );

  testWidgets(
    'the loading skeleton silhouettes all three rows at their real ratios',
    (tester) async {
      _useDesktopSurface(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dashboardControllerProvider.overrideWith(
              FakeLoadingDashboardController.new,
            ),
          ],
          child: const MaterialApp(
            locale: Locale('fr'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: DashboardScreen()),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('dashboardLoadingIndicator')),
        findsOneWidget,
      );
      // 1 strip silhouette + 2 for row 2 + 2 for row 3.
      expect(find.byType(SkeletonBlock), findsNWidgets(5));

      // The silhouette must not move the cards when the data lands, so it carries the same
      // shape: one full-width strip across row 1, and 1:1.35 across row 2.
      final blocks = [
        for (var i = 0; i < 5; i++)
          tester.getSize(find.byType(SkeletonBlock).at(i)),
      ];
      expect(blocks[0].height, 153);
      expect(blocks[2].width / blocks[1].width, closeTo(1.35, 0.01));
      // Rows 2 and 3 are equal-height in the silhouette too, as they are once data lands.
      expect(blocks[1].height, blocks[3].height);
      expect(blocks[3].width, closeTo(blocks[4].width, 0.5));
    },
  );

  testWidgets('the panel renders unchanged under the collapsed 76px nav rail', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardControllerProvider.overrideWith(
            () => FakeDashboardController(initialState: _state()),
          ),
          sidebarCollapsedProvider.overrideWith(FakeCollapsedSidebar.new),
        ],
        child: MaterialApp(
          locale: const Locale('fr'),
          theme: AppTheme.dark,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AppShell(
            currentPath: DashboardScreen.path,
            onNavigate: (_) {},
            child: const DashboardScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Collapsing the nav is chrome state, not panel state — the same data is drawn, just in
    // the wider content region the 76px rail leaves behind.
    expect(find.byType(KpiStrip), findsOneWidget);
    expect(find.byType(CategoryDonut), findsOneWidget);
    expect(find.byType(IncomeVsExpenseChart), findsOneWidget);
    expect(find.byType(CompactTransactionRow), findsNWidgets(4));
    expect(tester.takeException(), isNull);
  });
}
