import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/date_display.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_modal.dart';
import '../../../core/widgets/modal_parts.dart';
import '../../../core/widgets/picker_search_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../l10n/app_localizations.dart';
import '../application/add_to_series_controller.dart';
import '../application/subscriptions_controller.dart';
import '../domain/recurring_series.dart';
import '../domain/series_preview.dart';
import 'recurring_error_localizer.dart';
import 'recurring_modal_parts.dart';

/// Opens « Ajouter à « … » » for [series]: the outflows in no series,
/// closest first, several selectable at once.
Future<void> showAddChargesDialog(
  BuildContext context,
  RecurringSeries series,
) => showAppModal<void>(
  context: context,
  builder: (_) => AddChargesDialog(series: series),
);

/// The 560 px « Ajouter à « {série} » » modal (`docs/design/10` § Other
/// modals, `proposal_v6` `m-subscriptions`): the lead, a search field, the
/// candidate charges as checkable rows (date, bank label in Geist Mono over
/// the account, amount), the « Afficher plus » link, and « Annuler » · ink
/// « Ajouter {n} opérations ». A long series name wraps in the title, its
/// lines balanced by the frame, and never widens the modal.
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
  bool _loadMoreFailed = false;
  String? _saveError;

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
    setState(() => _loadMoreFailed = false);
    try {
      await _controller.loadMore();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadMoreFailed = true);
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
      await _controller.save();
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _saveError = localizeRecurringError(l10n, error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = chargePickerControllerProvider(widget.series.id);
    final state = ref.watch(provider);
    final ticked = state.value?.ticked.length ?? 0;

    return AppModal(
      key: const Key('chargePickerModal'),
      title: l10n.chargePickerTitle(widget.series.label),
      subtitle: Text(l10n.chargePickerIntro),
      width: AppModalSizes.w560,
      // Ticked charges are the user's input.
      dirty: ticked > 0,
      busy: _isSaving,
      saveError: _saveError,
      actions: [
        const AppModalCancel(key: Key('chargePickerCancel')),
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
          PickerSearchField(
            fieldKey: const Key('chargePickerSearch'),
            hint: l10n.chargePickerSearchHint,
            onChanged: _onSearch,
          ),
          const SizedBox(height: AppSpacing.fieldGap),
          switch (state) {
            AsyncValue(isLoading: true) => const PickerLoading(
              key: Key('chargePickerLoading'),
            ),
            AsyncValue(hasError: true) => ModalLoadError(
              key: const Key('chargePickerError'),
              message: l10n.chargePickerLoadError,
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
              loadMoreFailed: _loadMoreFailed,
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
    required this.loadMoreFailed,
    required this.onToggle,
    required this.onLoadMore,
  });

  final ChargePickerState state;
  final bool loadMoreFailed;
  final ValueChanged<PreviewTransaction> onToggle;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final dates = DayMonthFormat.yMMMd(
      Localizations.localeOf(context).toString(),
    );
    final accounts = {
      for (final account
          in ref.watch(subscriptionAccountsProvider).value ?? const [])
        account.id: account.displayName,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ModalList(
          children: [
            for (final transaction in state.items)
              ChargeRow(
                key: Key('chargePickerTick-${transaction.id}'),
                transaction: transaction,
                date: dates.format(transaction.bookedDate),
                caption: accounts[transaction.accountId],
                ticked: state.ticked.containsKey(transaction.id),
                onChanged: () => onToggle(transaction),
              ),
          ],
        ),
        if (state.hasMore) ...[
          const SizedBox(height: AppSpacing.fieldGap),
          if (loadMoreFailed)
            ModalLoadError(
              key: const Key('chargePickerLoadMoreError'),
              message: l10n.chargePickerLoadError,
              onRetry: onLoadMore,
            )
          else if (state.isLoadingMore)
            const PickerLoading(key: Key('chargePickerLoadingMore'), rows: 2)
          else
            RecurringModalLinkLine(
              link: RecurringModalLink(
                key: const Key('chargePickerLoadMore'),
                label: l10n.chargePickerLoadMore,
                onTap: onLoadMore,
              ),
            ),
        ],
      ],
    );
  }
}
