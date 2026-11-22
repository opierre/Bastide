import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../../core/l10n/date_display.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/app_modal.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../core/widgets/modal_parts.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/status_text.dart';
import '../../../l10n/app_localizations.dart';
import '../application/add_to_series_controller.dart';
import '../application/mark_recurring_controller.dart';
import '../application/open_series.dart';
import '../application/subscriptions_controller.dart';
import '../domain/recurring_series.dart';
import '../domain/series_preview.dart';
import 'recurring_error_localizer.dart';
import 'recurring_labels.dart';
import 'recurring_modal_parts.dart';
import 'series_picker.dart';
import 'subscriptions_screen.dart';

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
  final result = await showAppModal<MarkRecurringResult>(
    context: context,
    builder: (_) => MarkRecurringDialog(transactionId: transactionId),
  );
  if (result is! OpenExistingSeries || !context.mounted) return;
  ref.read(selectedSeriesProvider.notifier).open(result.series.id);
  context.go(SubscriptionsScreen.path);
}

/// Opens the Abonnements panel on [seriesId], a series a transaction row
/// points at. When the series was deleted since the row loaded, stays put and
/// says so in a toast instead; the row then reloads unmarked.
Future<void> openRecurringSeries(
  BuildContext context,
  WidgetRef ref, {
  required String seriesId,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final opened = await ref.read(seriesOpenerProvider).open(seriesId);
  if (!context.mounted) return;
  if (opened) {
    context.go(SubscriptionsScreen.path);
    return;
  }
  showAppToast(
    context,
    title: l10n.recurringSeriesGoneTitle,
    message: l10n.recurringSeriesGoneMessage,
    tone: BannerTone.warning,
  );
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

/// The 520 px « Marquer comme récurrent » modal (`docs/design/10` § Other
/// modals, `proposal_v6` `m-subscriptions`), in each of its variants:
///
/// - the preview: the series name with its confidence as status text, the
///   reasons on one line, the proposed cadence and amount, the checkable
///   charges with their summary, and the « Ajouter à une série existante… »
///   link; low confidence says so in the status text alone, no banner;
/// - a merchant already tracked: the lead names the series, the body lists
///   the charges it lacks and links to it;
/// - the series picker, with « Retour à l’aperçu » as the left ghost action;
/// - the loading silhouette and the load error, both without a lead.
class MarkRecurringDialog extends ConsumerStatefulWidget {
  const MarkRecurringDialog({super.key, required this.transactionId});

  final String transactionId;

  @override
  ConsumerState<MarkRecurringDialog> createState() =>
      _MarkRecurringDialogState();
}

class _MarkRecurringDialogState extends ConsumerState<MarkRecurringDialog> {
  bool _isSaving = false;
  String? _saveError;

  /// Whether the series picker replaces the preview. Purely which pane the
  /// dialog shows: the picker's own state lives in its controller.
  bool _picking = false;

  void _setPicking(bool picking) => setState(() {
    _picking = picking;
    _saveError = null;
  });

  /// Adds the transaction to [series], which learns its label, and closes.
  /// Either way a toast says how it went; on a failure the dialog stays open
  /// so the user can pick another series or cancel.
  Future<void> _confirm(RecurringSeries series) async {
    if (_isSaving) return;
    final l10n = AppLocalizations.of(context)!;
    // Looked up now: the toast outlives the dialog, whose context is gone by
    // the time a success is due.
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    setState(() {
      _isSaving = true;
      _saveError = null;
    });
    try {
      final saved = await ref
          .read(seriesPickerControllerProvider.notifier)
          .pick(series.id, widget.transactionId);
      if (overlay != null && overlay.mounted) {
        showAppToastOn(overlay, title: l10n.seriesPickerAdded(saved.label));
      }
      if (!mounted) return;
      Navigator.of(context).pop(SeriesSaved(saved));
    } catch (error) {
      if (overlay != null && overlay.mounted) {
        showAppToastOn(
          overlay,
          title: l10n.seriesPickerAddFailed,
          message: localizeRecurringError(l10n, error),
          tone: BannerTone.error,
        );
      }
      if (!mounted) return;
      setState(() => _isSaving = false);
    }
  }

  Future<void> _save() async {
    if (_isSaving) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isSaving = true;
      _saveError = null;
    });
    try {
      final saved = await ref
          .read(markRecurringControllerProvider(widget.transactionId).notifier)
          .save();
      if (!mounted) return;
      Navigator.of(context).pop(SeriesSaved(saved));
    } catch (error) {
      if (!mounted) return;
      // The ticks stay as they were; the frame shows the banner.
      setState(() {
        _isSaving = false;
        _saveError = localizeRecurringError(l10n, error);
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

    if (_picking) return _pickerModal(l10n);

    final state = ref.watch(provider);
    final loaded = state.isLoading ? null : state.value;
    final failed = !state.isLoading && state.hasError;
    final existing = switch (loaded?.outcome) {
      AlreadyInSeries(:final series) => series,
      _ => null,
    };
    final canSave = !_isSaving && (loaded?.selected.isNotEmpty ?? false);

    return AppModal(
      key: const Key('markRecurringModal'),
      title: l10n.markRecurringTitle,
      // The lead describes the body, so the loading silhouette and the load
      // error go without one (`proposal_v6` `m-frame`, États).
      subtitle: switch (loaded?.outcome) {
        Proposal() => Text(l10n.markRecurringIntro),
        AlreadyInSeries(:final series) => Text(
          l10n.markRecurringExistingIntro(series.label),
        ),
        null => null,
      },
      width: AppModalSizes.w520,
      // Unticking a proposed charge is the user's input.
      dirty: loaded != null && loaded.ticked.length != loaded.candidates.length,
      busy: _isSaving,
      saveError: _saveError,
      actions: [
        const AppModalCancel(key: Key('markRecurringCancel')),
        PrimaryButton(
          key: const Key('markRecurringSave'),
          label: existing != null
              ? l10n.markRecurringAddToSeries
              : l10n.markRecurringSave,
          isLoading: _isSaving,
          onPressed: canSave ? _save : null,
        ),
      ],
      child: switch (loaded) {
        _ when failed => ModalLoadError(
          message: l10n.markRecurringLoadError,
          onRetry: () => ref.invalidate(provider),
        ),
        MarkRecurringState(outcome: Proposal(:final preview)) => _ProposalBody(
          transactionId: widget.transactionId,
          preview: preview,
          state: loaded,
          onPickSeries: () => _setPicking(true),
        ),
        MarkRecurringState(outcome: AlreadyInSeries(:final series)) =>
          _ExistingSeriesBody(
            transactionId: widget.transactionId,
            series: series,
            state: loaded,
          ),
        null => const ModalLoadingBody(key: Key('markRecurringLoading')),
      },
    );
  }

  /// « Choisir une série »: « Retour à l’aperçu » as the left ghost action,
  /// then « Annuler » and « Confirmer ».
  Widget _pickerModal(AppLocalizations l10n) {
    final selected = ref.watch(seriesPickerControllerProvider).value?.selected;
    return AppModal(
      key: const Key('markRecurringPickerModal'),
      title: l10n.markRecurringTitle,
      subtitle: Text(l10n.seriesPickerIntro),
      width: AppModalSizes.w520,
      busy: _isSaving,
      leadingAction: AppButton(
        key: const Key('seriesPickerBack'),
        label: l10n.seriesPickerBack,
        icon: LucideIcons300.arrowLeft,
        variant: AppButtonVariant.ghost,
        onPressed: () => _setPicking(false),
      ),
      actions: [
        const AppModalCancel(key: Key('markRecurringCancel')),
        PrimaryButton(
          key: const Key('seriesPickerConfirm'),
          label: l10n.seriesPickerConfirm,
          isLoading: _isSaving,
          onPressed: selected != null && !_isSaving
              ? () => _confirm(selected)
              : null,
        ),
      ],
      child: const SeriesPickerBody(),
    );
  }
}

/// The preview: what Bastide would group, and why.
class _ProposalBody extends StatelessWidget {
  const _ProposalBody({
    required this.transactionId,
    required this.preview,
    required this.state,
    required this.onPickSeries,
  });

  final String transactionId;
  final SeriesPreview preview;
  final MarkRecurringState state;

  /// Opens the series picker, for a charge whose label has nothing in common
  /// with the series it belongs to.
  final VoidCallback onPickSeries;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toString();
    final secondary = textTheme.bodySmall?.copyWith(
      color: colors.textSecondary,
    );
    const gap = SizedBox(height: AppSpacing.fieldGap);
    const lineGap = SizedBox(height: AppSpacing.xs);

    Widget figure(String label, String value) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: secondary),
        lineGap,
        Text(value, style: textTheme.bodyMedium),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                preview.label,
                key: const Key('markRecurringLabel'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleSmall,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _Confidence(confidence: preview.confidence),
          ],
        ),
        lineGap,
        // Said once, on one line: no banner repeats the reasons.
        Text(
          [
            for (final reason in preview.reasons)
              _reasonLabel(l10n, reason, preview.transactions.length),
          ].join(' · '),
          key: const Key('markRecurringReasons'),
          style: secondary,
        ),
        gap,
        Row(
          children: [
            Expanded(
              child: figure(
                l10n.markRecurringCadenceLabel,
                cadenceLabel(l10n, preview.cadence),
              ),
            ),
            const SizedBox(width: AppModalSizes.columnGutter),
            Expanded(
              // What the subscription costs, unsigned, as the panel prints it.
              child: figure(
                l10n.markRecurringAmountLabel,
                formatAmount(
                  amountMinor: preview.expectedAmountMinor.abs(),
                  currency: preview.currency,
                  locale: locale,
                ),
              ),
            ),
          ],
        ),
        gap,
        _Checklist(transactionId: transactionId, state: state),
        lineGap,
        _TickedSummary(state: state),
        gap,
        RecurringModalLinkLine(
          link: RecurringModalLink(
            key: const Key('markRecurringPickSeries'),
            label: l10n.markRecurringPickSeries,
            icon: LucideIcons300.listPlus,
            onTap: onPickSeries,
          ),
        ),
      ],
    );
  }
}

/// A series already tracks this merchant: the charges it lacks, and a link
/// to the series. The lead names it.
class _ExistingSeriesBody extends StatelessWidget {
  const _ExistingSeriesBody({
    required this.transactionId,
    required this.series,
    required this.state,
  });

  final String transactionId;
  final RecurringSeries series;
  final MarkRecurringState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      key: const Key('markRecurringExisting'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Checklist(transactionId: transactionId, state: state),
        const SizedBox(height: AppSpacing.fieldGap),
        RecurringModalLinkLine(
          link: RecurringModalLink(
            key: const Key('markRecurringViewSeries'),
            label: l10n.markRecurringViewSeries(series.label),
            icon: LucideIcons300.arrowUpRight,
            onTap: () => Navigator.of(context).pop(OpenExistingSeries(series)),
          ),
        ),
      ],
    );
  }
}

/// The candidate charges as checkable rows, the most recent first.
class _Checklist extends ConsumerWidget {
  const _Checklist({required this.transactionId, required this.state});

  final String transactionId;
  final MarkRecurringState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dates = DayMonthFormat.yMMMd(
      Localizations.localeOf(context).toString(),
    );
    final controller = ref.read(
      markRecurringControllerProvider(transactionId).notifier,
    );
    return ModalList(
      children: [
        for (final transaction in state.candidates.reversed)
          ChargeRow(
            key: Key('markRecurringTick-${transaction.id}'),
            transaction: transaction,
            date: dates.format(transaction.bookedDate),
            ticked: state.ticked.contains(transaction.id),
            onChanged: () => controller.toggle(transaction.id),
          ),
      ],
    );
  }
}

/// « 3 opérations cochées · du 12 mars 2026 au 12 mai 2026 », 11
/// `textTertiary`; in `warning` when nothing is ticked, since saving then
/// waits on the user.
class _TickedSummary extends StatelessWidget {
  const _TickedSummary({required this.state});

  final MarkRecurringState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final styles = context.textStyles;
    final selected = state.selected;
    final dates = DayMonthFormat.yMMMd(
      Localizations.localeOf(context).toString(),
    );
    final text = switch (selected) {
      [] => l10n.markRecurringNoneTicked,
      [_] => l10n.markRecurringTickedCount(1),
      [final first, ..., final last] => l10n.markRecurringTickedRange(
        selected.length,
        dates.format(first.bookedDate),
        dates.format(last.bookedDate),
      ),
    };
    return Text(
      text,
      key: const Key('markRecurringSummary'),
      style: selected.isEmpty
          ? styles.helper.copyWith(color: context.colors.warning)
          : styles.helper,
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

/// Confidence as status text, no pill (`proposal_v6` `m-subscriptions`):
/// high in `textSecondary` with `check`, low in `warning` with
/// `triangle-alert`. Low is amber, not red: the user may still save. Medium,
/// which the mockup does not draw, is plain `textSecondary`.
class _Confidence extends StatelessWidget {
  const _Confidence({required this.confidence});

  final PreviewConfidence confidence;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    const key = Key('markRecurringConfidence');
    return switch (confidence) {
      PreviewConfidence.high => StatusText(
        key: key,
        label: l10n.markRecurringConfidenceHigh,
        icon: LucideIcons300.check,
      ),
      PreviewConfidence.medium => StatusText(
        key: key,
        label: l10n.markRecurringConfidenceMedium,
      ),
      PreviewConfidence.low => StatusText(
        key: key,
        label: l10n.markRecurringConfidenceLow,
        tone: StatusTone.warning,
      ),
    };
  }
}
