import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
import 'rule_pack_report.dart';

/// Runs the import flow end to end: choose a source, read what it would do,
/// and only then offer to write it.
///
/// The preview is not optional and not skippable. Importing straight from the
/// file picker would ask the user to accept a stranger's rules sight unseen,
/// and the count is the only thing that makes that judgement possible.
Future<void> startRulePackImport(
  BuildContext context,
  WidgetRef ref, {
  String? builtinId,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final controller = ref.read(rulePacksControllerProvider.notifier);

  PendingRulePack? pending;
  try {
    pending = builtinId == null
        ? await controller.pickForImport()
        : await controller.previewBuiltin(builtinId);
  } on RulePackRejected catch (rejected) {
    if (!context.mounted) return;
    await _showRefusal(context, rejected.reason);
    return;
  } catch (error) {
    if (!context.mounted) return;
    showAppToast(
      context,
      title: l10n.rulePackImportFailed,
      message: localizeRuleError(l10n, error),
      tone: BannerTone.error,
    );
    return;
  }

  if (pending == null || !context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (_) => RulePackImportSheet(pending: pending!),
  );
}

/// Explains why a file was turned away, in the terms the refusal was made in —
/// never as a generic failure. The user has to act on this (pick another file,
/// or edit this one), and « une erreur est survenue » tells them nothing about
/// which.
Future<void> _showRefusal(BuildContext context, RulePackRefusal reason) {
  final l10n = AppLocalizations.of(context)!;
  final message = switch (reason) {
    RulePackRefusal.malformed => l10n.rulePackRefusedMalformed,
    RulePackRefusal.unsupportedVersion => l10n.rulePackRefusedVersion(
      rulePackFormatVersion,
    ),
    RulePackRefusal.regexNotAllowed => l10n.rulePackRefusedRegex,
  };

  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AppModal(
      title: l10n.rulePackRefusedTitle,
      width: 480,
      actions: [
        PrimaryButton(
          label: l10n.rulePackClose,
          onPressed: () => Navigator.of(dialogContext).pop(),
        ),
      ],
      child: InlineBanner(
        key: const Key('rulePackRefusal'),
        tone: BannerTone.warning,
        message: message,
      ),
    ),
  );
}

/// The confirmation sheet: the pack's report, then the choice to import it.
class RulePackImportSheet extends ConsumerStatefulWidget {
  const RulePackImportSheet({super.key, required this.pending});

  final PendingRulePack pending;

  @override
  ConsumerState<RulePackImportSheet> createState() => _RulePackImportSheetState();
}

class _RulePackImportSheetState extends ConsumerState<RulePackImportSheet> {
  bool _applyNow = true;
  bool _isImporting = false;
  String? _errorText;

  RulePackPreview get _preview => widget.pending.preview;

  Future<void> _import() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isImporting = true;
      _errorText = null;
    });
    try {
      final result = await ref
          .read(rulePacksControllerProvider.notifier)
          .import(widget.pending, applyNow: _applyNow);
      if (!mounted) return;
      Navigator.of(context).pop();
      showAppToast(
        context,
        title: l10n.rulePackImportedTitle(result.createdCount),
        message: _applyNow
            ? l10n.rulePackImportedBody(result.recategorizedCount)
            : l10n.rulesApplyToastBody,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isImporting = false;
        _errorText = localizeRuleError(l10n, error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AppModal(
      title: _preview.name,
      width: 520,
      actions: [
        OutlinedButton(
          onPressed: _isImporting ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.rulePackCancel),
        ),
        PrimaryButton(
          key: const Key('rulePackImportConfirm'),
          label: l10n.rulePackImportConfirm,
          isLoading: _isImporting,
          onPressed: _isImporting || _preview.newCount == 0 ? null : _import,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_errorText != null) ...[
            InlineBanner(key: const Key('rulePackImportError'), message: _errorText!),
            const SizedBox(height: AppSpacing.md),
          ],
          // The headline the whole confirmation step exists for.
          InlineBanner(
            key: const Key('rulePackHeadline'),
            tone: BannerTone.info,
            message: l10n.rulePackWouldMatch(_preview.wouldMatchCount),
          ),
          const SizedBox(height: AppSpacing.md),
          RulePackReport(preview: _preview),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              AppToggle(
                key: const Key('rulePackApplyNow'),
                value: _applyNow,
                semanticLabel: l10n.rulePackApplyNowLabel,
                onChanged: _isImporting
                    ? null
                    : (value) => setState(() => _applyNow = value),
              ),
              const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
              Expanded(
                child: Text(
                  l10n.rulePackApplyNowLabel,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}
