import 'package:bastide/features/categories/application/categories_controller.dart';
import 'package:bastide/features/categories/domain/category.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A no-network `CategoriesController` double for widget tests: a fixed
/// catalog, plus a record of the writes the panel attempted.
class FakeCategoriesController extends CategoriesController {
  FakeCategoriesController({this.initialCategories = const [], this.loadError});

  final List<AppCategory> initialCategories;
  final Object? loadError;

  final deleteCalls = <String>[];
  Object? errorOnDelete;

  @override
  Future<List<AppCategory>> build() async {
    if (loadError != null) throw loadError!;
    return initialCategories;
  }

  @override
  Future<void> delete(String id) async {
    deleteCalls.add(id);
    if (errorOnDelete != null) throw errorOnDelete!;
    state = AsyncValue.data([
      for (final category in state.value ?? const <AppCategory>[])
        if (category.id != id && category.parentId != id) category,
    ]);
  }
}

AppCategory testCategory({
  String id = 'c1',
  String? userId,
  String? parentId,
  String name = 'category.food',
  String kind = 'expense',
  String icon = 'alimentation',
  String color = '#5AA9FF',
  bool isSystem = true,
}) => AppCategory(
  id: id,
  userId: userId,
  parentId: parentId,
  name: name,
  kind: kind,
  icon: icon,
  color: color,
  isSystem: isSystem,
);
