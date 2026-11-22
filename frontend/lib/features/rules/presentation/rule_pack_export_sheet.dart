import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_modal.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/app_checkbox.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../core/widgets/note_line.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../l10n/app_localizations.dart';
import '../application/rule_packs_controller.dart';
import '../domain/rule_pack.dart';
import 'rule_error_localizer.dart';

/// Builds the export and opens the review sheet.
///
/// Nothing is written until the user has read the pack. A silent download of a
/// file carrying « VIR SALAIRE DUPONT » is the failure mode this step exists to
/// prevent — patterns are typed against real bank labels, and those labels
/// carry names.
Future<void> startRulePackExport(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context)!;
  try {
    final export = await ref
        .read(rulePacksControllerProvider.notifier)
        .prepareExport();
    if (!context.mounted) return;
    await showAppModal<void>(
      context: context,
      builder: (_) => RulePackExportSheet(export: export),
    );
  } catch (error) {
    if (!context.mounted) return;
    showAppToast(
      context,
      title: l10n.rulePackExportFailed,
      message: localizeRuleError(l10n, error),
      tone: BannerTone.error,
    );
  }
}

/// « Exporter mes règles », 560 px (`docs/design/08` §Rule packs, proposal v6
/// `m-rules`): the privacy warning, the pack's contents verbatim in a `field`
/// well, and what it could not carry.
class RulePackExportSheet extends ConsumerStatefulWidget {
  const RulePackExportSheet({super.key, required this.export});

  final RulePackExport export;

  @override
  ConsumerState<RulePackExportSheet> createState() =>
      _RulePackExportSheetState();
}

class _RulePackExportSheetState extends ConsumerState<RulePackExportSheet> {
  late RulePackExport _export = widget.export;
  bool _includeLogos = false;
  bool _isRefreshing = false;
  bool _isSaving = false;
  String? _errorText;

  /// Rebuilds the export with or without logos. The pack is the backend's to
  /// assemble — it alone knows each rule's stored logo and the size cap — so
  /// toggling re-asks rather than patching the pack here.
  Future<void> _setIncludeLogos(bool value) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _includeLogos = value;
      _isRefreshing = true;
      _errorText = null;
    });
    try {
      final export = await ref
          .read(rulePacksControllerProvider.notifier)
          .prepareExport(includeLogos: value);
      if (!mounted) return;
      setState(() {
        _export = export;
        _isRefreshing = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        // The sheet still shows the previous pack, so the toggle goes back to
        // the state that pack was built with.
        _includeLogos = !value;
        _isRefreshing = false;
        _errorText = localizeRuleError(l10n, error);
      });
    }
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isSaving = true;
      _errorText = null;
    });
    try {
      final path = await ref
          .read(rulePacksControllerProvider.notifier)
          .saveExport(_export.pack);
      if (!mounted) return;
      if (path == null) {
        setState(() => _isSaving = false);
        return;
      }
      Navigator.of(context).pop();
      showAppToast(context, title: l10n.rulePackExportedTitle, message: path);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorText = localizeRuleError(l10n, error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final pack = _export.pack;
    final omitted = _export.omitted;
    final isBusy = _isSaving || _isRefreshing;
    final labelStyle = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: colors.textSecondary);
    const gap = SizedBox(height: AppSpacing.fieldGap);

    return AppModal(
      key: const Key('rulePackExportModal'),
      title: l10n.rulePackExportTitle,
      width: AppCategoriesPanel.packModalWidth,
      busy: _isSaving,
      saveError: _errorText,
      actions: [
        const AppModalCancel(key: Key('rulePackExportCancel')),
        PrimaryButton(
          key: const Key('rulePackExportSave'),
          label: l10n.rulePackExportSave,
          isLoading: _isSaving,
          onPressed: isBusy ? null : _save,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Something to act on before saving, so a banner and not a note;
          // nothing to dismiss, since the pack it warns about stays on screen
          // (`08` §Rule packs).
          InlineBanner(
            key: const Key('rulePackPrivacyNotice'),
            tone: BannerTone.warning,
            message: l10n.rulePackExportPrivacyNotice,
          ),
          gap,
          _IncludeLogosCheckbox(
            value: _includeLogos,
            onChanged: isBusy ? null : _setIncludeLogos,
          ),
          if (_includeLogos && !_isRefreshing) ...[
            gap,
            if (_export.logosTooLarge)
              InlineBanner(
                key: const Key('rulePackExportLogosTooLarge'),
                tone: BannerTone.warning,
                message: l10n.rulePackExportLogosTooLarge,
              )
            else
              NoteLine(
                key: const Key('rulePackExportLogoCount'),
                icon: LucideIcons300.image,
                text: l10n.rulePackExportLogoCount(_export.logoCount),
              ),
          ],
          gap,
          Text(
            l10n.rulePackExportContents(pack.rules.length),
            style: labelStyle,
          ),
          gap,
          // The file itself, not a summary of it: the point of the step is that
          // the user reads what leaves their machine.
          Container(
            key: const Key('rulePackExportPreview'),
            height: AppCategoriesPanel.packPreviewHeight,
            padding: const EdgeInsets.all(AppSpacing.smPlus),
            decoration: BoxDecoration(
              color: colors.field,
              borderRadius: BorderRadius.circular(AppRadii.container),
              border: Border.all(color: colors.lineStrong),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                // Each embedded logo stands in as its size: the picture is
                // still in the saved file, but its base64 is nothing a reader
                // can review, and tens of kilobytes of it per rule would bury
                // the patterns this step is for.
                pack.toPrettyJson(
                  elideLogo: (bytes) =>
                      l10n.rulePackExportLogoElided((bytes / 1024).ceil()),
                ),
                style: context.textStyles.mono,
              ),
            ),
          ),
          if (omitted.isNotEmpty) ...[
            gap,
            Text(l10n.rulePackOmittedLabel(omitted.length), style: labelStyle),
            gap,
            for (final (i, rule) in omitted.indexed) ...[
              if (i > 0) const SizedBox(height: AppSpacing.xsPlus),
              NoteLine(
                key: Key('rulePackOmitted-${rule.ruleId}'),
                icon: LucideIcons300.circleMinus,
                text: switch (rule.reason) {
                  RuleOmissionReason.regex => l10n.rulePackOmittedRegex(
                    rule.pattern,
                  ),
                  RuleOmissionReason.userCategory =>
                    l10n.rulePackOmittedUserCategory(rule.pattern),
                },
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// « Inclure les logos »: the design system's checkbox (`00` §6) with its
/// label, both of which toggle it.
class _IncludeLogosCheckbox extends StatelessWidget {
  const _IncludeLogosCheckbox({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final label = AppLocalizations.of(context)!.rulePackExportIncludeLogos;
    final onChanged = this.onChanged;
    return MouseRegion(
      cursor: onChanged == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onChanged == null ? null : () => onChanged(!value),
        behavior: HitTestBehavior.opaque,
        child: Row(
          children: [
            AppCheckbox(
              key: const Key('rulePackExportIncludeLogos'),
              value: value,
              semanticLabel: label,
              onChanged: onChanged,
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
            ),
          ],
        ),
      ),
    );
  }
}
