import 'package:finstride/core/theme/app_theme.dart';
import 'package:finstride/core/theme/tokens.dart';
import 'package:finstride/core/widgets/amount_text.dart';
import 'package:finstride/core/widgets/app_card.dart';
import 'package:finstride/core/widgets/inline_banner.dart';
import 'package:finstride/features/goals/application/goals_controller.dart';
import 'package:finstride/features/goals/domain/goal.dart';
import 'package:finstride/features/goals/presentation/goal_card.dart';
import 'package:finstride/features/goals/presentation/goals_screen.dart';
import 'package:finstride/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/goals_fixtures.dart';

/// The panel's own money formatting, so the expectations can't drift from the
/// locale's separators (French uses a narrow no-break space before « € »).
String _money(int amountMinor, {String locale = 'fr'}) =>
    formatAmount(amountMinor: amountMinor, currency: 'EUR', locale: locale);

Widget _wrap({
  required FakeGoalsController controller,
  Locale locale = const Locale('fr'),
}) {
  return ProviderScope(
    overrides: [goalsControllerProvider.overrideWith(() => controller)],
    child: MaterialApp(
      locale: locale,
      theme: appDarkTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: GoalsScreen()),
    ),
  );
}

/// The panel is drawn for the 1440×900 desktop frame the design targets — the
/// grid runs to two columns and needs the width it was drawn at.
void _useDesktopSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('a card renders its name, amounts, percent and bar in fr', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(controller: FakeGoalsController(initialGoals: specGoals())),
    );
    await tester.pumpAndSettle();

    expect(find.text("Fonds d'urgence"), findsOneWidget);
    expect(find.text(_money(640000)), findsOneWidget);
    expect(find.text('/ ${_money(1000000)}'), findsOneWidget);
    expect(find.text('64 %'), findsOneWidget);

    final bar = tester.widget<GoalProgressBar>(
      find.descendant(
        of: find.byKey(const Key('goalCard-g1')),
        matching: find.byType(GoalProgressBar),
      ),
    );
    expect(bar.fraction, closeTo(0.64, 1e-9));

    // What is set aside is a standing quantity, not a movement, so the money
    // rule's colors would state something false about it.
    final saved = tester.widget<AmountText>(
      find.byKey(const Key('goalSaved-g1')),
    );
    expect(saved.colorize, isFalse);

    // No account appears anywhere in this feature (`11-goals.md` §Concept).
    expect(find.textContaining('BNP'), findsNothing);
  });

  testWidgets('the same card formats its amounts for en', (tester) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        controller: FakeGoalsController(initialGoals: specGoals()),
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(_money(640000, locale: 'en')), findsOneWidget);
    expect(find.text('/ ${_money(1000000, locale: 'en')}'), findsOneWidget);
    expect(find.text('No deadline'), findsOneWidget);
    expect(find.text('Show archived goals (0)'), findsNothing);
  });

  testWidgets(
    'an over-funded goal clamps the bar and reports the true percent',
    (tester) async {
      _useDesktopSurface(tester);
      await tester.pumpWidget(
        _wrap(
          controller: FakeGoalsController(
            initialGoals: [
              testGoal(targetMinor: 1000000, progressMinor: 1180000),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // A bar past its own track reads as a rendering bug; a percentage rounded
      // down to 100 would be a lie about the user's money.
      final bar = tester.widget<GoalProgressBar>(find.byType(GoalProgressBar));
      expect(bar.fraction, 1.0);
      expect(find.text('118 %'), findsOneWidget);
    },
  );

  testWidgets('a reached goal renders its green treatment and check pill', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(controller: FakeGoalsController(initialGoals: specGoals())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Objectif atteint · Juin 2026'), findsOneWidget);

    final percent = tester.widget<Text>(
      find.byKey(const Key('goalPercent-g3')),
    );
    expect(percent.style?.color, AppColors.positive);

    // The reached card is outlined in green rather than the card hairline.
    final card = tester.widget<AppCard>(find.byKey(const Key('goalCard-g3')));
    expect((card.border! as Border).top.color, AppColors.positiveBorder);
  });

  testWidgets('the archived link states the count and reveals dimmed cards', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        controller: FakeGoalsController(
          initialGoals: [testGoal()],
          archivedGoals: [
            testGoal(
              id: 'g8',
              name: 'Vieux projet',
              status: GoalStatus.archived,
            ),
            testGoal(
              id: 'g9',
              name: 'Ancien voyage',
              status: GoalStatus.archived,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Afficher les objectifs archivés (2)'), findsOneWidget);
    expect(find.byKey(const Key('goalCard-g8')), findsNothing);

    await tester.tap(find.byKey(const Key('goalsArchivedToggle')));
    await tester.pumpAndSettle();

    expect(find.text('Masquer les objectifs archivés (2)'), findsOneWidget);
    expect(find.byKey(const Key('goalCard-g8')), findsOneWidget);
    final archivedCard = tester.widget<GoalCard>(
      find.byWidgetPredicate(
        (widget) => widget is GoalCard && widget.goal.id == 'g8',
      ),
    );
    expect(archivedCard.dimmed, isTrue);
  });

  testWidgets('over-allocation warns without blocking, and can be dismissed', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        controller: FakeGoalsController(
          initialGoals: [
            testGoal(progressMinor: 2445000, targetMinor: 3000000),
          ],
          savingsAccounts: [testSavingsAccount(balanceMinor: 2210000)],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final banner = find.byKey(const Key('goalsOverAllocationBanner'));
    expect(banner, findsOneWidget);
    expect(
      tester.widget<InlineBanner>(banner).message,
      'Vous avez réparti ${_money(2445000)} alors que vos comptes '
      "d'épargne totalisent ${_money(2210000)}.",
    );
    // The grid is still there: the warning informs, it never blocks (§13).
    expect(find.byKey(const Key('goalCard-g1')), findsOneWidget);

    await tester.tap(
      find.descendant(of: banner, matching: find.byType(IconButton)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('goalsOverAllocationBanner')), findsNothing);
    expect(find.byKey(const Key('goalCard-g1')), findsOneWidget);
  });

  testWidgets('a goal within its savings balance raises no banner', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        controller: FakeGoalsController(
          initialGoals: [testGoal(progressMinor: 640000)],
          savingsAccounts: [testSavingsAccount(balanceMinor: 2210000)],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('goalsOverAllocationBanner')), findsNothing);
  });

  testWidgets('the empty state offers the one action the panel wants', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(_wrap(controller: FakeGoalsController()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('goalsEmptyState')), findsOneWidget);
    expect(find.text('Donnez un nom à ce qui compte'), findsOneWidget);
    expect(find.byKey(const Key('goalsEmptyAddButton')), findsOneWidget);
  });

  testWidgets('the reassurance line is on the grid, above everything else', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(controller: FakeGoalsController(initialGoals: [testGoal()])),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Répartition sur le papier : vos comptes ne sont pas modifiés.',
      ),
      findsOneWidget,
    );
  });
}
