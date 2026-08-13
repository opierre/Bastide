import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/categories_repository.dart';
import '../domain/category.dart';

/// Which of the panel's two views is showing.
///
/// Held in its own provider rather than in the screen's `State` because the top
/// bar's primary button is contextual — « Nouvelle catégorie » or « Nouvelle
/// règle » — and the bar is built *above* the content region, so it can't read
/// state a child owns. See the fixed-chrome invariant in `frontend/CLAUDE.md`.
enum CategoriesView { categories, rules }

class CategoriesViewNotifier extends Notifier<CategoriesView> {
  @override
  CategoriesView build() => CategoriesView.categories;

  void set(CategoriesView view) => state = view;
}

final categoriesViewProvider = NotifierProvider<CategoriesViewNotifier, CategoriesView>(
  CategoriesViewNotifier.new,
);

/// The category catalog: system rows plus the caller's own.
///
/// Mutations replace `state` only on success, so a rejected edit surfaces to the
/// form as a thrown [ApiFailure] without blanking the loaded list — and a
/// forced patch of a system category (which the API 404s) leaves the tree
/// exactly as it was.
class CategoriesController extends AsyncNotifier<List<AppCategory>> {
  @override
  Future<List<AppCategory>> build() => ref.read(categoriesRepositoryProvider).list();

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => ref.read(categoriesRepositoryProvider).list());
  }

  Future<AppCategory> create({
    required String name,
    required String kind,
    required String icon,
    required String color,
    String? parentId,
  }) async {
    final created = await ref
        .read(categoriesRepositoryProvider)
        .create(name: name, kind: kind, icon: icon, color: color, parentId: parentId);
    state = AsyncValue.data([...?state.value, created]);
    return created;
  }

  Future<AppCategory> updateCategory(
    String id, {
    String? name,
    String? kind,
    String? icon,
    String? color,
    String? parentId,
    bool clearParent = false,
  }) async {
    final updated = await ref
        .read(categoriesRepositoryProvider)
        .update(
          id,
          name: name,
          kind: kind,
          icon: icon,
          color: color,
          parentId: parentId,
          clearParent: clearParent,
        );
    state = AsyncValue.data([
      for (final category in state.value ?? const <AppCategory>[])
        if (category.id == id) updated else category,
    ]);
    return updated;
  }

  /// Deletes a user category. Its subcategories go with it in the local state:
  /// the row is gone server-side, and leaving orphans parented to a missing id
  /// would render them as stray top-level rows until the next reload.
  Future<void> delete(String id) async {
    await ref.read(categoriesRepositoryProvider).delete(id);
    state = AsyncValue.data([
      for (final category in state.value ?? const <AppCategory>[])
        if (category.id != id && category.parentId != id) category,
    ]);
  }
}

final categoriesControllerProvider =
    AsyncNotifierProvider<CategoriesController, List<AppCategory>>(
      CategoriesController.new,
    );

/// The flat catalog arranged as parents-with-children, ready to render.
///
/// Backend order is preserved rather than re-sorted (`GET /categories` returns
/// system groups first, then the user's own): a localized re-sort would be
/// display logic, and it belongs no more in a provider than in a widget — while
/// re-sorting on the raw `name` would order system rows by their i18n *key*,
/// which is not the order any user reads.
///
/// A subcategory whose parent isn't in the list — impossible today, but a
/// truncated response would produce it — is promoted to the top level rather
/// than dropped, so a category can never silently vanish from the panel.
final categoryTreeProvider = Provider<AsyncValue<List<CategoryNode>>>((ref) {
  return ref.watch(categoriesControllerProvider).whenData(buildCategoryTree);
});

@visibleForTesting
List<CategoryNode> buildCategoryTree(List<AppCategory> categories) {
  final byId = {for (final category in categories) category.id: category};
  final childrenOf = <String, List<AppCategory>>{};
  final roots = <AppCategory>[];

  for (final category in categories) {
    final parentId = category.parentId;
    if (parentId != null && byId.containsKey(parentId)) {
      childrenOf.putIfAbsent(parentId, () => []).add(category);
    } else {
      roots.add(category);
    }
  }

  return [
    for (final root in roots)
      CategoryNode(
        category: root,
        children: childrenOf[root.id] ?? const <AppCategory>[],
      ),
  ];
}
