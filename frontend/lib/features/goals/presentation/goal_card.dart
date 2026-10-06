import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/app_card.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/goal.dart';
import 'goal_labels.dart';

/// One goal in the grid (`docs/design/11-goals.md` frame ①): name and pill,
/// the saved-against-target line with its percentage, and the progress bar.
///
/// **No account line, deliberately.** A goal is not linked to an account, and
/// the design shows none anywhere in this feature — putting one here would
/// promise the user that allocating moves money in a particular account, which
/// is exactly the thing a virtual envelope never does.
class GoalCard extends StatelessWidget {
  const GoalCard({
    super.key,
    required this.goal,
    required this.onOpen,
    this.dimmed = false,
  });

  final Goal goal;
  final VoidCallback onOpen;

  /// Archived goals are shown in place, faded: they are still the user's goals
  /// and still carry their history, they are simply out of the running.
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final card = AppCard(
      key: Key('goalCard-${goal.id}'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.cardPaddingWide,
        vertical: AppSpacing.cardPadding,
      ),
      onTap: onOpen,
      // The reached card is the panel's one celebratory surface: an iris tint
      // behind a green edge, so a finished goal is legible as finished from
      // across the grid rather than only in its percentage.
      gradient: goal.isReached ? AppColors.irisTintGradient : null,
      border: goal.isReached
          ? Border.all(color: AppColors.positiveBorder)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  goal.name,
                  key: Key('goalCardName-${goal.id}'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
              GoalPill(goal: goal),
            ],
          ),
          const SizedBox(height: AppSpacing.md - 2),
          GoalValueLine(goal: goal),
          const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
          GoalProgressBar(fraction: goal.barFraction),
        ],
      ),
    );

    if (!dimmed) return card;
    return Opacity(opacity: 0.55, child: card);
  }
}

/// « Sans échéance », « Juin 2028 », or the green « Objectif atteint · Juin 2026 ».
///
/// One pill with three readings rather than a pill plus a badge: the date and
/// the reached state answer the same question — where this goal stands in time
/// — and stacking two chips would make a finished goal look busier than a
/// running one.
class GoalPill extends StatelessWidget {
  const GoalPill({super.key, required this.goal});

  final Goal goal;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final month = goal.targetDate == null
        ? null
        : goalMonthLabel(locale, goal.targetDate!);

    final reached = goal.isReached;
    final label = reached
        ? (month == null ? l10n.goalPillReached : l10n.goalPillReachedOn(month))
        : (month ?? l10n.goalPillNoDeadline);

    return Container(
      key: Key('goalPill-${goal.id}'),
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm + 2),
      decoration: BoxDecoration(
        color: reached
            ? AppColors.positive.withValues(alpha: 0.12)
            : AppColors.surfaceHover,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (reached) ...[
            const Icon(
              Icons.check_rounded,
              size: 12,
              color: AppColors.positive,
            ),
            const SizedBox(width: AppSpacing.xs + 1),
          ],
          Text(
            label,
            style: TextStyle(
              fontFamily: AppFonts.geist,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: reached ? AppColors.positive : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// « 6 400,00 € / 10 000,00 € » with the percentage right-aligned.
///
/// The percentage is the *real* one, not the bar's clamped fraction: an
/// over-funded goal says 118 % beside a bar that stops at full. Hiding the
/// overshoot would be a lie about the user's money; drawing it would be a bug
/// (`docs/design/11-goals.md` §Notes).
class GoalValueLine extends StatelessWidget {
  const GoalValueLine({super.key, required this.goal});

  final Goal goal;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                // Neutral, never green or red: what is set aside is a standing
                // quantity, not a movement, so the ledger's sign colors would
                // state something false about it.
                child: AmountText(
                  key: Key('goalSaved-${goal.id}'),
                  amountMinor: goal.progressMinor,
                  currency: goal.currency,
                  colorize: false,
                  style: textTheme.displayMedium!.copyWith(fontSize: 24),
                ),
              ),
              const SizedBox(width: AppSpacing.xs + 2),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  '/ ${formatAmount(amountMinor: goal.targetMinor, currency: goal.currency, locale: locale)}',
                  key: Key('goalTarget-${goal.id}'),
                  style: tabularNumberStyle(
                    textTheme.bodyMedium!,
                  ).copyWith(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Text(
            goalPercentLabel(goal.progressPct, locale),
            key: Key('goalPercent-${goal.id}'),
            style: tabularNumberStyle(textTheme.titleSmall!).copyWith(
              fontSize: 14,
              color: goal.isReached ? AppColors.positive : AppColors.iris,
            ),
          ),
        ),
      ],
    );
  }
}

/// The 8 px progress bar: an inset track with an iris-gradient fill.
///
/// [fraction] is already clamped by the caller — this widget draws what it is
/// given and holds no opinion about over-funding.
class GoalProgressBar extends StatelessWidget {
  const GoalProgressBar({super.key, required this.fraction, this.height = 8});

  final double fraction;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.xs),
      child: Container(
        height: height,
        color: AppColors.surfaceHover,
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: fraction,
          child: const DecoratedBox(
            decoration: BoxDecoration(gradient: AppColors.goalProgressGradient),
          ),
        ),
      ),
    );
  }
}
