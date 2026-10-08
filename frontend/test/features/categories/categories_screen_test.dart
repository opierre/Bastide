import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/core/theme/tokens.dart';
import 'package:bastide/core/widgets/app_select.dart';
import 'package:bastide/features/categories/application/categories_controller.dart';
import 'package:bastide/features/categories/presentation/categories_screen.dart';
import 'package:bastide/features/rules/application/rules_controller.dart';
import 'package:bastide/features/rules/domain/rule.dart';
import 'package:bastide/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_categories_controller.dart';
import '../../support/fake_rules_controller.dart';

Widget _wrap({
  required FakeCategoriesController controller,
  List<Rule> rules = const [],
  Locale locale = const Locale('fr'),
}) {
  return ProviderScope(
    overrides: [
      categoriesControllerProvider.overrideWith(() => controller),
      rulesControllerProvider.overrideWith(
        () => FakeRulesController(initialRules: rules),
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

/// The panel is drawn for the 1440×900 desktop frame the design targets — four
/// cards to a row need the width they were drawn at.
void _useDesktopSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Finder _inCard(String id, Finder matching) => find.descendant(
  of: find.byKey(Key('categoryCard-$id')),
  matching: matching,
);

final _food = testCategory(id: 'food', name: 'category.food');
final _groceries = testCategory(
  id: 'groceries',
  parentId: 'food',
  name: 'category.food.groceries',
);
final _own = testCategory(
  id: 'own',
  userId: 'u1',
  name: 'Épargne projet',
  icon: 'loisirs',
  color: '#64748B',
  isSystem: false,
);

void main() {
  testWidgets('a system card renders the lock and offers no menu', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(controller: FakeCategoriesController(initialCategories: [_food])),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('categoryLock-food')), findsOneWidget);
    expect(find.byKey(const Key('categoryMenu-food')), findsNothing);
    expect(find.byKey(const Key('categoryBadgeSystem-food')), findsOneWidget);
    expect(_inCard('food', find.text('Dépense')), findsOneWidget);
  });

  testWidgets('a custom card renders the ⋯ menu, and no lock', (tester) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(controller: FakeCategoriesController(initialCategories: [_own])),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('categoryLock-own')), findsNothing);
    expect(find.byKey(const Key('categoryBadgeCustom-own')), findsOneWidget);

    await tester.tap(find.byKey(const Key('categoryMenu-own')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('categoryEdit-own')), findsOneWidget);
    expect(find.byKey(const Key('categoryDelete-own')), findsOneWidget);
  });

  testWidgets(
    'a card draws its chip glyph, or the icon a custom category chose',
    (tester) async {
      _useDesktopSurface(tester);
      await tester.pumpWidget(
        _wrap(
          controller: FakeCategoriesController(
            initialCategories: [_food, _own],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final food = tester.widget<Icon>(
        find.byKey(const Key('categoryIcon-food')),
      );
      expect(food.icon, Icons.rice_bowl_outlined);
      expect(food.color, CategoryHues.alimentation);
      final own = tester.widget<Icon>(
        find.byKey(const Key('categoryIcon-own')),
      );
      expect(own.icon, Icons.star_outline_rounded);
    },
  );

  testWidgets('subcategories render as chips inside their parent card', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        controller: FakeCategoriesController(
          initialCategories: [_food, _groceries],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('categoryCard-groceries')), findsNothing);
    expect(
      _inCard('food', find.byKey(const Key('subcategoryChip-groceries'))),
      findsOneWidget,
    );
    expect(_inCard('food', find.text('Courses')), findsOneWidget);
    expect(
      _inCard('food', find.byKey(const Key('addSubcategory-food'))),
      findsOneWidget,
    );
  });

  testWidgets('the view carries no amounts or shares', (tester) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        controller: FakeCategoriesController(
          initialCategories: [_food, _groceries, _own],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('€'), findsNothing);
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('cards run four to a row, the fifth below the first', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        controller: FakeCategoriesController(
          initialCategories: [
            for (final id in ['a', 'b', 'c', 'd', 'e'])
              testCategory(id: id, name: 'category.food'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final first = tester.getRect(find.byKey(const Key('categoryCard-a')));
    final fourth = tester.getRect(find.byKey(const Key('categoryCard-d')));
    final fifth = tester.getRect(find.byKey(const Key('categoryCard-e')));
    expect(fourth.top, first.top);
    expect(fifth.left, first.left);
    expect(fifth.top - first.bottom, AppSpacing.gridGap);
    expect(first.height, greaterThanOrEqualTo(196));
  });

  testWidgets(
    'deleting a custom category asks first, then calls the controller',
    (tester) async {
      _useDesktopSurface(tester);
      final controller = FakeCategoriesController(initialCategories: [_own]);
      await tester.pumpWidget(_wrap(controller: controller));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('categoryMenu-own')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('categoryDelete-own')));
      await tester.pumpAndSettle();
      expect(controller.deleteCalls, isEmpty);

      await tester.tap(find.byKey(const Key('categoryDeleteConfirmButton')));
      await tester.pumpAndSettle();
      expect(controller.deleteCalls, ['own']);
    },
  );

  testWidgets('a system subcategory chip is inert', (tester) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        controller: FakeCategoriesController(
          initialCategories: [_food, _groceries],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('subcategoryChip-groceries')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('categoryFormSubmit')), findsNothing);
  });

  testWidgets(
    'a custom subcategory chip opens its edit modal, which can delete it',
    (tester) async {
      _useDesktopSurface(tester);
      final controller = FakeCategoriesController(
        initialCategories: [
          _food,
          testCategory(
            id: 'mine',
            userId: 'u1',
            parentId: 'food',
            name: 'Marché',
            isSystem: false,
          ),
        ],
      );
      await tester.pumpWidget(_wrap(controller: controller));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('subcategoryChip-mine')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('categoryFormSubmit')), findsOneWidget);

      await tester.tap(find.byKey(const Key('categoryFormDelete')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('categoryDeleteConfirmButton')));
      await tester.pumpAndSettle();

      expect(controller.deleteCalls, ['mine']);
      expect(find.byKey(const Key('categoryFormSubmit')), findsNothing);
    },
  );

  testWidgets(
    '« + Sous-catégorie » opens the create modal with the parent preset',
    (tester) async {
      _useDesktopSurface(tester);
      await tester.pumpWidget(
        _wrap(controller: FakeCategoriesController(initialCategories: [_food])),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('addSubcategory-food')));
      await tester.pumpAndSettle();

      final parent = tester.widget<AppSelect<String?>>(
        find.byKey(const Key('categoryFormParent')),
      );
      expect(parent.value, 'food');
      expect(find.byKey(const Key('categoryFormDelete')), findsNothing);
    },
  );

  testWidgets(
    'a subcategory hides kind, icon and colour, and names its parent in the header',
    (tester) async {
      _useDesktopSurface(tester);
      await tester.pumpWidget(
        _wrap(controller: FakeCategoriesController(initialCategories: [_food])),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('addSubcategory-food')));
      await tester.pumpAndSettle();

      final header = find.byKey(const Key('categoryFormParentLine'));
      expect(
        find.descendant(of: header, matching: find.text('Alimentation')),
        findsOneWidget,
      );
      final glyph = tester.widget<Icon>(
        find.descendant(of: header, matching: find.byType(Icon)),
      );
      expect(glyph.icon, Icons.rice_bowl_outlined);
      expect(glyph.color, CategoryHues.alimentation);
      expect(find.byKey(const Key('categoryFormKind')), findsNothing);
      expect(find.byKey(const Key('categoryFormIcon')), findsNothing);
      expect(find.byKey(const Key('categoryFormColor-#64748B')), findsNothing);

      tester
          .widget<AppSelect<String?>>(
            find.byKey(const Key('categoryFormParent')),
          )
          .onChanged(null);
      await tester.pumpAndSettle();

      expect(header, findsNothing);
      expect(find.byKey(const Key('categoryFormKind')), findsOneWidget);
      expect(find.byKey(const Key('categoryFormIcon')), findsOneWidget);
      expect(
        find.byKey(const Key('categoryFormColor-#64748B')),
        findsOneWidget,
      );
    },
  );

  // --- the rule-count footer ----------------------------------------------------------

  testWidgets('the footer counts rules on the category and its subcategories', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        controller: FakeCategoriesController(
          initialCategories: [_food, _groceries, _own],
        ),
        rules: [
          testRule(id: 'r1', categoryId: 'groceries'),
          testRule(id: 'r2', priority: 2, categoryId: 'food', enabled: false),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(_inCard('food', find.text('2 règles automatiques')), findsOneWidget);

    final none = tester.widget<Text>(_inCard('own', find.text('Aucune règle')));
    expect(none.style?.color, AppColors.warning);
  });

  testWidgets('the footer opens the rules view filtered on the category', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        controller: FakeCategoriesController(
          initialCategories: [
            _food,
            _groceries,
            testCategory(id: 'transport', name: 'category.transport'),
          ],
        ),
        rules: [
          testRule(id: 'r1', categoryId: 'groceries'),
          testRule(
            id: 'r2',
            priority: 2,
            pattern: 'SNCF',
            categoryId: 'transport',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('categoryRules-food')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('rulesFilterChip')), findsOneWidget);
    expect(find.byKey(const Key('ruleRow-r1')), findsOneWidget);
    expect(find.byKey(const Key('ruleRow-r2')), findsNothing);
    // A subset can't be reordered meaningfully, so its handles don't drag.
    expect(find.byKey(const Key('ruleHandleDisabled-r1')), findsOneWidget);

    await tester.tap(find.byKey(const Key('rulesFilterClear')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('rulesFilterChip')), findsNothing);
    expect(find.byKey(const Key('ruleRow-r2')), findsOneWidget);
    expect(find.byKey(const Key('ruleHandleDisabled-r1')), findsNothing);
  });

  testWidgets('a category with no rule links nowhere', (tester) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(controller: FakeCategoriesController(initialCategories: [_own])),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('categoryRules-own')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('categoryCard-own')), findsOneWidget);
    expect(find.byKey(const Key('rulesFilterChip')), findsNothing);
  });

  // --- non-happy paths and locales ----------------------------------------------------

  testWidgets('renders the empty state with no categories at all', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(_wrap(controller: FakeCategoriesController()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('categoriesEmptyState')), findsOneWidget);
    expect(
      find.byKey(const Key('emptyStateAddCategoryButton')),
      findsOneWidget,
    );
  });

  testWidgets('a load failure renders the error state with a retry', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(controller: FakeCategoriesController(loadError: Exception('boom'))),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('categoriesErrorText')), findsOneWidget);
    expect(find.byKey(const Key('categoriesRetryButton')), findsOneWidget);
  });

  testWidgets('fr and en render the same card geometry', (tester) async {
    _useDesktopSurface(tester);
    final categories = [_food, _groceries, _own];

    await tester.pumpWidget(
      _wrap(
        controller: FakeCategoriesController(initialCategories: categories),
      ),
    );
    await tester.pumpAndSettle();
    final frCard = tester.getRect(find.byKey(const Key('categoryCard-food')));
    expect(find.text('Personnalisée'), findsOneWidget);
    expect(find.text('Sous-catégorie'), findsNWidgets(2));

    await tester.pumpWidget(
      _wrap(
        controller: FakeCategoriesController(initialCategories: categories),
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.getRect(find.byKey(const Key('categoryCard-food'))), frCard);
    expect(find.text('Custom'), findsOneWidget);
    expect(find.text('Food'), findsOneWidget);
    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('No rules'), findsNWidgets(2));
  });
}
