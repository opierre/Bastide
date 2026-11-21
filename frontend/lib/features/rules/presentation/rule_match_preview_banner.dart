import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/inline_banner.dart';
import '../../../core/widgets/note_line.dart';
import '../../../l10n/app_localizations.dart';
import '../application/rule_preview_controller.dart';
import 'rule_error_localizer.dart';

/// The note the rule editor shows under the target category
/// (`docs/design/08` §Rule editor): the count, and one example named so the
/// user can tell at a glance whether the rule caught what they meant
/// (« Correspond à 7 opérations existantes, dont « CB CARREFOUR PARIS 15 »
/// du 14 mai 2026. »).
///
/// A note, not a banner: it is something to know, not to act on. A failed
/// count is the exception, a warning banner, since the user may want to retry.
/// Silent while the pattern is empty, and silent on a rejected pattern too:
/// that message belongs on the field.
class RuleMatchPreviewBanner extends StatelessWidget {
  const RuleMatchPreviewBanner({super.key, required this.state});

  final RulePreviewState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (state.isLoading && state.preview == null) {
      return NoteLine(
        key: const Key('rulePreviewLoading'),
        text: l10n.rulePreviewLoading,
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
            DateFormat.yMMMMd(locale).format(sample.bookedDate),
          );

    return NoteLine(key: const Key('rulePreviewBanner'), text: message);
  }
}
