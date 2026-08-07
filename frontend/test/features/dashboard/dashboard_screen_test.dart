import 'package:finstride/core/theme/app_theme.dart';
import 'package:finstride/core/theme/tokens.dart';
import 'package:finstride/core/widgets/amount_text.dart';
import 'package:finstride/features/dashboard/application/dashboard_controller.dart';
import 'package:finstride/features/dashboard/domain/dashboard_summary.dart';
import 'package:finstride/features/dashboard/presentation/dashboard_screen.dart';
import 'package:finstride/features/dashboard/presentation/stat_card.dart';
import 'package:finstride/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_dashboard_controller.dart';

DashboardSummary _summary({
  int incomeMinor = 285000,
  int expenseMinor = 221435,
  int netMinor = 63565,
  double savingsRate = 0.223,
  double incomeDeltaPct = 2.1,
  double expenseDeltaPct = 4.8,
  double netDeltaPct = -6.1,
  double savingsRateDeltaPct = 1.9,
  List<CategoryBreakdown> byCategory = const [
    CategoryBreakdown(categoryId: 'c1', name: 'category.housing', amountMinor: 132861, pct: 60),
    CategoryBreakdown(categoryId: 'c2', name: 'category.food', amountMinor: 88574, pct: 40),
  ],
}) => DashboardSummary(
  incomeMinor: incomeMinor,
  expenseMinor: expenseMinor,
  netMinor: netMinor,
  savingsRate: savingsRate,
  incomeDeltaPct: incomeDeltaPct,
  expenseDeltaPct: expenseDeltaPct,
  netDeltaPct: netDeltaPct,
  savingsRateDeltaPct: savingsRateDeltaPct,
  byCategory: byCategory,
  currency: 'EUR',
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
  testWidgets('renders stat cards with formatted values and trend semantics for fr', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(state: DashboardState(month: DateTime(2026, 5), summary: _summary())),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(formatAmount(amountMinor: 285000, currency: 'EUR', locale: 'fr', showPositiveSign: true)),
      findsOneWidget,
    );
    expect(
      find.text(formatAmount(amountMinor: -221435, currency: 'EUR', locale: 'fr', showPositiveSign: true)),
      findsOneWidget,
    );
    // Net is neutral in *color* but still signed — the spec draws `+635,65 €` in primary
    // text, so the sign carries the direction the color no longer does.
    expect(
      find.text(
        formatAmount(amountMinor: 63565, currency: 'EUR', locale: 'fr', showPositiveSign: true),
      ),
      findsOneWidget,
    );
    final net = tester.widget<Text>(
      find.descendant(
        of: find.byType(StatCard),
        matching: find.textContaining('63', findRichText: false),
      ),
    );
    expect(net.style?.color, AppColors.textPrimary);

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
    await tester.pumpWidget(
      _wrap(
        state: DashboardState(
          month: DateTime(2026, 5),
          summary: _summary(savingsRate: 0.118),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Objectif : 20 % · en cours'), findsOneWidget);
  });

  testWidgets('row 1 lays the four cards out on the spec 1:1:1:1.35 grid', (tester) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(state: DashboardState(month: DateTime(2026, 5), summary: _summary())),
    );
    await tester.pumpAndSettle();

    final stats = tester.widgetList<StatCard>(find.byType(StatCard)).toList();
    expect(stats, hasLength(3));
    final statWidth = tester.getSize(find.byType(StatCard).first).width;
    final savingsWidth = tester.getSize(find.byType(SavingsRateCard)).width;

    // Every StatCard is the same width, and the savings hero is 1.35× one of them.
    for (var i = 1; i < 3; i++) {
      expect(tester.getSize(find.byType(StatCard).at(i)).width, closeTo(statWidth, 0.5));
    }
    expect(savingsWidth / statWidth, closeTo(1.35, 0.01));
  });

  testWidgets('renders stat cards with formatted values for en', (tester) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        state: DashboardState(month: DateTime(2026, 5), summary: _summary()),
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(formatAmount(amountMinor: 285000, currency: 'EUR', locale: 'en', showPositiveSign: true)),
      findsOneWidget,
    );
    expect(find.text(formatDeltaPct(2.1, 'en')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders the category breakdown chart with localized names and amounts', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(state: DashboardState(month: DateTime(2026, 5), summary: _summary())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Logement'), findsOneWidget);
    expect(find.text('Alimentation'), findsOneWidget);
    expect(
      find.text(formatAmount(amountMinor: 132861, currency: 'EUR', locale: 'fr')),
      findsOneWidget,
    );
    expect(find.text('60 %'), findsOneWidget);
    expect(find.text('40 %'), findsOneWidget);
  });

  testWidgets('renders the encouraging empty state with a CTA when there is no data', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        state: DashboardState(
          month: DateTime(2026, 5),
          summary: _summary(incomeMinor: 0, expenseMinor: 0, netMinor: 0, byCategory: const []),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Importez un relevé pour donner vie à votre argent'), findsOneWidget);
    expect(find.byKey(const Key('dashboardGoToImportsButton')), findsOneWidget);
  });
}
