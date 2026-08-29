import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/category_display.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/category_chip.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../core/widgets/monogram_avatar.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../application/subscriptions_controller.dart';
import '../domain/recurring_series.dart';
import 'price_history_chart.dart';
import 'recurring_labels.dart';

/// One series in full (`docs/design/10` frame ②): the stats, the price-increase
/// banner with its annualised impact, and the occurrence history the series was
/// deduced from.
///
/// A panel state rather than a route — same chrome, same top-bar controls, an
/// iris back link rather than a browser step.
///
/// The history is not decoration. The user is being asked to trust a deduction
/// ("these five charges are one subscription, and it got more expensive"), so
/// the evidence for it is on the screen that asks.
class SeriesDetailView extends ConsumerWidget {
  const SeriesDetailView({super.key, required this.seriesId});

  final String seriesId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final detail = ref.watch(seriesDetailProvider(seriesId));

    return Column(
      key: const Key('seriesDetail'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('seriesDetailBack'),
            onPressed: () => ref.read(selectedSeriesProvider.notifier).close(),
            icon: const Icon(Icons.arrow_back_rounded, size: 16, color: AppColors.iris),
            label: Text(
              l10n.subscriptionDetailBack,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: AppColors.iris),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: switch (detail) {
            AsyncData(:final value) => _DetailBody(detail: value),
            AsyncError() => ErrorStateView(
              message: l10n.subscriptionDetailLoadFailed,
              messageKey: const Key('seriesDetailErrorText'),
              retryLabel: l10n.subscriptionsRetry,
              retryKey: const Key('seriesDetailRetryButton'),
              onRetry: () => ref.invalidate(seriesDetailProvider(seriesId)),
            ),
            _ => const SkeletonList(
              key: Key('seriesDetailLoading'),
              itemCount: 3,
              itemHeight: 92,
            ),
          },
        ),
      ],
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
    final account = accounts
        .where((candidate) => candidate.id == series.accountId)
        .firstOrNull;
    final accountName = account?.displayName ?? '';
    final annual = series.annualPriceImpactMinor;

    return ListView(
      key: const Key('seriesDetailContent'),
      children: [
        _HeaderCard(series: series, accountName: accountName),
        if (series.priceChangedAt case final changedAt? when annual != null) ...[
          const SizedBox(height: AppSpacing.gridGap),
          InlineBanner(
            key: const Key('seriesIncreaseBanner'),
            tone: BannerTone.warning,
            message: l10n.subscriptionDetailIncrease(
              _money(series.previousAmountMinor!, series.currency, locale),
              _money(series.expectedAmountMinor, series.currency, locale),
              seriesDateFormat(locale).format(changedAt),
              // The annualised figure is stated with an explicit sign: it is
              // the direction of the change, not a balance, and « 24,00 € par
              // an » alone would not say whether that is more or less.
              formatAmount(
                amountMinor: annual.abs(),
                currency: series.currency,
                locale: locale,
                showPositiveSign: true,
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.gridGap),
        _HistoryCard(detail: detail, accountName: accountName),
        const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
        Text(
          l10n.subscriptionDetailFootnote,
          key: const Key('seriesDetailFootnote'),
          style: AppTextStyles.helper.copyWith(color: AppColors.textDisabled),
        ),
      ],
    );
  }
}

class _HeaderCard extends ConsumerWidget {
  const _HeaderCard({required this.series, required this.accountName});

  final RecurringSeries series;
  final String accountName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final textTheme = Theme.of(context).textTheme;
    final category = series.categoryId == null
        ? null
        : ref.watch(subscriptionCategoriesByIdProvider)[series.categoryId];
    final since = seriesMonthLabel(locale, series.firstSeenDate);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.cardPaddingWide),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MonogramAvatar(name: series.label, size: 48),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        series.label,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleLarge?.copyWith(fontSize: 20),
                      ),
                    ),
                    if (category != null) ...[
                      const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
                      CategoryChip(
                        label: localizedCategoryName(l10n, category.name),
                        slug: categorySlugFor(
                          name: category.name,
                          kind: category.kind,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.xs + 2),
                Text(
                  // A declared series was never detected, so saying it was
                  // would misdescribe where it came from — and the user is the
                  // one who typed it in.
                  series.isManual
                      ? l10n.subscriptionDetailTrackedSince(accountName, since)
                      : l10n.subscriptionDetailDetectedSince(accountName, since),
                  key: const Key('seriesDetailSubline'),
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          _Stat(
            label: l10n.subscriptionDetailCadence,
            child: Text(cadenceLabel(l10n, series.cadence), style: textTheme.titleSmall),
          ),
          const SizedBox(width: AppSpacing.lg),
          _Stat(
            label: l10n.subscriptionDetailExpectedAmount,
            // Neutral and unsigned like the list column, and for the same
            // reason: it is what the subscription costs, not a movement.
            child: AmountText(
              key: const Key('seriesDetailExpectedAmount'),
              amountMinor: series.expectedAmountMinor.abs(),
              currency: series.currency,
              colorize: false,
              style: textTheme.titleSmall,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          _Stat(
            label: l10n.subscriptionDetailNextCharge,
            child: Text(
              seriesDateFormat(locale).format(series.nextExpectedDate),
              style: tabularNumberStyle(textTheme.titleSmall!),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label.toUpperCase(), style: AppTextStyles.sectionLabel),
        const SizedBox(height: AppSpacing.xs + 2),
        child,
      ],
    );
  }
}

/// The price the series has been charged at over time, drawn as a step curve,
/// with the charge it stepped at marked.
///
/// A curve rather than the column of amounts this card used to hold: five
/// near-identical prices make the reader do the comparison, where a line has
/// already done it. The amounts themselves stay one hover away, so the
/// evidence the footnote asks the user to check is still on the screen that
/// asks.
class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.detail, required this.accountName});

  final SeriesDetail detail;
  final String accountName;

  /// Plot height. Tall enough that a single-cent step is still a visible tread,
  /// short enough that the card doesn't push the footnote off a laptop screen.
  static const _chartHeight = 184.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final textTheme = Theme.of(context).textTheme;
    final series = detail.series;
    final stepped = _steppedUpOccurrence();

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.subscriptionDetailHistoryTitle, style: textTheme.titleMedium),
          const SizedBox(height: 3),
          Text(
            l10n.subscriptionDetailHistorySubtitle(accountName),
            style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          if (detail.occurrences.isEmpty)
            Text(
              l10n.subscriptionDetailHistoryEmpty,
              key: const Key('seriesHistoryEmpty'),
              style: AppTextStyles.helper,
            )
          else ...[
            SizedBox(
              height: _chartHeight,
              child: PriceHistoryChart(
                series: series,
                occurrences: detail.occurrences,
              ),
            ),
            if (stepped != null) ...[
              const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
              // The legend for the amber point on the curve, in the same pill
              // the list row uses for the same fact.
              Align(
                alignment: Alignment.centerLeft,
                child: StatusPill(
                  key: Key('seriesOccurrenceChange-${stepped.id}'),
                  tone: StatusPillTone.warning,
                  label: l10n.subscriptionDetailChange(
                    _money(series.previousAmountMinor!, series.currency, locale),
                    _money(series.expectedAmountMinor, series.currency, locale),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  /// The charge the recorded price change landed on, or `null` when the series
  /// never stepped — or when the change predates the occurrences on hand.
  SeriesOccurrence? _steppedUpOccurrence() {
    final changedAt = detail.series.priceChangedAt;
    if (changedAt == null || detail.series.previousAmountMinor == null) return null;
    return detail.occurrences
        .where((occurrence) => _sameDay(occurrence.bookedDate, changedAt))
        .firstOrNull;
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

/// A price as the panel states one: unsigned, because it is what the
/// subscription costs rather than a movement on the ledger.
String _money(int amountMinor, String currency, String locale) =>
    formatAmount(amountMinor: amountMinor.abs(), currency: currency, locale: locale);
