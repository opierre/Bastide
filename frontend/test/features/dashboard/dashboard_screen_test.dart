import 'package:bastide/core/navigation/sidebar_controller.dart';
import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/core/theme/tokens.dart';
import 'package:bastide/core/widgets/amount_text.dart';
import 'package:bastide/core/widgets/app_card.dart';
import 'package:bastide/core/widgets/app_segmented.dart';
import 'package:bastide/core/widgets/app_shell.dart';
import 'package:bastide/core/widgets/bar_charts.dart';
import 'package:bastide/core/widgets/institution_avatar.dart';
import 'package:bastide/core/widgets/primary_button.dart';
import 'package:bastide/core/widgets/repere_meter.dart';
import 'package:bastide/core/widgets/state_views.dart';
import 'package:bastide/core/widgets/status_text.dart';
import 'package:bastide/features/dashboard/application/dashboard_controller.dart';
import 'package:bastide/features/dashboard/domain/dashboard_summary.dart';
import 'package:bastide/features/dashboard/domain/dashboard_trends.dart';
import 'package:bastide/features/dashboard/presentation/category_spending.dart';
import 'package:bastide/features/dashboard/presentation/dashboard_screen.dart';
import 'package:bastide/features/dashboard/presentation/monthly_savings.dart';
import 'package:bastide/features/dashboard/presentation/reading_line.dart';
import 'package:bastide/features/dashboard/presentation/recent_activity.dart';
import 'package:bastide/features/transactions/application/review_count_provider.dart';
import 'package:bastide/l10n/app_localizations.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../support/route_probe.dart';
import '../../support/dashboard_fixtures.dart';
import '../../support/fake_dashboard_controller.dart';

DashboardState _state({
  DashboardSummary? summary,
  DashboardTrends? trends,
  List<RecentTransaction>? recent,
}) => DashboardState(
  month: DateTime(2026, 5),
  summary: summary ?? specSummary(),
  trends: trends ?? specTrends(),
  recent: recent ?? specRecent(),
);

Widget _wrap({
  required DashboardState state,
  Locale locale = const Locale('fr'),
  ThemeData? theme,
  bool routed = false,
}) {
  return ProviderScope(
    overrides: [
      dashboardControllerProvider.overrideWith(
        () => FakeDashboardController(initialState: state),
      ),
    ],
    child: routed
        ? MaterialApp.router(
            locale: locale,
            theme: theme ?? AppTheme.dark,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: probeRouter(const DashboardScreen()),
          )
        : MaterialApp(
            locale: locale,
            theme: theme ?? AppTheme.dark,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: const DashboardScreen()),
          ),
  );
}

/// The panel is drawn for the 1440×900 desktop frame the design targets.
void _useDesktopSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

String _amount(int minor, {String locale = 'fr'}) => formatAmount(
  amountMinor: minor,
  currency: 'EUR',
  locale: locale,
  showPositiveSign: true,
);

Future<void> _pump(
  WidgetTester tester,
  DashboardState state, {
  Locale locale = const Locale('fr'),
  ThemeData? theme,
}) async {
  _useDesktopSurface(tester);
  await tester.pumpWidget(_wrap(state: state, locale: locale, theme: theme));
  await tester.pumpAndSettle();
}

Finder _byKey(String key) => find.byKey(Key(key));

void main() {
  BuildContext ctx(WidgetTester tester) =>
      tester.element(find.byType(DashboardScreen));

  testWidgets('a recent activity row opens Transactions on it', (tester) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(_wrap(state: _state(), routed: true));
    await tester.pumpAndSettle();

    await tester.tap(_byKey('dashboardRecentRow-t1'));
    await tester.pumpAndSettle();

    expect(
      probedLocation(tester.widget(_byKey('routeProbe'))),
      '/transactions?operation=t1',
    );
  });

  group('reading line', () {
    testWidgets('leads with the savings rate, then income, expenses, net', (
      tester,
    ) async {
      await _pump(tester, _state());

      final xs = [
        for (final id in ['savings', 'income', 'expense', 'net'])
          tester.getTopLeft(_byKey('dashboardReading-$id')).dx,
      ];
      for (var i = 1; i < xs.length; i++) {
        expect(xs[i], greaterThan(xs[i - 1]));
      }
      expect(
        tester.getSize(_byKey('dashboardReading-savings')).width,
        ReadingLine.leadWidth,
      );
      // No card around it, no card anywhere on the panel.
      expect(find.byType(AppCard), findsNothing);
    });

    testWidgets('the rate reads against its goal on the repère', (
      tester,
    ) async {
      await _pump(tester, _state());

      expect(
        tester.widget<Text>(_byKey('dashboardSavingsRateValue')).data,
        formatRatioPct(0.223, 'fr'),
      );
      final meter = tester.widget<RepereMeter>(
        _byKey('dashboardSavingsGoalBar'),
      );
      // Scale 0 to twice the goal: 22,3 % sits just past the middle mark.
      expect(meter.fraction, closeTo(0.5575, 0.0001));
      expect(meter.markFraction, 0.5);
      expect(
        meter.markLabel,
        'objectif ${formatRatioPct(0.2, 'fr', decimalDigits: 0)}',
      );
      expect(meter.tone, RepereTone.done);

      final status = tester.widget<StatusText>(
        _byKey('dashboardSavingsGoalReached'),
      );
      expect(status.label, 'Objectif atteint');
      expect(status.tone, StatusTone.positive);
      expect(
        tester.widget<Text>(_byKey('dashboardSavingsDelta')).data,
        ' · +1,9 pt depuis avril',
      );
    });

    testWidgets('a goal not met says so without an icon', (tester) async {
      await _pump(
        tester,
        _state(
          summary: specSummary(savingsRate: 0.18, savingsRateDeltaPct: -0.8),
        ),
      );

      expect(_byKey('dashboardSavingsGoalReached'), findsNothing);
      expect(
        tester.widget<Text>(_byKey('dashboardSavingsDelta')).data,
        'Objectif ${formatRatioPct(0.2, 'fr', decimalDigits: 0)} en cours'
        ' · −0,8 pt depuis avril',
      );
      expect(
        tester.widget<RepereMeter>(_byKey('dashboardSavingsGoalBar')).tone,
        RepereTone.normal,
      );
    });

    testWidgets('the mark and the status follow the user\'s goal', (
      tester,
    ) async {
      await _pump(
        tester,
        _state(summary: specSummary(savingsRate: 0.223, savingsRateGoal: 0.30)),
      );

      final meter = tester.widget<RepereMeter>(
        _byKey('dashboardSavingsGoalBar'),
      );
      expect(
        meter.markLabel,
        'objectif ${formatRatioPct(0.3, 'fr', decimalDigits: 0)}',
      );
      expect(meter.fraction, closeTo(0.223 / 0.6, 0.0001));
      expect(meter.tone, RepereTone.normal);
      expect(_byKey('dashboardSavingsGoalReached'), findsNothing);
      expect(
        tester.widget<Text>(_byKey('dashboardSavingsDelta')).data,
        'Objectif ${formatRatioPct(0.3, 'fr', decimalDigits: 0)} en cours'
        ' · +1,9 pt depuis avril',
      );
    });

    testWidgets('no income: the rate is « — » and the repère is not drawn', (
      tester,
    ) async {
      await _pump(
        tester,
        _state(
          summary: specSummary(
            incomeMinor: 0,
            netMinor: -221435,
            savingsRate: 0,
          ),
        ),
      );

      expect(
        tester.widget<Text>(_byKey('dashboardSavingsRateValue')).data,
        '—',
      );
      expect(_byKey('dashboardSavingsGoalBar'), findsNothing);
    });

    testWidgets('signed figures; only Net takes the sign colour', (
      tester,
    ) async {
      await _pump(tester, _state());
      final colors = AppColors.of(ctx(tester));

      AmountText value(String id) =>
          tester.widget<AmountText>(_byKey('dashboardReadingValue-$id'));
      expect(value('income').amountMinor, 285000);
      expect(value('expense').amountMinor, -221435);
      expect(value('net').amountMinor, 63565);
      expect(value('income').colorize, isFalse);
      expect(value('expense').colorize, isFalse);
      expect(value('net').colorize, isTrue);
      expect(
        find.descendant(
          of: _byKey('dashboardReading-income'),
          matching: find.text(_amount(285000)),
        ),
        findsOneWidget,
      );
      expect(find.text(_amount(-221435)), findsOneWidget);

      Icon icon(String id) => tester.widget<Icon>(
        find.descendant(
          of: _byKey('dashboardReadingTrend-$id'),
          matching: find.byType(Icon),
        ),
      );
      // A rise in expenses is bad news; a fall in net is bad news.
      expect(icon('income').icon, LucideIcons300.trendingUp);
      expect(icon('income').color, colors.positive);
      expect(icon('expense').icon, LucideIcons300.trendingUp);
      expect(icon('expense').color, colors.negative);
      expect(icon('net').icon, LucideIcons300.trendingDown);
      expect(icon('net').color, colors.negative);
      // The percent is unsigned: the icon carries the direction.
      expect(
        tester.widget<Text>(_byKey('dashboardReadingDelta-net')).data,
        formatRatioPct(0.061, 'fr'),
      );
      expect(find.text('vs avril'), findsNWidgets(3));
    });

    testWidgets('a flat month draws minus in textSecondary', (tester) async {
      await _pump(tester, _state(summary: specSummary(incomeDeltaPct: 0)));

      final icon = tester.widget<Icon>(
        find.descendant(
          of: _byKey('dashboardReadingTrend-income'),
          matching: find.byType(Icon),
        ),
      );
      expect(icon.icon, LucideIcons300.minus);
      expect(icon.color, AppColors.of(ctx(tester)).textSecondary);
    });
  });

  group('dépenses par catégorie', () {
    testWidgets('ranks the categories, largest first, with the total', (
      tester,
    ) async {
      await _pump(tester, _state());

      final rows = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith(
              'dashboardSpendingRow-',
            ),
      );
      expect(rows, findsNWidgets(7));
      final ys = [
        for (final id in ['c1', 'c2', 'c3', 'c4', 'c5', 'c6', 'c7'])
          tester.getTopLeft(_byKey('dashboardSpendingRow-$id')).dy,
      ];
      for (var i = 1; i < ys.length; i++) {
        expect(ys[i], greaterThan(ys[i - 1]));
      }
      expect(
        tester.getSize(_byKey('dashboardSpendingRow-c1')).height,
        CategorySpending.rowHeight,
      );
      expect(
        tester.widget<AmountText>(_byKey('dashboardCategoryTotal')).amountMinor,
        221435,
      );

      // Bars are measured against the largest row.
      final bars = find.byKey(const Key('dashboardSpendingBar'));
      final first = tester.getSize(bars.at(0)).width;
      final second = tester.getSize(bars.at(1)).width;
      expect(second / first, closeTo(48620 / 95000, 0.01));
      expect(tester.getSize(bars.at(0)).height, 6);
    });

    for (final (themeName, theme, palette) in [
      ('dark', AppTheme.dark, CategoryColors.dark),
      ('light', AppTheme.light, CategoryColors.light),
    ]) {
      testWidgets('a custom category wears its own hue ($themeName)', (
        tester,
      ) async {
        await _pump(
          tester,
          _state(
            summary: specSummary(
              expenseMinor: 10000,
              byCategory: const [
                CategoryBreakdown(
                  categoryId: 'garden',
                  name: 'Jardin',
                  hue: 'cat6',
                  amountMinor: 7000,
                  pct: 70,
                ),
                CategoryBreakdown(
                  categoryId: 'misc',
                  name: 'Divers',
                  hue: 'cat0',
                  amountMinor: 3000,
                  pct: 30,
                ),
              ],
            ),
          ),
          theme: theme,
        );

        Color barColor(String id) {
          final bar = tester.widget<Container>(
            find.descendant(
              of: _byKey('dashboardSpendingRow-$id'),
              matching: find.byKey(const Key('dashboardSpendingBar')),
            ),
          );
          return (bar.decoration! as BoxDecoration).color!;
        }

        Color dotColor(String id) {
          final dot = tester.widget<Container>(
            find.descendant(
              of: _byKey('dashboardSpendingRow-$id'),
              matching: find.byKey(const Key('categoryLabelDot')),
            ),
          );
          return (dot.decoration! as BoxDecoration).color!;
        }

        expect(find.text('Jardin'), findsOneWidget);
        expect(barColor('garden'), palette.cat6);
        expect(dotColor('garden'), palette.cat6);
        expect(barColor('misc'), palette.cat0);
      });
    }

    testWidgets('a month without spending shows the note', (tester) async {
      await _pump(
        tester,
        _state(
          summary: specSummary(
            expenseMinor: 0,
            netMinor: 285000,
            savingsRate: 1,
            byCategory: const [],
          ),
        ),
      );

      expect(_byKey('dashboardCategoryEmpty'), findsOneWidget);
      expect(find.text('Aucune dépense ce mois.'), findsOneWidget);
    });
  });

  group('épargne mensuelle', () {
    testWidgets('bars only, the month in progress hatched', (tester) async {
      await _pump(tester, _state());

      final chart = tester.widget<SignedBarChart>(find.byType(SignedBarChart));
      expect(chart.values, hasLength(12));
      expect(chart.provisional, {11});
      // No view switch: the chart is bars only.
      expect(
        find.descendant(
          of: _byKey('dashboardMonthlySavings'),
          matching: find.byWidgetPredicate((w) => w is AppSegmented),
        ),
        findsNothing,
      );
      expect(
        tester.widget<AmountText>(_byKey('dashboardAverageSaved')).amountMinor,
        specTrends().averageSavedMinor,
      );
      expect(find.text('en moyenne sur 12 mois'), findsOneWidget);
    });

    testWidgets('an earlier month hatches nothing', (tester) async {
      // The window ends on May 2026, but the calendar has moved on to July.
      final trends = specTrends();
      await _pump(
        tester,
        _state(
          trends: DashboardTrends(
            savingsSeries: trends.savingsSeries,
            currency: trends.currency,
            currentMonth: DateTime(2026, 7),
          ),
        ),
      );

      expect(
        tester.widget<SignedBarChart>(find.byType(SignedBarChart)).provisional,
        isEmpty,
      );
    });

    testWidgets('hovering a month names its signed amount', (tester) async {
      await _pump(tester, _state());

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(gesture.removePointer);
      await gesture.addPointer(location: Offset.zero);
      await gesture.moveTo(tester.getCenter(_byKey('signedBarSlot-8')));
      await tester.pumpAndSettle();

      final card = find.byKey(const Key('signedBarTooltip'));
      expect(card, findsOneWidget);
      expect(
        find.descendant(
          of: card,
          matching: find.textContaining(_amount(-11840), findRichText: true),
        ),
        findsOneWidget,
      );
    });
  });

  group('activité récente', () {
    testWidgets('a header-less table of 36 px rows', (tester) async {
      await _pump(tester, _state());

      expect(find.byType(RecentActivity), findsOneWidget);
      expect(
        tester.getSize(_byKey('dashboardRecentRow-t1')).height,
        AppSizes.tableRow,
      );
      expect(find.text('BNP Compte courant'), findsNWidgets(3));
      expect(find.text('Toutes les transactions'), findsOneWidget);
    });

    testWidgets('as many rows as fit, six at 900 px', (tester) async {
      final many = [
        for (var i = 0; i < 12; i++)
          RecentTransaction(
            id: 'r$i',
            label: 'Café du Port',
            accountLabel: 'Compte courant',
            bookedDate: DateTime(2026, 5, 20 - i),
            amountMinor: -420,
            currency: 'EUR',
          ),
      ];
      await _pump(tester, _state(recent: many));

      final shown = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith(
              'dashboardRecentRow-',
            ),
      );
      expect(shown.evaluate().length, inInclusiveRange(5, 8));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a raw bank label is set in Geist Mono behind « ? »', (
      tester,
    ) async {
      await _pump(
        tester,
        _state(
          recent: [
            RecentTransaction(
              id: 'raw',
              label: 'CB CAFE DU PORT 12/05',
              accountLabel: 'Compte courant',
              bookedDate: DateTime(2026, 5, 12),
              amountMinor: -512,
              currency: 'EUR',
              isRawLabel: true,
            ),
          ],
        ),
      );

      final label = tester.widget<Text>(find.text('CB CAFE DU PORT 12/05'));
      expect(label.style?.fontFamily, AppFonts.mono);
      final avatar = tester.widget<InstitutionAvatar>(
        find.descendant(
          of: _byKey('dashboardRecentRow-raw'),
          matching: find.byType(InstitutionAvatar),
        ),
      );
      expect(avatar.name, isEmpty);
    });
  });

  group('states', () {
    testWidgets('no transaction at all: the empty state', (tester) async {
      await _pump(tester, _state(recent: const []));

      expect(find.byType(EmptyStateView), findsOneWidget);
      expect(find.text('Aucune donnée pour ce mois'), findsOneWidget);
      expect(_byKey('dashboardGoToImportsButton'), findsOneWidget);
      expect(find.byType(PrimaryButton), findsOneWidget);
      expect(find.byType(ReadingLine), findsNothing);
    });

    testWidgets('a month without data keeps the panel with « — » figures', (
      tester,
    ) async {
      await _pump(
        tester,
        _state(
          summary: specSummary(
            incomeMinor: 0,
            expenseMinor: 0,
            netMinor: 0,
            savingsRate: 0,
            byCategory: const [],
          ),
        ),
      );

      expect(find.byType(EmptyStateView), findsNothing);
      for (final id in ['income', 'expense', 'net']) {
        final text = tester.widget<Text>(_byKey('dashboardReadingValue-$id'));
        expect(text.data, '—');
        expect(text.style?.color, AppColors.of(ctx(tester)).textTertiary);
        expect(_byKey('dashboardReadingTrend-$id'), findsNothing);
      }
      expect(find.text('Aucune dépense ce mois.'), findsOneWidget);
      // The chart and the activity keep their own ranges.
      expect(find.byType(SignedBarChart), findsOneWidget);
      expect(find.byType(RecentActivity), findsOneWidget);
    });

    testWidgets('loading draws the silhouette, not a spinner', (tester) async {
      _useDesktopSurface(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dashboardControllerProvider.overrideWith(
              FakeLoadingDashboardController.new,
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.dark,
            locale: const Locale('fr'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: DashboardScreen()),
          ),
        ),
      );
      await tester.pump();

      expect(_byKey('dashboardLoadingIndicator'), findsOneWidget);
      expect(find.byType(SkeletonBlock), findsNWidgets(5));
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('renders in en', (tester) async {
      await _pump(tester, _state(), locale: const Locale('en'));

      expect(find.text('Savings rate'), findsOneWidget);
      expect(
        find.descendant(
          of: _byKey('dashboardReading-income'),
          matching: find.text(_amount(285000, locale: 'en')),
        ),
        findsOneWidget,
      );
      expect(_amount(285000, locale: 'en'), '+€2,850.00');
      expect(find.text('vs April'), findsNWidgets(3));
      expect(find.text('Spending by category'), findsOneWidget);
      expect(find.text('Monthly savings'), findsOneWidget);
      expect(find.text('on average over 12 months'), findsOneWidget);
      expect(find.text('All transactions'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders in the light theme', (tester) async {
      await _pump(tester, _state(), theme: AppTheme.light);

      expect(find.byType(ReadingLine), findsOneWidget);
      expect(
        tester.widget<Text>(_byKey('dashboardSavingsRateValue')).style?.color,
        AppColors.light.text,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the collapsed sidebar draws the same blocks, wider', (
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
            reviewCountProvider.overrideWith((ref) async => 0),
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

      expect(find.byType(ReadingLine), findsOneWidget);
      expect(find.byType(CategorySpending), findsOneWidget);
      expect(find.byType(MonthlySavings), findsOneWidget);
      expect(find.byType(RecentActivity), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
