import 'package:flutter/foundation.dart';

/// Which rule's logo a transaction or a series shows, and which version of
/// it.
///
/// The backend resolves it when the row is read (the first enabled rule, by
/// priority, that has a logo and matches) and sends `logo_rule_id` +
/// `logo_updated_at`; both `null` mean the monogram. The version is part of
/// the identity: a replaced logo is a new [LogoRef], so a picture cached
/// under the old one is never shown in its place.
@immutable
class LogoRef {
  const LogoRef({required this.ruleId, required this.updatedAt});

  /// The reference a wire row carries, or `null` when it shows the monogram.
  static LogoRef? fromJson(Map<String, dynamic> json) {
    final ruleId = json['logo_rule_id'] as String?;
    final updatedAt = json['logo_updated_at'] as String?;
    if (ruleId == null || updatedAt == null) return null;
    return LogoRef(ruleId: ruleId, updatedAt: DateTime.parse(updatedAt));
  }

  final String ruleId;
  final DateTime updatedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LogoRef &&
          other.ruleId == ruleId &&
          other.updatedAt == updatedAt);

  @override
  int get hashCode => Object.hash(ruleId, updatedAt);
}
