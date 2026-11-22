import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_link.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../core/widgets/repere_meter.dart';
import '../../../l10n/app_localizations.dart';
import '../../categorization/application/run_controller.dart';
import '../../categorization/domain/categorization_run.dart';

/// The banner that replaces the review tab's progress row while a run is
/// classifying (`07-transactions.md` §Tab « À vérifier »): the banner recipe
/// of `00` §7 with a 14 px spinner, « Catégorisation en cours : 84 sur 213
/// opérations », the counts in `textSecondary`, a secondary « Annuler », and
/// a repère under the text.
///
/// Non-blocking by construction: it sits in the column above the table, which
/// stays usable while rows leave it as the run commits batches.
class AiRunBanner extends ConsumerWidget {
  const AiRunBanner({super.key, required this.run});

  final CategorizationRun run;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      key: const Key('aiRunBanner'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.smPlus,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadii.container),
        border: Border.all(color: colors.lineStrong),
      ),
      child: Row(
        children: [
          SizedBox.square(
            dimension: AppSizes.iconSmall,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: colors.accent,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: l10n.runBannerRunning(
                          run.processedCount,
                          run.totalCount,
                        ),
                      ),
                      const TextSpan(text: '  '),
                      TextSpan(
                        text: l10n.runBannerRunningDetail(
                          run.assignedCount,
                          run.deferredCount,
                        ),
                        style: TextStyle(color: colors.textSecondary),
                      ),
                    ],
                  ),
                  key: const Key('aiRunBannerHeadline'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tabularNumberStyle(textTheme.bodyMedium!),
                ),
                const SizedBox(height: AppSpacing.xsPlus),
                RepereMeter(fraction: run.progress),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.smPlus),
          AppButton(
            key: const Key('aiRunBannerCancel'),
            label: l10n.runBannerCancel,
            onPressed: () => ref.read(runControllerProvider.notifier).cancel(),
          ),
        ],
      ),
    );
  }
}

/// What a finished run has to say, when it has anything to say at all.
///
/// Nothing for `success` and `cancelled`: a run that did what it was asked,
/// or that the user stopped themselves, needs no announcement; the progress
/// row coming back is the report. `partial` and `failed` show a dismissible
/// banner whose `warning` icon alone carries the tone.
class RunOutcomeBanner extends ConsumerWidget {
  const RunOutcomeBanner({super.key, required this.run, this.onView});

  final CategorizationRun run;

  /// « Voir »: the rows the run could not analyse are the rows still in the
  /// queue, which the review tab already lists.
  final VoidCallback? onView;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final controller = ref.read(runControllerProvider.notifier);

    return switch (run.status) {
      RunStatus.partial => InlineBanner(
        key: const Key('aiRunPartialBanner'),
        tone: BannerTone.warning,
        message: l10n.runBannerPartial(run.failedCount),
        onDismiss: controller.dismissBanner,
        dismissTooltip: l10n.runBannerDismiss,
        actions: [
          AppLink(
            key: const Key('aiRunBannerAction'),
            label: l10n.runBannerPartialAction,
            small: false,
            onTap: () {
              onView?.call();
              controller.dismissBanner();
            },
          ),
        ],
      ),
      RunStatus.failed => InlineBanner(
        key: const Key('aiRunFailedBanner'),
        tone: BannerTone.warning,
        message: l10n.runBannerFailed,
        onDismiss: controller.dismissBanner,
        dismissTooltip: l10n.runBannerDismiss,
      ),
      _ => const SizedBox.shrink(),
    };
  }
}
