import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/date_field.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/property.dart';
import 'property_form_modal.dart';

/// An ownership share printed as the locale's percent — « 50 % », « 33,33 % ».
String formatOwnershipShare(int bps, String locale) {
  final format = NumberFormat.percentPattern(locale)
    ..minimumFractionDigits = 0
    ..maximumFractionDigits = 2;
  return format.format(bps / fullOwnershipBps);
}

/// The glyph a property nature pill carries beside its hue, so the nature is
/// never on color alone: two buildings for a rental, a house otherwise.
IconData propertyKindIcon(PropertyKind kind) => switch (kind) {
  PropertyKind.rental => Icons.apartment_outlined,
  _ => Icons.home_outlined,
};

enum _PropertyAction { edit, revalue, archive, unarchive }

/// One declared property in the Biens grid (`15-synthese.md` §Biens view).
///
/// The held value is the headline: it is what enters the synthèse. Every
/// figure is neutral — a declared value is a statement, not a movement.
class PropertyCard extends StatelessWidget {
  const PropertyCard({
    super.key,
    required this.property,
    this.onEdit,
    this.onRevalue,
    this.onArchive,
    this.onUnarchive,
  });

  final Property property;
  final VoidCallback? onEdit;
  final VoidCallback? onRevalue;
  final VoidCallback? onArchive;

  /// Set on an archived property, which offers only this.
  final VoidCallback? onUnarchive;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final textTheme = Theme.of(context).textTheme;
    final dateFormat = appDateFormat(locale);
    final id = property.id;

    String money(int minor) => formatAmount(
      amountMinor: minor,
      currency: property.currency,
      locale: locale,
    );

    final valuedOn = dateFormat.format(property.valuedOn);
    final price = property.acquisitionPriceMinor;
    final acquiredOn = property.acquiredOn;
    final delta = property.acquisitionDeltaMinor;

    return AppCard(
      key: Key('propertyCard-$id'),
      onTap: onEdit,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  property.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.headlineSmall,
                ),
              ),
              _PropertyMenu(
                key: Key('propertyMenu-$id'),
                l10n: l10n,
                archived: property.archived,
                onSelected: (action) => switch (action) {
                  _PropertyAction.edit => onEdit?.call(),
                  _PropertyAction.revalue => onRevalue?.call(),
                  _PropertyAction.archive => onArchive?.call(),
                  _PropertyAction.unarchive => onUnarchive?.call(),
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: Alignment.centerLeft,
            child: _KindPill(
              key: Key('propertyKind-$id'),
              label: propertyKindLabel(l10n, property.kind),
              kind: property.kind,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AmountText(
            key: Key('propertyHeldValue-$id'),
            amountMinor: property.userShareValueMinor,
            currency: property.currency,
            colorize: false,
            maxLines: 1,
            style: textTheme.displayMedium!.copyWith(fontSize: 24),
          ),
          const SizedBox(height: 2),
          // « estimée le … » on every card: a declared value ages, and the
          // card says how old it is.
          Text(
            property.isPartlyOwned
                ? l10n.propertyCardCaptionPart(
                    money(property.marketValueMinor),
                    valuedOn,
                  )
                : l10n.propertyCardCaptionWhole(valuedOn),
            key: Key('propertyCaption-$id'),
            style: tabularNumberStyle(
              AppTextStyles.helper,
            ).copyWith(fontSize: 12),
          ),
          const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
          const Divider(height: 1, thickness: 1, color: AppColors.borderSubtle),
          const SizedBox(height: AppSpacing.sm + 2),
          _KeyValue(
            label: l10n.propertyCardOwnership,
            value: formatOwnershipShare(property.ownershipBps, locale),
            valueKey: Key('propertyOwnership-$id'),
          ),
          _KeyValue(
            label: l10n.propertyCardAcquisition,
            value: switch ((price, acquiredOn)) {
              (final price?, final date?) => l10n.propertyCardAcquisitionValue(
                money(price),
                dateFormat.format(date),
              ),
              (final price?, null) => money(price),
              _ => '—',
            },
            valueKey: Key('propertyAcquisition-$id'),
          ),
          _KeyValue(
            label: l10n.propertyCardSinceAcquisition,
            value: switch (delta) {
              null => '—',
              >= 0 => l10n.propertyCardAbove(
                money(delta),
                property.isPartlyOwned.toString(),
              ),
              // Printed as a distance below, so the figure keeps no sign of its
              // own and stays a neutral statement.
              _ => l10n.propertyCardBelow(
                money(-delta),
                property.isPartlyOwned.toString(),
              ),
            },
            valueKey: Key('propertySinceAcquisition-$id'),
          ),
        ],
      ),
    );
  }
}

class _PropertyMenu extends StatelessWidget {
  const _PropertyMenu({
    super.key,
    required this.l10n,
    required this.archived,
    required this.onSelected,
  });

  final AppLocalizations l10n;
  final bool archived;
  final ValueChanged<_PropertyAction> onSelected;

  PopupMenuItem<_PropertyAction> _item(
    _PropertyAction action,
    IconData icon,
    String label,
  ) => PopupMenuItem(
    key: Key('propertyMenu-${action.name}'),
    value: action,
    child: Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: AppSpacing.sm + 2),
        // French labels run long, and a menu is capped in width.
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_PropertyAction>(
      icon: const Icon(Icons.more_horiz_rounded, size: 18),
      tooltip: l10n.propertyMenuTooltip,
      position: PopupMenuPosition.under,
      onSelected: onSelected,
      itemBuilder: (context) => archived
          ? [
              _item(
                _PropertyAction.unarchive,
                Icons.unarchive_outlined,
                l10n.propertyMenuUnarchive,
              ),
            ]
          : [
              _item(
                _PropertyAction.edit,
                Icons.edit_outlined,
                l10n.propertyMenuEdit,
              ),
              _item(
                _PropertyAction.revalue,
                Icons.sell_outlined,
                l10n.propertyMenuRevalue,
              ),
              // Archive, never delete: the loans linked to a property keep
              // their link, and the property can come back.
              _item(
                _PropertyAction.archive,
                Icons.archive_outlined,
                l10n.propertyMenuArchive,
              ),
            ],
    );
  }
}

/// The CategoryChip-style nature pill: hue at 14 % with full-hue text and an
/// 11 px leading glyph.
class _KindPill extends StatelessWidget {
  const _KindPill({super.key, required this.label, required this.kind});

  final String label;
  final PropertyKind kind;

  @override
  Widget build(BuildContext context) {
    final hue = AssetHues.forPropertyKind(kind.wireValue);
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm + 2),
      decoration: BoxDecoration(
        color: hue.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(propertyKindIcon(kind), size: 11, color: hue),
          const SizedBox(width: AppSpacing.xs + 1),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: hue),
          ),
        ],
      ),
    );
  }
}

/// One 12 px row of the card's key/value list.
class _KeyValue extends StatelessWidget {
  const _KeyValue({
    required this.label,
    required this.value,
    required this.valueKey,
  });

  final String label;
  final String value;
  final Key valueKey;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall!.copyWith(fontSize: 12);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: style.copyWith(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            value,
            key: valueKey,
            style: tabularNumberStyle(
              style,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
