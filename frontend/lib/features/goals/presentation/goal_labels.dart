import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/l10n/date_display.dart';
import '../../../core/pictures/pictures.dart';
import '../../../l10n/app_localizations.dart';
import '../application/goals_controller.dart';
import '../domain/goal.dart';

/// Maps the goals feature's stable error `code`s (see
/// `backend/app/features/goals/service.py`) to a localized message.
///
/// `GOAL_NOT_FOUND` is the one the panel is likeliest to meet even though it
/// never offers an action on a goal it isn't showing: the table may be a few
/// seconds old, and a goal changed in another window is enough to make a
/// legal-looking click land on nothing.
String localizeGoalError(AppLocalizations l10n, Object? error) {
  if (error is GoalImageError) return goalImageFailureText(l10n, error.failure);
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

/// The localized reason a picture didn't become a goal's banner: the avatar's
/// wording (`11-goals.md` §Banner image).
String goalImageFailureText(
  AppLocalizations l10n,
  PictureUploadFailure failure,
) => switch (failure) {
  PictureUploadFailure.tooLarge => l10n.goalImageTooLarge(
    maxPictureUploadBytes ~/ (1024 * 1024),
  ),
  PictureUploadFailure.invalidType => l10n.goalImageInvalid,
  PictureUploadFailure.generic => l10n.goalImageError,
};

/// « Juin 2028 »: the month a goal is aimed at, set as a label.
String goalMonthLabel(String locale, DateTime date) =>
    _capitalize(DateFormat.yMMMM(locale).format(date));

/// French month names come out of `intl` lowercased; set alone, as a cell,
/// the design draws a leading capital.
String _capitalize(String value) =>
    value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);

/// « Atteint en avril 2026 »: the month inside a sentence keeps the locale's
/// own case. Falls back to the goal's last change if the backend sent no date.
String goalReachedLabel(AppLocalizations l10n, String locale, Goal goal) =>
    l10n.goalReachedIn(
      DateFormat.yMMMM(locale).format(goal.reachedOn ?? goal.updatedAt),
    );

/// The deadline line of a goal, in the table and on the banner: reached,
/// « Juin 2028 », or « Sans échéance ».
String goalDeadlineLabel(AppLocalizations l10n, String locale, Goal goal) {
  if (goal.isReached) return goalReachedLabel(l10n, locale, goal);
  return switch (goal.targetDate) {
    final date? => goalMonthLabel(locale, date),
    null => l10n.goalNoDeadline,
  };
}

/// « 64 % »: a goal's progress as a whole percent.
///
/// Unrounded past the point: the figure sits beside an exact pair of amounts,
/// and a goal at 99,6 % that claimed 100 % would be contradicted by them.
/// Reported unclamped, so an over-funded goal says 118 % while its repère
/// stops at full (`11-goals.md` §Behaviour).
String goalPercentLabel(double progressPct, String locale) => withUnit(
  NumberFormat('0', locale).format((progressPct * 100).truncate()),
  '%',
).replaceAll('-', '−');
