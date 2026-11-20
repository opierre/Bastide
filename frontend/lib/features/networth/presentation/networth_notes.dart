import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/date_field.dart';
import '../../../core/widgets/note_line.dart';
import '../../../core/widgets/section_heading.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/networth_summary.dart';

/// « À savoir » (`15-synthese.md` §5b): what the synthèse leaves out on
/// purpose, and how it reads what it counts, as notes (`00` §7). Left
/// unexplained, these choices would read as missing features.
///
/// The placements note arrives with the placements in the net worth (#218).
class NetworthNotes extends StatelessWidget {
  const NetworthNotes({super.key, required this.summary});

  final NetWorthSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final oldest = summary.valuedOnOldest;
    const gap = SizedBox(height: AppSpacing.sm);

    return Column(
      key: const Key('networthNotes'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeading(title: l10n.networthNotesTitle),
        NoteLine(
          key: const Key('networthNoteGoals'),
          icon: LucideIcons300.flag,
          text: l10n.networthExclusionGoalsBody,
        ),
        gap,
        NoteLine(
          key: const Key('networthNoteSubscriptions'),
          icon: LucideIcons300.repeat,
          text: l10n.networthExclusionSubscriptionsBody,
        ),
        // It names the oldest current estimate, so it needs a property.
        if (summary.propertyValuesHeldFlat && oldest != null) ...[
          gap,
          NoteLine(
            key: const Key('networthNoteHeldFlat'),
            text: l10n.networthSeriesCaveat(
              appDateFormat(locale).format(oldest),
            ),
          ),
        ],
      ],
    );
  }
}
