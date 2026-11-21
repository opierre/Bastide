import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/core/theme/tokens.dart';
import 'package:bastide/core/widgets/app_toggle.dart';
import 'package:bastide/features/categories/application/categories_controller.dart';
import 'package:bastide/features/categories/presentation/categories_screen.dart';
import 'package:bastide/features/categories/presentation/categories_top_bar_actions.dart';
import 'package:bastide/features/rules/application/rule_match_counts.dart';
import 'package:bastide/features/rules/application/rules_controller.dart';
import 'package:bastide/l10n/app_localizations.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_categories_controller.dart';
import '../../support/fake_rules_controller.dart';

/// The panel with its title-bar controls above it, as the shell lays it out.
Widget _wrap({
  required FakeRulesController rules,
  FakeCategoriesController? categories,
  Map<String, int> matchCounts = const {},
  Locale locale = const Locale('fr'),
  ThemeData? theme,
}) {
  return ProviderScope(
    overrides: [
      rulesControllerProvider.overrideWith(() => rules),
      categoriesControllerProvider.overrideWith(
        () =>
            categories ??
            FakeCategoriesController(
              initialCategories: [
                testCategory(id: 'food', name: 'category.food'),
                testCategory(
                  id: 'groceries',
                  parentId: 'food',
                  name: 'category.food.groceries',
                ),
              ],
            ),
      ),
      ruleMatchCountsProvider.overrideWith((ref) async => matchCounts),
    ],
    child: MaterialApp(
      locale: locale,
      theme: theme ?? AppTheme.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: CategoriesTopBarActions(),
            ),
            Expanded(child: CategoriesScreen()),
          ],
        ),
      ),
    ),
  );
}

void _useDesktopSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('the table heads its columns and a row fills them', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        rules: FakeRulesController(initialRules: [testRule()]),
        matchCounts: const {'r1': 48},
      ),
    );
    await tester.pumpAndSettle();

    for (final header in [
      'Ordre',
      'Champ',
      'Condition',
      'Motif',
      'Catégorie',
      'Correspondances',
      'Active',
    ]) {
      expect(find.text(header), findsOneWidget, reason: header);
    }
    expect(find.text('Commerçant'), findsOneWidget);
    expect(find.text('contient'), findsOneWidget);
    expect(find.text('CARREFOUR'), findsOneWidget);
    // The category label: the parent, then the subcategory after « › ».
    expect(find.text('Alimentation'), findsWidgets);
    expect(
      find.text('Alimentation › Courses', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('48'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('ruleRow-r1'))).height,
      AppSizes.tableRow,
    );
  });

  testWidgets('a row shows its position in the whole order', (tester) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        rules: FakeRulesController(
          initialRules: [
            testRule(),
            testRule(id: 'r2', priority: 5, pattern: 'SNCF'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    Text position(String id) =>
        tester.widget<Text>(find.byKey(Key('rulePosition-$id')));
    expect(position('r1').data, '1');
    expect(position('r2').data, '2');
  });

  testWidgets('a disabled rule is dimmed with its toggle off', (tester) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        rules: FakeRulesController(
          initialRules: [
            testRule(),
            testRule(id: 'r2', priority: 2, pattern: 'AMAZON', enabled: false),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    Color? colorOf(String text) =>
        tester.widget<Text>(find.text(text)).style?.color;
    expect(colorOf('AMAZON'), AppColors.dark.textTertiary);
    expect(colorOf('CARREFOUR'), AppColors.dark.text);

    final toggle = tester.widget<AppToggle>(
      find.byKey(const Key('ruleToggle-r2')),
    );
    expect(toggle.value, isFalse);
  });

  testWidgets('a row opens the rule editor', (tester) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(rules: FakeRulesController(initialRules: [testRule()])),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('CARREFOUR'));
    await tester.pumpAndSettle();

    expect(find.text('Modifier la règle'), findsOneWidget);
  });

  testWidgets('hovering the grip shows a hand cursor', (tester) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(rules: FakeRulesController(initialRules: [testRule()])),
    );
    await tester.pumpAndSettle();

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);
    await gesture.addPointer(location: Offset.zero);
    await gesture.moveTo(
      tester.getCenter(find.byKey(const Key('ruleHandle-r1'))),
    );
    await tester.pump();

    expect(
      RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
      SystemMouseCursors.click,
    );
  });

  testWidgets('dragging a row by its grip reorders through the controller', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    final rules = FakeRulesController(
      initialRules: [
        testRule(),
        testRule(id: 'r2', priority: 2, pattern: 'SNCF'),
        testRule(id: 'r3', priority: 3, pattern: 'FNAC'),
      ],
    );
    await tester.pumpWidget(_wrap(rules: rules));
    await tester.pumpAndSettle();

    final drag = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('ruleHandle-r1'))),
    );
    await tester.pump(kLongPressTimeout);
    await drag.moveBy(const Offset(0, AppSizes.tableRow * 2.5));
    await tester.pump();
    await drag.up();
    await tester.pumpAndSettle();

    expect(rules.reorderCalls, hasLength(1));
    expect(rules.reorderCalls.single.oldIndex, 0);
  });

  testWidgets('a rule with a start date says from when it applies', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        rules: FakeRulesController(
          initialRules: [
            testRule(),
            testRule(id: 'r2', appliesFrom: DateTime(2026, 1, 30)),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ruleAppliesFrom-r1')), findsNothing);
    expect(find.text('à partir du 30/01/2026'), findsOneWidget);
  });

  testWidgets('toggling a rule calls the controller', (tester) async {
    _useDesktopSurface(tester);
    final rules = FakeRulesController(initialRules: [testRule()]);
    await tester.pumpWidget(_wrap(rules: rules));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('ruleToggle-r1')));
    await tester.pumpAndSettle();

    expect(rules.toggleCalls, [(id: 'r1', enabled: false)]);
  });

  testWidgets('« Exécuter les règles » shows the count and the reassurance', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    final rules = FakeRulesController(
      initialRules: [testRule()],
      applyCount: 48,
    );
    await tester.pumpWidget(_wrap(rules: rules));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('applyRulesButton')));
    await tester.pumpAndSettle();

    expect(rules.applyCalls, 1);
    expect(find.byKey(const Key('appToast')), findsOneWidget);
    expect(find.text('48 opérations recatégorisées'), findsOneWidget);
    expect(
      find.text('Vos catégories choisies à la main n’ont pas été modifiées.'),
      findsOneWidget,
    );
  });

  testWidgets('« Nouvelle règle » in the title bar opens the editor', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(rules: FakeRulesController(initialRules: [testRule()])),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('addRuleButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ruleFormSubmit')), findsOneWidget);
  });

  testWidgets('a rule whose category is gone says the category is missing', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        rules: FakeRulesController(
          initialRules: [testRule(categoryId: 'deleted')],
        ),
        categories: FakeCategoriesController(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Catégorie introuvable'), findsOneWidget);
  });

  testWidgets('with no rule at all, the pane explains what a rule does', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(_wrap(rules: FakeRulesController()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('rulesEmptyState')), findsOneWidget);
    expect(find.text('Aucune règle'), findsOneWidget);
    expect(find.byKey(const Key('emptyStateAddRuleButton')), findsOneWidget);
  });

  testWidgets('a load failure renders the error state with a retry', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(rules: FakeRulesController(loadError: Exception('boom'))),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('rulesErrorText')), findsOneWidget);
    expect(find.byKey(const Key('rulesRetryButton')), findsOneWidget);
  });

  testWidgets('the light theme draws the pattern in its own text colour', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        rules: FakeRulesController(initialRules: [testRule()]),
        theme: AppTheme.light,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.text('CARREFOUR')).style?.color,
      AppColors.light.text,
    );
  });

  testWidgets('fr and en render the same row geometry', (tester) async {
    _useDesktopSurface(tester);
    final rules = [testRule()];

    await tester.pumpWidget(
      _wrap(rules: FakeRulesController(initialRules: rules)),
    );
    await tester.pumpAndSettle();
    final frRow = tester.getRect(find.byKey(const Key('ruleRow-r1')));
    expect(find.text('contient'), findsOneWidget);

    await tester.pumpWidget(
      _wrap(
        rules: FakeRulesController(initialRules: rules),
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.getRect(find.byKey(const Key('ruleRow-r1'))), frRow);
    expect(find.text('contains'), findsOneWidget);
    expect(find.text('Food › Groceries', findRichText: true), findsOneWidget);
    expect(find.text('Matches'), findsOneWidget);
  });
}
