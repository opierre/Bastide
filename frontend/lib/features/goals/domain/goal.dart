import 'package:flutter/foundation.dart';

/// Lifecycle of a savings goal. Mirrors the backend's `GoalStatus` literal
/// (`backend/app/features/goals/schemas.py`).
///
/// [reached] is *derived* server-side from the allocation ledger and is never
/// asserted by this client — the patch payload accepts only [active] and
/// [archived], which are the user's two decisions about a goal
/// (`PROJECT.md` §13).
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
/// display-only field (`PROJECT.md` §13, `docs/design/11-goals.md` §Concept).
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
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;

  /// Positive minor units. A target is an amount to reach, not a movement, so
  /// the ledger's sign convention doesn't apply to it (`PROJECT.md` §8).
  final int targetMinor;

  final String currency;
  final DateTime? targetDate;

  /// One of [goalIconKeys] — the goal's chosen glyph, picked in the form.
  final String icon;

  /// One of [goalColorKeys] — a `#RRGGBB` string, picked in the form.
  final String color;

  final GoalStatus status;

  /// The *signed* sum of this goal's allocations, so it falls again when the
  /// user takes money back out.
  final int progressMinor;

  /// `progressMinor / targetMinor`, unclamped: an over-funded goal reports past
  /// 1.0 and the UI decides what to draw with it (`PROJECT.md` §13).
  final double progressPct;

  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isReached => status == GoalStatus.reached;
  bool get isArchived => status == GoalStatus.archived;

  /// What the progress *bar* draws: the ratio capped at full.
  ///
  /// The bar clamps while [progressPct] does not, and the two are deliberately
  /// separate. A bar drawn past its own track reads as a rendering bug, but
  /// rounding the percentage down to 100 % would be a lie about the user's
  /// money — so the drawing clamps and the text tells the truth
  /// (`docs/design/11-goals.md` §Notes).
  double get barFraction => progressPct.clamp(0.0, 1.0);
}

/// The glyphs a goal may carry, as the wire stores them.
///
/// A fixed vocabulary rather than free text: `icon` is an opaque string to the
/// backend, so the set of legal values is the frontend's to define, and a goal
/// created here must be drawable by any later build of the app.
const goalIconKeys = <String>['flag', 'home', 'travel', 'car', 'study', 'gift'];

/// The hues a goal may carry — the palette's accent and data colors, so a goal
/// can never be given a tone the design system doesn't own
/// (`docs/design/00-shared-design-block.md` §Palette).
const goalColorKeys = <String>[
  '#8B8CF9',
  '#4FD1E8',
  '#4ADE80',
  '#FFB84D',
  '#F472B6',
  '#5AA9FF',
];

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
