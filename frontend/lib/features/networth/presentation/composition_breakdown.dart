import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/dashed_border.dart';
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

/// « Composition de l'actif » (`15-synthese.md` §Row 2): where the value sits,
/// as the HorizontalBars recipe — one stacked 10 px strip over legend rows.
///
/// A Donut was rejected in the frame: four slices where two sit near 2 % read
/// as an error. Every amount and share is the server's; the strip only turns
/// the amounts into widths.
class CompositionBreakdownCard extends StatelessWidget {
  const CompositionBreakdownCard({
    super.key,
    required this.summary,
    required this.properties,
    required this.onNewProperty,
  });

  final NetWorthSummary summary;

  /// The live properties, for the « part détenue » labels and the foot note.
  final List<Property> properties;
  final VoidCallback onNewProperty;

  String _label(AppLocalizations l10n, CompositionEntry entry) {
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

  static Color _hue(CompositionEntry entry) =>
      entry.group == CompositionGroup.account
      ? AssetHues.forAccountType(entry.key)
      : AssetHues.forPropertyKind(entry.key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final textTheme = Theme.of(context).textTheme;
    final hasProperties = summary.composition.any(
      (entry) => entry.group == CompositionGroup.property,
    );

    return AppCard(
      key: const Key('compositionCard'),
      padding: const EdgeInsets.symmetric(
        horizontal: 22,
        vertical: AppSpacing.cardPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.networthCompositionTitle, style: textTheme.titleMedium),
          const SizedBox(height: 2),
          Text(
            l10n.networthCompositionSubtitle,
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _Strip(entries: summary.composition, hue: _hue),
          const SizedBox(height: AppSpacing.sm),
          for (final entry in summary.composition)
            _LegendRow(
              key: Key('compositionRow-${entry.group.wireValue}-${entry.key}'),
              hue: _hue(entry),
              label: _label(l10n, entry),
              share: formatCompositionShare(entry.shareBps, locale),
              amount: formatAmount(
                amountMinor: entry.amountMinor,
                currency: summary.currency,
                locale: locale,
              ),
            ),
          const Spacer(),
          const SizedBox(height: AppSpacing.sm),
          if (hasProperties)
            Text(
              _foot(l10n, locale),
              key: const Key('compositionFoot'),
              style: tabularNumberStyle(
                AppTextStyles.helper,
              ).copyWith(fontSize: 11, color: AppColors.textDisabled),
            )
          else
            _InvitePlate(onNewProperty: onNewProperty),
        ],
      ),
    );
  }

  /// Names each partly owned property with both figures — the held share and
  /// the declared value it is a share of.
  String _foot(AppLocalizations l10n, String locale) {
    final partlyOwned = properties.where((property) => property.isPartlyOwned);
    if (partlyOwned.isEmpty) return l10n.networthCompositionFootWhole;
    String money(int minor) => formatAmount(
      amountMinor: minor,
      currency: summary.currency,
      locale: locale,
    );
    final items = [
      for (final property in partlyOwned)
        l10n.networthCompositionFootItem(
          property.label,
          money(property.userShareValueMinor),
          money(property.marketValueMinor),
        ),
    ];
    return l10n.networthCompositionFoot(items.join(' · '));
  }
}

/// The 10 px stacked strip, gap 2, radius 5.
///
/// Only positive slices are drawn: a credit account's negative balance has no
/// width to take, so it stays in the legend alone (decided in review).
class _Strip extends StatelessWidget {
  const _Strip({required this.entries, required this.hue});

  final List<CompositionEntry> entries;
  final Color Function(CompositionEntry) hue;

  @override
  Widget build(BuildContext context) {
    final drawn = entries.where((entry) => entry.amountMinor > 0).toList();
    return ClipRRect(
      key: const Key('compositionStrip'),
      borderRadius: BorderRadius.circular(5),
      child: SizedBox(
        height: 10,
        child: drawn.isEmpty
            ? const ColoredBox(color: AppColors.surfaceHover)
            : Row(
                children: [
                  for (var index = 0; index < drawn.length; index++) ...[
                    if (index > 0) const SizedBox(width: 2),
                    Expanded(
                      key: Key(
                        'compositionSegment-${drawn[index].group.wireValue}-'
                        '${drawn[index].key}',
                      ),
                      flex: drawn[index].amountMinor,
                      child: ColoredBox(color: hue(drawn[index])),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

/// A 38 px legend row: hue square · label · percent · value.
class _LegendRow extends StatelessWidget {
  const _LegendRow({
    super.key,
    required this.hue,
    required this.label,
    required this.share,
    required this.amount,
  });

  final Color hue;
  final String label;
  final String share;
  final String amount;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium!;
    return SizedBox(
      height: 38,
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: hue,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            share,
            style: tabularNumberStyle(
              style,
            ).copyWith(color: AppColors.textDisabled),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            amount,
            textAlign: TextAlign.right,
            style: tabularNumberStyle(
              style,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Frame ④: with no property, the strip holds the accounts alone and this
/// plate says why, with the way to declare one.
class _InvitePlate extends StatelessWidget {
  const _InvitePlate({required this.onNewProperty});

  final VoidCallback onNewProperty;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;

    return DashedBorder(
      key: const Key('compositionInvite'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.xs,
          children: [
            Text(
              l10n.networthCompositionInvite,
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            InkWell(
              key: const Key('compositionInviteAction'),
              onTap: onNewProperty,
              child: Text(
                l10n.networthCompositionInviteAction,
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.iris,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
