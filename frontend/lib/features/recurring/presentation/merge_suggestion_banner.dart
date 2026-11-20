import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../l10n/app_localizations.dart';
import '../application/subscriptions_controller.dart';
import '../domain/recurring_series.dart';

/// Offers to merge two series the bank split by renaming the merchant
/// (« STREAMCO » becoming « STREAMCO - STREAMCO TV »), as a Banner
/// (`docs/design/10` §2): `merge` icon, the sentence, a ghost « Ce sont deux
/// abonnements » and a secondary « Fusionner ».
///
/// Neutral, never a warning: nothing is wrong, the panel has noticed
/// something it can tidy up. Both answers are remembered server-side, so the
/// pair is asked about once.
class MergeSuggestionBanner extends ConsumerStatefulWidget {
  const MergeSuggestionBanner({super.key, required this.suggestion});

  final MergeSuggestion suggestion;

  /// The banner's height: a 28 px button inside 8 px of padding and a 1 px
  /// border, top and bottom. The stack of suggestions is sized on it.
  static const height = AppSizes.button + 2 * (AppSpacing.sm + 1);

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
    // Looked up before the await: the reload that follows a merge takes this
    // suggestion off the panel, and with it this banner, so the confirmation
    // cannot depend on the banner still being mounted.
    final overlay = Overlay.maybeOf(context);
    setState(() => _busy = true);
    final merged = await ref
        .read(subscriptionsControllerProvider.notifier)
        .merge(widget.suggestion);
    if (mounted) setState(() => _busy = false);
    if (merged && overlay != null && overlay.mounted) {
      showAppToastOn(
        overlay,
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

    return InlineBanner.custom(
      key: const Key('subscriptionsMergeBanner'),
      icon: LucideIcons300.merge,
      content: Text(
        l10n.subscriptionsMergeSuggestion(
          widget.suggestion.source.label,
          widget.suggestion.target.label,
        ),
        key: const Key('subscriptionsMergeText'),
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      actions: [
        AppButton(
          key: const Key('subscriptionsMergeKeepApart'),
          label: l10n.subscriptionsMergeKeepApart,
          variant: AppButtonVariant.ghost,
          onPressed: _busy ? null : _keepApart,
        ),
        AppButton(
          key: const Key('subscriptionsMergeAction'),
          label: l10n.subscriptionsMergeAction,
          isLoading: _busy,
          onPressed: _merge,
        ),
      ],
    );
  }
}
