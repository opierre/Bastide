import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/app_table.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../application/recurring_detection.dart';
import '../application/subscriptions_controller.dart';
import '../domain/recurring_series.dart';
import '../domain/recurring_summary.dart';
import 'merge_suggestions_panel.dart';
import 'recurring_error_localizer.dart';
import 'recurring_labels.dart';
import 'series_detail.dart';
import 'series_form_modal.dart';
import 'series_row.dart';
import 'summary_item.dart';

/// « Abonnements » (`docs/design/10-subscriptions.md`): the summary line, the
/// merge suggestions when there are any, then the table sorted by next
/// charge. Sections, not cards: nothing here is framed.
class SubscriptionsScreen extends ConsumerWidget {
  const SubscriptionsScreen({super.key});

  static const path = '/subscriptions';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedSeriesProvider);

    return Padding(
      key: const Key('screen-subscriptions'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageX,
        vertical: AppSpacing.pageY,
      ),
      child: selected == null
          ? const _SubscriptionsList()
          : SeriesDetailView(seriesId: selected),
    );
  }
}

/// The panel's contribution to the title bar. The list shows the secondary
/// « Détecter » (`10` § Title bar); there is no « Nouvel abonnement », since a
/// series is created from its charges in Transactions. An open series shows
/// its own « Modifier » and `ellipsis` menu instead (`10` § Series detail).
class SubscriptionsTopBarActions extends ConsumerWidget {
  const SubscriptionsTopBarActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final selected = ref.watch(selectedSeriesProvider);
    if (selected != null) return SeriesDetailTopBarActions(seriesId: selected);

    final detecting = ref.watch(recurringDetectionProvider);
    return AppButton(
      key: const Key('subscriptionsDetectButton'),
      label: l10n.subscriptionsDetect,
      icon: LucideIcons300.scanSearch,
      isLoading: detecting,
      onPressed: () => runRecurringDetection(context, ref),
    );
  }
}

/// The panel's title: « Abonnements », or, on an open series,
/// « Abonnements / » leading back to the list, then the series' name.
class SubscriptionsTitle extends ConsumerWidget {
  const SubscriptionsTitle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final selected = ref.watch(selectedSeriesProvider);
    if (selected == null) return TitleBarTitle(title: l10n.navSubscriptions);

    final label = ref.watch(seriesDetailProvider(selected)).value?.series.label;
    return TitleBarTitle(
      key: const Key('subscriptionsDetailTitle'),
      crumb: TitleBarCrumb(
        label: l10n.navSubscriptions,
        onTap: () => ref.read(selectedSeriesProvider.notifier).close(),
      ),
      title: label ?? '',
    );
  }
}

/// Runs a detection pass and reports it in a toast: the one path behind every
/// « Détecter » button, so the running state and the result read the same
/// wherever the pass was started.
///
/// The overlay and the strings are taken before the await: the empty state's
/// button is gone once the reload behind the pass lands, and its result still
/// has to be said.
Future<void> runRecurringDetection(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context)!;
  final overlay = Overlay.maybeOf(context);
  try {
    final result = await ref.read(recurringDetectionProvider.notifier).run();
    if (result == null || overlay == null || !overlay.mounted) return;
    showAppToastOn(
      overlay,
      title: l10n.subscriptionsDetectResult(result.createdCount),
      message: l10n.subscriptionsDetectResultDetail(result.updatedCount),
    );
  } catch (error) {
    if (overlay == null || !overlay.mounted) return;
    showAppToastOn(
      overlay,
      title: l10n.subscriptionsDetectFailed,
      message: localizeRecurringError(l10n, error),
      tone: BannerTone.error,
    );
  }
}

class _SubscriptionsList extends ConsumerWidget {
  const _SubscriptionsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(subscriptionsControllerProvider);
    final detecting = ref.watch(recurringDetectionProvider);

    return switch (state) {
      AsyncData(:final value)
          when value.rows.isEmpty &&
              value.archived.isEmpty &&
              value.statusFilter == null =>
        EmptyStateView(
          key: const Key('subscriptionsEmptyState'),
          title: l10n.subscriptionsEmptyTitle,
          message: l10n.subscriptionsEmptyBody,
          action: PrimaryButton(
            key: const Key('subscriptionsEmptyDetectButton'),
            label: l10n.subscriptionsDetect,
            isLoading: detecting,
            // The transactions may already be imported: running detection
            // over them is the step that fills this panel.
            onPressed: () => runRecurringDetection(context, ref),
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
      _ => const _ListSkeleton(key: Key('subscriptionsLoadingIndicator')),
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
          const SizedBox(height: AppSpacing.section),
        ],
        SubscriptionsSummaryLine(summary: state.summary),
        const SizedBox(height: AppSpacing.section),
        if (state.mergeSuggestions.isNotEmpty) ...[
          MergeSuggestionsPanel(suggestions: state.mergeSuggestions),
          const SizedBox(height: AppSpacing.section),
        ],
        Expanded(child: _SeriesTable(state: state)),
      ],
    );
  }
}

/// The panel's summary line (`10` §1, `00` §7): « Charge mensuelle » leads at
/// 40 px, then « Actifs », « Prochain prélèvement » and « À regarder » at
/// 20 px. A vertical hairline separates the lead from the rest only.
///
/// Every figure is read straight from `/recurring/summary`, never recomputed
/// from the rows: the burden normalises cadences and excludes cancelled
/// series, rules the server owns.
class SubscriptionsSummaryLine extends StatelessWidget {
  const SubscriptionsSummaryLine({super.key, required this.summary});

  final RecurringSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final minor = tabularNumberStyle(textTheme.displaySmall!);

    // The breakdown names only the cadences in play: « 0 hebdomadaire » would
    // spend a line on a fact about nothing.
    final breakdown = [
      for (final cadence in Cadence.values)
        if ((summary.cadenceCounts[cadence] ?? 0) > 0)
          cadenceCountLabel(l10n, cadence, summary.cadenceCounts[cadence]!),
    ].join(' · ');

    final next = summary.nextCharge;
    final watch = summary.watchCount;

    return IntrinsicHeight(
      key: const Key('subscriptionsSummaryLine'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SummaryItem(
            label: l10n.subscriptionsBurdenLabel,
            labelGap: AppSpacing.xs,
            caption: l10n.subscriptionsBurdenCaption,
            // Unsigned and neutral: what the subscriptions cost per month, a
            // quantity rather than a movement.
            figure: AmountText(
              key: const Key('subscriptionsMonthlyBurden'),
              amountMinor: summary.monthlyTotalMinor.abs(),
              currency: summary.currency,
              colorize: false,
              maxLines: 1,
              style: textTheme.displayLarge!.copyWith(color: colors.text),
            ),
          ),
          const SummaryHairline(),
          Flexible(
            child: SummaryItem(
              label: l10n.subscriptionsActiveLabel,
              caption: breakdown,
              figure: Text(
                '${summary.activeCount}',
                key: const Key('subscriptionsActiveCount'),
                style: minor.copyWith(color: colors.text),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xxl),
          Flexible(
            flex: 2,
            child: SummaryItem(
              label: l10n.subscriptionsNextLabel,
              caption: next == null
                  ? null
                  : l10n.subscriptionsNextCaption(
                      formatAmount(
                        amountMinor: next.amountMinor.abs(),
                        currency: summary.currency,
                        locale: locale,
                      ),
                      seriesLongDateFormat(locale).format(next.dueOn),
                    ),
              figure: Text(
                next == null
                    ? l10n.subscriptionsValueNone
                    : l10n.subscriptionsNextValue(
                        next.label,
                        nextChargeWhen(l10n, next.dueOn, DateTime.now()),
                      ),
                key: const Key('subscriptionsNextCharge'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: minor.copyWith(
                  color: next == null ? colors.textTertiary : colors.text,
                ),
              ),
            ),
          ),
          if (watch > 0) ...[
            const SizedBox(width: AppSpacing.xxl),
            Flexible(
              child: SummaryItem(
                key: const Key('subscriptionsWatch'),
                label: l10n.subscriptionsWatchLabel,
                caption: [
                  if (summary.priceIncreases.isNotEmpty)
                    l10n.subscriptionsWatchIncreases(
                      summary.priceIncreases.length,
                    ),
                  if (summary.missed.isNotEmpty)
                    l10n.subscriptionsWatchMissed(summary.missed.length),
                ].join(' · '),
                figure: Text(
                  '$watch',
                  key: const Key('subscriptionsWatchCount'),
                  style: minor.copyWith(color: colors.warning),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The table: header, the live rows, and under them the archived rows when
/// revealed, behind their group row. The link that reveals them sits below.
class _SeriesTable extends ConsumerWidget {
  const _SeriesTable({required this.state});

  final SubscriptionsState state;

  Future<void> _handle(
    BuildContext context,
    WidgetRef ref,
    RecurringSeries series,
    SeriesAction action,
  ) async {
    final controller = ref.read(subscriptionsControllerProvider.notifier);
    switch (action) {
      case SeriesAction.edit:
        await showSeriesForm(context, series: series);
      case SeriesAction.archive:
        await controller.archive(series.id);
      case SeriesAction.unarchive:
        await controller.unarchive(series.id);
      case SeriesAction.confirm:
        await controller.changeStatus(series.id, SeriesStatus.confirmed);
      case SeriesAction.dismiss:
        await controller.changeStatus(series.id, SeriesStatus.dismissed);
      case SeriesAction.cancel:
        await controller.changeStatus(series.id, SeriesStatus.cancelled);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final categories = ref.watch(subscriptionCategoriesByIdProvider);
    final controller = ref.read(subscriptionsControllerProvider.notifier);
    final archivedRows = state.showArchived
        ? state.archivedRows
        : const <SubscriptionRow>[];

    Widget seriesRow(SubscriptionRow row) => SeriesRow(
      row: row,
      category: categories[row.series.categoryId],
      onOpen: () =>
          ref.read(selectedSeriesProvider.notifier).open(row.series.id),
      onAction: (action) => _handle(context, ref, row.series, action),
    );

    final entries = [
      for (final row in state.rows) seriesRow(row),
      if (archivedRows.isNotEmpty) ...[
        AppTableGroupRow(
          key: const Key('subscriptionsArchivedSection'),
          label: l10n.subscriptionsArchivedSection,
        ),
        for (final row in archivedRows) seriesRow(row),
      ],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SeriesTableHeader(sort: state.sort, onSort: controller.sortBy),
        Expanded(
          child: ListView(
            key: const Key('subscriptionsList'),
            children: entries,
          ),
        ),
        if (state.archived.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton(
              key: const Key('subscriptionsArchivedToggle'),
              variant: AppButtonVariant.ghost,
              icon: LucideIcons300.archive,
              onPressed: controller.toggleArchived,
              label: state.showArchived
                  ? l10n.subscriptionsHideArchived(state.archived.length)
                  : l10n.subscriptionsShowArchived(state.archived.length),
            ),
          ),
        ],
      ],
    );
  }
}

/// The summary line's silhouette: label, 40 px figure, caption.
const _summarySilhouette = 86.0;

/// How many row silhouettes the loading state draws.
const _rowSilhouettes = 8;

/// The list's silhouette: the summary line, then table rows, in `hover`
/// blocks pulsing together, so nothing moves when the data lands (`00` §7).
class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonPulse(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SkeletonBlock(height: _summarySilhouette),
          const SizedBox(height: AppSpacing.section),
          Expanded(
            child: ClipRect(
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < _rowSilhouettes; i++)
                      const Padding(
                        padding: EdgeInsets.only(bottom: AppSpacing.sm),
                        child: SkeletonBlock(
                          height: AppSizes.tableRow - AppSpacing.sm,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
