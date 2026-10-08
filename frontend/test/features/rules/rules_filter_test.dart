import 'package:bastide/features/rules/application/rules_filter.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_categories_controller.dart';
import '../../support/fake_rules_controller.dart';

void main() {
  final categories = [
    testCategory(id: 'food', name: 'category.food'),
    testCategory(
      id: 'groceries',
      parentId: 'food',
      name: 'category.food.groceries',
    ),
    testCategory(id: 'transport', name: 'category.transport'),
  ];

  test(
    'a subcategory rule counts toward its parent, disabled ones included',
    () {
      final counts = countRulesByRootCategory([
        testRule(id: 'r1', categoryId: 'groceries'),
        testRule(id: 'r2', categoryId: 'food', enabled: false),
        testRule(id: 'r3', categoryId: 'transport'),
      ], categories);

      expect(counts, {'food': 2, 'transport': 1});
    },
  );

  test(
    'a rule whose category is gone counts under its own id, not a parent',
    () {
      final counts = countRulesByRootCategory([
        testRule(categoryId: 'deleted'),
      ], categories);

      expect(counts, {'deleted': 1});
    },
  );
}
