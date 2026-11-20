import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/recurring_series.dart';
import 'merge_suggestion_banner.dart';

/// Every pair the server proposes to merge, one Banner each, 8 px apart
/// (`docs/design/10` §2).
///
/// A single suggestion is the plain banner. With more than one, a header row
/// sits above: `merge`, « 3 suggestions de fusion » 12 `textSecondary`, and a
/// ghost chevron that folds them for the session. The suggestions stay
/// pending server-side; only an answer removes one. Past three banners the
/// stack scrolls, so a long list never pushes the table off the panel.
class MergeSuggestionsPanel extends StatefulWidget {
  const MergeSuggestionsPanel({super.key, required this.suggestions});

  final List<MergeSuggestion> suggestions;

  /// Three banners and the two gaps between them.
  static const _maxListHeight =
      3 * MergeSuggestionBanner.height + 2 * AppSpacing.sm;

  @override
  State<MergeSuggestionsPanel> createState() => _MergeSuggestionsPanelState();
}

class _MergeSuggestionsPanelState extends State<MergeSuggestionsPanel> {
  /// Purely local UI state: whether the stack is folded under its header.
  bool _collapsed = false;

  @override
  Widget build(BuildContext context) {
    final suggestions = widget.suggestions;
    if (suggestions.length == 1) return _banner(suggestions.single);

    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;

    return Column(
      key: const Key('subscriptionsMergePanel'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(
              LucideIcons300.merge,
              size: AppSizes.iconSmall,
              color: colors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.xsPlus),
            Expanded(
              child: Text(
                l10n.subscriptionsMergeSuggestionsCount(suggestions.length),
                key: const Key('subscriptionsMergeCount'),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
              ),
            ),
            AppButton(
              key: const Key('subscriptionsMergeToggle'),
              label: _collapsed
                  ? l10n.subscriptionsMergeSuggestionsShow
                  : l10n.subscriptionsMergeSuggestionsHide,
              icon: _collapsed
                  ? LucideIcons300.chevronDown
                  : LucideIcons300.chevronUp,
              iconOnly: true,
              variant: AppButtonVariant.ghost,
              onPressed: () => setState(() => _collapsed = !_collapsed),
            ),
          ],
        ),
        if (!_collapsed) ...[
          const SizedBox(height: AppSpacing.sm),
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: MergeSuggestionsPanel._maxListHeight,
            ),
            child: ListView.separated(
              key: const Key('subscriptionsMergeList'),
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: suggestions.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (_, index) => _banner(suggestions[index]),
            ),
          ),
        ],
      ],
    );
  }

  /// Keyed by the pair, so a banner's in-flight state stays with its pair
  /// when an answer elsewhere reloads the list and shifts the rows.
  Widget _banner(MergeSuggestion suggestion) => MergeSuggestionBanner(
    key: ValueKey('merge-${suggestion.target.id}-${suggestion.source.id}'),
    suggestion: suggestion,
  );
}
