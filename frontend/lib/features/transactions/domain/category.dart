import 'package:flutter/foundation.dart';

/// A category as returned by `GET /categories` — system + the caller's own.
/// Used only for the category picker; the category *embedded* on a
/// transaction is [TransactionCategory] instead (see `transaction.dart`).
///
/// Named `PickerCategory` rather than `Category`: the latter collides with
/// `dart:ui`'s `@Category` annotation, exported transitively through
/// `flutter/foundation.dart`.
@immutable
class PickerCategory {
  const PickerCategory({
    required this.id,
    required this.userId,
    required this.parentId,
    required this.name,
    required this.kind,
    required this.icon,
    required this.color,
    required this.isSystem,
  });

  final String id;
  final String? userId;
  final String? parentId;
  final String name;
  final String kind;
  final String icon;
  final String color;
  final bool isSystem;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PickerCategory &&
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
