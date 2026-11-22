import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_checkbox.dart';
import '../../../core/widgets/app_modal.dart';
import '../../../core/widgets/app_table.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../core/widgets/monogram_avatar.dart';
import '../../../core/widgets/note_line.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/repere_meter.dart';
import '../../../l10n/app_localizations.dart';
import '../../categories/application/categories_controller.dart';
import '../../categories/domain/category.dart';
import '../application/rule_pack_import_controller.dart';
import '../application/rule_packs_controller.dart';
import '../domain/rule_pack.dart';
import 'rule_error_localizer.dart';
import 'rule_pack_logo_chip.dart';
import 'rule_pack_report.dart';
import 'rule_row.dart';

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
    await showAppModal<void>(
      context: context,
      builder: (_) => RulePackRefusedModal(reason: rejected.reason),
    );
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
  await showAppModal<void>(
    context: context,
    builder: (_) => RulePackImportSheet(pending: pending!),
  );
}

/// « Ce fichier n’a pas été accepté » (`08-categories-rules.md` §Other
/// modals, proposal v6 `m-rules`), 480 px: an acknowledgement whose banner
/// says why the file was turned away, in the terms the refusal was made in
/// and never as a generic failure. The user has to act on this (pick another
/// file, or edit this one), and « une erreur est survenue » tells them
/// nothing about which.
class RulePackRefusedModal extends StatelessWidget {
  const RulePackRefusedModal({super.key, required this.reason});

  final RulePackRefusal reason;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final message = switch (reason) {
      RulePackRefusal.malformed => l10n.rulePackRefusedMalformed,
      RulePackRefusal.unsupportedVersion => l10n.rulePackRefusedVersion(
        rulePackFormatVersion,
      ),
      RulePackRefusal.regexNotAllowed => l10n.rulePackRefusedRegex,
    };
    return AppModal(
      key: const Key('rulePackRefusedModal'),
      title: l10n.rulePackRefusedTitle,
      width: AppModalSizes.w480,
      kind: AppModalKind.acknowledgement,
      actions: const [AppModalClose(key: Key('rulePackRefusedClose'))],
      child: InlineBanner(
        key: const Key('rulePackRefusal'),
        tone: BannerTone.error,
        message: message,
      ),
    );
  }
}

/// The import modal, 560 px (`docs/design/08` §Rule packs, proposal v6
/// `m-rules`), titled with the pack's name: the pack's report, its rules on
/// the standard table, then the choice to import it. While the run downloads
/// logos, the body gives way to their progress.
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

  /// Every import ends the same way, whether or not it downloaded logos: the
  /// modal closes on a toast, and the logos that didn't make it follow in
  /// their own acknowledgement.
  void _onStateChanged(
    RulePackImportState? previous,
    RulePackImportState next,
  ) {
    final result = next.result;
    if (result == null || previous?.result != null) return;
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
    // embedded picture that isn't one, a download that failed) are listed so
    // the user knows which rules still show a monogram, and why.
    if (result.logoFailures.isNotEmpty) {
      showAppModal<void>(
        context: navigator.context,
        builder: (_) =>
            RulePackLogoFailuresModal(failures: result.logoFailures),
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

    // The run cannot be cancelled, and closing the modal would lose its
    // result: it stays until the import ends, unless following it failed;
    // then the user is not held hostage to a run they can't see.
    final canClose = !state.isInFlight || state.error != null;
    final downloading = state.isDownloading && state.error == null;

    return AppModal(
      key: const Key('rulePackImportModal'),
      title: _preview.name,
      width: AppCategoriesPanel.packModalWidth,
      // The rules are being written: the form is locked and « Importer »
      // spins. The logo downloads that follow show their own progress.
      busy: state.isInFlight && !downloading && state.error == null,
      saveError: _errorText(l10n, state),
      onCancel: canClose ? null : () {},
      actions: [
        if (canClose)
          const AppModalCancel(key: Key('rulePackImportCancel'))
        else
          AppButton(
            key: const Key('rulePackImportCancel'),
            label: l10n.modalCancel,
            onPressed: null,
          ),
        if (!downloading)
          PrimaryButton(
            key: const Key('rulePackImportConfirm'),
            label: l10n.rulePackImportConfirm,
            isLoading: state.isInFlight,
            onPressed: state.isInFlight || !_preview.hasAnythingToImport
                ? null
                : _import,
          ),
      ],
      child: switch (state.run) {
        final run? when downloading => _LogoDownloadProgress(run: run),
        _ => _form(l10n, state.isInFlight),
      },
    );
  }

  Widget _form(AppLocalizations l10n, bool isImporting) {
    const gap = SizedBox(height: AppSpacing.fieldGap);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The headline the whole confirmation step exists for.
        NoteLine(
          key: const Key('rulePackHeadline'),
          icon: LucideIcons300.listChecks,
          text: l10n.rulePackWouldMatch(_preview.wouldMatchCount),
        ),
        gap,
        RulePackReport(preview: _preview),
        if (widget.pending.pack case final pack?
            when pack.rules.isNotEmpty) ...[
          gap,
          _PackRulesTable(rules: pack.rules),
        ],
        gap,
        if (_preview.linksLogos) ...[
          _LabeledCheckbox(
            key: const Key('rulePackDownloadLogos'),
            value: _downloadLogos,
            label: l10n.rulePackLogoDownload(_preview.logoDownloadCount),
            onChanged: isImporting
                ? null
                : (value) => setState(() => _downloadLogos = value),
          ),
          const SizedBox(height: AppSpacing.xs),
          Padding(
            // Aligned with the label, past the box and its gap.
            padding: const EdgeInsetsDirectional.only(
              start: AppCheckbox.size + AppSpacing.sm,
            ),
            child: Text(
              l10n.rulePackLogoDownloadHelper,
              key: const Key('rulePackLogoDownloadHelper'),
              style: context.textStyles.helper,
            ),
          ),
          gap,
        ],
        _LabeledCheckbox(
          key: const Key('rulePackApplyNow'),
          value: _applyNow,
          label: l10n.rulePackApplyNowLabel,
          onChanged: isImporting
              ? null
              : (value) => setState(() => _applyNow = value),
        ),
      ],
    );
  }
}

/// The logo downloads, settled out of total, while the run fetches them: the
/// count over a meter, and the note that the rules are already in.
class _LogoDownloadProgress extends StatelessWidget {
  const _LogoDownloadProgress({required this.run});

  final RulePackImportRun run;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final progress = l10n.rulePackLogoProgress(run.logoDone, run.logoTotal);

    return Column(
      key: const Key('rulePackLogoProgress'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          progress,
          key: const Key('rulePackLogoProgressLabel'),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        RepereMeter(fraction: run.logoProgress, semanticLabel: progress),
        const SizedBox(height: AppSpacing.fieldGap),
        NoteLine(text: l10n.rulePackLogoProgressNotice),
      ],
    );
  }
}

/// The columns of the pack's rule table: the 22 px logo or monogram, the
/// pattern, the target category on the right.
const _packRuleColumns = [
  AppTableColumn(label: '', width: MonogramAvatar.small),
  AppTableColumn(label: ''),
  AppTableColumn(label: '', numeric: true),
];

/// « Règles du pack »: each rule on the standard table without a header,
/// behind its logo or monogram, so the user sees what the pack brings rule
/// by rule and not only as counts.
class _PackRulesTable extends ConsumerWidget {
  const _PackRulesTable({required this.rules});

  final List<RulePackEntry> rules;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final categories =
        ref.watch(categoriesControllerProvider).value ?? const <AppCategory>[];
    // A pack names system categories by their key, which is what a system
    // category stores as its name.
    final byKey = {
      for (final category in categories)
        if (category.isSystem) category.name: category,
    };
    final byId = {for (final category in categories) category.id: category};

    return Column(
      key: const Key('rulePackRulesList'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.rulePackRulesLabel,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: context.colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.fieldGap),
        for (final (index, rule) in rules.indexed)
          AppTableRow(
            key: Key('rulePackRule-$index'),
            columns: _packRuleColumns,
            cells: [
              RulePackLogoChip(entry: rule, size: MonogramAvatar.small),
              Text(
                rule.pattern,
                overflow: TextOverflow.ellipsis,
                style: context.textStyles.mono.copyWith(
                  color: context.colors.text,
                ),
              ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: switch (byKey[rule.categoryKey]) {
                  final category? => RuleTargetLabel(
                    category: category,
                    parent: byId[category.parentId],
                  ),
                  null => RuleTargetLabel(category: null, parent: null),
                },
              ),
            ],
          ),
      ],
    );
  }
}

/// The standard checkbox and its label, both toggling the choice.
class _LabeledCheckbox extends StatelessWidget {
  const _LabeledCheckbox({
    super.key,
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
        onTap: onChanged == null ? null : () => onChanged(!value),
        behavior: HitTestBehavior.opaque,
        child: Row(
          children: [
            AppCheckbox(
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

/// « N logos n’ont pas pu être ajoutés » (`08-categories-rules.md` §Other
/// modals, proposal v6 `m-rules`), 480 px: an acknowledgement shown after the
/// import has already succeeded. The banner says so first, so the list reads
/// as a footnote to a done import rather than as a failure.
class RulePackLogoFailuresModal extends StatelessWidget {
  const RulePackLogoFailuresModal({super.key, required this.failures});

  final List<RulePackLogoFailure> failures;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AppModal(
      key: const Key('rulePackLogoFailuresModal'),
      title: l10n.rulePackLogoFailuresTitle(failures.length),
      width: AppModalSizes.w480,
      kind: AppModalKind.acknowledgement,
      actions: const [AppModalClose(key: Key('rulePackLogoFailuresClose'))],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InlineBanner(
            key: const Key('rulePackLogoFailuresNotice'),
            tone: BannerTone.warning,
            message: l10n.rulePackLogoFailuresNotice,
          ),
          const SizedBox(height: AppSpacing.fieldGap),
          for (final (i, failure) in failures.indexed) ...[
            if (i > 0) const SizedBox(height: AppSpacing.xsPlus),
            NoteLine(
              key: Key('rulePackLogoFailure-${failure.index}'),
              icon: LucideIcons300.circleX,
              text: switch (failure.reason) {
                RulePackLogoFailureReason.invalidImage =>
                  l10n.rulePackLogoFailureInvalidImage(failure.pattern),
                RulePackLogoFailureReason.tooLarge =>
                  l10n.rulePackLogoFailureTooLarge(failure.pattern),
                RulePackLogoFailureReason.downloadFailed =>
                  l10n.rulePackLogoFailureDownloadFailed(failure.pattern),
              },
            ),
          ],
        ],
      ),
    );
  }
}
