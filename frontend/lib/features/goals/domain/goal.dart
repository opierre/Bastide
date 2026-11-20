import 'package:flutter/foundation.dart';

/// Lifecycle of a savings goal. Mirrors the backend's `GoalStatus` literal
/// (`backend/app/features/goals/schemas.py`).
///
/// [reached] is *derived* server-side from the allocation ledger and is never
/// asserted by this client — the patch payload accepts only [active] and
/// [archived], which are the user's two decisions about a goal.
enum GoalStatus {
  active,
  reached,
  archived;

  static GoalStatus fromWire(String value) =>
      GoalStatus.values.firstWhere((status) => status.name == value);

  String get wireValue => name;
}

/// A savings goal as returned by `GET /goals`.
///
/// There is deliberately no `accountId`: a goal is not linked to an account,
/// and the column the earlier drafts carried was dropped rather than kept as a
/// display-only field (`docs/design/11-goals.md` §Concept).
/// The only account-derived figure in this feature is the aggregate savings
/// total behind the over-allocation banner, which the controller reads from
/// accounts and never stores on a goal.
@immutable
class Goal {
  const Goal({
    required this.id,
    required this.name,
    required this.targetMinor,
    required this.currency,
    required this.targetDate,
    required this.icon,
    required this.color,
    required this.status,
    required this.progressMinor,
    required this.progressPct,
    this.reachedOn,
    this.imageUpdatedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;

  /// Positive minor units. A target is an amount to reach, not a movement, so
  /// the ledger's sign convention doesn't apply to it.
  final int targetMinor;

  final String currency;
  final DateTime? targetDate;

  /// The stored glyph key; the v2 panel does not draw it.
  final String icon;

  /// The stored hue key; the v2 panel does not draw it.
  final String color;

  final GoalStatus status;

  /// The *signed* sum of this goal's allocations, so it falls again when the
  /// user takes money back out.
  final int progressMinor;

  /// `progressMinor / targetMinor`, unclamped: an over-funded goal reports past
  /// 1.0 and the UI decides what to draw with it.
  final double progressPct;

  /// The date of the allocation that last carried the goal to its target,
  /// derived server-side from the ledger; `null` while the goal is under it.
  final DateTime? reachedOn;

  /// When the banner image last changed, or `null` when the goal has none.
  /// Part of the picture's identity: a new value means new bytes to fetch.
  final DateTime? imageUpdatedAt;

  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isReached => status == GoalStatus.reached;
  bool get isArchived => status == GoalStatus.archived;
  bool get hasImage => imageUpdatedAt != null;

  /// What is left to set aside; never negative, an over-funded goal has
  /// nothing left.
  int get remainingMinor =>
      targetMinor > progressMinor ? targetMinor - progressMinor : 0;

  /// The reference to this goal's current banner image, or `null` without one.
  GoalImageRef? get imageRef => switch (imageUpdatedAt) {
    final updatedAt? => GoalImageRef(goalId: id, updatedAt: updatedAt),
    null => null,
  };

  /// What the progress *bar* draws: the ratio capped at full.
  ///
  /// The bar clamps while [progressPct] does not, and the two are deliberately
  /// separate. A bar drawn past its own track reads as a rendering bug, but
  /// rounding the percentage down to 100 % would be a lie about the user's
  /// money — so the drawing clamps and the text tells the truth
  /// (`docs/design/11-goals.md` §Notes).
  double get barFraction => progressPct.clamp(0.0, 1.0);
}

/// Which goal's banner image, and which version of it.
///
/// The version is part of the identity: a replaced image is a new
/// [GoalImageRef], so bytes cached under the old one are never shown in its
/// place.
@immutable
class GoalImageRef {
  const GoalImageRef({required this.goalId, required this.updatedAt});

  final String goalId;
  final DateTime updatedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GoalImageRef &&
          other.goalId == goalId &&
          other.updatedAt == updatedAt);

  @override
  int get hashCode => Object.hash(goalId, updatedAt);
}

/// The glyph and hue a new goal is stored with.
///
/// The v2 panel draws neither (`docs/design/11-goals.md` §Removed from v1),
/// but the API still requires both on create, so every new goal carries
/// these wire values.
const defaultGoalIcon = 'flag';
const defaultGoalColor = '#8B8CF9';

/// A savings account, as much of one as this feature needs: a balance to add
/// into the total the over-allocation banner compares against.
///
/// Not the accounts feature's `Account` — that model carries an opening
/// balance, an OFX id and an archive flag this panel has no use for, and a
/// feature owns the wire shapes it reads (see the architecture skill).
@immutable
class SavingsAccount {
  const SavingsAccount({
    required this.id,
    required this.balanceMinor,
    required this.currency,
  });

  final String id;
  final int balanceMinor;
  final String currency;
}
