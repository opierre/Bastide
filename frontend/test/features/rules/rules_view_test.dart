import 'package:finstride/core/theme/app_theme.dart';
import 'package:finstride/core/widgets/app_toggle.dart';
import 'package:finstride/features/categories/application/categories_controller.dart';
import 'package:finstride/features/categories/presentation/categories_screen.dart';
import 'package:finstride/features/rules/application/rules_controller.dart';
import 'package:finstride/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_categories_controller.dart';
import '../../support/fake_rules_controller.dart';

Widget _wrap({
  required FakeRulesController rules,
  FakeCategoriesController? categories,
  Locale locale = const Locale('fr'),
}) {
  return ProviderScope(
    overrides: [
      rulesControllerProvider.overrideWith(() => rules),
      categoriesControllerProvider.overrideWith(
        () =>
            categories ??
            FakeCategoriesController(
              initialCategories: [
                testCategory(id: 'groceries', name: 'category.food.groceries'),
              ],
            ),
      ),
    ],
    child: MaterialApp(
      locale: locale,
      theme: appDarkTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: CategoriesScreen()),
    ),
  );
}

/// Switches the panel to its rules half — the segmented control is part of the
/// screen, so the tests drive it the way a user would.
Future<void> _openRules(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('rulesViewSegment')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'a rule row renders its condition badge, pattern and target chip',
    (tester) async {
      await tester.pumpWidget(
        _wrap(rules: FakeRulesController(initialRules: [testRule()])),
      );
      await tester.pumpAndSettle();
      await _openRules(tester);

      expect(find.byKey(const Key('ruleCondition-r1')), findsOneWidget);
      expect(find.text('contient'), findsOneWidget);
      expect(find.text('CARREFOUR'), findsOneWidget);
      expect(find.text('Courses'), findsOneWidget);
      expect(find.text('Commerçant'), findsOneWidget);
    },
  );

  testWidgets(
    'a disabled rule renders at reduced opacity with its toggle off',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          rules: FakeRulesController(
            initialRules: [
              testRule(),
              testRule(
                id: 'r2',
                priority: 2,
                pattern: 'AMAZON',
                enabled: false,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _openRules(tester);

      // The row's own wash is its outermost Opacity — the toggle carries one of
      // its own for its disabled state, which is not what this asserts.
      double rowOpacity(String id) => tester
          .widgetList<Opacity>(
            find.descendant(
              of: find.byKey(Key('ruleRow-$id')),
              matching: find.byType(Opacity),
            ),
          )
          .first
          .opacity;

      expect(rowOpacity('r1'), 1.0);
      expect(rowOpacity('r2'), 0.5);

      final toggle = tester.widget<AppToggle>(
        find.byKey(const Key('ruleToggle-r2')),
      );
      expect(toggle.value, isFalse);
    },
  );

  testWidgets('toggling a rule calls the controller', (tester) async {
    final rules = FakeRulesController(initialRules: [testRule()]);
    await tester.pumpWidget(_wrap(rules: rules));
    await tester.pumpAndSettle();
    await _openRules(tester);

    await tester.tap(find.byKey(const Key('ruleToggle-r1')));
    await tester.pumpAndSettle();

    expect(rules.toggleCalls, [(id: 'r1', enabled: false)]);
  });

  testWidgets('« Exécuter les règles » shows the count and the reassurance', (
    tester,
  ) async {
    final rules = FakeRulesController(
      initialRules: [testRule()],
      applyCount: 48,
    );
    await tester.pumpWidget(_wrap(rules: rules));
    await tester.pumpAndSettle();
    await _openRules(tester);

    await tester.tap(find.byKey(const Key('applyRulesButton')));
    await tester.pumpAndSettle();

    expect(rules.applyCalls, 1);
    expect(find.byKey(const Key('appToast')), findsOneWidget);
    expect(find.text('48 transactions recatégorisées'), findsOneWidget);
    expect(
      find.text(
        "Vos catégories choisies manuellement n'ont pas été modifiées.",
      ),
      findsOneWidget,
    );
  });

  testWidgets('a rule whose category is gone renders the uncategorized chip', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        rules: FakeRulesController(
          initialRules: [testRule(categoryId: 'deleted')],
        ),
        categories: FakeCategoriesController(),
      ),
    );
    await tester.pumpAndSettle();
    await _openRules(tester);

    expect(find.text('Catégorie introuvable'), findsOneWidget);
  });

  testWidgets('the rules empty state explains what a rule does', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(rules: FakeRulesController()));
    await tester.pumpAndSettle();
    await _openRules(tester);

    expect(find.byKey(const Key('rulesEmptyState')), findsOneWidget);
    expect(find.byKey(const Key('emptyStateAddRuleButton')), findsOneWidget);
  });

  testWidgets('a load failure renders the error state with a retry', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(rules: FakeRulesController(loadError: Exception('boom'))),
    );
    await tester.pumpAndSettle();
    await _openRules(tester);

    expect(find.byKey(const Key('rulesErrorText')), findsOneWidget);
    expect(find.byKey(const Key('rulesRetryButton')), findsOneWidget);
  });

  testWidgets('fr and en render the same row geometry', (tester) async {
    final rules = [testRule()];

    await tester.pumpWidget(
      _wrap(rules: FakeRulesController(initialRules: rules)),
    );
    await tester.pumpAndSettle();
    await _openRules(tester);
    final frRow = tester.getSize(find.byKey(const Key('ruleRow-r1')));
    expect(find.text('contient'), findsOneWidget);

    await tester.pumpWidget(
      _wrap(
        rules: FakeRulesController(initialRules: rules),
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();
    await _openRules(tester);

    // Size, not position: the priority note above the list is a full sentence
    // and wraps to a different number of lines in each language, so the card
    // legitimately starts lower in French. What must not change is the row —
    // a French label that grew the row or clipped its chip is the failure this
    // guards against.
    expect(tester.getSize(find.byKey(const Key('ruleRow-r1'))), frRow);
    expect(find.text('contains'), findsOneWidget);
    expect(find.text('Groceries'), findsOneWidget);
  });
}
