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
import '../application/add_to_series_controller.dart';
import '../application/mark_recurring_controller.dart';
import '../application/subscriptions_controller.dart';
import '../domain/recurring_series.dart';
import '../domain/series_preview.dart';
import 'recurring_error_localizer.dart';
import 'recurring_labels.dart';
import 'series_picker.dart';
import 'subscriptions_screen.dart';
import 'transaction_check_row.dart';

/// Opens « Marquer comme récurrent » for [transactionId].
///
/// When the transaction already belongs to a series, the dialog closes as soon
/// as the server says so and the Abonnements panel opens on that series
/// instead: proposing a second one would only end in a conflict. When a series
/// only tracks its merchant, the dialog offers to add the charges it lacks.
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

/// The ticked transactions were saved: as a new series, or added to one.
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

  /// Whether the series picker replaces the preview. Purely which pane the
  /// dialog shows: the picker's own state lives in its controller.
  bool _picking = false;

  void _setPicking(bool picking) => setState(() {
    _picking = picking;
    _errorText = null;
  });

  /// Adds the transaction to [series], which learns its label, and closes.
  Future<void> _pick(RecurringSeries series) async {
    setState(() {
      _isSaving = true;
      _errorText = null;
    });
    try {
      final saved = await ref
          .read(seriesPickerControllerProvider.notifier)
          .pick(series.id, widget.transactionId);
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
      // Nothing left to add: the series already holds this charge.
      if (next.value?.outcome case AlreadyInSeries(
        :final series,
        addable: [],
      )) {
        Navigator.of(context).pop(OpenExistingSeries(series));
      }
    });
    final state = ref.watch(provider);
    final existing = switch (state.value?.outcome) {
      AlreadyInSeries(:final series) => series,
      _ => null,
    };
    final canSave =
        !_isSaving &&
        !state.isLoading &&
        (state.value?.selected.isNotEmpty ?? false);

    if (_picking) {
      return AppModal(
        title: l10n.markRecurringTitle,
        width: 520,
        actions: [
          OutlinedButton(
            key: const Key('seriesPickerBack'),
            onPressed: _isSaving ? null : () => _setPicking(false),
            child: Text(l10n.seriesPickerBack),
          ),
          OutlinedButton(
            key: const Key('markRecurringCancel'),
            onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
            child: Text(l10n.markRecurringCancel),
          ),
        ],
        child: SeriesPickerBody(
          onPick: _pick,
          enabled: !_isSaving,
          errorText: _errorText,
        ),
      );
    }

    return AppModal(
      title: l10n.markRecurringTitle,
      width: 520,
      actions: [
        OutlinedButton(
          key: const Key('markRecurringCancel'),
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.markRecurringCancel),
        ),
        if (existing != null)
          OutlinedButton(
            key: const Key('markRecurringViewSeries'),
            onPressed: _isSaving
                ? null
                : () => Navigator.of(context).pop(OpenExistingSeries(existing)),
            child: Text(l10n.markRecurringViewSeries),
          ),
        PrimaryButton(
          key: const Key('markRecurringSave'),
          label: existing != null
              ? l10n.markRecurringAddToSeries
              : l10n.markRecurringSave,
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
            onPickSeries: () => _setPicking(true),
          ),
        AsyncValue(
          value: MarkRecurringState(
            outcome: AlreadyInSeries(:final series, addable: [_, ...]),
          ),
        )
            when !state.isLoading =>
          _ExistingSeriesBody(
            transactionId: widget.transactionId,
            series: series,
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
    required this.onPickSeries,
  });

  final String transactionId;
  final SeriesPreview preview;
  final MarkRecurringState state;
  final String? errorText;
  final bool enabled;

  /// Opens the series picker, for a charge whose label has nothing in common
  /// with the series it belongs to.
  final VoidCallback onPickSeries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;

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
        _Checklist(
          transactionId: transactionId,
          state: state,
          enabled: enabled,
        ),
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('markRecurringPickSeries'),
            onPressed: enabled ? onPickSeries : null,
            icon: const Icon(
              Icons.playlist_add_rounded,
              size: 16,
              color: AppColors.iris,
            ),
            label: Text(
              l10n.markRecurringPickSeries,
              style: textTheme.labelMedium?.copyWith(color: AppColors.iris),
            ),
          ),
        ),
      ],
    );
  }
}

/// The checklist of candidate transactions and the summary of the ticked ones,
/// shared by the proposal and the add-to-series bodies.
class _Checklist extends ConsumerWidget {
  const _Checklist({
    required this.transactionId,
    required this.state,
    required this.enabled,
  });

  final String transactionId;
  final MarkRecurringState state;
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
                for (final transaction in state.candidates)
                  TransactionCheckRow(
                    tickKey: Key('markRecurringTick-${transaction.id}'),
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

/// A series already tracks this merchant: offer to add the charges it lacks.
class _ExistingSeriesBody extends StatelessWidget {
  const _ExistingSeriesBody({
    required this.transactionId,
    required this.series,
    required this.state,
    required this.errorText,
    required this.enabled,
  });

  final String transactionId;
  final RecurringSeries series;
  final MarkRecurringState state;
  final String? errorText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      key: const Key('markRecurringExisting'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InlineBanner(
          tone: BannerTone.info,
          message: l10n.markRecurringExistingIntro(series.label),
        ),
        const SizedBox(height: AppSpacing.md),
        if (errorText != null) ...[
          InlineBanner(
            key: const Key('markRecurringError'),
            message: errorText!,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        _Checklist(
          transactionId: transactionId,
          state: state,
          enabled: enabled,
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
