import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/core/theme/tokens.dart';
import 'package:bastide/core/widgets/app_segmented.dart';
import 'package:bastide/core/widgets/app_select.dart';
import 'package:bastide/core/widgets/category_icons.dart';
import 'package:bastide/features/categories/application/categories_controller.dart';
import 'package:bastide/features/categories/presentation/categories_screen.dart';
import 'package:bastide/features/rules/application/rule_match_counts.dart';
import 'package:bastide/features/rules/application/rules_controller.dart';
import 'package:bastide/features/rules/domain/rule.dart';
import 'package:bastide/l10n/app_localizations.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../support/fake_categories_controller.dart';
import '../../support/fake_rules_controller.dart';

Widget _wrap({
  required FakeCategoriesController controller,
  List<Rule> rules = const [],
  Locale locale = const Locale('fr'),
  ThemeData? theme,
}) {
  return ProviderScope(
    overrides: [
      categoriesControllerProvider.overrideWith(() => controller),
      rulesControllerProvider.overrideWith(
        () => FakeRulesController(initialRules: rules),
      ),
      ruleMatchCountsProvider.overrideWith((ref) async => const {}),
    ],
    child: MaterialApp(
      locale: locale,
      theme: theme ?? AppTheme.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: CategoriesScreen()),
    ),
  );
}

/// The panel is drawn for the 1440×900 desktop frame the design targets.
void _useDesktopSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> _hover(WidgetTester tester, Finder finder) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  addTearDown(gesture.removePointer);
  await gesture.addPointer(location: Offset.zero);
  await gesture.moveTo(tester.getCenter(finder));
  await tester.pumpAndSettle();
}

Finder _inItem(String id, Finder matching) => find.descendant(
  of: find.byKey(Key('categoryTreeItem-$id')),
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
  icon: 'star',
  color: 'cat0',
  isSystem: false,
);

void main() {
  testWidgets('two panes: the 340 px tree beside the rules pane', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(controller: FakeCategoriesController(initialCategories: [_food])),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byKey(const Key('categoryTreePane'))).width,
      AppCategoriesPanel.treeWidth,
    );
    expect(find.byKey(const Key('rulesPane')), findsOneWidget);
    expect(find.text('Catégories'), findsOneWidget);
    expect(find.text('Règles'), findsOneWidget);
    expect(find.byKey(const Key('categoriesSystemNote')), findsOneWidget);
  });

  testWidgets('« Toutes les règles » is selected by default, with the total', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        controller: FakeCategoriesController(initialCategories: [_food]),
        rules: [
          testRule(),
          testRule(id: 'r2', priority: 2),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final all = find.byKey(const Key('categoryTreeAll'));
    expect(
      find.descendant(of: all, matching: find.text('Toutes les règles')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: all, matching: find.text('2 règles')),
      findsOneWidget,
    );
    expect(
      tester.getSemantics(all),
      isSemantics(isSelected: true, isButton: true, hasTapAction: true),
    );
  });

  testWidgets('an item draws its chevron, hue dot, glyph and name', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        controller: FakeCategoriesController(initialCategories: [_food, _own]),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      _inItem('food', find.byIcon(LucideIcons300.chevronRight)),
      findsOneWidget,
    );
    final dot = tester.widget<Container>(
      find.byKey(const Key('categoryDot-food')),
    );
    expect((dot.decoration! as BoxDecoration).color, CategoryColors.dark.cat2);
    final food = tester.widget<Icon>(
      find.byKey(const Key('categoryIcon-food')),
    );
    expect(food.icon, LucideIcons300.utensils);
    final own = tester.widget<Icon>(find.byKey(const Key('categoryIcon-own')));
    expect(own.icon, LucideIcons300.star);
    expect(_inItem('food', find.text('Alimentation')), findsOneWidget);
  });

  testWidgets('an open category lists each subcategory with its own glyph in '
      'the main category’s hue', (tester) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        controller: FakeCategoriesController(
          initialCategories: [
            testCategory(
              id: 'pets',
              name: 'category.pets',
              icon: 'paw-print',
              color: 'cat10',
            ),
            testCategory(
              id: 'vet',
              parentId: 'pets',
              name: 'category.pets.vet',
              icon: 'syringe',
              color: 'cat10',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('categoryTreeItem-pets')));
    await tester.pumpAndSettle();

    final dot = tester.widget<Container>(
      find.byKey(const Key('categoryDot-pets')),
    );
    expect((dot.decoration! as BoxDecoration).color, CategoryColors.dark.cat10);
    final vet = tester.widget<Icon>(find.byKey(const Key('categoryIcon-vet')));
    expect(vet.icon, LucideIcons300.syringe);
    expect(vet.color, CategoryColors.dark.cat10);
    expect(find.byKey(const Key('categoryDot-vet')), findsNothing);
  });

  testWidgets('the panel carries no badge, no amount and no share', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        controller: FakeCategoriesController(initialCategories: [_food, _own]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Système'), findsNothing);
    expect(find.text('Personnalisée'), findsNothing);
    expect(find.textContaining('€'), findsNothing);
    expect(find.textContaining('%'), findsNothing);
  });

  // --- counts -----------------------------------------------------------------------

  testWidgets(
    'counts rules on a category and its subcategories, « aucune règle » in warning',
    (tester) async {
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

      expect(_inItem('food', find.text('2 règles')), findsOneWidget);
      final none = tester.widget<Text>(
        _inItem('own', find.text('aucune règle')),
      );
      expect(none.style?.color, AppColors.dark.warning);
    },
  );

  // --- selection and expansion -------------------------------------------------------

  testWidgets(
    'selecting a category filters the rules, opens it, and the x returns to all',
    (tester) async {
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
      expect(
        find.byKey(const Key('categoryTreeSubitem-groceries')),
        findsNothing,
      );

      await tester.tap(find.byKey(const Key('categoryTreeItem-food')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('categoryTreeSubitem-groceries')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('addSubcategory-food')), findsOneWidget);
      expect(find.byKey(const Key('rulesFilterChip')), findsOneWidget);
      expect(find.byKey(const Key('ruleRow-r1')), findsOneWidget);
      expect(find.byKey(const Key('ruleRow-r2')), findsNothing);
      // Filtered: no drag, the grip is hidden, the position stays.
      expect(find.byKey(const Key('ruleHandle-r1')), findsNothing);
      expect(find.byKey(const Key('rulePosition-r1')), findsOneWidget);

      await tester.tap(find.byKey(const Key('rulesFilterClear')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('rulesFilterChip')), findsNothing);
      expect(find.byKey(const Key('ruleRow-r2')), findsOneWidget);
      expect(find.byKey(const Key('ruleHandle-r1')), findsOneWidget);
    },
  );

  testWidgets('the chevron opens and closes without changing the selection', (
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

    await tester.tap(find.byKey(const Key('categoryTreeToggle-food')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('categoryTreeSubitem-groceries')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('rulesFilterChip')), findsNothing);

    await tester.tap(find.byKey(const Key('categoryTreeToggle-food')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('categoryTreeSubitem-groceries')),
      findsNothing,
    );
  });

  testWidgets('a filtered category with no rule says so and offers a rule', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        controller: FakeCategoriesController(initialCategories: [_food, _own]),
        rules: [testRule(categoryId: 'food')],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('categoryTreeItem-own')));
    await tester.pumpAndSettle();

    expect(find.text('Aucune règle pour cette catégorie.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('rulesFilterEmptyAdd')));
    await tester.pumpAndSettle();

    // The new rule targets the filtered category.
    final target = tester.widget<AppSelect<String?>>(
      find.byKey(const Key('ruleFormCategory')),
    );
    expect(target.value, 'own');
  });

  // --- system versus custom ----------------------------------------------------------

  testWidgets('a system category shows the lock on hover and offers no menu', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(controller: FakeCategoriesController(initialCategories: [_food])),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('categoryLock-food')), findsNothing);

    await _hover(tester, find.byKey(const Key('categoryTreeItem-food')));

    expect(find.byKey(const Key('categoryLock-food')), findsOneWidget);
    expect(find.byKey(const Key('categoryMenu-food')), findsNothing);
  });

  testWidgets('a custom category shows the menu on hover: edit and delete', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(controller: FakeCategoriesController(initialCategories: [_own])),
    );
    await tester.pumpAndSettle();

    await _hover(tester, find.byKey(const Key('categoryTreeItem-own')));
    expect(find.byKey(const Key('categoryLock-own')), findsNothing);

    await tester.tap(find.byKey(const Key('categoryMenu-own')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('categoryEdit-own')), findsOneWidget);
    expect(find.byKey(const Key('categoryDelete-own')), findsOneWidget);
  });

  testWidgets(
    'deleting a custom category asks first, then calls the controller',
    (tester) async {
      _useDesktopSurface(tester);
      final controller = FakeCategoriesController(initialCategories: [_own]);
      await tester.pumpWidget(_wrap(controller: controller));
      await tester.pumpAndSettle();

      await _hover(tester, find.byKey(const Key('categoryTreeItem-own')));
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

  testWidgets('a system subcategory is inert', (tester) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        controller: FakeCategoriesController(
          initialCategories: [_food, _groceries],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('categoryTreeToggle-food')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('categoryTreeSubitem-groceries')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('categoryFormSubmit')), findsNothing);
  });

  testWidgets(
    'a custom subcategory opens its edit modal, which can delete it',
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
      await tester.tap(find.byKey(const Key('categoryTreeToggle-food')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('categoryTreeSubitem-mine')));
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

  // --- the category form ---------------------------------------------------------------

  testWidgets('the tree’s plus opens the category form', (tester) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(controller: FakeCategoriesController(initialCategories: [_food])),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('addCategoryButton')));
    await tester.pumpAndSettle();

    expect(find.text('Nouvelle catégorie'), findsWidgets);
    expect(find.byKey(const Key('categoryFormKind')), findsOneWidget);
    expect(find.byKey(const Key('categoryFormIcon-star')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('categoryFormIcon-star'))),
      const Size.square(AppCategoriesPanel.iconCell),
    );
    expect(
      tester.getSize(find.byKey(const Key('categoryFormColor-cat1'))),
      const Size.square(AppCategoriesPanel.colorSquare),
    );
  });

  testWidgets(
    '« + Sous-catégorie » presets the parent and hides kind, icon and colour',
    (tester) async {
      _useDesktopSurface(tester);
      await tester.pumpWidget(
        _wrap(controller: FakeCategoriesController(initialCategories: [_food])),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('categoryTreeToggle-food')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('addSubcategory-food')));
      await tester.pumpAndSettle();

      final parent = tester.widget<AppSelect<String?>>(
        find.byKey(const Key('categoryFormParent')),
      );
      expect(parent.value, 'food');
      // The parent reads as its category label: the hue's dot, then the name.
      expect(
        parent.items.firstWhere((item) => item.value == 'food').leading,
        isNotNull,
      );
      expect(find.byKey(const Key('categoryFormDelete')), findsNothing);
      final lead = find.byKey(const Key('categoryFormParentLine'));
      expect(
        find.descendant(of: lead, matching: find.text('Alimentation')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('categoryFormKind')), findsNothing);
      expect(find.byKey(const Key('categoryFormIcon')), findsNothing);
      expect(find.byKey(const Key('categoryFormColor-cat0')), findsNothing);

      parent.onChanged!(null);
      await tester.pumpAndSettle();

      expect(lead, findsNothing);
      expect(find.byKey(const Key('categoryFormKind')), findsOneWidget);
      expect(find.byKey(const Key('categoryFormIcon')), findsOneWidget);
      expect(find.byKey(const Key('categoryFormColor-cat0')), findsOneWidget);
    },
  );

  testWidgets('editing a category selects the glyph it stores', (tester) async {
    _useDesktopSurface(tester);
    final controller = FakeCategoriesController(initialCategories: [_own]);
    await tester.pumpWidget(_wrap(controller: controller));
    await tester.pumpAndSettle();

    await _hover(tester, find.byKey(const Key('categoryTreeItem-own')));
    await tester.tap(find.byKey(const Key('categoryMenu-own')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('categoryEdit-own')));
    await tester.pumpAndSettle();

    // `_own` stores « star »: that is the selected cell.
    expect(
      tester.getSemantics(find.byKey(const Key('categoryFormIcon-star'))),
      isSemantics(
        isSelected: true,
        isButton: true,
        hasTapAction: true,
        label: 'Loisirs',
      ),
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('categoryFormIcon')),
        matching: find.byType(Icon),
      ),
      findsNWidgets(CategoryIcons.glyphs.length),
    );
  });

  testWidgets('a custom category with an unknown key falls back to its glyph', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        controller: FakeCategoriesController(
          initialCategories: [
            testCategory(
              id: 'pet',
              userId: 'u1',
              name: 'Chat',
              icon: 'paw-print',
              color: 'cat0',
              isSystem: false,
            ),
            testCategory(
              id: 'odd',
              userId: 'u1',
              name: 'Bizarre',
              icon: 'not-an-icon',
              color: 'cat0',
              isSystem: false,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<Icon>(find.byKey(const Key('categoryIcon-pet'))).icon,
      LucideIcons300.pawPrint,
    );
    expect(
      tester.widget<Icon>(find.byKey(const Key('categoryIcon-odd'))).icon,
      LucideIcons300.shapes,
    );
  });

  Future<void> openOwnDelete(WidgetTester tester) async {
    await _hover(tester, find.byKey(const Key('categoryTreeItem-own')));
    await tester.tap(find.byKey(const Key('categoryMenu-own')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('categoryDelete-own')));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'the delete confirmation names the category, says what goes with it, '
    'and « Annuler » deletes nothing',
    (tester) async {
      _useDesktopSurface(tester);
      final controller = FakeCategoriesController(initialCategories: [_own]);
      await tester.pumpWidget(_wrap(controller: controller));
      await tester.pumpAndSettle();
      await openOwnDelete(tester);

      final modal = find.byKey(const Key('categoryDeleteModal'));
      expect(
        tester.getSize(find.byKey(const Key('appModalFrame'))).width,
        AppCategoriesPanel.categoryFormWidth,
      );
      expect(
        find.text('Supprimer la catégorie « Épargne projet » ?'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Ses sous-catégories seront supprimées aussi. Les transactions '
          'concernées redeviendront non catégorisées.',
        ),
        findsOneWidget,
      );
      expect(find.byType(AlertDialog), findsNothing);

      await tester.tap(find.byKey(const Key('categoryDeleteCancel')));
      await tester.pumpAndSettle();
      expect(modal, findsNothing);
      expect(controller.deleteCalls, isEmpty);
    },
  );

  testWidgets('the delete confirmation in English', (tester) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        controller: FakeCategoriesController(initialCategories: [_own]),
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();
    await openOwnDelete(tester);

    expect(find.text('Delete the category “Épargne projet”?'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets(
    'the form: Type is a segmented control, the selected colour carries a '
    'check and its name',
    (tester) async {
      _useDesktopSurface(tester);
      await tester.pumpWidget(
        _wrap(controller: FakeCategoriesController(initialCategories: [_food])),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('addCategoryButton')));
      await tester.pumpAndSettle();

      expect(
        tester.getSize(find.byKey(const Key('appModalFrame'))).width,
        AppCategoriesPanel.categoryFormWidth,
      );
      final kind = find.byKey(const Key('categoryFormKind'));
      expect(tester.widget<AppSegmented<String>>(kind).value, 'expense');
      expect(find.text('Dépense'), findsOneWidget);
      expect(find.text('Revenu'), findsOneWidget);
      expect(find.text('Transfert'), findsOneWidget);
      expect(find.text('Catégorie parente'), findsOneWidget);
      expect(find.text('Aucune (catégorie principale)'), findsOneWidget);

      // Grey is the default slot: it holds the check and is named « Gris ».
      Finder checkIn(String slot) => find.descendant(
        of: find.byKey(Key('categoryFormColor-$slot')),
        matching: find.byKey(const Key('categoryFormColorCheck')),
      );
      expect(checkIn('cat0'), findsOneWidget);
      expect(
        tester.getSemantics(find.byKey(const Key('categoryFormColor-cat0'))),
        isSemantics(
          isSelected: true,
          isButton: true,
          hasTapAction: true,
          label: 'Gris',
        ),
      );
      final check = tester.widget<Icon>(
        find.byKey(const Key('categoryFormColorCheck')),
      );
      expect(check.size, AppCategoriesPanel.colorCheck);
      expect(check.color, AppColors.dark.bg);

      await tester.tap(find.byKey(const Key('categoryFormColor-cat1')));
      await tester.pumpAndSettle();
      expect(checkIn('cat0'), findsNothing);
      expect(checkIn('cat1'), findsOneWidget);

      // Every slot is offered, each under its own name.
      for (final (slot, name) in const [
        ('cat7', 'Prune'),
        ('cat8', 'Cyan'),
        ('cat9', 'Olive'),
        ('cat10', 'Brun'),
      ]) {
        expect(
          tester.getSemantics(find.byKey(Key('categoryFormColor-$slot'))),
          isSemantics(isButton: true, hasTapAction: true, label: name),
        );
      }
    },
  );

  testWidgets('the selected colour’s check is in `text` on the light theme', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        controller: FakeCategoriesController(initialCategories: [_food]),
        theme: AppTheme.light,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('addCategoryButton')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<Icon>(find.byKey(const Key('categoryFormColorCheck')))
          .color,
      AppColors.light.text,
    );
  });

  testWidgets('creating saves the name, kind, icon and colour chosen', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    final controller = FakeCategoriesController(initialCategories: [_food]);
    await tester.pumpWidget(_wrap(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('addCategoryButton')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('categoryFormName')),
      'Projets',
    );
    await tester.tap(find.byKey(const Key('categoryFormKind-income')));
    await tester.tap(find.byKey(const Key('categoryFormIcon-star')));
    await tester.tap(find.byKey(const Key('categoryFormColor-cat3')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('categoryFormSubmit')));
    await tester.pumpAndSettle();

    expect(controller.createCalls, [
      {
        'name': 'Projets',
        'kind': 'income',
        'icon': 'star',
        'color': 'cat3',
        'parentId': null,
      },
    ]);
    expect(find.byKey(const Key('categoryFormModal')), findsNothing);
  });

  testWidgets('a refused save shows the frame’s banner and keeps the input', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    final controller = FakeCategoriesController(initialCategories: [_food])
      ..errorOnCreate = Exception('refused');
    await tester.pumpWidget(_wrap(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('addCategoryButton')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('categoryFormName')),
      'Projets',
    );
    await tester.tap(find.byKey(const Key('categoryFormSubmit')));
    await tester.pumpAndSettle();

    expect(
      find.text('Une erreur est survenue. Veuillez réessayer.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('categoryFormModal')), findsOneWidget);
    expect(find.text('Projets'), findsOneWidget);
  });

  testWidgets(
    'a subcategory is saved under its parent, with its parent’s hue',
    (tester) async {
      _useDesktopSurface(tester);
      final controller = FakeCategoriesController(initialCategories: [_food]);
      await tester.pumpWidget(_wrap(controller: controller));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('categoryTreeToggle-food')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('addSubcategory-food')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('categoryFormName')),
        'Marché',
      );
      await tester.tap(find.byKey(const Key('categoryFormSubmit')));
      await tester.pumpAndSettle();

      final call = controller.createCalls.single;
      expect(call['parentId'], 'food');
      expect(call['kind'], 'expense');
      expect(call['color'], 'cat2');
    },
  );

  testWidgets('typed input makes « Annuler » ask before dropping it', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(controller: FakeCategoriesController(initialCategories: [_food])),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('addCategoryButton')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('categoryFormName')),
      'Projets',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('categoryFormCancel')));
    await tester.pumpAndSettle();

    expect(find.text('Abandonner les modifications ?'), findsOneWidget);
  });

  // --- non-happy paths, themes and locales ---------------------------------------------

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

  testWidgets('the selected item takes the hover ground in the light theme', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        controller: FakeCategoriesController(initialCategories: [_food]),
        theme: AppTheme.light,
      ),
    );
    await tester.pumpAndSettle();

    final ground = tester.widget<Container>(
      find
          .descendant(
            of: find.byKey(const Key('categoryTreeAll')),
            matching: find.byType(Container),
          )
          .first,
    );
    expect((ground.decoration! as BoxDecoration).color, AppColors.light.hover);
  });

  testWidgets('fr and en render the same tree geometry', (tester) async {
    _useDesktopSurface(tester);
    final categories = [_food, _groceries, _own];

    await tester.pumpWidget(
      _wrap(
        controller: FakeCategoriesController(initialCategories: categories),
      ),
    );
    await tester.pumpAndSettle();
    final frItem = tester.getRect(
      find.byKey(const Key('categoryTreeItem-food')),
    );
    expect(find.text('aucune règle'), findsNWidgets(3));

    await tester.pumpWidget(
      _wrap(
        controller: FakeCategoriesController(initialCategories: categories),
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getRect(find.byKey(const Key('categoryTreeItem-food'))),
      frItem,
    );
    expect(find.text('All rules'), findsOneWidget);
    expect(find.text('Food'), findsOneWidget);
    expect(find.text('no rule'), findsNWidgets(3));
  });
}
