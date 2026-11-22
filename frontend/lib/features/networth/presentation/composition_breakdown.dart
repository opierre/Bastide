import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/app_table.dart';
import '../../../core/widgets/category_label.dart';
import '../../../core/widgets/section_heading.dart';
import '../../../l10n/app_localizations.dart';
import '../../properties/domain/property.dart';
import '../../properties/presentation/property_form_modal.dart';
import '../domain/networth_summary.dart';

/// A composition share printed as the locale's percent — « 81,3 % ».
String formatCompositionShare(int bps, String locale) {
  final format = NumberFormat.percentPattern(locale)
    ..minimumFractionDigits = 1
    ..maximumFractionDigits = 1;
  return format.format(bps / 10000);
}

/// « Composition de l’actif » (`15-synthese.md` §3a): the composition bar of
/// `00` §9, then a table without header (label, share, amount), rows by
/// descending amount.
///
/// Hues follow rank: `cat1` for the largest slice onward, the same hue on the
/// bar and on the row's dot. Every amount and share is the server's; the bar
/// only turns the amounts into widths. No donut.
class CompositionSection extends StatelessWidget {
  const CompositionSection({
    super.key,
    required this.summary,
    required this.properties,
  });

  final NetWorthSummary summary;

  /// The live properties, for the « part détenue » labels and notes.
  final List<Property> properties;

  static const _columns = [
    AppTableColumn(label: ''),
    AppTableColumn(label: '', width: AppNetworth.shareColumn, numeric: true),
    AppTableColumn(label: '', width: AppNetworth.amountColumn, numeric: true),
  ];

  String _label(AppLocalizations l10n, CompositionEntry entry) {
    if (entry.group == CompositionGroup.investment) {
      return l10n.networthCompositionInvestments;
    }
    if (entry.group == CompositionGroup.account) {
      return switch (entry.key) {
        'checking' => l10n.networthCompositionChecking,
        'savings' => l10n.networthCompositionSavings,
        'credit' => l10n.networthCompositionCredit,
        'deferred_card' => l10n.networthCompositionDeferredCard,
        'cash' => l10n.networthCompositionCash,
        _ => l10n.networthCompositionOtherAccounts,
      };
    }
    final kind = PropertyKind.fromWire(entry.key);
    final label = propertyKindLabel(l10n, kind);
    final partlyOwned = properties.any(
      (property) => property.kind == kind && property.isPartlyOwned,
    );
    return partlyOwned ? l10n.networthCompositionHeldShare(label) : label;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final entries = summary.compositionByAmount;
    final hues = context.categoryColors;
    String money(int minor) => formatAmount(
      amountMinor: minor,
      currency: summary.currency,
      locale: locale,
    );
    final partlyOwned = [
      for (final property in properties)
        if (property.isPartlyOwned) property,
    ];

    return Column(
      key: const Key('compositionSection'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeading(title: l10n.networthCompositionTitle),
        const SizedBox(height: AppSpacing.xs),
        _Bar(entries: entries, hue: hues.forRank),
        const SizedBox(height: AppSpacing.smPlus),
        for (final (index, entry) in entries.indexed)
          AppTableRow(
            key: Key('compositionRow-${entry.group.wireValue}-${entry.key}'),
            columns: _columns,
            cells: [
              _CompositionLabel(
                hue: hues.forRank(index),
                label: _label(l10n, entry),
              ),
              Text(
                formatCompositionShare(entry.shareBps, locale),
                style: TextStyle(color: context.colors.textTertiary),
              ),
              Text(money(entry.amountMinor)),
            ],
          ),
        for (final property in partlyOwned) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.networthCompositionPartNote(
              property.label,
              money(property.userShareValueMinor),
              money(property.marketValueMinor),
            ),
            key: Key('compositionPartNote-${property.id}'),
            style: tabularNumberStyle(
              Theme.of(context).textTheme.bodySmall!,
            ).copyWith(color: context.colors.textTertiary),
          ),
        ],
      ],
    );
  }
}

/// The composition bar (`00` §9): 8 px, segments 2 px apart, radius 2.
///
/// Only positive slices are drawn: a credit account's negative balance has no
/// width to take, so it stays in the table alone.
class _Bar extends StatelessWidget {
  const _Bar({required this.entries, required this.hue});

  final List<CompositionEntry> entries;
  final Color Function(int rank) hue;

  @override
  Widget build(BuildContext context) {
    final drawn = [
      for (final (rank, entry) in entries.indexed)
        if (entry.amountMinor > 0) (rank, entry),
    ];
    const radius = BorderRadius.all(Radius.circular(AppRadii.bar));

    return SizedBox(
      key: const Key('compositionBar'),
      height: AppChart.compositionBarHeight,
      child: drawn.isEmpty
          ? DecoratedBox(
              decoration: BoxDecoration(
                color: context.colors.lineStrong,
                borderRadius: radius,
              ),
            )
          : Row(
              children: [
                for (final (i, (rank, entry)) in drawn.indexed) ...[
                  if (i > 0) const SizedBox(width: AppChart.compositionBarGap),
                  Expanded(
                    key: Key(
                      'compositionSegment-${entry.group.wireValue}-${entry.key}',
                    ),
                    flex: entry.amountMinor,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: hue(rank),
                        borderRadius: radius,
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

/// A category-style label (`00` §7): the 8 px dot in the segment's hue, then
/// the name, here in `text`.
class _CompositionLabel extends StatelessWidget {
  const _CompositionLabel({required this.hue, required this.label});

  final Color hue;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          key: const Key('compositionDot'),
          width: CategoryLabel.dotSize,
          height: CategoryLabel.dotSize,
          decoration: BoxDecoration(
            color: hue,
            borderRadius: BorderRadius.circular(AppRadii.bar),
          ),
        ),
        const SizedBox(width: AppSpacing.xsPlus),
        Flexible(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}
