import 'package:finstride/core/theme/app_theme.dart';
import 'package:finstride/core/theme/tokens.dart';
import 'package:finstride/core/widgets/amount_text.dart';
import 'package:finstride/core/widgets/area_line.dart';
import 'package:finstride/features/dashboard/application/dashboard_controller.dart';
import 'package:finstride/features/dashboard/domain/dashboard_summary.dart';
import 'package:finstride/features/dashboard/presentation/category_breakdown.dart';
import 'package:finstride/features/dashboard/presentation/dashboard_screen.dart';
import 'package:finstride/features/dashboard/presentation/savings_trend.dart';
import 'package:finstride/features/dashboard/presentation/stat_card.dart';
import 'package:finstride/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/dashboard_fixtures.dart';
import '../../support/fake_dashboard_controller.dart';

DashboardState _state({DashboardSummary? summary}) => DashboardState(
  month: DateTime(2026, 5),
  summary: summary ?? specSummary(),
  trends: specTrends(),
);

Widget _wrap({required DashboardState state, Locale locale = const Locale('fr')}) {
  return ProviderScope(
    overrides: [
      dashboardControllerProvider.overrideWith(
        () => FakeDashboardController(initialState: state),
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

/// The panel is drawn for the 1440×900 desktop frame the design targets.
void _useDesktopSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  // --- row 1: the stat grid --------------------------------------------------------------

  testWidgets('renders stat cards with formatted values and trend semantics for fr', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(_wrap(state: _state()));
    await tester.pumpAndSettle();

    expect(
      find.text(
        formatAmount(
          amountMinor: 285000,
          currency: 'EUR',
          locale: 'fr',
          showPositiveSign: true,
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        formatAmount(
          amountMinor: -221435,
          currency: 'EUR',
          locale: 'fr',
          showPositiveSign: true,
        ),
      ),
      findsOneWidget,
    );
    // Net is neutral in *color* but still signed — the spec draws `+635,65 €` in primary
    // text, so the sign carries the direction the color no longer does.
    final netText = formatAmount(
      amountMinor: 63565,
      currency: 'EUR',
      locale: 'fr',
      showPositiveSign: true,
    );
    expect(find.text(netText), findsOneWidget);
    expect(tester.widget<Text>(find.text(netText)).style?.color, AppColors.textPrimary);

    // Income up is good, expense up is bad, net down is bad.
    expect(find.text(formatDeltaPct(2.1, 'fr')), findsOneWidget);
    expect(find.text(formatDeltaPct(4.8, 'fr')), findsOneWidget);
    expect(find.text(formatDeltaPct(-6.1, 'fr')), findsOneWidget);

    // The savings rate's change is in percentage *points*, not percent, and its value sits
    // inside the ring rather than beside it.
    expect(find.text('+1,9 pt'), findsOneWidget);
    expect(find.text(formatDeltaPct(1.9, 'fr')), findsNothing);
    expect(
      tester.widget<Text>(find.byKey(const Key('dashboardSavingsRateValue'))).data,
      formatPct(22.3, 'fr'),
    );

    // Captions naming what each trend is measured against.
    expect(find.text('vs avril'), findsNWidgets(2));
    expect(find.text('revenus − dépenses'), findsOneWidget);
    expect(find.text('Objectif : 20 % · atteint'), findsOneWidget);
  });

  testWidgets('the savings caption frames a missed goal as progress, not shortfall', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(_wrap(state: _state(summary: specSummary(savingsRate: 0.118))));
    await tester.pumpAndSettle();

    expect(find.text('Objectif : 20 % · en cours'), findsOneWidget);
  });

  testWidgets('row 1 lays the four cards out on the spec 1:1:1:1.35 grid', (tester) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(_wrap(state: _state()));
    await tester.pumpAndSettle();

    expect(find.byType(StatCard), findsNWidgets(3));
    final statWidth = tester.getSize(find.byType(StatCard).first).width;
    final savingsWidth = tester.getSize(find.byType(SavingsRateCard)).width;

    for (var i = 1; i < 3; i++) {
      expect(tester.getSize(find.byType(StatCard).at(i)).width, closeTo(statWidth, 0.5));
    }
    expect(savingsWidth / statWidth, closeTo(1.35, 0.01));
  });

  testWidgets('renders stat cards with formatted values for en', (tester) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(_wrap(state: _state(), locale: const Locale('en')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        formatAmount(
          amountMinor: 285000,
          currency: 'EUR',
          locale: 'en',
          showPositiveSign: true,
        ),
      ),
      findsOneWidget,
    );
    expect(find.text(formatDeltaPct(2.1, 'en')), findsOneWidget);
    expect(find.text('Income (month)'.toUpperCase()), findsOneWidget);
    expect(find.text('income − expenses'), findsOneWidget);
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
      expect(find.text(name), findsOneWidget, reason: '$name missing from the legend');
    }

    // Descending by amount, top to bottom — the donut is drawn in the same order.
    final tops = [for (final name in expected) tester.getTopLeft(find.text(name)).dy];
    for (var i = 1; i < tops.length; i++) {
      expect(tops[i], greaterThan(tops[i - 1]), reason: '${expected[i]} is out of order');
    }

    // Shares carry one decimal — rounding to whole percent would collapse the tail.
    expect(find.text('42,9 %'), findsOneWidget);
    expect(find.text('2,8 %'), findsOneWidget);
  });

  testWidgets('the donut is drawn at the spec\'s r80 / stroke 24 and centres the total', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(_wrap(state: _state()));
    await tester.pumpAndSettle();

    expect(CategoryDonut.radius, 80);
    expect(CategoryDonut.stroke, 24);
    expect(CategoryDonut.gap, 3);
    expect(tester.getSize(find.byType(CategoryDonut)), const Size(212, 212));

    // The centre is the month's expense total as a neutral figure, over its caption.
    expect(
      find.text(formatAmount(amountMinor: 221435, currency: 'EUR', locale: 'fr')),
      findsOneWidget,
    );
    expect(find.text('dépensés'), findsOneWidget);
    expect(find.text('Mai 2026 · 7 catégories'), findsOneWidget);
  });

  testWidgets('the savings line heads with the running total and the latest month\'s step', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(_wrap(state: _state()));
    await tester.pumpAndSettle();

    expect(find.text('Évolution de l\'épargne'), findsOneWidget);
    expect(find.text('Épargne cumulée · 6 mois'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('dashboardTotalSaved')),
        matching: find.text(formatAmount(amountMinor: 1084000, currency: 'EUR', locale: 'fr')),
      ),
      findsOneWidget,
    );

    // The step into May is May's net, and it is green because it is positive.
    final delta = tester.widget<Text>(find.byKey(const Key('dashboardSavingsDelta')));
    final may = formatAmount(
      amountMinor: 63565,
      currency: 'EUR',
      locale: 'fr',
      showPositiveSign: true,
    );
    expect(delta.data, '$may en mai');
    expect(delta.style?.color, AppColors.positive);

    // Six points, labelled Déc. → Mai.
    final area = tester.widget<AreaLine>(find.byType(AreaLine));
    expect(area.values, hasLength(6));
    expect(area.labels, ['Déc.', 'Janv.', 'Févr.', 'Mars', 'Avr.', 'Mai']);
  });

  testWidgets('row 2 splits 1.35 / 1 at the spec\'s 322px height', (tester) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(_wrap(state: _state()));
    await tester.pumpAndSettle();

    final donutCard = tester.getSize(find.byType(CategoryBreakdownChart));
    final savingsCard = tester.getSize(find.byType(SavingsTrendChart));

    expect(donutCard.height, 322);
    expect(savingsCard.height, 322);
    expect(donutCard.width / savingsCard.width, closeTo(1.35, 0.01));
  });

  // --- states ------------------------------------------------------------------------------

  testWidgets('renders the encouraging empty state with a CTA when there is no data', (
    tester,
  ) async {
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
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Importez un relevé pour donner vie à votre argent'), findsOneWidget);
    expect(find.byKey(const Key('dashboardGoToImportsButton')), findsOneWidget);
  });
}
