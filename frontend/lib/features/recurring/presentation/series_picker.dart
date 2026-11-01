import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../core/widgets/monogram_avatar.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../application/add_to_series_controller.dart';
import '../application/subscriptions_controller.dart';
import '../domain/recurring_series.dart';
import 'recurring_labels.dart';

/// The « Ajouter à une série existante… » step of the mark-as-recurring
/// dialog: the user's series on every account, searchable by label, each with
/// its account, cadence and expected amount. Tapping one hands it to [onPick].
class SeriesPickerBody extends ConsumerWidget {
  const SeriesPickerBody({
    super.key,
    required this.onPick,
    required this.enabled,
    this.errorText,
  });

  final ValueChanged<RecurringSeries> onPick;
  final bool enabled;

  /// Why the last pick failed, shown inline so the user can try another.
  final String? errorText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final state = ref.watch(seriesPickerControllerProvider);

    return Column(
      key: const Key('seriesPicker'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.seriesPickerIntro,
          style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.md),
        if (errorText != null) ...[
          InlineBanner(
            key: const Key('seriesPickerError'),
            message: errorText!,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        PickerSearchField(
          fieldKey: const Key('seriesPickerSearch'),
          hint: l10n.seriesPickerSearchHint,
          onChanged: ref.read(seriesPickerControllerProvider.notifier).search,
        ),
        const SizedBox(height: AppSpacing.sm),
        switch (state) {
          AsyncValue(hasError: true) when !state.isLoading => ErrorStateView(
            message: l10n.seriesPickerLoadError,
            retryLabel: l10n.markRecurringRetry,
            retryKey: const Key('seriesPickerRetry'),
            onRetry: () => ref.invalidate(seriesPickerControllerProvider),
          ),
          AsyncValue(:final value?) when value.series.isEmpty => PickerMessage(
            key: const Key('seriesPickerEmpty'),
            text: l10n.seriesPickerEmpty,
          ),
          AsyncValue(:final value?) when value.visible.isEmpty => PickerMessage(
            key: const Key('seriesPickerNoMatch'),
            text: l10n.seriesPickerNoMatch(value.query.trim()),
          ),
          AsyncValue(:final value?) => PickerListFrame(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              children: [
                for (final series in value.visible)
                  _SeriesPickRow(
                    series: series,
                    onTap: enabled ? () => onPick(series) : null,
                  ),
              ],
            ),
          ),
          _ => const PickerLoading(key: Key('seriesPickerLoading')),
        },
      ],
    );
  }
}

class _SeriesPickRow extends ConsumerWidget {
  const _SeriesPickRow({required this.series, required this.onTap});

  final RecurringSeries series;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toString();
    final accounts = ref.watch(subscriptionAccountsProvider).value ?? const [];
    final account = accounts
        .where((candidate) => candidate.id == series.accountId)
        .firstOrNull;

    return InkWell(
      key: Key('seriesPickerRow-${series.id}'),
      onTap: onTap,
      hoverColor: AppColors.surfaceRowHover,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm + AppSpacing.xs,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            MonogramAvatar(name: series.label, size: 28),
            const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    series.label,
                    style: textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    l10n.seriesPickerRowDetail(
                      account?.displayName ?? '',
                      cadenceLabel(l10n, series.cadence),
                      // What the subscription costs, unsigned, as the panel
                      // prints it everywhere else.
                      formatAmount(
                        amountMinor: series.expectedAmountMinor.abs(),
                        currency: series.currency,
                        locale: locale,
                      ),
                    ),
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The inset search field both pickers open on.
class PickerSearchField extends StatelessWidget {
  const PickerSearchField({
    super.key,
    required this.fieldKey,
    required this.hint,
    required this.onChanged,
  });

  final Key fieldKey;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: fieldKey,
      autofocus: true,
      onChanged: onChanged,
      style: Theme.of(context).textTheme.bodyMedium,
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        prefixIcon: const Icon(Icons.search_rounded, size: 16),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 30,
          minHeight: 30,
        ),
        filled: true,
        fillColor: AppColors.surfaceField,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      ),
    );
  }
}

/// The inset well a picker's list scrolls in, capped so the dialog keeps its
/// actions on screen.
class PickerListFrame extends StatelessWidget {
  const PickerListFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 300),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceField,
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(color: AppColors.border),
        ),
        child: child,
      ),
    );
  }
}

class PickerLoading extends StatelessWidget {
  const PickerLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 120,
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

class PickerMessage extends StatelessWidget {
  const PickerMessage({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}
