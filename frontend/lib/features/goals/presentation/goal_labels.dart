import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/goal.dart';

/// Maps the goals feature's stable error `code`s (see
/// `backend/app/features/goals/service.py`) to a localized message.
///
/// `GOAL_NOT_FOUND` is the one the panel is likeliest to meet even though it
/// never offers an action on a goal it isn't showing: the grid may be a few
/// seconds old, and a goal removed in another window is enough to make a
/// legal-looking click land on nothing.
String localizeGoalError(AppLocalizations l10n, Object? error) {
  if (error is ApiFailure) {
    switch (error.code) {
      case 'GOAL_NOT_FOUND':
        return l10n.goalErrorNotFound;
      case 'GOAL_ALLOCATION_NOT_FOUND':
        return l10n.goalErrorAllocationNotFound;
      case 'VALIDATION_ERROR':
        return l10n.goalErrorValidation;
    }
  }
  return l10n.goalErrorGeneric;
}

/// « Juin 2028 » — the month a goal is aimed at, as its pill states it.
String goalMonthLabel(String locale, DateTime date) =>
    _capitalize(DateFormat.yMMMM(locale).format(date));

/// French month names come out of `intl` lowercased; the pill sets them as a
/// label, where a leading capital is what the design draws.
String _capitalize(String value) =>
    value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);

/// « 64 % » — a goal's progress as the card and the ring state it.
///
/// Whole percent, and *unrounded past the point*: the figure sits beside an
/// exact pair of amounts, and a goal at 99,6 % that claimed 100 % would be
/// contradicted by the two numbers next to it. Reported unclamped, so an
/// over-funded goal says 118 % while its bar stops at full
/// (`docs/design/11-goals.md` §Notes).
String goalPercentLabel(double progressPct, String locale) =>
    '${NumberFormat('0', locale).format(progressPct * 100)} %';

/// The glyph a goal's stored [Goal.icon] key stands for.
///
/// The mapping lives in presentation rather than on the domain model: the wire
/// carries a key, and which glyph draws it is a decision of this app's icon
/// language, not a fact about the goal. An unknown key — a goal written by a
/// later build — falls back to the flag rather than throwing.
IconData goalIconData(String key) => switch (key) {
  'home' => Icons.home_rounded,
  'travel' => Icons.flight_rounded,
  'car' => Icons.directions_car_rounded,
  'study' => Icons.school_rounded,
  'gift' => Icons.card_giftcard_rounded,
  _ => Icons.flag_rounded,
};

/// The hue a goal's stored [Goal.color] key stands for, resolved against the
/// palette's tokens so a goal can never introduce a color the design system
/// does not own. Unknown keys fall back to the accent.
Color goalColorValue(String key) => switch (key) {
  '#4FD1E8' => AppColors.cyan,
  '#4ADE80' => AppColors.positive,
  '#FFB84D' => AppColors.warning,
  '#F472B6' => CategoryHues.loisirs,
  '#5AA9FF' => AppColors.info,
  _ => AppColors.iris,
};
