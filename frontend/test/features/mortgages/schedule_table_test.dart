import 'package:finstride/core/theme/app_theme.dart';
import 'package:finstride/core/widgets/amount_text.dart';
import 'package:finstride/features/mortgages/application/mortgages_controller.dart';
import 'package:finstride/features/mortgages/domain/mortgage.dart';
import 'package:finstride/features/mortgages/presentation/mortgages_screen.dart';
import 'package:finstride/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/mortgages_fixtures.dart';

String _money(int amountMinor) =>
    formatAmount(amountMinor: amountMinor, currency: 'EUR', locale: 'fr');

class _DetailOpen extends SelectedMortgage {
  @override
  String? build() => 'm1';
}

/// The panel opened on the crédit immobilier's detail, as frame ② draws it.
Widget _wrap({List<int>? requestedYears}) {
  return ProviderScope(
    overrides: [
      mortgagesControllerProvider.overrideWith(
        () => FakeMortgagesController(initialMortgages: [testMortgage()]),
      ),
      mortgagesTodayProvider.overrideWithValue(() => mortgagesToday),
      selectedMortgageProvider.overrideWith(_DetailOpen.new),
      mortgageDetailProvider.overrideWith(
        (ref, id) async => MortgageDetailView(
          detail: testDetail(),
          interestStillDueMinor: 9240674,
        ),
      ),
      scheduleWindowProvider.overrideWith((ref, window) async {
        requestedYears?.add(window.year);
        return testScheduleYear(year: window.year);
      }),
    ],
    child: MaterialApp(
      locale: const Locale('fr'),
      theme: appDarkTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: MortgagesScreen()),
    ),
  );
}

/// The 1440×900 frame the design targets, as every panel test in the app pumps
/// it — the screen as the page body.
const _frame = Size(1440, 900);

void _useDesktopSurface(WidgetTester tester) {
  tester.view.physicalSize = _frame;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

String? _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(Key(key))).data;

void main() {
  testWidgets('a year renders its twelve rows and the API totals in the foot', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    final window = testScheduleYear();
    for (final row in window.rows) {
      expect(find.byKey(Key('scheduleRow-${row.ordinal}')), findsOneWidget);
    }

    // Insurance has its own column, apart from interest and principal.
    final row = window.rows.first;
    expect(_text(tester, 'scheduleInterest-${row.ordinal}'), _money(64140));
    expect(_text(tester, 'schedulePrincipal-${row.ordinal}'), _money(55367));
    expect(_text(tester, 'scheduleInsurance-${row.ordinal}'), _money(2880));
    expect(_text(tester, 'scheduleTotal-${row.ordinal}'), _money(122387));

    expect(_text(tester, 'scheduleFootInterest'), _money(766782));
    expect(_text(tester, 'scheduleFootPrincipal'), _money(667302));
    expect(_text(tester, 'scheduleFootInsurance'), _money(34560));
    expect(_text(tester, 'scheduleFootTotal'), _money(1468644));
    expect(
      _text(tester, 'scheduleFootOutstanding'),
      'au 31/12/2026 : ${_money(21862220)}',
    );
    expect(find.text('Total 2026'), findsOneWidget);
    expect(
      _text(tester, 'scheduleSubtitle'),
      "Année 4 sur 26 · 12 échéances · l'assurance est comptée à part",
    );
  });

  testWidgets(
    'rows are the dense variant and a full year fits the frame unscrolled',
    (tester) async {
      _useDesktopSurface(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      final rows = find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith('scheduleRow-'),
      );
      expect(rows, findsNWidgets(12));
      for (final element in rows.evaluate()) {
        expect(tester.getSize(find.byWidget(element.widget)).height, 28);
      }

      // No scrollable wraps the table: the foot is laid out inside the frame.
      expect(
        find.ancestor(
          of: find.byKey(const Key('scheduleTable')),
          matching: find.byType(Scrollable),
        ),
        findsNothing,
      );
      expect(
        tester.getRect(find.byKey(const Key('scheduleFoot'))).bottom,
        lessThanOrEqualTo(_frame.height),
      );
    },
  );

  testWidgets('the current instalment row carries the iris wash', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    Color? washOf(int month) {
      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byKey(
                Key('scheduleRow-${testScheduleRow(month).ordinal}'),
              ),
              matching: find.byType(Container),
            )
            .first,
      );
      return (container.decoration! as BoxDecoration).color;
    }

    // Today is 14/05/2026 and the next instalment 01/06/2026: May is current.
    expect(washOf(5), const Color(0x0F8B8CF9));
    expect(washOf(4), isNull);
    expect(washOf(6), isNull);
  });

  testWidgets('the YearSwitcher opens on the current year, steps, and jumps', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    final requested = <int>[];
    await tester.pumpWidget(_wrap(requestedYears: requested));
    await tester.pumpAndSettle();

    expect(_text(tester, 'yearSwitcherLabel'), '2026');
    expect(requested, [2026]);
    for (final year in [2023, 2024, 2025, 2026, 2027]) {
      expect(find.byKey(Key('yearSwitcherYear-$year')), findsOneWidget);
    }
    expect(find.text('… 2048'), findsOneWidget);

    await tester.tap(find.byKey(const Key('yearSwitcherNext')));
    await tester.pumpAndSettle();
    expect(_text(tester, 'yearSwitcherLabel'), '2027');
    expect(find.text('Total 2027'), findsOneWidget);

    await tester.tap(find.byKey(const Key('yearSwitcherYear-2024')));
    await tester.pumpAndSettle();
    expect(_text(tester, 'yearSwitcherLabel'), '2024');
    expect(requested, [2026, 2027, 2024]);
  });
}
