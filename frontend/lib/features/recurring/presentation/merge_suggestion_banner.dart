import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../l10n/app_localizations.dart';
import '../application/subscriptions_controller.dart';
import '../domain/recurring_series.dart';

/// Offers to merge two series the bank split by renaming the merchant
/// (« STREAMCO » becoming « STREAMCO - STREAMCO TV »).
///
/// Info-toned, not a warning: nothing is wrong, the panel has noticed something
/// it can tidy up. Both answers are remembered server-side, so the pair is
/// asked about once.
class MergeSuggestionBanner extends ConsumerStatefulWidget {
  const MergeSuggestionBanner({super.key, required this.suggestion});

  final MergeSuggestion suggestion;

  @override
  ConsumerState<MergeSuggestionBanner> createState() =>
      _MergeSuggestionBannerState();
}

class _MergeSuggestionBannerState extends ConsumerState<MergeSuggestionBanner> {
  /// Whether an answer is in flight, so both buttons hold still meanwhile.
  bool _busy = false;

  Future<void> _merge() async {
    final l10n = AppLocalizations.of(context)!;
    final target = widget.suggestion.target.label;
    setState(() => _busy = true);
    final merged = await ref
        .read(subscriptionsControllerProvider.notifier)
        .merge(widget.suggestion);
    if (!mounted) return;
    setState(() => _busy = false);
    if (merged) {
      showAppToast(
        context,
        title: l10n.subscriptionsMergeDone,
        message: l10n.subscriptionsMergeDoneDetail(target),
      );
    }
  }

  Future<void> _keepApart() async {
    setState(() => _busy = true);
    await ref
        .read(subscriptionsControllerProvider.notifier)
        .keepApart(widget.suggestion);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      key: const Key('subscriptionsMergeBanner'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + AppSpacing.xs,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.32)),
      ),
      child: Row(
        children: [
          const Icon(Icons.merge_type_rounded, size: 15, color: AppColors.info),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              l10n.subscriptionsMergeSuggestion(
                widget.suggestion.source.label,
                widget.suggestion.target.label,
              ),
              key: const Key('subscriptionsMergeText'),
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          TextButton(
            key: const Key('subscriptionsMergeKeepApart'),
            onPressed: _busy ? null : _keepApart,
            child: Text(l10n.subscriptionsMergeKeepApart),
          ),
          const SizedBox(width: AppSpacing.sm),
          PrimaryButton(
            key: const Key('subscriptionsMergeAction'),
            label: l10n.subscriptionsMergeAction,
            height: 30,
            isLoading: _busy,
            onPressed: _busy ? null : _merge,
          ),
        ],
      ),
    );
  }
}
