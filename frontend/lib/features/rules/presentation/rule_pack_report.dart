import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/rule_pack.dart';

/// The preview report: how many rules are new, how many are duplicates the
/// import will skip, and which category keys this install cannot resolve.
///
/// All four figures are shown even when they are zero. « 0 doublon » is an
/// answer; a missing line is a question.
class RulePackReport extends StatelessWidget {
  const RulePackReport({super.key, required this.preview});

  final RulePackPreview preview;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ReportLine(label: l10n.rulePackRuleCount, value: '${preview.total}'),
        _ReportLine(label: l10n.rulePackNewCount, value: '${preview.newCount}'),
        _ReportLine(
          label: l10n.rulePackDuplicateCount,
          value: '${preview.duplicateCount}',
        ),
        _ReportLine(
          label: l10n.rulePackUnresolvedCount,
          value: '${preview.unresolved.length}',
        ),
        if (preview.unresolved.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.rulePackUnresolvedDetail(preview.unresolved.join(', ')),
            key: const Key('rulePackUnresolvedDetail'),
            style: AppTextStyles.helper.copyWith(color: AppColors.warning),
          ),
        ],
        if (preview.samples.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text(l10n.rulePackSamplesLabel, style: AppTextStyles.sectionLabel),
          const SizedBox(height: AppSpacing.sm - 2),
          for (final sample in preview.samples)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '${DateFormat.yMd(Localizations.localeOf(context).toString()).format(sample.bookedDate)}  ${sample.descriptionClean}',
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.mono,
              ),
            ),
        ],
      ],
    );
  }
}

class _ReportLine extends StatelessWidget {
  const _ReportLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(value, style: tabularNumberStyle(textTheme.titleSmall!)),
        ],
      ),
    );
  }
}
