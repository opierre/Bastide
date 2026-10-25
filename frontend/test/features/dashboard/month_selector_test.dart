import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/features/dashboard/application/dashboard_controller.dart';
import 'package:bastide/features/dashboard/domain/dashboard_summary.dart';
import 'package:bastide/features/dashboard/presentation/month_selector.dart';
import 'package:bastide/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/dashboard_fixtures.dart';
import '../../support/fake_dashboard_controller.dart';

const _summary = DashboardSummary(
  incomeMinor: 285000,
  expenseMinor: 221435,
  netMinor: 63565,
  savingsRate: 0.223,
  incomeDeltaPct: 0,
  expenseDeltaPct: 0,
  netDeltaPct: 0,
  savingsRateDeltaPct: 0,
  byCategory: [],
  currency: 'EUR',
);

Widget _wrap(FakeDashboardController controller) {
  return ProviderScope(
    overrides: [dashboardControllerProvider.overrideWith(() => controller)],
    child: MaterialApp(
      locale: const Locale('fr'),
      theme: appDarkTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: Center(child: DashboardTopBarActions())),
    ),
  );
}

FakeDashboardController _controllerAt(DateTime month) =>
    FakeDashboardController(
      initialState: DashboardState(
        month: month,
        summary: _summary,
        trends: specTrends(),
        recent: specRecent(),
      ),
    );

void main() {
  testWidgets('the chevrons still step one month at a time', (tester) async {
    final controller = _controllerAt(DateTime(2026, 5));
    await tester.pumpWidget(_wrap(controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('dashboardMonthPrev')));
    await tester.pumpAndSettle();

    expect(controller.changeMonthCalls, [DateTime(2026, 4)]);
  });

  testWidgets('the pill keeps its width whichever month it names', (
    tester,
  ) async {
    // « Mai 2026 » and « Septembre 2026 » differ by a third: a pill sized to
    // its label moved the chevron out from under a pointer stepping through.
    await tester.pumpWidget(_wrap(_controllerAt(DateTime(2026, 5))));
    await tester.pumpAndSettle();
    final may = tester.getRect(find.byType(DashboardTopBarActions));
    final mayNext = tester.getCenter(
      find.byKey(const Key('dashboardMonthNext')),
    );

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_wrap(_controllerAt(DateTime(2026, 9))));
    await tester.pumpAndSettle();

    expect(find.text('Septembre 2026'), findsOneWidget);
    expect(tester.getRect(find.byType(DashboardTopBarActions)), may);
    expect(
      tester.getCenter(find.byKey(const Key('dashboardMonthNext'))),
      mayNext,
    );
  });

  testWidgets('tapping the label opens the picker on the selected month', (
    tester,
  ) async {
    final controller = _controllerAt(DateTime(2026, 5));
    await tester.pumpWidget(_wrap(controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('dashboardMonthPickerButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dashboardPickerYearLabel')), findsOneWidget);
    expect(find.text('2026'), findsOneWidget);
    for (var month = 1; month <= 12; month++) {
      expect(find.byKey(Key('dashboardPickerMonth-$month')), findsOneWidget);
    }
  });

  testWidgets('paging the year and picking a month selects that month', (
    tester,
  ) async {
    final controller = _controllerAt(DateTime(2026, 5));
    await tester.pumpWidget(_wrap(controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('dashboardMonthPickerButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('dashboardYearPrev')));
    await tester.pumpAndSettle();

    expect(find.text('2025'), findsOneWidget);

    await tester.tap(find.byKey(const Key('dashboardPickerMonth-3')));
    await tester.pumpAndSettle();

    expect(controller.changeMonthCalls, [DateTime(2025, 3)]);
    // The choice closes the popover — the picker is not a panel that lingers.
    expect(find.byKey(const Key('dashboardPickerYearLabel')), findsNothing);
  });

  testWidgets('paging the year without choosing leaves the month alone', (
    tester,
  ) async {
    final controller = _controllerAt(DateTime(2026, 5));
    await tester.pumpWidget(_wrap(controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('dashboardMonthPickerButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('dashboardYearNext')));
    await tester.pumpAndSettle();

    // Dismiss without picking.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(controller.changeMonthCalls, isEmpty);

    // Re-opening starts back on the year the dashboard is actually showing.
    await tester.tap(find.byKey(const Key('dashboardMonthPickerButton')));
    await tester.pumpAndSettle();

    expect(find.text('2026'), findsOneWidget);
  });
}
