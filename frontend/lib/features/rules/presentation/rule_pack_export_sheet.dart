import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_modal.dart';
import '../../../core/widgets/app_toast.dart';
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
    final export = await ref.read(rulePacksControllerProvider.notifier).prepareExport();
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
  ConsumerState<RulePackExportSheet> createState() => _RulePackExportSheetState();
}

class _RulePackExportSheetState extends ConsumerState<RulePackExportSheet> {
  bool _isSaving = false;
  String? _errorText;

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isSaving = true;
      _errorText = null;
    });
    try {
      final path = await ref
          .read(rulePacksControllerProvider.notifier)
          .saveExport(widget.export.pack);
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
    final pack = widget.export.pack;
    final omitted = widget.export.omitted;

    return AppModal(
      title: l10n.rulePackExportTitle,
      width: 520,
      actions: [
        OutlinedButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.rulePackCancel),
        ),
        PrimaryButton(
          key: const Key('rulePackExportSave'),
          label: l10n.rulePackExportSave,
          isLoading: _isSaving,
          onPressed: _isSaving ? null : _save,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_errorText != null) ...[
            InlineBanner(key: const Key('rulePackExportError'), message: _errorText!),
            const SizedBox(height: AppSpacing.md),
          ],
          InlineBanner(
            key: const Key('rulePackPrivacyNotice'),
            tone: BannerTone.warning,
            message: l10n.rulePackExportPrivacyNotice,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(l10n.rulePackExportContents(pack.rules.length), style: AppTextStyles.sectionLabel),
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
              child: SelectableText(pack.toPrettyJson(), style: AppTextStyles.mono),
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
                child: Text(
                  switch (rule.reason) {
                    RuleOmissionReason.regex => l10n.rulePackOmittedRegex(rule.pattern),
                    RuleOmissionReason.userCategory => l10n.rulePackOmittedUserCategory(
                      rule.pattern,
                    ),
                  },
                  style: AppTextStyles.helper,
                ),
              ),
          ],
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}
