import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_modal.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/app_toggle.dart';
import '../../../core/widgets/inline_banner.dart';
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
    await showDialog<void>(
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

/// The review sheet: the pack's contents verbatim, what it could not carry, and
/// a plain warning that patterns can hold personal detail.
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
    final pack = _export.pack;
    final omitted = _export.omitted;
    final isBusy = _isSaving || _isRefreshing;

    return AppModal(
      title: l10n.rulePackExportTitle,
      width: 520,
      actions: [
        OutlinedButton(
          onPressed: isBusy ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.rulePackCancel),
        ),
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
          if (_errorText != null) ...[
            InlineBanner(
              key: const Key('rulePackExportError'),
              message: _errorText!,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          InlineBanner(
            key: const Key('rulePackPrivacyNotice'),
            tone: BannerTone.warning,
            message: l10n.rulePackExportPrivacyNotice,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              AppToggle(
                key: const Key('rulePackExportIncludeLogos'),
                value: _includeLogos,
                semanticLabel: l10n.rulePackExportIncludeLogos,
                onChanged: isBusy ? null : _setIncludeLogos,
              ),
              const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
              Expanded(
                child: Text(
                  l10n.rulePackExportIncludeLogos,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          if (_includeLogos && !_isRefreshing) ...[
            const SizedBox(height: AppSpacing.sm),
            if (_export.logosTooLarge)
              InlineBanner(
                key: const Key('rulePackExportLogosTooLarge'),
                tone: BannerTone.warning,
                message: l10n.rulePackExportLogosTooLarge,
              )
            else
              Text(
                l10n.rulePackExportLogoCount(_export.logoCount),
                key: const Key('rulePackExportLogoCount'),
                style: AppTextStyles.helper,
              ),
          ],
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.rulePackExportContents(pack.rules.length),
            style: AppTextStyles.sectionLabel,
          ),
          const SizedBox(height: AppSpacing.sm - 2),
          // The file itself, not a summary of it: the point of the step is that
          // the user reads what leaves their machine.
          Container(
            key: const Key('rulePackExportPreview'),
            constraints: const BoxConstraints(maxHeight: 220),
            padding: const EdgeInsets.all(AppSpacing.sm + AppSpacing.xs),
            decoration: BoxDecoration(
              color: AppColors.surfaceField,
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(color: AppColors.border),
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
                style: AppTextStyles.mono,
              ),
            ),
          ),
          if (omitted.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.rulePackOmittedLabel(omitted.length),
              style: AppTextStyles.sectionLabel,
            ),
            const SizedBox(height: AppSpacing.sm - 2),
            for (final rule in omitted)
              Padding(
                key: Key('rulePackOmitted-${rule.ruleId}'),
                padding: const EdgeInsets.only(top: 2),
                child: Text(switch (rule.reason) {
                  RuleOmissionReason.regex => l10n.rulePackOmittedRegex(
                    rule.pattern,
                  ),
                  RuleOmissionReason.userCategory =>
                    l10n.rulePackOmittedUserCategory(rule.pattern),
                }, style: AppTextStyles.helper),
              ),
          ],
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}
