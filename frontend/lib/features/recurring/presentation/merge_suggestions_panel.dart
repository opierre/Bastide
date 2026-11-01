import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/recurring_series.dart';
import 'merge_suggestion_banner.dart';

/// Every pair the server proposes to merge, each with its own « Fusionner »
/// and « Ce sont deux abonnements ».
///
/// A single suggestion is the plain banner of `docs/design/10`. Several are
/// stacked under a count header, so none hides behind another; the stack is
/// capped at three banners' height and scrolls past that, so a long list
/// never pushes the series table off the panel. The header's chevron folds
/// the stack away for the session — the suggestions stay pending server-side,
/// only an answer removes one.
class MergeSuggestionsPanel extends StatefulWidget {
  const MergeSuggestionsPanel({super.key, required this.suggestions});

  final List<MergeSuggestion> suggestions;

  /// Three banners and the two gaps between them: a banner is a 30 px button
  /// inside 8 px of vertical padding.
  static const _maxListHeight =
      3 * (30 + 2 * AppSpacing.sm) + 2 * AppSpacing.sm;

  @override
  State<MergeSuggestionsPanel> createState() => _MergeSuggestionsPanelState();
}

class _MergeSuggestionsPanelState extends State<MergeSuggestionsPanel> {
  /// Purely local UI state: whether the stack is folded under its header.
  bool _collapsed = false;

  @override
  Widget build(BuildContext context) {
    final suggestions = widget.suggestions;
    if (suggestions.length == 1) {
      return _banner(suggestions.single);
    }

    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      key: const Key('subscriptionsMergePanel'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Icon(
              Icons.merge_type_rounded,
              size: 15,
              color: AppColors.info,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                l10n.subscriptionsMergeSuggestionsCount(suggestions.length),
                key: const Key('subscriptionsMergeCount'),
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              key: const Key('subscriptionsMergeToggle'),
              tooltip: _collapsed
                  ? l10n.subscriptionsMergeSuggestionsShow
                  : l10n.subscriptionsMergeSuggestionsHide,
              visualDensity: VisualDensity.compact,
              iconSize: 18,
              color: AppColors.textSecondary,
              icon: Icon(
                _collapsed
                    ? Icons.expand_more_rounded
                    : Icons.expand_less_rounded,
              ),
              onPressed: () => setState(() => _collapsed = !_collapsed),
            ),
          ],
        ),
        if (!_collapsed) ...[
          const SizedBox(height: AppSpacing.xs),
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
