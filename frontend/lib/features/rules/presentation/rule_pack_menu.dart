import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../application/rule_packs_controller.dart';
import '../domain/rule_pack.dart';
import 'rule_pack_export_sheet.dart';
import 'rule_pack_import_sheet.dart';

enum _PackAction { importFile, importBuiltin, export }

/// The « Importer / Exporter » affordance on the rules view.
///
/// A menu rather than two buttons: packs are an occasional errand beside the
/// rules themselves, and the header's weight belongs to « Exécuter les règles ».
class RulePackMenu extends ConsumerWidget {
  const RulePackMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final builtin =
        ref.watch(builtinPacksProvider).value ?? const <BuiltinPack>[];
    final firstBuiltin = builtin.isEmpty ? null : builtin.first;

    return PopupMenuButton<_PackAction>(
      key: const Key('rulePackMenu'),
      icon: const Icon(Icons.import_export_rounded, size: 18),
      tooltip: l10n.rulePackMenuTooltip,
      position: PopupMenuPosition.under,
      onSelected: (action) => switch (action) {
        _PackAction.importFile => startRulePackImport(context, ref),
        _PackAction.importBuiltin => startRulePackImport(
          context,
          ref,
          builtinId: firstBuiltin!.id,
        ),
        _PackAction.export => startRulePackExport(context, ref),
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _PackAction.importFile,
          child: _MenuRow(
            icon: Icons.file_upload_outlined,
            label: l10n.rulePackImportFile,
          ),
        ),
        if (firstBuiltin != null)
          PopupMenuItem(
            value: _PackAction.importBuiltin,
            child: _MenuRow(
              icon: Icons.auto_awesome_outlined,
              label: l10n.rulePackImportBuiltin(firstBuiltin.name),
            ),
          ),
        PopupMenuItem(
          value: _PackAction.export,
          child: _MenuRow(
            icon: Icons.file_download_outlined,
            label: l10n.rulePackExportAction,
          ),
        ),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: AppSpacing.sm),
        // Flexible, because these labels carry a pack's own name — « Importer
        // "Commerçants français" » — and a menu is not wide enough to promise
        // any of them will fit.
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}

/// The cold-start offer on the rules empty state: the bundled pack, by name and
/// rule count, one click from a preview.
///
/// This is where a new user with no rules actually is, so it is where the
/// bundled pack has to be — a menu entry two clicks away on a screen that says
/// « you have no rules » is not an offer.
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
