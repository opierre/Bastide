import 'package:finstride/core/theme/app_theme.dart';
import 'package:finstride/core/theme/tokens.dart';
import 'package:finstride/core/widgets/amount_text.dart';
import 'package:finstride/features/categories/application/categories_controller.dart';
import 'package:finstride/features/categories/application/category_spend_controller.dart';
import 'package:finstride/features/categories/domain/category_spend.dart';
import 'package:finstride/features/categories/presentation/categories_screen.dart';
import 'package:finstride/features/categories/presentation/category_spend_bar.dart';
import 'package:finstride/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_categories_controller.dart';

/// The panel's own money formatting, so the expectations can't drift from the
/// locale's separators (French uses a narrow no-break space before « € »).
String _eur(int amountMinor) =>
    formatAmount(amountMinor: amountMinor, currency: 'EUR', locale: 'fr');

/// May 2026 — the month every mockup and fixture in the project is set in.
final _month = DateTime(2026, 5);

MonthlySpend _spend({int totalMinor = 0, Map<String, int> byCategoryId = const {}}) =>
    MonthlySpend(
      month: _month,
      currency: 'EUR',
      totalMinor: totalMinor,
      byCategoryId: byCategoryId,
    );

Widget _wrap({
  required FakeCategoriesController controller,
  Locale locale = const Locale('fr'),
  MonthlySpend? spend,
  Object? spendError,
}) {
  return ProviderScope(
    overrides: [
      categoriesControllerProvider.overrideWith(() => controller),
      monthlySpendProvider.overrideWith((ref) {
        if (spendError != null) throw spendError;
        return spend ?? _spend();
      }),
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

/// The panel is drawn for the 1440×900 desktop frame the design targets — the
/// row grid runs to the spend columns and needs the width it was drawn at.
void _useDesktopSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('a system row renders the lock and offers no edit or delete', (tester) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        controller: FakeCategoriesController(
          initialCategories: [testCategory(id: 'food', name: 'category.food')],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('categoryLock-food')), findsOneWidget);
    expect(find.byKey(const Key('categoryEdit-food')), findsNothing);
    expect(find.byKey(const Key('categoryDelete-food')), findsNothing);
    expect(find.byKey(const Key('categoryBadgeSystem')), findsOneWidget);
  });

  testWidgets('a custom row renders the ⋯ and the trash, and no lock', (tester) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        controller: FakeCategoriesController(
          initialCategories: [
            testCategory(id: 'own', userId: 'u1', name: 'Épargne projet', isSystem: false),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('categoryEdit-own')), findsOneWidget);
    expect(find.byKey(const Key('categoryDelete-own')), findsOneWidget);
    expect(find.byKey(const Key('categoryLock-own')), findsNothing);
    expect(find.byKey(const Key('categoryBadgeCustom')), findsOneWidget);
    expect(find.text('Épargne projet'), findsOneWidget);
  });

  testWidgets('subcategories render indented under their parent', (tester) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        controller: FakeCategoriesController(
          initialCategories: [
            testCategory(id: 'food', name: 'category.food'),
            testCategory(id: 'groceries', parentId: 'food', name: 'category.food.groceries'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final parent = tester.getTopLeft(find.text('Alimentation'));
    final child = tester.getTopLeft(find.text('Courses'));
    expect(child.dx, greaterThan(parent.dx));
    expect(child.dy, greaterThan(parent.dy));
  });

  testWidgets('deleting a custom category asks first, then calls the controller', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    final controller = FakeCategoriesController(
      initialCategories: [
        testCategory(id: 'own', userId: 'u1', name: 'Épargne projet', isSystem: false),
      ],
    );
    await tester.pumpWidget(_wrap(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('categoryDelete-own')));
    await tester.pumpAndSettle();
    expect(controller.deleteCalls, isEmpty);

    await tester.tap(find.byKey(const Key('categoryDeleteConfirmButton')));
    await tester.pumpAndSettle();
    expect(controller.deleteCalls, ['own']);
  });

  testWidgets('renders the empty state with no categories at all', (tester) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(_wrap(controller: FakeCategoriesController()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('categoriesEmptyState')), findsOneWidget);
    expect(find.byKey(const Key('emptyStateAddCategoryButton')), findsOneWidget);
  });

  testWidgets('a load failure renders the error state with a retry', (tester) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(controller: FakeCategoriesController(loadError: Exception('boom'))),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('categoriesErrorText')), findsOneWidget);
    expect(find.byKey(const Key('categoriesRetryButton')), findsOneWidget);
  });

  testWidgets('badges start and affordances end on shared columns', (tester) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        controller: FakeCategoriesController(
          initialCategories: [
            testCategory(id: 'food', name: 'category.food'),
            testCategory(
              id: 'own',
              userId: 'u1',
              name: 'Épargne projet longue à afficher',
              isSystem: false,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Names of very different lengths must not move the badge column.
    expect(
      tester.getTopLeft(find.byKey(const Key('categoryBadgeSystem'))).dx,
      tester.getTopLeft(find.byKey(const Key('categoryBadgeCustom'))).dx,
    );

    // The lock stands where the ⋯ stands: one trailing axis for both rows.
    expect(
      tester.getCenter(find.byKey(const Key('categoryLock-food'))).dx,
      moreOrLessEquals(tester.getCenter(find.byIcon(Icons.more_horiz_rounded)).dx, epsilon: 1),
    );
  });

  testWidgets('fr and en render the same row geometry', (tester) async {
    _useDesktopSurface(tester);
    final categories = [
      testCategory(id: 'food', name: 'category.food'),
      testCategory(id: 'own', userId: 'u1', name: 'Épargne projet', isSystem: false),
    ];

    await tester.pumpWidget(
      _wrap(controller: FakeCategoriesController(initialCategories: categories)),
    );
    await tester.pumpAndSettle();
    final frRow = tester.getRect(find.byKey(const Key('categoryRow-own')));
    expect(find.text('Personnalisée'), findsOneWidget);

    await tester.pumpWidget(
      _wrap(
        controller: FakeCategoriesController(initialCategories: categories),
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.getRect(find.byKey(const Key('categoryRow-own'))), frRow);
    expect(find.text('Custom'), findsOneWidget);
    expect(find.text('Food'), findsOneWidget);
  });

  // --- the spend-share columns ---------------------------------------------------------

  testWidgets('a parent row draws its bar in its own hue, over the group total', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        controller: FakeCategoriesController(
          initialCategories: [
            testCategory(id: 'food', name: 'category.food', color: '#5AA9FF'),
            testCategory(id: 'groceries', parentId: 'food', name: 'category.food.groceries'),
          ],
        ),
        // 180 € on the parent itself + 220 € on Courses, of a 1 000 € month.
        spend: _spend(totalMinor: 100000, byCategoryId: {'food': 18000, 'groceries': 22000}),
      ),
    );
    await tester.pumpAndSettle();

    final bar = tester.widget<CategorySpendBar>(
      find.descendant(
        of: find.byKey(const Key('categorySpend-food')),
        matching: find.byType(CategorySpendBar),
      ),
    );
    expect(bar.color, CategoryHues.alimentation);
    // 400 € of a 1 000 € month — the subcategory folded into its parent.
    expect(bar.fraction, closeTo(0.40, 0.001));
    expect(find.text('40,0 %'), findsOneWidget);
    expect(find.text(_eur(40000)), findsOneWidget);
  });

  testWidgets('a subcategory row shows its amount and no bar', (tester) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        controller: FakeCategoriesController(
          initialCategories: [
            testCategory(id: 'food', name: 'category.food'),
            testCategory(id: 'groceries', parentId: 'food', name: 'category.food.groceries'),
          ],
        ),
        spend: _spend(totalMinor: 100000, byCategoryId: {'groceries': 22000}),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const Key('categorySpend-groceries')),
        matching: find.byType(CategorySpendBar),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('categorySpend-groceries')),
        matching: find.text(_eur(22000)),
      ),
      findsOneWidget,
    );

    // The two amounts end on the same edge: one column, one decimal point.
    expect(
      tester.getBottomRight(find.byKey(const Key('categorySpend-groceries'))).dx,
      tester.getBottomRight(find.byKey(const Key('categorySpend-food'))).dx,
    );
  });

  testWidgets('a category that spent nothing renders a dash, not a zero', (tester) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        controller: FakeCategoriesController(
          initialCategories: [testCategory(id: 'income', name: 'category.income')],
        ),
        spend: _spend(totalMinor: 100000),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('categorySpendNone')), findsOneWidget);
    expect(find.textContaining('0,00'), findsNothing);
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('the caption names the month the figures cover, per locale', (tester) async {
    _useDesktopSurface(tester);
    final categories = [testCategory(id: 'food', name: 'category.food')];

    await tester.pumpWidget(
      _wrap(
        controller: FakeCategoriesController(initialCategories: categories),
        spend: _spend(totalMinor: 100000, byCategoryId: {'food': 40000}),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Dépenses de mai 2026'), findsOneWidget);

    await tester.pumpWidget(
      _wrap(
        controller: FakeCategoriesController(initialCategories: categories),
        spend: _spend(totalMinor: 100000, byCategoryId: {'food': 40000}),
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Spending in May 2026'), findsOneWidget);
  });

  testWidgets('a failed spend summary costs the panel its bars and nothing else', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        controller: FakeCategoriesController(
          initialCategories: [
            testCategory(id: 'own', userId: 'u1', name: 'Épargne projet', isSystem: false),
          ],
        ),
        spendError: Exception('sidecar down'),
      ),
    );
    await tester.pumpAndSettle();

    // The tree still renders, fully manageable — no error state, no caption, and
    // no dash claiming the category spent nothing.
    expect(find.byKey(const Key('categoryRow-own')), findsOneWidget);
    expect(find.byKey(const Key('categoryEdit-own')), findsOneWidget);
    expect(find.byKey(const Key('categoriesErrorText')), findsNothing);
    expect(find.byKey(const Key('categoriesSpendCaption')), findsNothing);
    expect(find.byKey(const Key('categorySpendNone')), findsNothing);
    expect(find.byType(CategorySpendBar), findsNothing);
  });
}
