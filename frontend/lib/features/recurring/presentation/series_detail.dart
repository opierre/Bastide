import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../../core/l10n/category_display.dart';
import '../../../core/l10n/date_display.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_popover.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/category_label.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../core/widgets/note_line.dart';
import '../../../core/widgets/section_heading.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/summary_line.dart';
import '../../../l10n/app_localizations.dart';
import '../application/subscriptions_controller.dart';
import '../domain/recurring_series.dart';
import 'add_charges_dialog.dart';
import 'price_history_chart.dart';
import 'recurring_error_localizer.dart';
import 'recurring_labels.dart';
import 'series_form_modal.dart';

/// One series in full (`docs/design/10` § Series detail): the summary line,
/// the price-rise banner with its yearly cost, the charge history drawn as a
/// step line, and the note that the series is deduced from those charges.
///
/// A state of the panel rather than a route: the title bar's crumb
/// « Abonnements / » leads back to the list.
///
/// The history is not decoration. The user is asked to trust a deduction
/// ("these charges are one subscription, and it got more expensive"), so the
/// evidence for it is on the screen that asks.
class SeriesDetailView extends ConsumerWidget {
  const SeriesDetailView({super.key, required this.seriesId});

  final String seriesId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final detail = ref.watch(seriesDetailProvider(seriesId));

    return KeyedSubtree(
      key: const Key('seriesDetail'),
      child: switch (detail) {
        AsyncData(:final value) => _DetailBody(detail: value),
        AsyncError() => ErrorStateView(
          message: l10n.subscriptionDetailLoadFailed,
          messageKey: const Key('seriesDetailErrorText'),
          retryLabel: l10n.subscriptionsRetry,
          retryKey: const Key('seriesDetailRetryButton'),
          onRetry: () => ref.invalidate(seriesDetailProvider(seriesId)),
        ),
        _ => const _DetailSkeleton(key: Key('seriesDetailLoading')),
      },
    );
  }
}

/// The open series' title-bar controls: a secondary « Modifier » opening the
/// edit modal, then an `ellipsis` menu holding « Ajouter une opération » and
/// « Archiver » (or « Désarchiver »).
class SeriesDetailTopBarActions extends ConsumerStatefulWidget {
  const SeriesDetailTopBarActions({super.key, required this.seriesId});

  final String seriesId;

  @override
  ConsumerState<SeriesDetailTopBarActions> createState() =>
      _SeriesDetailTopBarActionsState();
}

class _SeriesDetailTopBarActionsState
    extends ConsumerState<SeriesDetailTopBarActions> {
  final _menu = MenuController();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final series = ref
        .watch(seriesDetailProvider(widget.seriesId))
        .value
        ?.series;
    if (series == null) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppButton(
          key: const Key('seriesDetailEdit'),
          label: l10n.subscriptionActionEdit,
          onPressed: series.isArchived ? null : () => _edit(series),
        ),
        const SizedBox(width: AppSpacing.sm),
        MenuAnchor(
          controller: _menu,
          style: AppPopover.menuStyle(context),
          alignmentOffset: const Offset(0, AppSpacing.xs),
          menuChildren: [
            // A dismissed series is the user's "no", an archived one is put
            // away: nothing is added to either.
            if (series.status != SeriesStatus.dismissed && !series.isArchived)
              AppMenuItem(
                key: const Key('seriesDetailAddCharge'),
                label: l10n.chargePickerAction,
                leading: const Icon(LucideIcons300.plus),
                onPressed: () => showAddChargesDialog(context, series),
              ),
            AppMenuItem(
              key: const Key('seriesDetailArchive'),
              label: series.isArchived
                  ? l10n.subscriptionActionUnarchive
                  : l10n.subscriptionActionArchive,
              leading: Icon(
                series.isArchived
                    ? LucideIcons300.archiveRestore
                    : LucideIcons300.archive,
              ),
              onPressed: () => _toggleArchive(series),
            ),
          ],
          child: AppButton(
            key: const Key('seriesDetailMore'),
            label: l10n.subscriptionDetailMoreActions,
            icon: LucideIcons300.ellipsis,
            iconOnly: true,
            onPressed: () => _menu.isOpen ? _menu.close() : _menu.open(),
          ),
        ),
      ],
    );
  }

  Future<void> _edit(RecurringSeries series) async {
    final saved = await showSeriesForm(context, series: series);
    if (saved != null) ref.invalidate(seriesDetailProvider(series.id));
  }

  /// The view stays open and re-reads the series, so the item turns into its
  /// opposite: the user sees the change land and can undo it in place. A
  /// refusal is said in a toast, since the list's banner is out of sight.
  Future<void> _toggleArchive(RecurringSeries series) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = ref.read(subscriptionsControllerProvider.notifier);
    final done = series.isArchived
        ? await controller.unarchive(series.id)
        : await controller.archive(series.id);
    if (done || !mounted) return;
    showAppToast(
      context,
      title: l10n.subscriptionArchiveFailed,
      message: localizeRecurringError(
        l10n,
        ref.read(subscriptionsControllerProvider).value?.actionError,
      ),
      tone: BannerTone.error,
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.detail});

  final SeriesDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final series = detail.series;
    final accounts = ref.watch(subscriptionAccountsProvider).value ?? const [];
    final accountName =
        accounts
            .where((candidate) => candidate.id == series.accountId)
            .firstOrNull
            ?.displayName ??
        '';
    final annual = series.annualPriceImpactMinor;

    return ListView(
      key: const Key('seriesDetailContent'),
      children: [
        _DetailSummaryLine(series: series, accountName: accountName),
        const _SectionBreak(),
        // The banner belongs to the history block below it: space, no
        // hairline of its own (`00` §1.2).
        if (series.priceChangedAt case final changedAt?
            when annual != null) ...[
          InlineBanner(
            key: const Key('seriesIncreaseBanner'),
            tone: BannerTone.warning,
            icon: LucideIcons300.trendingUp,
            message: l10n.subscriptionDetailIncrease(
              _money(series.previousAmountMinor!, series.currency, locale),
              _money(series.expectedAmountMinor, series.currency, locale),
              DayMonthFormat.yMMMd(locale).format(changedAt),
              // Stated with its sign: the direction of the change, not a
              // balance. « 24,00 € par an » alone would not say whether that
              // is more or less.
              formatAmount(
                amountMinor: annual.abs(),
                currency: series.currency,
                locale: locale,
                showPositiveSign: true,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.section),
        ],
        SectionHeading(
          title: l10n.subscriptionDetailHistoryTitle,
          trailing: Text(
            l10n.subscriptionDetailHistorySubtitle(accountName),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
        ),
        // Every series has charges: it is detected from them, or created from
        // the ones the user ticked.
        SizedBox(
          height: PriceHistoryChart.height,
          child: PriceHistoryChart(
            series: series,
            occurrences: detail.occurrences,
          ),
        ),
        const SizedBox(height: AppSpacing.section),
        NoteLine(
          key: const Key('seriesDetailFootnote'),
          text: l10n.subscriptionDetailFootnote,
        ),
      ],
    );
  }
}

/// The detail's summary line: « Montant attendu » leads at 40 px, then
/// « Cadence » and « Prochain prélèvement » at 20 px; on the right, 12
/// `textSecondary`, the category label over « {account} · détecté depuis
/// {mois} ».
class _DetailSummaryLine extends ConsumerWidget {
  const _DetailSummaryLine({required this.series, required this.accountName});

  final RecurringSeries series;
  final String accountName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final minor = tabularNumberStyle(textTheme.displaySmall!);
    final category = series.categoryId == null
        ? null
        : ref.watch(subscriptionCategoriesByIdProvider)[series.categoryId];
    final since = seriesMonthLabel(locale, series.firstSeenDate);
    // A cancelled or archived series expects no charge.
    final settled =
        series.status == SeriesStatus.cancelled || series.isArchived;

    return IntrinsicHeight(
      key: const Key('seriesDetailSummaryLine'),
      // Two groups pushed apart rather than one row of flex items: the space
      // the items leave unused falls between the groups, so the right block
      // ends on the panel's right edge, with the account beside « Historique
      // des prélèvements ».
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            flex: 2,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SummaryItem(
                  label: l10n.subscriptionDetailExpectedAmount,
                  labelGap: AppSpacing.xs,
                  // Neutral and unsigned like the list's column: what the
                  // subscription costs, not a movement.
                  figure: AmountText(
                    key: const Key('seriesDetailExpectedAmount'),
                    amountMinor: series.expectedAmountMinor.abs(),
                    currency: series.currency,
                    colorize: false,
                    maxLines: 1,
                    style: textTheme.displayLarge!.copyWith(color: colors.text),
                  ),
                ),
                const SummaryHairline(),
                Flexible(
                  child: SummaryItem(
                    label: l10n.subscriptionDetailCadence,
                    figure: Text(
                      cadenceLabel(l10n, series.cadence),
                      key: const Key('seriesDetailCadence'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: minor.copyWith(color: colors.text),
                    ),
                  ),
                ),
                const SummaryHairline(),
                Flexible(
                  child: SummaryItem(
                    label: l10n.subscriptionDetailNextCharge,
                    figure: Text(
                      settled
                          ? l10n.subscriptionsValueNone
                          : seriesLongDateFormat(
                              locale,
                            ).format(series.nextExpectedDate),
                      key: const Key('seriesDetailNextCharge'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: minor.copyWith(
                        color: settled ? colors.textTertiary : colors.text,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xxl),
          Flexible(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (category == null)
                  CategoryLabel.uncategorized(label: l10n.categoryUncategorized)
                else
                  CategoryLabel(
                    label: localizedCategoryName(l10n, category.name),
                    slug: categorySlugFor(
                      name: category.name,
                      kind: category.kind,
                    ),
                  ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  // A series the user created from its charges was never
                  // detected, so saying it was would misdescribe it.
                  series.isManual
                      ? l10n.subscriptionDetailTrackedSince(accountName, since)
                      : l10n.subscriptionDetailDetectedSince(
                          accountName,
                          since,
                        ),
                  key: const Key('seriesDetailSubline'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 24 px, a hairline, 24 px: the gap between two blocks (`00` §1.2).
class _SectionBreak extends StatelessWidget {
  const _SectionBreak();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.section),
    child: Divider(height: 1, thickness: 1, color: context.colors.line),
  );
}

/// The summary line's silhouette: label, 40 px figure.
const _summarySilhouette = 66.0;

/// The heading over the chart and its gap.
const _headingSilhouette = 28.0;

/// The detail's silhouette: the summary line, then the history block.
class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const SkeletonPulse(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SkeletonBlock(height: _summarySilhouette),
          SizedBox(height: AppSpacing.section * 2 + 1),
          SkeletonBlock(height: _headingSilhouette + PriceHistoryChart.height),
        ],
      ),
    );
  }
}

/// A price as the panel states one: unsigned, because it is what the
/// subscription costs rather than a movement on the ledger.
String _money(int amountMinor, String currency, String locale) => formatAmount(
  amountMinor: amountMinor.abs(),
  currency: currency,
  locale: locale,
);
