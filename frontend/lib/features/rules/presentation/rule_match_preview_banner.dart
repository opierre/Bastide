import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/inline_banner.dart';
import '../../../l10n/app_localizations.dart';
import '../application/rule_preview_controller.dart';
import 'rule_error_localizer.dart';

/// The info banner frame 08 draws under the pattern field: the count, and one
/// example named so the user can tell at a glance whether the rule caught what
/// they meant.
///
/// Silent while the pattern is empty, and silent on a rejected pattern too —
/// that message belongs on the field, and repeating it here would state the
/// same failure twice.
class RuleMatchPreviewBanner extends StatelessWidget {
  const RuleMatchPreviewBanner({super.key, required this.state});

  final RulePreviewState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (state.isLoading && state.preview == null) {
      return InlineBanner(
        key: const Key('rulePreviewLoading'),
        tone: BannerTone.info,
        message: l10n.rulePreviewLoading,
      );
    }
    if (state.error != null) {
      if (isRulePatternInvalid(state.error)) return const SizedBox.shrink();
      return InlineBanner(
        key: const Key('rulePreviewError'),
        tone: BannerTone.warning,
        message: localizeRuleError(l10n, state.error),
      );
    }

    final preview = state.preview;
    if (preview == null) return const SizedBox.shrink();

    final sample = preview.samples.isEmpty ? null : preview.samples.first;
    final locale = Localizations.localeOf(context).toString();
    final message = sample == null
        ? l10n.rulePreviewCount(preview.matchCount)
        : l10n.rulePreviewCountWithSample(
            preview.matchCount,
            sample.descriptionClean,
            DateFormat.yMd(locale).format(sample.bookedDate),
          );

    return InlineBanner(
      key: const Key('rulePreviewBanner'),
      tone: BannerTone.info,
      message: message,
    );
  }
}
