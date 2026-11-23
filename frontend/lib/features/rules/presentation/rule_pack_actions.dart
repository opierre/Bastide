import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../l10n/app_localizations.dart';
import '../application/rule_packs_controller.dart';
import '../domain/rule_pack.dart';
import 'rule_pack_export_sheet.dart';
import 'rule_pack_import_sheet.dart';

/// The pack actions at the right of the rules pane's header, one 28 px
/// secondary icon button each, 8 px apart: the toolbar button of every other
/// panel (`00` §6).
///
/// Buttons rather than a menu: behind a single icon, users did not find them.
/// Icon-only so the header stays quiet; each button names its action in a
/// tooltip. Secondary rather than ghost: a ghost button shows only its 14 px
/// icon, which read as a control too small for a toolbar. The built-in pack button hides once that pack is imported.
class RulePackActions extends ConsumerWidget {
  const RulePackActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final offered = ref.watch(offeredBuiltinPacksProvider);
    final firstBuiltin = offered.isEmpty ? null : offered.first;

    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: AppSpacing.sm,
      children: [
        _PackActionButton(
          key: const Key('rulePackImportButton'),
          icon: LucideIcons300.fileUp,
          tooltip: l10n.rulePackImportFile,
          onPressed: () => startRulePackImport(context, ref),
        ),
        // Only when the app bundles a pack the user has not imported yet: there
        // is nothing to offer otherwise.
        if (firstBuiltin != null)
          _PackActionButton(
            key: const Key('rulePackImportBuiltinButton'),
            icon: LucideIcons300.packagePlus,
            tooltip: l10n.rulePackImportBuiltin(firstBuiltin.name),
            onPressed: () =>
                startRulePackImport(context, ref, builtinId: firstBuiltin.id),
          ),
        _PackActionButton(
          key: const Key('rulePackExportButton'),
          icon: LucideIcons300.fileDown,
          tooltip: l10n.rulePackExportAction,
          onPressed: () => startRulePackExport(context, ref),
        ),
      ],
    );
  }
}

class _PackActionButton extends StatelessWidget {
  const _PackActionButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: AppButton(
        label: tooltip,
        icon: icon,
        iconOnly: true,
        onPressed: onPressed,
      ),
    );
  }
}

/// The cold-start offer on the rules empty state: the bundled pack, by name and
/// rule count, one click from a preview.
///
/// This is where a new user with no rules actually is, so it is where the
/// bundled pack has to be — an unlabelled icon on a screen that says « you
/// have no rules » is not an offer.
class BuiltinPackOffer extends ConsumerWidget {
  const BuiltinPackOffer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final packs =
        ref.watch(builtinPacksProvider).value ?? const <BuiltinPack>[];
    if (packs.isEmpty) return const SizedBox.shrink();

    // The user's locale first: a French user offered an English merchant pack
    // would get a pack that matches nothing on their statements.
    final locale = Localizations.localeOf(context).languageCode;
    final pack = packs.firstWhere(
      (candidate) => candidate.locale == locale,
      orElse: () => packs.first,
    );
    // Already imported: offering it again would only report duplicates.
    if (pack.imported) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppButton(
          key: const Key('emptyStateBuiltinPackButton'),
          label: l10n.rulePackStartWith(pack.name, pack.ruleCount),
          icon: LucideIcons300.packagePlus,
          onPressed: () =>
              startRulePackImport(context, ref, builtinId: pack.id),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n.rulePackStartWithHelper,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: context.colors.textTertiary),
        ),
      ],
    );
  }
}
