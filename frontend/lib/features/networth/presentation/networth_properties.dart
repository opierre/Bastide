import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_popover.dart';
import '../../../core/widgets/app_table.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../core/widgets/note_line.dart';
import '../../../l10n/app_localizations.dart';
import '../../properties/application/properties_controller.dart';
import '../../properties/domain/property.dart';
import '../../properties/presentation/property_form_modal.dart';
import 'networth_link.dart';

/// « Biens » (`15-synthese.md` §5a): the declared properties as a table, a
/// row menu (Modifier · Nouvelle estimation · Archiver), and the archived ones
/// behind a link beneath. A row opens the property form.
///
/// With no property, the block says what the assets then hold and offers
/// « Nouveau bien ».
class NetworthProperties extends ConsumerWidget {
  const NetworthProperties({
    super.key,
    required this.state,
    required this.currency,
  });

  final PropertiesState state;

  /// The user's currency, for the form's amount fields.
  final String currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final colors = context.colors;
    final controller = ref.read(propertiesControllerProvider.notifier);
    final columns = [
      AppTableColumn(label: l10n.propertiesColumnProperty, flex: 3),
      AppTableColumn(label: l10n.propertiesColumnKind, flex: 2),
      AppTableColumn(
        label: l10n.propertiesColumnShare,
        width: AppNetworth.propertyShareColumn,
        numeric: true,
      ),
      AppTableColumn(
        label: l10n.propertiesColumnHeldValue,
        width: AppNetworth.propertyValueColumn,
        numeric: true,
      ),
      const AppTableColumn(
        label: '',
        width: AppNetworth.menuColumn,
        numeric: true,
      ),
    ];

    Widget row(Property property) => _PropertyRow(
      key: Key('propertyRow-${property.id}'),
      property: property,
      columns: columns,
      onEdit: () =>
          showPropertyForm(context, currency: currency, initial: property),
      onRevalue: () => showRevalueForm(context, property),
      onArchive: () => controller.archive(property.id),
      onUnarchive: () => controller.unarchive(property.id),
    );

    final live = state.properties;
    final archived = state.archived;

    return Column(
      key: const Key('networthProperties'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Heading with the count right after it (`15` §5a).
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(
            children: [
              Text(l10n.propertiesTitle, style: textTheme.titleSmall),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '${live.length}',
                key: const Key('propertiesCount'),
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.textTertiary,
                ),
              ),
            ],
          ),
        ),
        if (state.actionError != null) ...[
          InlineBanner(
            key: const Key('propertiesActionError'),
            message: localizePropertyError(l10n, state.actionError),
            onDismiss: controller.clearActionError,
            dismissTooltip: l10n.propertiesDismiss,
          ),
          const SizedBox(height: AppSpacing.smPlus),
        ],
        if (live.isEmpty)
          Wrap(
            key: const Key('propertiesEmptyNote'),
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              NoteLine(text: l10n.networthNoPropertyNote),
              NetworthLink(
                key: const Key('propertiesEmptyAdd'),
                label: l10n.networthAddProperty,
                onTap: () => showPropertyForm(context, currency: currency),
              ),
            ],
          )
        else ...[
          AppTableHeader(columns: columns),
          for (final property in live) row(property),
        ],
        if (archived.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.smPlus),
          _ArchivedLink(
            count: archived.length,
            open: state.showArchived,
            onTap: controller.toggleArchived,
          ),
          if (state.showArchived) ...[
            const SizedBox(height: AppSpacing.sm),
            // In place rather than on a screen of their own: restoring is a
            // change of mind, not a recovery.
            for (final property in archived) row(property),
          ],
        ],
      ],
    );
  }
}

class _PropertyRow extends StatelessWidget {
  const _PropertyRow({
    super.key,
    required this.property,
    required this.columns,
    required this.onEdit,
    required this.onRevalue,
    required this.onArchive,
    required this.onUnarchive,
  });

  final Property property;
  final List<AppTableColumn> columns;
  final VoidCallback onEdit;
  final VoidCallback onRevalue;
  final VoidCallback onArchive;
  final VoidCallback onUnarchive;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final colors = context.colors;
    final address = property.address;
    final archived = property.archived;
    final secondary = TextStyle(
      color: archived ? colors.textTertiary : colors.textSecondary,
    );
    final id = property.id;

    return AppTableRow(
      columns: columns,
      dimmed: archived,
      twoLines: address != null,
      onTap: archived ? null : onEdit,
      cells: [
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(property.label, maxLines: 1, overflow: TextOverflow.ellipsis),
            if (address != null)
              Text(
                address,
                key: Key('propertyAddress-$id'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.textTertiary),
              ),
          ],
        ),
        Text(
          propertyKindLabel(l10n, property.kind),
          key: Key('propertyKind-$id'),
          style: secondary,
        ),
        Text(
          formatOwnershipShare(property.ownershipBps, locale),
          key: Key('propertyOwnership-$id'),
          style: secondary,
        ),
        Text(
          formatAmount(
            amountMinor: property.userShareValueMinor,
            currency: property.currency,
            locale: locale,
          ),
          key: Key('propertyHeldValue-$id'),
        ),
        _PropertyMenu(
          property: property,
          onEdit: onEdit,
          onRevalue: onRevalue,
          onArchive: onArchive,
          onUnarchive: onUnarchive,
        ),
      ],
    );
  }
}

/// The row's `ellipsis` menu. An archived property offers only « Désarchiver ».
class _PropertyMenu extends StatefulWidget {
  const _PropertyMenu({
    required this.property,
    required this.onEdit,
    required this.onRevalue,
    required this.onArchive,
    required this.onUnarchive,
  });

  final Property property;
  final VoidCallback onEdit;
  final VoidCallback onRevalue;
  final VoidCallback onArchive;
  final VoidCallback onUnarchive;

  @override
  State<_PropertyMenu> createState() => _PropertyMenuState();
}

class _PropertyMenuState extends State<_PropertyMenu> {
  final _menu = MenuController();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final id = widget.property.id;

    AppMenuItem item(String name, String label, VoidCallback onPressed) =>
        AppMenuItem(
          key: Key('propertyMenu-$name'),
          label: label,
          onPressed: onPressed,
        );

    return MenuAnchor(
      controller: _menu,
      style: AppPopover.menuStyle(context),
      alignmentOffset: const Offset(0, AppSpacing.xs),
      menuChildren: widget.property.archived
          ? [item('unarchive', l10n.propertyMenuUnarchive, widget.onUnarchive)]
          : [
              item('edit', l10n.propertyMenuEdit, widget.onEdit),
              item('revalue', l10n.propertyMenuRevalue, widget.onRevalue),
              // Archive, never delete: the loans linked to a property keep
              // their link, and the property can come back.
              item('archive', l10n.propertyMenuArchive, widget.onArchive),
            ],
      child: AppButton(
        key: Key('propertyMenu-$id'),
        label: l10n.propertyMenuTooltip,
        icon: LucideIcons300.ellipsis,
        iconOnly: true,
        variant: AppButtonVariant.ghost,
        onPressed: () => _menu.isOpen ? _menu.close() : _menu.open(),
      ),
    );
  }
}

/// `archive` 14 px + « 2 biens archivés », 12 `textSecondary`.
class _ArchivedLink extends StatelessWidget {
  const _ArchivedLink({
    required this.count,
    required this.open,
    required this.onTap,
  });

  final int count;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Semantics(
        button: true,
        expanded: open,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            key: const Key('propertiesArchivedToggle'),
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons300.archive,
                  size: AppSizes.iconSmall,
                  color: colors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.xsPlus),
                Text(
                  l10n.propertiesArchivedLink(count),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
