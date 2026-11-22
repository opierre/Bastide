import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/institution_avatar.dart';
import '../../../core/widgets/modal_parts.dart';
import '../../../core/widgets/picker_search_field.dart';
import '../../../l10n/app_localizations.dart';
import '../application/add_to_series_controller.dart';
import '../application/subscriptions_controller.dart';
import '../domain/recurring_series.dart';
import 'recurring_labels.dart';
import 'recurring_modal_parts.dart';

/// The « Ajouter à une série existante… » step of the mark-as-recurring
/// modal (`proposal_v6` `m-subscriptions`, « choisir une série »): a search
/// field, then the user's series on every account, each with its account,
/// cadence and expected amount. Tapping one only selects it: the modal's
/// « Confirmer » adds the transaction. The lead is the modal's; while it
/// saves, the modal's frame disables the body.
class SeriesPickerBody extends ConsumerWidget {
  const SeriesPickerBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(seriesPickerControllerProvider);

    return Column(
      key: const Key('seriesPicker'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PickerSearchField(
          fieldKey: const Key('seriesPickerSearch'),
          hint: l10n.seriesPickerSearchHint,
          onChanged: ref.read(seriesPickerControllerProvider.notifier).search,
        ),
        const SizedBox(height: AppSpacing.fieldGap),
        switch (state) {
          AsyncValue(hasError: true) when !state.isLoading => ModalLoadError(
            key: const Key('seriesPickerError'),
            message: l10n.seriesPickerLoadError,
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
          AsyncValue(:final value?) => ModalList(
            children: [
              for (final series in value.visible)
                _SeriesPickRow(
                  key: Key('seriesPickerRow-${series.id}'),
                  series: series,
                  selected: series.id == value.selectedId,
                  onTap: () => ref
                      .read(seriesPickerControllerProvider.notifier)
                      .select(series.id),
                ),
            ],
          ),
          _ => const PickerLoading(key: Key('seriesPickerLoading')),
        },
      ],
    );
  }
}

/// A 48 px row: the monogram, the label over « compte · cadence · montant »
/// in `textTertiary`. The chosen series takes `accentSoft`, a `check`, and
/// its detail line turns `textSecondary`.
class _SeriesPickRow extends ConsumerWidget {
  const _SeriesPickRow({
    super.key,
    required this.series,
    required this.selected,
    required this.onTap,
  });

  final RecurringSeries series;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toString();
    final accounts = ref.watch(subscriptionAccountsProvider).value ?? const [];
    final account = accounts
        .where((candidate) => candidate.id == series.accountId)
        .firstOrNull;

    return ModalListRow(
      twoLines: true,
      selected: selected,
      onTap: onTap,
      child: Row(
        children: [
          InstitutionAvatar(name: series.label, logo: series.logo),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  series.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium,
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textStyles.helper.copyWith(
                    color: selected
                        ? colors.textSecondary
                        : colors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          // The check repeats the tint, so the choice never rests on colour.
          if (selected) ...[
            const SizedBox(width: AppSpacing.sm),
            Icon(
              LucideIcons300.check,
              key: const Key('seriesPickerSelected'),
              size: AppSizes.iconSmall,
              color: colors.accent,
            ),
          ],
        ],
      ),
    );
  }
}
