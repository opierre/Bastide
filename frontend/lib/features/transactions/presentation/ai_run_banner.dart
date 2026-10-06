import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_card.dart';
import '../../../l10n/app_localizations.dart';
import '../../categorization/application/run_controller.dart';
import '../../categorization/domain/categorization_run.dart';
import '../application/transactions_controller.dart';

/// The banner that stands in for the review queue's header card while a run is
/// classifying (`docs/design/07` frame ⑦).
///
/// Non-blocking by construction: it is a card in the column above the list, not
/// a modal or an overlay. The list beneath stays interactive, and rows leave it
/// as the run commits batches — which is the whole point of running stage 2
/// outside the request that triggered it (PROJECT.md §7).
class AiRunBanner extends ConsumerWidget {
  const AiRunBanner({super.key, required this.run});

  final CategorizationRun run;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return AppCard(
      key: const Key('aiRunBanner'),
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      gradient: AppColors.irisTintGradient,
      border: Border.all(color: AppColors.irisBorderStrong),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.iris,
                ),
              ),
              const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.runBannerRunning(run.processedCount, run.totalCount),
                      key: const Key('aiRunBannerHeadline'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.runBannerRunningDetail(
                        run.assignedCount,
                        run.deferredCount,
                      ),
                      key: const Key('aiRunBannerDetail'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              SizedBox(
                height: 30,
                child: OutlinedButton(
                  key: const Key('aiRunBannerCancel'),
                  onPressed: () =>
                      ref.read(runControllerProvider.notifier).cancel(),
                  child: Text(l10n.runBannerCancel),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
          RunProgressBar(fraction: run.progress),
        ],
      ),
    );
  }
}

/// The 6px iris-gradient bar shared by the running banner and the queue's
/// header card, so a run finishing doesn't change the shape of the progress
/// the user was watching.
class RunProgressBar extends StatelessWidget {
  const RunProgressBar({super.key, required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 6,
      decoration: BoxDecoration(
        color: AppColors.surfaceHover,
        borderRadius: BorderRadius.circular(AppRadii.xs),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: fraction.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.irisDeep, AppColors.iris],
            ),
            borderRadius: BorderRadius.circular(AppRadii.xs),
          ),
        ),
      ),
    );
  }
}

/// What a finished run has to say, when it has anything to say at all.
///
/// Renders nothing for `success` and `cancelled`: a run that did what it was
/// asked, or that the user stopped themselves, needs no announcement — the
/// header card coming back is the report. `partial` and `failed` are surfaced
/// on a tint with a dismiss, never as an error wall over the queue.
class RunOutcomeBanner extends ConsumerWidget {
  const RunOutcomeBanner({super.key, required this.run});

  final CategorizationRun run;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return switch (run.status) {
      RunStatus.partial => _OutcomeCard(
        cardKey: const Key('aiRunPartialBanner'),
        tone: AppColors.warning,
        icon: Icons.warning_amber_rounded,
        message: l10n.runBannerPartial(run.failedCount),
        actionLabel: l10n.runBannerPartialAction,
        // The rows a run couldn't analyse are exactly the rows still needing
        // review, so « Voir » is the review filter.
        onAction: () {
          ref.read(transactionFiltersProvider.notifier).setNeedsReview(true);
          ref.read(runControllerProvider.notifier).dismissBanner();
        },
      ),
      RunStatus.failed => _OutcomeCard(
        cardKey: const Key('aiRunFailedBanner'),
        tone: AppColors.warning,
        icon: Icons.info_outline_rounded,
        message: l10n.runBannerFailed,
      ),
      _ => const SizedBox.shrink(),
    };
  }
}

class _OutcomeCard extends ConsumerWidget {
  const _OutcomeCard({
    required this.cardKey,
    required this.tone,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final Key cardKey;
  final Color tone;
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      key: cardKey,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + AppSpacing.xs,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: tone.withValues(alpha: 0.32)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: tone),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: tone),
            ),
          ),
          if (actionLabel != null) ...[
            const SizedBox(width: AppSpacing.sm),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                key: const Key('aiRunBannerAction'),
                onTap: onAction,
                child: Text(
                  actionLabel!,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: tone,
                    decoration: TextDecoration.underline,
                    decorationColor: tone,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(width: AppSpacing.sm),
          IconButton(
            key: const Key('aiRunBannerDismiss'),
            iconSize: 14,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            padding: EdgeInsets.zero,
            tooltip: l10n.runBannerDismiss,
            icon: Icon(Icons.close_rounded, color: tone),
            onPressed: () =>
                ref.read(runControllerProvider.notifier).dismissBanner(),
          ),
        ],
      ),
    );
  }
}
