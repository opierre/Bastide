import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_modal.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../application/add_to_series_controller.dart';
import '../application/subscriptions_controller.dart';
import '../domain/recurring_series.dart';
import '../domain/series_preview.dart';
import 'recurring_error_localizer.dart';
import 'recurring_labels.dart';
import 'series_picker.dart';
import 'transaction_check_row.dart';

/// Opens « Ajouter une opération » for [series]: the outflows in no series,
/// closest first, several selectable at once.
Future<void> showAddChargesDialog(
  BuildContext context,
  RecurringSeries series,
) => showDialog<void>(
  context: context,
  builder: (_) => AddChargesDialog(series: series),
);

class AddChargesDialog extends ConsumerStatefulWidget {
  const AddChargesDialog({super.key, required this.series});

  final RecurringSeries series;

  @override
  ConsumerState<AddChargesDialog> createState() => _AddChargesDialogState();
}

class _AddChargesDialogState extends ConsumerState<AddChargesDialog> {
  /// How long typing pauses before the search goes to the server, so a word
  /// typed fast is one request rather than one per letter.
  static const _searchDelay = Duration(milliseconds: 300);

  Timer? _searchTimer;
  bool _isSaving = false;
  String? _errorText;

  ChargePickerController get _controller =>
      ref.read(chargePickerControllerProvider(widget.series.id).notifier);

  @override
  void dispose() {
    _searchTimer?.cancel();
    super.dispose();
  }

  void _onSearch(String query) {
    _searchTimer?.cancel();
    _searchTimer = Timer(_searchDelay, () => _controller.search(query));
  }

  Future<void> _loadMore() async {
    try {
      await _controller.loadMore();
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _errorText = AppLocalizations.of(context)!.chargePickerLoadError,
      );
    }
  }

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
      _errorText = null;
    });
    try {
      await _controller.save();
      if (!mounted) return;
      Navigator.of(context).pop();
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
    final textTheme = Theme.of(context).textTheme;
    final provider = chargePickerControllerProvider(widget.series.id);
    final state = ref.watch(provider);
    final ticked = state.value?.ticked.length ?? 0;

    return AppModal(
      title: l10n.chargePickerTitle(widget.series.label),
      width: 560,
      actions: [
        OutlinedButton(
          key: const Key('chargePickerCancel'),
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.markRecurringCancel),
        ),
        PrimaryButton(
          key: const Key('chargePickerSave'),
          label: l10n.chargePickerSave(ticked),
          isLoading: _isSaving,
          onPressed: !_isSaving && ticked > 0 ? _save : null,
        ),
      ],
      child: Column(
        key: const Key('chargePicker'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.chargePickerIntro,
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (_errorText != null) ...[
            InlineBanner(
              key: const Key('chargePickerError'),
              message: _errorText!,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          PickerSearchField(
            fieldKey: const Key('chargePickerSearch'),
            hint: l10n.chargePickerSearchHint,
            onChanged: _onSearch,
          ),
          const SizedBox(height: AppSpacing.sm),
          switch (state) {
            AsyncValue(isLoading: true) => const PickerLoading(
              key: Key('chargePickerLoading'),
            ),
            AsyncValue(hasError: true) => ErrorStateView(
              message: l10n.chargePickerLoadError,
              retryLabel: l10n.markRecurringRetry,
              retryKey: const Key('chargePickerRetry'),
              onRetry: () => ref.invalidate(provider),
            ),
            AsyncValue(:final value?) when value.items.isEmpty => PickerMessage(
              key: const Key('chargePickerEmpty'),
              text: value.query.trim().isEmpty
                  ? l10n.chargePickerEmpty
                  : l10n.chargePickerNoMatch(value.query.trim()),
            ),
            AsyncValue(:final value?) => _CandidateList(
              state: value,
              enabled: !_isSaving,
              onToggle: _controller.toggle,
              onLoadMore: _loadMore,
            ),
            _ => const PickerLoading(key: Key('chargePickerLoading')),
          },
        ],
      ),
    );
  }
}

class _CandidateList extends ConsumerWidget {
  const _CandidateList({
    required this.state,
    required this.enabled,
    required this.onToggle,
    required this.onLoadMore,
  });

  final ChargePickerState state;
  final bool enabled;
  final ValueChanged<PreviewTransaction> onToggle;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final dates = seriesDateFormat(Localizations.localeOf(context).toString());
    final accounts = {
      for (final account
          in ref.watch(subscriptionAccountsProvider).value ?? const [])
        account.id: account.displayName,
    };

    return PickerListFrame(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        children: [
          for (final transaction in state.items)
            TransactionCheckRow(
              tickKey: Key('chargePickerTick-${transaction.id}'),
              transaction: transaction,
              date: dates.format(transaction.bookedDate),
              caption: accounts[transaction.accountId],
              ticked: state.ticked.containsKey(transaction.id),
              onChanged: enabled ? () => onToggle(transaction) : null,
            ),
          if (state.hasMore)
            Center(
              child: state.isLoadingMore
                  ? const Padding(
                      padding: EdgeInsets.all(AppSpacing.sm),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.iris,
                        ),
                      ),
                    )
                  : TextButton(
                      key: const Key('chargePickerLoadMore'),
                      onPressed: onLoadMore,
                      child: Text(l10n.chargePickerLoadMore),
                    ),
            ),
        ],
      ),
    );
  }
}
