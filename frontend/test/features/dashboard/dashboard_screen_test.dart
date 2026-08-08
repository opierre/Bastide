import 'package:finstride/core/navigation/sidebar_controller.dart';
import 'package:finstride/core/theme/app_theme.dart';
import 'package:finstride/core/theme/tokens.dart';
import 'package:finstride/core/widgets/amount_text.dart';
import 'package:finstride/core/widgets/area_line.dart';
import 'package:finstride/core/widgets/app_shell.dart';
import 'package:finstride/core/widgets/category_chip.dart';
import 'package:finstride/core/widgets/primary_button.dart';
import 'package:finstride/core/widgets/state_views.dart';
import 'package:finstride/features/dashboard/application/dashboard_controller.dart';
import 'package:finstride/features/dashboard/domain/dashboard_summary.dart';
import 'package:finstride/features/dashboard/domain/dashboard_trends.dart';
import 'package:finstride/features/dashboard/presentation/category_breakdown.dart';
import 'package:finstride/features/dashboard/presentation/dashboard_screen.dart';
import 'package:finstride/features/dashboard/presentation/income_vs_expense.dart';
import 'package:finstride/features/dashboard/presentation/recent_activity.dart';
import 'package:finstride/features/dashboard/presentation/savings_trend.dart';
import 'package:finstride/features/dashboard/presentation/stat_card.dart';
import 'package:finstride/l10n/app_localizations.dart';
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
      find.descendant(
        of: find.byType(StatCard),
        matching: find.text(
          formatAmount(
            amountMinor: 285000,
            currency: 'EUR',
            locale: 'fr',
            showPositiveSign: true,
          ),
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
    final netInCard = find.descendant(
      of: find.byType(StatCard),
      matching: find.text(netText),
    );
    expect(netInCard, findsOneWidget);
    expect(tester.widget<Text>(netInCard).style?.color, AppColors.textPrimary);

    // A trend pill is colored by whether the movement is good news, not by its sign: income
    // up is green, net down is red — and the expense card inverts, because spending 4,8 %
    // more than last month is the one rise the panel should not congratulate.
    Color? pillColor(double delta) => tester
        .widget<Text>(find.text(formatDeltaPct(delta, 'fr')))
        .style
        ?.color;

    expect(find.text(formatDeltaPct(2.1, 'fr')), findsOneWidget);
    expect(find.text(formatDeltaPct(4.8, 'fr')), findsOneWidget);
    expect(find.text(formatDeltaPct(-6.1, 'fr')), findsOneWidget);
    expect(pillColor(2.1), AppColors.positive);
    expect(pillColor(4.8), AppColors.negative);
    expect(pillColor(-6.1), AppColors.negative);

    // The savings rate's change is in percentage *points*, not percent, and its value sits
    // inside the ring rather than beside it.
    expect(find.text('+1,9 pt'), findsOneWidget);
    expect(find.text(formatDeltaPct(1.9, 'fr')), findsNothing);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('dashboardSavingsRateValue')))
          .data,
      formatPct(22.3, 'fr'),
    );

    // Captions naming what each trend is measured against.
    expect(find.text('vs avril'), findsNWidgets(2));
    expect(find.text('revenus − dépenses'), findsOneWidget);
    expect(find.text('Objectif : 20 % · atteint'), findsOneWidget);
  });

  testWidgets(
    'an expense card that fell reads green — spending less is the good news',
    (tester) async {
      _useDesktopSurface(tester);
      await tester.pumpWidget(
        _wrap(state: _state(summary: specSummary(expenseDeltaPct: -4.6))),
      );
      await tester.pumpAndSettle();

      final pill = find.text(formatDeltaPct(-4.6, 'fr'));
      expect(pill, findsOneWidget);
      expect(tester.widget<Text>(pill).style?.color, AppColors.positive);
    },
  );

  testWidgets(
    'the savings hero card is outlined in iris, not the neutral card border',
    (tester) async {
      _useDesktopSurface(tester);
      await tester.pumpWidget(_wrap(state: _state()));
      await tester.pumpAndSettle();

      // The card's own ramp is a few percent of lightness wide, so the border is what carries
      // the hero apart from the three neutral cards beside it.
      final decorated = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(SavingsRateCard),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = decorated.decoration! as BoxDecoration;
      expect(decoration.gradient, AppColors.irisGradient);
      expect(
        (decoration.border! as Border).top.color,
        AppColors.irisBorderStrong,

      // The tint is a wash over the same base the neutral cards use, so the ring reads against
      // the app's inset-plate track and the pill keeps its ordinary semantic green — neither
      // of which a saturated iris ground could carry.
      final ring = tester.widget<CircularProgressIndicator>(
        find.descendant(
          of: find.byType(SavingsRateRing),
          matching: find.byType(CircularProgressIndicator),
        ),
      );
      expect(ring.value, closeTo(0.223, 0.0001));
      expect(ring.backgroundColor, AppColors.surfaceHover);
      expect(ring.valueColor?.value, AppColors.iris);
      expect(tester.widget<Text>(find.text('+1,9 pt')).style?.color, AppColors.positive);

      // The label is iris rather than the gray every other stat label takes.
      expect(
        tester.widget<Text>(find.text('Taux d\'épargne'.toUpperCase())).style?.color,
        AppColors.iris,
      );
      );
    },
  );

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
      find.descendant(
        of: find.byType(StatCard),
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

  testWidgets('row 2 splits 1.35 / 1, at the same height as row 3', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(_wrap(state: _state()));
    await tester.pumpAndSettle();

    final donutCard = tester.getSize(find.byType(CategoryBreakdownChart));
    final savingsCard = tester.getSize(find.byType(SavingsTrendChart));

    expect(donutCard.height, savingsCard.height);
    expect(donutCard.width / savingsCard.width, closeTo(1.35, 0.01));

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
    expect(tester.widget<Text>(net(-11840)).style?.color, AppColors.negative);
    for (final minor in [54020, 73710, 63565]) {
      expect(tester.widget<Text>(net(minor)).style?.color, AppColors.positive);
    }
  });

  testWidgets('the current month\'s bar label is primary, earlier months recede', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(_wrap(state: _state()));
    await tester.pumpAndSettle();

    final bars = find.byType(IncomeVsExpenseChart);
    Text label(String month) =>
        tester.widget<Text>(find.descendant(of: bars, matching: find.text(month)));

    expect(label('Mai').style?.color, AppColors.textPrimary);
    for (final month in ['Févr.', 'Mars', 'Avr.']) {
      expect(label(month).style?.color, AppColors.textSecondary);
    }
  });

  testWidgets('hovering a bar names that month\'s income and expense', (tester) async {
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
      contains(formatAmount(amountMinor: -221435, currency: 'EUR', locale: 'fr')),
    );
  });

  testWidgets('the activity list is the compact variant: no chip, amount over date', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(_wrap(state: _state()));
    await tester.pumpAndSettle();

    expect(find.text('Activité récente'), findsOneWidget);
    expect(find.byType(CompactTransactionRow), findsNWidgets(4));
    // The compact variant deliberately drops the category chip the 52px row carries.
    expect(find.byType(CategoryChip), findsNothing);

    for (final row in ['Carrefour', 'Novatech SARL', 'SNCF Connect', 'Free Mobile']) {
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

    expect(find.byKey(const Key('dashboardViewAllTransactions')), findsOneWidget);
  });

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

  testWidgets('a monogram with no pinned hue falls back to the neutral plate', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(_wrap(state: _state()));
    await tester.pumpAndSettle();

    // Carrefour and Novatech carry pinned hues (#3B82F6 and #6C6AF0, both as the spec's
    // table has them). Their *initials* come from `MonogramAvatar.initialsFor`, which takes
    // one letter per word — so « Novatech SARL » reads NS where the table draws NV.
    expect(find.text('CA'), findsOneWidget);
    expect(find.text('NS'), findsOneWidget);
    // SNCF Connect and Free Mobile have no pinned hue, so they keep the neutral "?" plate
    // rather than the table's SC / FM.
    expect(find.text('?'), findsNWidgets(2));
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
          recent: const [],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Importez un relevé pour donner vie à votre argent'), findsOneWidget);
    // The reassurance answers the doubt the CTA creates — the user has just been asked to
    // hand over a bank statement.
    expect(
      find.text('Tout reste sur cet ordinateur — rien n\'est envoyé en ligne.'),
      findsOneWidget,
    );
    // One *primary* CTA, per the EmptyState spec.
    expect(find.byKey(const Key('dashboardGoToImportsButton')), findsOneWidget);
    expect(find.byType(PrimaryButton), findsOneWidget);

    // Nothing else is on screen: the empty state replaces the whole panel.
    expect(find.byType(StatCard), findsNothing);
    expect(find.byType(CategoryDonut), findsNothing);
    expect(find.byType(IncomeVsExpenseChart), findsNothing);
  });

  testWidgets('the loading skeleton silhouettes all three rows at their real ratios', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardControllerProvider.overrideWith(FakeLoadingDashboardController.new),
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
      // 4 stat silhouettes + 2 for row 2 + 2 for row 3.
      expect(find.byType(SkeletonBlock), findsNWidgets(8));

      // The silhouette must not move the cards when the data lands, so it carries the same
      // ratios: 1:1:1:1.35 across row 1, and 1.35:1 across row 2.
      final blocks = [
        for (var i = 0; i < 8; i++)
          tester.getSize(find.byType(SkeletonBlock).at(i)),
      ];
      expect(blocks[0].height, 175);
      expect(blocks[3].width / blocks[0].width, closeTo(1.35, 0.01));
      expect(blocks[4].width / blocks[5].width, closeTo(1.35, 0.01));
      // Rows 2 and 3 are equal-height in the silhouette too, as they are once data lands.
      expect(blocks[4].height, blocks[6].height);
      expect(blocks[6].width, closeTo(blocks[7].width, 0.5));
    },
  );

  testWidgets('the panel renders unchanged under the collapsed 76px nav rail', (tester) async {
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
          theme: appDarkTheme,
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
    expect(find.byType(StatCard), findsNWidgets(3));
    expect(find.byType(CategoryDonut), findsOneWidget);
    expect(find.byType(IncomeVsExpenseChart), findsOneWidget);
    expect(find.byType(CompactTransactionRow), findsNWidgets(4));
    expect(tester.takeException(), isNull);
  });
}
