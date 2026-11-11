import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../application/rule_packs_controller.dart';
import '../domain/rule_pack.dart';
import 'rule_pack_export_sheet.dart';
import 'rule_pack_import_sheet.dart';

/// The pack actions on the rules view, one icon button each, beside
/// « Exécuter les règles ».
///
/// Buttons rather than a menu: behind a single icon, users did not find them.
/// Icon-only so the header's weight still belongs to « Exécuter les règles »;
/// each button names its action in a tooltip.
class RulePackActions extends ConsumerWidget {
  const RulePackActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final builtin =
        ref.watch(builtinPacksProvider).value ?? const <BuiltinPack>[];
    final firstBuiltin = builtin.isEmpty ? null : builtin.first;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PackActionButton(
          key: const Key('rulePackImportButton'),
          icon: Icons.file_upload_outlined,
          tooltip: l10n.rulePackImportFile,
          onPressed: () => startRulePackImport(context, ref),
        ),
        // Only when the app bundles a pack: there is nothing to offer otherwise.
        if (firstBuiltin != null)
          _PackActionButton(
            key: const Key('rulePackImportBuiltinButton'),
            icon: Icons.auto_awesome_outlined,
            tooltip: l10n.rulePackImportBuiltin(firstBuiltin.name),
            onPressed: () =>
                startRulePackImport(context, ref, builtinId: firstBuiltin.id),
          ),
        _PackActionButton(
          key: const Key('rulePackExportButton'),
          icon: Icons.file_download_outlined,
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
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      iconSize: 18,
      // 34 px, the search pill's icon targets: three Material 48 px buttons
      // crowd the header beside a French « Exécuter les règles » label.
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      color: AppColors.textSecondary,
      icon: Icon(icon),
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton.icon(
          key: const Key('emptyStateBuiltinPackButton'),
          onPressed: () =>
              startRulePackImport(context, ref, builtinId: pack.id),
          icon: const Icon(Icons.auto_awesome_outlined, size: 16),
          label: Text(l10n.rulePackStartWith(pack.name, pack.ruleCount)),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n.rulePackStartWithHelper,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textDisabled),
        ),
      ],
    );
  }
}
