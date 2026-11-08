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
import '../application/rule_pack_import_controller.dart';
import '../application/rule_packs_controller.dart';
import '../domain/rule_pack.dart';
import 'rule_error_localizer.dart';
import 'rule_pack_logo_chip.dart';
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
  ConsumerState<RulePackImportSheet> createState() =>
      _RulePackImportSheetState();
}

class _RulePackImportSheetState extends ConsumerState<RulePackImportSheet> {
  bool _applyNow = true;

  // Off by default: a linked logo is fetched from Wikimedia only when the user
  // ticks the box, never as a side effect of importing someone's pack.
  bool _downloadLogos = false;

  RulePackPreview get _preview => widget.pending.preview;

  void _import() {
    ref
        .read(rulePackImportControllerProvider.notifier)
        .start(
          widget.pending,
          applyNow: _applyNow,
          downloadLogos: _downloadLogos,
        );
  }

  /// An import with no logos to download ends as it always did: the sheet
  /// closes on a toast. One that downloaded logos keeps the sheet open, so
  /// its result replaces the progress bar the user was watching.
  void _onStateChanged(
    RulePackImportState? previous,
    RulePackImportState next,
  ) {
    final result = next.result;
    if (result == null || previous?.result != null || next.hasLogoDownloads) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final navigator = Navigator.of(context);
    navigator.pop();
    showAppToast(
      context,
      title: l10n.rulePackImportedTitle(result.createdCount),
      message: _applyNow
          ? l10n.rulePackImportedBody(result.recategorizedCount)
          : l10n.rulesApplyToastBody,
    );
    // The import succeeded either way; the logos that didn't make it (an
    // embedded picture that isn't one) are listed so the user knows which
    // rules still show a monogram, and why.
    if (result.logoFailures.isNotEmpty) {
      showDialog<void>(
        context: navigator.context,
        builder: (_) =>
            RulePackLogoFailuresDialog(failures: result.logoFailures),
      );
    }
  }

  String? _errorText(AppLocalizations l10n, RulePackImportState state) {
    if (state.hasFailed) return l10n.rulePackImportRunFailed;
    if (state.error case final error?) return localizeRuleError(l10n, error);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    ref.listen(rulePackImportControllerProvider, _onStateChanged);
    final state = ref.watch(rulePackImportControllerProvider);
    final errorText = _errorText(l10n, state);

    // The run cannot be cancelled, and closing the sheet would lose its
    // result: the sheet stays until the import ends, unless following it
    // failed — then the user is not held hostage to a run they can't see.
    final canClose = !state.isInFlight || state.error != null;

    if (state.result case final result? when state.hasLogoDownloads) {
      return AppModal(
        title: _preview.name,
        width: 520,
        actions: [
          PrimaryButton(
            key: const Key('rulePackImportDone'),
            label: l10n.rulePackClose,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
        child: _ImportResultView(result: result, appliedNow: _applyNow),
      );
    }

    final isImporting = state.isInFlight;
    return PopScope(
      canPop: canClose,
      child: AppModal(
        title: _preview.name,
        width: 520,
        actions: [
          OutlinedButton(
            key: const Key('rulePackImportCancel'),
            onPressed: canClose ? () => Navigator.of(context).pop() : null,
            child: Text(l10n.rulePackCancel),
          ),
          if (!state.isDownloading)
            PrimaryButton(
              key: const Key('rulePackImportConfirm'),
              label: l10n.rulePackImportConfirm,
              isLoading: isImporting,
              onPressed: isImporting || !_preview.hasAnythingToImport
                  ? null
                  : _import,
            ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (errorText != null) ...[
              InlineBanner(
                key: const Key('rulePackImportError'),
                message: errorText,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            if (state.run case final run? when state.isDownloading)
              _LogoDownloadProgress(run: run)
            else
              ..._form(context, l10n, isImporting),
          ],
        ),
      ),
    );
  }

  List<Widget> _form(
    BuildContext context,
    AppLocalizations l10n,
    bool isImporting,
  ) {
    return [
      // The headline the whole confirmation step exists for.
      InlineBanner(
        key: const Key('rulePackHeadline'),
        tone: BannerTone.info,
        message: l10n.rulePackWouldMatch(_preview.wouldMatchCount),
      ),
      const SizedBox(height: AppSpacing.md),
      RulePackReport(preview: _preview),
      if (widget.pending.pack case final pack? when pack.rules.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.md),
        _PackRulesList(rules: pack.rules),
      ],
      const SizedBox(height: AppSpacing.md),
      if (_preview.linksLogos) ...[
        _LogoDownloadCheckbox(
          value: _downloadLogos,
          label: l10n.rulePackLogoDownload(_preview.logoDownloadCount),
          onChanged: isImporting
              ? null
              : (value) => setState(() => _downloadLogos = value),
        ),
        const SizedBox(height: AppSpacing.xs),
        Padding(
          // Aligned with the label, past the box and its gap.
          padding: const EdgeInsets.only(
            left: 18 + AppSpacing.sm + AppSpacing.xs,
          ),
          child: Text(
            l10n.rulePackLogoDownloadHelper,
            key: const Key('rulePackLogoDownloadHelper'),
            style: AppTextStyles.helper,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
      ],
      Row(
        children: [
          AppToggle(
            key: const Key('rulePackApplyNow'),
            value: _applyNow,
            semanticLabel: l10n.rulePackApplyNowLabel,
            onChanged: isImporting
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
    ];
  }
}

/// The logo downloads, settled out of total, while the run fetches them.
class _LogoDownloadProgress extends StatelessWidget {
  const _LogoDownloadProgress({required this.run});

  final RulePackImportRun run;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      key: const Key('rulePackLogoProgress'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.rulePackLogoProgress(run.logoDone, run.logoTotal),
          key: const Key('rulePackLogoProgressLabel'),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
        Semantics(
          label: l10n.rulePackLogoProgress(run.logoDone, run.logoTotal),
          child: _ProgressBar(fraction: run.logoProgress),
        ),
        const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
        Text(l10n.rulePackLogoProgressNotice, style: AppTextStyles.helper),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }
}

/// The 6px iris-gradient run bar, as the categorization banner draws it
/// (`transactions/presentation/ai_run_banner.dart`); redrawn here rather than
/// imported, since one feature does not reach into another's widgets.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 6,
      decoration: BoxDecoration(
        color: AppColors.surfaceHover,
        borderRadius: BorderRadius.circular(AppRadii.xs),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: fraction.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.irisDeep, AppColors.iris],
            ),
            borderRadius: BorderRadius.circular(AppRadii.xs),
          ),
        ),
      ),
    );
  }
}

/// What an import that downloaded logos did, in the sheet that showed its
/// progress: the same words as the toast an import without logos ends on,
/// then the logos that could not be attached.
class _ImportResultView extends StatelessWidget {
  const _ImportResultView({required this.result, required this.appliedNow});

  final RulePackImportResult result;
  final bool appliedNow;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      key: const Key('rulePackImportResult'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InlineBanner(
          key: const Key('rulePackImportedBanner'),
          tone: BannerTone.success,
          message: l10n.rulePackImportedTitle(result.createdCount),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          appliedNow
              ? l10n.rulePackImportedBody(result.recategorizedCount)
              : l10n.rulesApplyToastBody,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (result.logoFailures.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.rulePackLogoFailuresTitle(result.logoFailures.length),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          RulePackLogoFailuresList(failures: result.logoFailures),
        ],
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }
}

/// The pack's rules, each behind its logo or monogram, so the user sees what
/// the pack brings rule by rule and not only as counts.
class _PackRulesList extends StatelessWidget {
  const _PackRulesList({required this.rules});

  final List<RulePackEntry> rules;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.rulePackRulesLabel, style: AppTextStyles.sectionLabel),
        const SizedBox(height: AppSpacing.sm - 2),
        ConstrainedBox(
          // A pack can hold up to a thousand rules: the list scrolls inside a
          // bounded plate instead of stretching the sheet.
          constraints: const BoxConstraints(maxHeight: 200),
          child: ListView.builder(
            key: const Key('rulePackRulesList'),
            shrinkWrap: true,
            itemCount: rules.length,
            itemBuilder: (context, index) {
              final rule = rules[index];
              return Padding(
                key: Key('rulePackRule-$index'),
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    RulePackLogoChip(entry: rule),
                    const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
                    Expanded(
                      child: Text(
                        rule.pattern,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.mono,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// The gradient checkbox the rules modals draw (see `always_categorize_modal`).
/// Material's [Checkbox] paints a flat fill and carries touch-sized padding,
/// neither of which matches the spec.
class _LogoDownloadCheckbox extends StatelessWidget {
  const _LogoDownloadCheckbox({
    required this.value,
    required this.label,
    required this.onChanged,
  });

  final bool value;
  final String label;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;

    return MouseRegion(
      cursor: onChanged == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      child: GestureDetector(
        key: const Key('rulePackDownloadLogos'),
        onTap: onChanged == null ? null : () => onChanged(!value),
        behavior: HitTestBehavior.opaque,
        child: Row(
          children: [
            Semantics(
              checked: value,
              label: label,
              child: Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: value ? AppColors.irisGradient : null,
                  color: value ? null : AppColors.surfaceField,
                  borderRadius: BorderRadius.circular(AppRadii.xs + 1),
                  border: Border.all(
                    color: value ? Colors.transparent : AppColors.border,
                  ),
                ),
                child: value
                    ? const Icon(
                        Icons.check_rounded,
                        size: 13,
                        color: AppColors.irisInk,
                      )
                    : null,
              ),
            ),
            const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
            Flexible(
              child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
            ),
          ],
        ),
      ),
    );
  }
}

/// The logos an import could not attach, each with its reason.
///
/// Shown after the import has already succeeded: the banner says so first, so
/// the list reads as a footnote to a done import rather than as a failure.
class RulePackLogoFailuresDialog extends StatelessWidget {
  const RulePackLogoFailuresDialog({super.key, required this.failures});

  final List<RulePackLogoFailure> failures;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AppModal(
      title: l10n.rulePackLogoFailuresTitle(failures.length),
      width: 480,
      actions: [
        PrimaryButton(
          key: const Key('rulePackLogoFailuresClose'),
          label: l10n.rulePackClose,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InlineBanner(
            key: const Key('rulePackLogoFailuresNotice'),
            tone: BannerTone.info,
            message: l10n.rulePackLogoFailuresNotice,
          ),
          const SizedBox(height: AppSpacing.md),
          RulePackLogoFailuresList(failures: failures),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}

/// Each logo an import could not attach, with its reason.
class RulePackLogoFailuresList extends StatelessWidget {
  const RulePackLogoFailuresList({super.key, required this.failures});

  final List<RulePackLogoFailure> failures;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final failure in failures)
          Padding(
            key: Key('rulePackLogoFailure-${failure.index}'),
            padding: const EdgeInsets.only(top: 2),
            child: Text(switch (failure.reason) {
              RulePackLogoFailureReason.invalidImage =>
                l10n.rulePackLogoFailureInvalidImage(failure.pattern),
              RulePackLogoFailureReason.tooLarge =>
                l10n.rulePackLogoFailureTooLarge(failure.pattern),
              RulePackLogoFailureReason.downloadFailed =>
                l10n.rulePackLogoFailureDownloadFailed(failure.pattern),
            }, style: AppTextStyles.helper),
          ),
      ],
    );
  }
}
