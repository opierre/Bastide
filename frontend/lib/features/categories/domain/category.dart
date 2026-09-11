import 'package:flutter/foundation.dart';

/// A category as returned by `GET /categories` — the system catalog plus the
/// caller's own. One shape for the resource across the app: the categories
/// panel edits it, the transactions picker chooses from it.
///
/// The category *embedded* on a transaction is a different, narrower thing
/// (`TransactionCategory` in `features/transactions/domain/transaction.dart`) —
/// it carries no `parent_id` and no ownership, because a transaction row never
/// needs them.
///
/// Named `AppCategory` rather than `Category`: the latter collides with
/// `dart:ui`'s `@Category` annotation, exported transitively through
/// `flutter/foundation.dart`.
@immutable
class AppCategory {
  const AppCategory({
    required this.id,
    required this.userId,
    required this.parentId,
    required this.name,
    required this.kind,
    required this.icon,
    required this.color,
    required this.isSystem,
  });

  factory AppCategory.fromJson(Map<String, dynamic> json) => AppCategory(
    id: json['id'] as String,
    userId: json['user_id'] as String?,
    parentId: json['parent_id'] as String?,
    name: json['name'] as String,
    kind: json['kind'] as String,
    icon: json['icon'] as String,
    color: json['color'] as String,
    isSystem: json['is_system'] as bool,
  );

  final String id;
  final String? userId;
  final String? parentId;

  /// An i18n key (`category.food.groceries`) for system categories, free text
  /// for the user's own — see `core/l10n/category_display.dart`.
  final String name;

  /// `income` · `expense` · `transfer`.
  final String kind;
  final String icon;
  final String color;

  /// System categories are seeded, shared, and read-only: the API refuses to
  /// patch or delete them, and the UI says so before the user tries.
  final bool isSystem;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppCategory &&
          other.id == id &&
          other.userId == userId &&
          other.parentId == parentId &&
          other.name == name &&
          other.kind == kind &&
          other.icon == icon &&
          other.color == color &&
          other.isSystem == isSystem);

  @override
  int get hashCode =>
      Object.hash(id, userId, parentId, name, kind, icon, color, isSystem);
}

/// One parent category with the subcategories filed under it, in the order the
/// tree renders. Built by the controller (see `categories_controller.dart`) so
/// the rows stay pure presentation.
@immutable
class CategoryNode {
  const CategoryNode({required this.category, required this.children});

  final AppCategory category;
  final List<AppCategory> children;
}
