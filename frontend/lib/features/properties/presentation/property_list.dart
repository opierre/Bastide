import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/dashed_border.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../l10n/app_localizations.dart';
import '../application/properties_controller.dart';
import '../domain/property.dart';
import 'property_card.dart';
import 'property_form_modal.dart';

/// The Biens view (`15-synthese.md` frame ②): the property cards three to a
/// row with the dashed « Nouveau bien » tile, and the archived link beneath.
class PropertyList extends ConsumerWidget {
  const PropertyList({super.key, required this.state, required this.currency});

  final PropertiesState state;

  /// The user's currency, for the form's amount fields.
  final String currency;

  static const _columns = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final controller = ref.read(propertiesControllerProvider.notifier);

    Widget card(Property property) => property.archived
        ? PropertyCard(
            property: property,
            onUnarchive: () => controller.unarchive(property.id),
          )
        : PropertyCard(
            property: property,
            onEdit: () => showPropertyForm(
              context,
              currency: currency,
              initial: property,
            ),
            onRevalue: () => showRevalueForm(context, property),
            onArchive: () => controller.archive(property.id),
          );

    final newTile = _NewPropertyTile(
      onTap: () => showPropertyForm(context, currency: currency),
    );

    return ListView(
      key: const Key('propertyList'),
      children: [
        if (state.actionError != null) ...[
          InlineBanner(
            key: const Key('propertiesActionError'),
            message: localizePropertyError(l10n, state.actionError),
            onDismiss: controller.clearActionError,
            dismissTooltip: l10n.propertiesDismiss,
          ),
          const SizedBox(height: AppSpacing.gridGap),
        ],
        _Grid(children: [...state.properties.map(card), newTile]),
        const SizedBox(height: AppSpacing.gridGap),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('propertiesArchivedToggle'),
            onPressed: state.archived.isEmpty
                ? null
                : controller.toggleArchived,
            icon: const Icon(Icons.archive_outlined, size: 15),
            label: Text(
              state.showArchived
                  ? l10n.propertiesHideArchived(state.archived.length)
                  : l10n.propertiesShowArchived(state.archived.length),
            ),
          ),
        ),
        if (state.showArchived) ...[
          const SizedBox(height: AppSpacing.sm),
          // In place rather than on a screen of their own: unarchiving is a
          // change of mind, not a recovery.
          _Grid(children: [...state.archived.map(card)]),
        ],
      ],
    );
  }
}

/// Rows of three, gap 18, each row as tall as its tallest card.
class _Grid extends StatelessWidget {
  const _Grid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    const columns = PropertyList._columns;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var start = 0; start < children.length; start += columns) ...[
          if (start > 0) const SizedBox(height: AppSpacing.gridGap),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var column = 0; column < columns; column++) ...[
                  if (column > 0) const SizedBox(width: AppSpacing.gridGap),
                  Expanded(
                    child: start + column < children.length
                        ? children[start + column]
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _NewPropertyTile extends StatelessWidget {
  const _NewPropertyTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;

    return DashedBorder(
      radius: AppRadii.lg,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const Key('propertyNewTile'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add_rounded, size: 22, color: AppColors.iris),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.propertiesNewTileTitle,
                  style: textTheme.titleSmall?.copyWith(color: AppColors.iris),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n.propertiesNewTileBody,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
