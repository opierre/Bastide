import 'package:finstride/core/theme/app_theme.dart';
import 'package:finstride/features/categories/application/categories_controller.dart';
import 'package:finstride/features/categories/presentation/categories_screen.dart';
import 'package:finstride/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_categories_controller.dart';

Widget _wrap({
  required FakeCategoriesController controller,
  Locale locale = const Locale('fr'),
}) {
  return ProviderScope(
    overrides: [categoriesControllerProvider.overrideWith(() => controller)],
    child: MaterialApp(
      locale: locale,
      theme: appDarkTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: CategoriesScreen()),
    ),
  );
}

void main() {
  testWidgets('a system row renders the lock and offers no edit or delete', (tester) async {
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
    await tester.pumpWidget(
      _wrap(
        controller: FakeCategoriesController(
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
    await tester.pumpWidget(_wrap(controller: FakeCategoriesController()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('categoriesEmptyState')), findsOneWidget);
    expect(find.byKey(const Key('emptyStateAddCategoryButton')), findsOneWidget);
  });

  testWidgets('a load failure renders the error state with a retry', (tester) async {
    await tester.pumpWidget(
      _wrap(controller: FakeCategoriesController(loadError: Exception('boom'))),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('categoriesErrorText')), findsOneWidget);
    expect(find.byKey(const Key('categoriesRetryButton')), findsOneWidget);
  });

  testWidgets('fr and en render the same row geometry', (tester) async {
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
}
