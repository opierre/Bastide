import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../imports/presentation/imports_screen.dart';
import '../application/subscriptions_controller.dart';
import '../domain/recurring_series.dart';
import '../domain/recurring_summary.dart';
import 'recurring_error_localizer.dart';
import 'recurring_labels.dart';
import 'series_detail.dart';
import 'series_form_modal.dart';
import 'series_row.dart';

/// The Abonnements panel: the monthly burden, the detected series with their
/// signals, and the lifecycle actions over them (`docs/design/10`).
class SubscriptionsScreen extends ConsumerWidget {
  const SubscriptionsScreen({super.key});

  static const path = '/subscriptions';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedSeriesProvider);

    return Padding(
      key: const Key('screen-subscriptions'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.contentX,
        vertical: AppSpacing.contentY,
      ),
      child: selected == null
          ? const _SubscriptionsList()
          : SeriesDetailView(seriesId: selected),
    );
  }
}

/// The subscriptions panel's contribution to the top bar: « Détecter » beside
/// the primary « Nouveau paiement récurrent ».
///
/// Both stay available on the detail view. The detail is a state of this panel,
/// not a different one, and chrome that rearranged itself under the user would
/// break the invariant the shell exists to hold (`docs/design/00` §Layout).
class SubscriptionsTopBarActions extends ConsumerStatefulWidget {
  const SubscriptionsTopBarActions({super.key});

  @override
  ConsumerState<SubscriptionsTopBarActions> createState() =>
      _SubscriptionsTopBarActionsState();
}

class _SubscriptionsTopBarActionsState
    extends ConsumerState<SubscriptionsTopBarActions> {
  bool _detecting = false;

  Future<void> _detect() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _detecting = true);
    try {
      final result = await ref
          .read(subscriptionsControllerProvider.notifier)
          .detect();
      if (!mounted) return;
      showAppToast(
        context,
        title: l10n.subscriptionsDetectResult(result.createdCount),
        message: l10n.subscriptionsDetectResultDetail(result.updatedCount),
      );
    } catch (error) {
      if (!mounted) return;
      showAppToast(
        context,
        title: l10n.subscriptionsDetectFailed,
        message: localizeRecurringError(l10n, error),
        tone: BannerTone.error,
      );
    } finally {
      if (mounted) setState(() => _detecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton(
          key: const Key('subscriptionsDetectButton'),
          onPressed: _detecting ? null : _detect,
          child: Text(
            _detecting
                ? l10n.subscriptionsDetectRunning
                : l10n.subscriptionsDetect,
          ),
        ),
        const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
        PrimaryButton(
          key: const Key('addSubscriptionButton'),
          label: l10n.subscriptionsAdd,
          icon: Icons.add_rounded,
          onPressed: () => showSeriesForm(context),
        ),
      ],
    );
  }
}

class _SubscriptionsList extends ConsumerWidget {
  const _SubscriptionsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(subscriptionsControllerProvider);

    return switch (state) {
      AsyncData(:final value)
          when value.rows.isEmpty && value.statusFilter == null =>
        EmptyStateView(
          key: const Key('subscriptionsEmptyState'),
          icon: Icons.autorenew_rounded,
          title: l10n.subscriptionsEmptyTitle,
          message: l10n.subscriptionsEmptyBody,
          action: PrimaryButton(
            key: const Key('subscriptionsEmptyImportsButton'),
            label: l10n.subscriptionsEmptyCta,
            height: 44,
            // More history is what actually produces a detection, so the offer
            // is the imports panel rather than "declare one by hand".
            onPressed: () => context.go(ImportsScreen.path),
          ),
        ),
      AsyncData(:final value) => _LoadedPanel(state: value),
      AsyncError() => ErrorStateView(
        message: l10n.subscriptionsLoadFailed,
        messageKey: const Key('subscriptionsErrorText'),
        retryLabel: l10n.subscriptionsRetry,
        retryKey: const Key('subscriptionsRetryButton'),
        onRetry: () =>
            ref.read(subscriptionsControllerProvider.notifier).refresh(),
      ),
      _ => const Padding(
        key: Key('subscriptionsLoadingIndicator'),
        padding: EdgeInsets.only(top: AppSpacing.lg),
        child: SkeletonList(itemHeight: 56),
      ),
    };
  }
}

class _LoadedPanel extends ConsumerWidget {
  const _LoadedPanel({required this.state});

  final SubscriptionsState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.actionError != null) ...[
          InlineBanner(
            key: const Key('subscriptionsActionError'),
            message: localizeRecurringError(l10n, state.actionError),
          ),
          const SizedBox(height: AppSpacing.gridGap),
        ],
        _SummaryRow(summary: state.summary),
        const SizedBox(height: AppSpacing.gridGap),
        Expanded(child: _TableCard(rows: state.rows)),
      ],
    );
  }
}

/// The three cards of frame ①, read straight from `/recurring/summary`.
///
/// Nothing here is recomputed from the rows below. The burden normalises
/// cadences, excludes cancelled series, and skips the ones with no period —
/// three rules the server owns (`PROJECT.md` §12), and a second implementation
/// in Dart would be a second answer.
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.summary});

  final RecurringSummary summary;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 125, child: _BurdenCard(summary: summary)),
          const SizedBox(width: AppSpacing.gridGap),
          Expanded(flex: 100, child: _ActiveCard(summary: summary)),
          const SizedBox(width: AppSpacing.gridGap),
          Expanded(flex: 120, child: _NextChargeCard(summary: summary)),
        ],
      ),
    );
  }
}

/// The panel's only tinted card. The burden is the figure the whole screen
/// exists to produce, so it is the one that gets the hero treatment.
class _BurdenCard extends StatelessWidget {
  const _BurdenCard({required this.summary});

  final RecurringSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final caption = summary.cancelledCount > 0
        ? '${l10n.subscriptionsBurdenCaption} '
              '${l10n.subscriptionsBurdenExcluded(summary.cancelledCount)}'
        : l10n.subscriptionsBurdenCaption;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.cardPaddingWide),
      gradient: AppColors.irisTintGradient,
      border: Border.all(color: AppColors.irisBorderStrong),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.subscriptionsBurdenLabel.toUpperCase(),
            style: AppTextStyles.statLabel.copyWith(color: AppColors.iris),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Unsigned and neutral: this is what the subscriptions cost per
          // month, a quantity rather than a movement. The red the money rule
          // would give it belongs to charges that have actually landed.
          AmountText(
            key: const Key('subscriptionsMonthlyBurden'),
            amountMinor: summary.monthlyTotalMinor.abs(),
            currency: summary.currency,
            colorize: false,
            style: textTheme.displayMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            caption,
            key: const Key('subscriptionsBurdenCaption'),
            style: AppTextStyles.helper,
          ),
        ],
      ),
    );
  }
}

class _ActiveCard extends StatelessWidget {
  const _ActiveCard({required this.summary});

  final RecurringSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;

    // The breakdown names only the cadences actually in play: printing
    // « 0 hebdomadaire » would spend a line on a fact about nothing.
    final parts = [
      for (final cadence in Cadence.values)
        if ((summary.cadenceCounts[cadence] ?? 0) > 0)
          cadenceCountLabel(l10n, cadence, summary.cadenceCounts[cadence]!),
    ];
    final breakdown = parts.join(' · ');
    final caption = summary.cancelledCount > 0
        ? [
            if (breakdown.isNotEmpty) breakdown,
            l10n.subscriptionsCancelledCount(summary.cancelledCount),
          ].join(' — ')
        : breakdown;

    return _StatCard(
      label: l10n.subscriptionsActiveLabel,
      caption: caption,
      value: Text(
        '${summary.activeCount}',
        key: const Key('subscriptionsActiveCount'),
        style: tabularNumberStyle(textTheme.displayMedium!),
      ),
    );
  }
}

class _NextChargeCard extends StatelessWidget {
  const _NextChargeCard({required this.summary});

  final RecurringSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final textTheme = Theme.of(context).textTheme;
    final next = summary.nextCharge;

    // A notch under the neutral cards' 29: this value is a name and a phrase
    // rather than a figure, and it needs the room the extra characters take.
    final valueStyle = textTheme.displayMedium!.copyWith(fontSize: 24);

    if (next == null) {
      return _StatCard(
        label: l10n.subscriptionsNextLabel,
        caption: '',
        value: Text(
          l10n.subscriptionsNextNone,
          key: const Key('subscriptionsNextCharge'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: valueStyle.copyWith(color: AppColors.textSecondary),
        ),
      );
    }

    return _StatCard(
      label: l10n.subscriptionsNextLabel,
      caption: l10n.subscriptionsNextCaption(
        formatAmount(
          amountMinor: next.amountMinor.abs(),
          currency: summary.currency,
          locale: locale,
        ),
        seriesDateFormat(locale).format(next.dueOn),
      ),
      value: Text(
        l10n.subscriptionsNextValue(
          next.label,
          nextChargeWhen(l10n, next.dueOn, DateTime.now()),
        ),
        key: const Key('subscriptionsNextCharge'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: valueStyle,
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.caption,
  });

  final String label;
  final Widget value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.cardPaddingWide),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label.toUpperCase(), style: AppTextStyles.statLabel),
          const SizedBox(height: AppSpacing.sm),
          value,
          const SizedBox(height: AppSpacing.sm),
          Text(caption, style: AppTextStyles.helper),
        ],
      ),
    );
  }
}

class _TableCard extends ConsumerWidget {
  const _TableCard({required this.rows});

  final List<SubscriptionRow> rows;

  Future<void> _handle(
    BuildContext context,
    WidgetRef ref,
    RecurringSeries series,
    SeriesAction action,
  ) async {
    if (action == SeriesAction.edit) {
      await showSeriesForm(context, initial: series);
      return;
    }

    final status = switch (action) {
      SeriesAction.confirm => SeriesStatus.confirmed,
      SeriesAction.dismiss => SeriesStatus.dismissed,
      SeriesAction.cancel => SeriesStatus.cancelled,
      SeriesAction.edit => null,
    };
    if (status == null) return;
    await ref
        .read(subscriptionsControllerProvider.notifier)
        .changeStatus(series.id, status);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(subscriptionCategoriesByIdProvider);

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.cardPadding,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SeriesTableHeader(),
          Expanded(
            child: ListView.separated(
              key: const Key('subscriptionsList'),
              itemCount: rows.length,
              separatorBuilder: (_, _) => const Divider(
                height: 1,
                thickness: 1,
                color: AppColors.borderSubtle,
              ),
              itemBuilder: (context, index) {
                final row = rows[index];
                return SeriesRow(
                  row: row,
                  category: categories[row.series.categoryId],
                  onOpen: () => ref
                      .read(selectedSeriesProvider.notifier)
                      .open(row.series.id),
                  onAction: (action) =>
                      _handle(context, ref, row.series, action),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
