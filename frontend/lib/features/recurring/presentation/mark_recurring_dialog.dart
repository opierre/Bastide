import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/app_modal.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../application/mark_recurring_controller.dart';
import '../application/subscriptions_controller.dart';
import '../domain/recurring_series.dart';
import '../domain/series_preview.dart';
import 'recurring_error_localizer.dart';
import 'recurring_labels.dart';
import 'subscriptions_screen.dart';

/// Opens « Marquer comme récurrent » for [transactionId].
///
/// When the transaction already belongs to a series, the dialog closes as soon
/// as the server says so and the Abonnements panel opens on that series
/// instead: proposing a second one would only end in a conflict.
Future<void> showMarkRecurringDialog(
  BuildContext context,
  WidgetRef ref, {
  required String transactionId,
}) async {
  final result = await showDialog<MarkRecurringResult>(
    context: context,
    builder: (_) => MarkRecurringDialog(transactionId: transactionId),
  );
  if (result is! OpenExistingSeries || !context.mounted) return;
  ref.read(selectedSeriesProvider.notifier).open(result.series.id);
  context.go(SubscriptionsScreen.path);
}

/// How the dialog closed, when it did not simply get cancelled.
sealed class MarkRecurringResult {
  const MarkRecurringResult(this.series);

  final RecurringSeries series;
}

/// A new series was saved from the ticked transactions.
final class SeriesSaved extends MarkRecurringResult {
  const SeriesSaved(super.series);
}

/// The transaction was already in [series]; the caller opens it.
final class OpenExistingSeries extends MarkRecurringResult {
  const OpenExistingSeries(super.series);
}

/// The 520 px preview dialog: the matching transactions as a checklist, the
/// confidence chip with its reasons, and the proposed cadence and amount.
class MarkRecurringDialog extends ConsumerStatefulWidget {
  const MarkRecurringDialog({super.key, required this.transactionId});

  final String transactionId;

  @override
  ConsumerState<MarkRecurringDialog> createState() =>
      _MarkRecurringDialogState();
}

class _MarkRecurringDialogState extends ConsumerState<MarkRecurringDialog> {
  bool _isSaving = false;
  String? _errorText;

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
      _errorText = null;
    });
    try {
      final saved = await ref
          .read(markRecurringControllerProvider(widget.transactionId).notifier)
          .save();
      if (!mounted) return;
      Navigator.of(context).pop(SeriesSaved(saved));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorText = localizeRecurringError(
          AppLocalizations.of(context)!,
          error,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = markRecurringControllerProvider(widget.transactionId);
    ref.listen(provider, (_, next) {
      if (next.value?.outcome case AlreadyInSeries(:final series)) {
        Navigator.of(context).pop(OpenExistingSeries(series));
      }
    });
    final state = ref.watch(provider);
    final canSave =
        !_isSaving &&
        (state.value?.outcome is Proposal) &&
        (state.value?.selected.isNotEmpty ?? false);

    return AppModal(
      title: l10n.markRecurringTitle,
      width: 520,
      actions: [
        OutlinedButton(
          key: const Key('markRecurringCancel'),
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.markRecurringCancel),
        ),
        PrimaryButton(
          key: const Key('markRecurringSave'),
          label: l10n.markRecurringSave,
          isLoading: _isSaving,
          onPressed: canSave ? _save : null,
        ),
      ],
      child: switch (state) {
        AsyncValue(hasError: true) when !state.isLoading => ErrorStateView(
          message: l10n.markRecurringLoadError,
          retryLabel: l10n.markRecurringRetry,
          retryKey: const Key('markRecurringRetry'),
          onRetry: () => ref.invalidate(provider),
        ),
        AsyncValue(
          value: MarkRecurringState(outcome: Proposal(:final preview)),
        )
            when !state.isLoading =>
          _ProposalBody(
            transactionId: widget.transactionId,
            preview: preview,
            state: state.requireValue,
            errorText: _errorText,
            enabled: !_isSaving,
          ),
        _ => const _LoadingBody(),
      },
    );
  }
}

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      key: Key('markRecurringLoading'),
      height: 160,
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: AppColors.iris,
          ),
        ),
      ),
    );
  }
}

class _ProposalBody extends ConsumerWidget {
  const _ProposalBody({
    required this.transactionId,
    required this.preview,
    required this.state,
    required this.errorText,
    required this.enabled,
  });

  final String transactionId;
  final SeriesPreview preview;
  final MarkRecurringState state;
  final String? errorText;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toString();
    final dates = seriesDateFormat(locale);
    final selected = state.selected;
    final controller = ref.read(
      markRecurringControllerProvider(transactionId).notifier,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.markRecurringIntro,
          style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.md),
        if (errorText != null) ...[
          InlineBanner(
            key: const Key('markRecurringError'),
            message: errorText!,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        Row(
          children: [
            _ConfidenceChip(confidence: preview.confidence),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                preview.label,
                style: textTheme.titleSmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          key: const Key('markRecurringReasons'),
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            for (final reason in preview.reasons)
              Text(
                _reasonLabel(l10n, reason, preview.transactions.length),
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
        if (preview.confidence == PreviewConfidence.low) ...[
          const SizedBox(height: AppSpacing.md),
          InlineBanner(
            key: const Key('markRecurringLowWarning'),
            tone: BannerTone.warning,
            message: l10n.markRecurringLowWarning,
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _SummaryFigure(
                label: l10n.markRecurringCadenceLabel,
                child: Text(
                  cadenceLabel(l10n, preview.cadence),
                  style: textTheme.bodyMedium,
                ),
              ),
            ),
            Expanded(
              child: _SummaryFigure(
                label: l10n.markRecurringAmountLabel,
                child: AmountText(
                  amountMinor: preview.expectedAmountMinor,
                  currency: preview.currency,
                  style: textTheme.bodyMedium!,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 260),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceField,
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(color: AppColors.border),
            ),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              children: [
                for (final transaction in preview.transactions)
                  _TransactionCheckRow(
                    transaction: transaction,
                    date: dates.format(transaction.bookedDate),
                    ticked: state.ticked.contains(transaction.id),
                    onChanged: enabled
                        ? () => controller.toggle(transaction.id)
                        : null,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
        Wrap(
          key: const Key('markRecurringSummary'),
          spacing: AppSpacing.sm,
          children: [
            if (selected.isEmpty)
              Text(
                l10n.markRecurringNoneTicked,
                style: textTheme.bodySmall?.copyWith(color: AppColors.warning),
              )
            else ...[
              Text(
                l10n.markRecurringTickedCount(selected.length),
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              if (selected.length > 1)
                Text(
                  l10n.markRecurringTickedRange(
                    dates.format(selected.first.bookedDate),
                    dates.format(selected.last.bookedDate),
                  ),
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ],
        ),
      ],
    );
  }
}

String _reasonLabel(
  AppLocalizations l10n,
  PreviewReason reason,
  int count,
) => switch (reason) {
  PreviewReason.occurrences => l10n.markRecurringReasonOccurrences(count),
  PreviewReason.cadenceWeekly => l10n.markRecurringReasonCadenceWeekly,
  PreviewReason.cadenceMonthly => l10n.markRecurringReasonCadenceMonthly,
  PreviewReason.cadenceQuarterly => l10n.markRecurringReasonCadenceQuarterly,
  PreviewReason.cadenceYearly => l10n.markRecurringReasonCadenceYearly,
  PreviewReason.amountStable => l10n.markRecurringReasonAmountStable,
  PreviewReason.amountChanged => l10n.markRecurringReasonAmountChanged,
  PreviewReason.amountOutsideTolerance =>
    l10n.markRecurringReasonAmountOutsideTolerance,
  PreviewReason.gapOutsideTolerance =>
    l10n.markRecurringReasonGapOutsideTolerance,
  PreviewReason.tooFewOccurrences => l10n.markRecurringReasonTooFewOccurrences,
  PreviewReason.noRhythm => l10n.markRecurringReasonNoRhythm,
};

/// Confidence as a tinted chip whose glyph repeats the hue's meaning, so the
/// level never rests on color alone. Low is amber, not red: the user may still
/// save, the dialog only says the app could not find a rhythm.
class _ConfidenceChip extends StatelessWidget {
  const _ConfidenceChip({required this.confidence});

  final PreviewConfidence confidence;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final (label, color, icon) = switch (confidence) {
      PreviewConfidence.high => (
        l10n.markRecurringConfidenceHigh,
        AppColors.positive,
        Icons.check_circle_outline_rounded,
      ),
      PreviewConfidence.medium => (
        l10n.markRecurringConfidenceMedium,
        AppColors.info,
        Icons.adjust_rounded,
      ),
      PreviewConfidence.low => (
        l10n.markRecurringConfidenceLow,
        AppColors.warning,
        Icons.warning_amber_rounded,
      ),
    };
    return AppChip(
      key: const Key('markRecurringConfidence'),
      label: label,
      color: color,
      icon: icon,
    );
  }
}

class _SummaryFigure extends StatelessWidget {
  const _SummaryFigure({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 2),
        child,
      ],
    );
  }
}

/// One checklist line: the gradient checkbox the rule modal draws, the date,
/// the label and the signed amount.
class _TransactionCheckRow extends StatelessWidget {
  const _TransactionCheckRow({
    required this.transaction,
    required this.date,
    required this.ticked,
    required this.onChanged,
  });

  final PreviewTransaction transaction;
  final String date;
  final bool ticked;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return MouseRegion(
      cursor: onChanged == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      child: GestureDetector(
        key: Key('markRecurringTick-${transaction.id}'),
        onTap: onChanged,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm + AppSpacing.xs,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Semantics(
                checked: ticked,
                label: transaction.label,
                child: Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: ticked ? AppColors.irisGradient : null,
                    color: ticked ? null : AppColors.surfaceField,
                    borderRadius: BorderRadius.circular(AppRadii.xs + 1),
                    border: Border.all(
                      color: ticked ? Colors.transparent : AppColors.border,
                    ),
                  ),
                  child: ticked
                      ? const Icon(
                          Icons.check_rounded,
                          size: 13,
                          color: AppColors.irisInk,
                        )
                      : null,
                ),
              ),
              const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
              SizedBox(
                width: 90,
                child: Text(
                  date,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  transaction.label,
                  style: textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              AmountText(
                amountMinor: transaction.amountMinor,
                currency: transaction.currency,
                style: textTheme.bodyMedium!,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
