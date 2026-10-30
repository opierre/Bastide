import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/app_segmented.dart';
import '../../../core/widgets/area_line.dart';
import '../../../core/widgets/dashed_border.dart';
import '../../../core/widgets/institution_avatar.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../imports/presentation/imports_screen.dart';
import '../../transactions/application/transactions_controller.dart';
import '../../transactions/presentation/transaction_row.dart';
import '../../transactions/presentation/transactions_screen.dart';
import '../application/account_detail_controller.dart';
import '../domain/account.dart';
import '../domain/account_overview.dart';
import 'account_error_localizer.dart';
import 'account_type_label.dart';
import 'cycle_bars.dart';
import 'settlement_rule_dialog.dart';

/// One account, in depth: its balance and how it moved, the deferred cards on
/// either side of it, and its latest transactions
/// (`docs/design/16-account-detail.md`).
///
/// A view *within* « Comptes »: the sidebar keeps that section selected and
/// the top bar names the account, with a link back to the list.
class AccountDetailScreen extends ConsumerWidget {
  const AccountDetailScreen({super.key, required this.accountId});

  static const path = '/accounts/:accountId';

  /// The route for [accountId]'s detail.
  static String location(String accountId) => '/accounts/$accountId';

  /// The account id in [path] when it is an account's detail, else `null`.
  static String? idFromPath(String path) {
    final segments = Uri.parse(path).pathSegments;
    return segments.length == 2 && segments.first == 'accounts'
        ? segments[1]
        : null;
  }

  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final overview = ref.watch(accountOverviewProvider(accountId));

    return ListView(
      key: const Key('screen-account-detail'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.contentX,
        vertical: AppSpacing.contentY,
      ),
      children: [
        const Align(alignment: Alignment.centerLeft, child: _BackLink()),
        const SizedBox(height: AppSpacing.md),
        ...switch (overview) {
          AsyncData(:final value) => [
            _IdentityCard(overview: value),
            const SizedBox(height: AppSpacing.gridGap),
            SizedBox(
              height: _chartRowHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 2, child: _ChartCard(overview: value)),
                  const SizedBox(width: AppSpacing.gridGap),
                  Expanded(
                    child: value.settlement == null
                        ? _PeriodStatsCard(overview: value)
                        : _CycleStatsCard(
                            settlement: value.settlement!,
                            currency: value.account.currency,
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.gridGap),
            if (value.settlement case final settlement?)
              _SettlementSection(card: value.account, settlement: settlement)
            else
              _LinkedCardsSection(overview: value),
            const SizedBox(height: AppSpacing.gridGap),
            _RecentTransactionsCard(accountId: accountId),
          ],
          AsyncError(:final error) => [
            SizedBox(
              height: 420,
              child: ErrorStateView(
                message: localizeAccountError(l10n, error),
                messageKey: const Key('accountDetailErrorText'),
                retryLabel: l10n.accountsRetry,
                retryKey: const Key('accountDetailRetryButton'),
                onRetry: () =>
                    ref.invalidate(accountOverviewProvider(accountId)),
              ),
            ),
          ],
          _ => const [_DetailSkeleton()],
        },
      ],
    );
  }
}

/// The balance chart and the stats card beside it share one fixed height, so
/// the row reads as one band whatever each holds.
const _chartRowHeight = 300.0;

String _locale(BuildContext context) =>
    Localizations.localeOf(context).toString();

class _BackLink extends StatelessWidget {
  const _BackLink();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return TextButton.icon(
      key: const Key('accountDetailBack'),
      onPressed: () => context.go('/accounts'),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.textSecondary,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: Theme.of(context).textTheme.bodyMedium,
      ),
      icon: const Icon(Icons.chevron_left_rounded, size: 16),
      label: Text(l10n.accountDetailBack),
    );
  }
}

// ── Row 1: identity and headline ────────────────────────────────────────────

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.overview});

  final AccountOverview overview;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final account = overview.account;
    final settlement = overview.settlement;
    final locale = _locale(context);
    final today = DateFormat.yMMMd(locale).format(DateTime.now());
    final debit = settlement?.nextDebitDate;

    return AppCard(
      key: const Key('accountDetailIdentity'),
      padding: const EdgeInsets.all(AppSpacing.cardPaddingWide),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              InstitutionAvatar(name: account.institution, size: 48),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.name,
                      style: textTheme.headlineMedium?.copyWith(
                        fontFamily: AppFonts.geist,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: AppSpacing.sm + 2,
                      runSpacing: AppSpacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          account.institution,
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        AppChip(label: accountTypeLabel(l10n, account.type)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    (settlement == null
                            ? l10n.accountDetailBalanceLabel
                            : l10n.accountDetailCycleLabel)
                        .toUpperCase(),
                    style: AppTextStyles.sectionLabel,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  // The headline is this panel's data point, so it carries the
                  // sign colors; a card's open cycle is spending, so it reads red.
                  AmountText(
                    key: const Key('accountDetailHeadline'),
                    amountMinor:
                        settlement?.currentCycleMinor ?? account.balanceMinor,
                    currency: account.currency,
                    showPositiveSign: true,
                    style: textTheme.displayLarge!,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    debit == null
                        ? l10n.accountDetailAsOf(today)
                        : l10n.accountDetailCycleAsOf(
                            today,
                            DateFormat.MMMd(locale).format(debit),
                          ),
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.gridGap),
          const Divider(height: 1, color: AppColors.borderSubtle),
          const SizedBox(height: 14),
          _MetaStrip(overview: overview),
        ],
      ),
    );
  }
}

/// Two or three inline facts along the identity card's foot. Wraps to a second
/// line rather than truncating: French labels run long.
class _MetaStrip extends StatelessWidget {
  const _MetaStrip({required this.overview});

  final AccountOverview overview;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = _locale(context);
    final date = DateFormat.yMMMd(locale);
    final digits = overview.settlement?.cardLastDigits;
    final first = overview.firstTransactionDate;
    final imported = overview.lastImportAt;

    return Wrap(
      spacing: 28,
      runSpacing: AppSpacing.sm,
      children: [
        if (digits != null)
          _MetaFact(
            icon: Icons.credit_card_rounded,
            text: l10n.accountDetailMaskedNumber(digits),
          ),
        _MetaFact(
          key: const Key('accountDetailHistory'),
          icon: Icons.calendar_today_outlined,
          text: first == null
              ? l10n.accountDetailNoHistory
              : l10n.accountDetailHistorySince(date.format(first)),
        ),
        _MetaFact(
          key: const Key('accountDetailLastImport'),
          icon: Icons.download_rounded,
          text: imported == null
              ? l10n.accountDetailNoImport
              : l10n.accountDetailLastImport(date.format(imported.toLocal())),
          onTap: imported == null ? null : () => context.go(ImportsScreen.path),
        ),
      ],
    );
  }
}

class _MetaFact extends StatelessWidget {
  const _MetaFact({
    super.key,
    required this.icon,
    required this.text,
    this.onTap,
  });

  final IconData icon;
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
      fontSize: 12,
      color: AppColors.textSecondary,
      decoration: onTap == null ? null : TextDecoration.underline,
      decorationColor: AppColors.borderDashed,
    );
    final fact = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: AppColors.textSecondary),
        const SizedBox(width: 7),
        Text(text, style: tabularNumberStyle(style!)),
      ],
    );
    if (onTap == null) return fact;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.xs),
      child: fact,
    );
  }
}

// ── Row 2: chart and stats ──────────────────────────────────────────────────

class _ChartCard extends ConsumerWidget {
  const _ChartCard({required this.overview});

  final AccountOverview overview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final accountId = overview.account.id;
    final settlement = overview.settlement;

    final Widget body;
    if (settlement != null) {
      body = settlement.cycles.isEmpty
          ? const _ChartEmpty()
          : _CycleChart(
              settlement: settlement,
              currency: overview.account.currency,
            );
    } else if (!overview.hasChartHistory) {
      body = const _ChartEmpty();
    } else {
      body = _BalanceChart(
        accountId: accountId,
        currency: overview.account.currency,
        history: overview.balanceHistory,
      );
    }

    return AppCard(
      key: const Key('accountDetailChart'),
      padding: const EdgeInsets.fromLTRB(22, 20, 22, AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 34,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    settlement == null
                        ? l10n.accountDetailBalanceChartTitle
                        : l10n.accountDetailCyclesChartTitle,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (settlement == null && overview.hasChartHistory)
                  SizedBox(
                    width: 240,
                    child: AppSegmented<BalanceRange>(
                      segments: [
                        AppSegment(
                          key: const Key('accountDetailRange-six'),
                          value: BalanceRange.sixMonths,
                          label: l10n.accountDetailRangeSixMonths,
                        ),
                        AppSegment(
                          key: const Key('accountDetailRange-twelve'),
                          value: BalanceRange.twelveMonths,
                          label: l10n.accountDetailRangeTwelveMonths,
                        ),
                        AppSegment(
                          key: const Key('accountDetailRange-all'),
                          value: BalanceRange.all,
                          label: l10n.accountDetailRangeAll,
                        ),
                      ],
                      value: ref.watch(
                        balanceRangeControllerProvider(accountId),
                      ),
                      onChanged: ref
                          .read(
                            balanceRangeControllerProvider(accountId).notifier,
                          )
                          .select,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(child: body),
        ],
      ),
    );
  }
}

String Function(num) _compactMoney(BuildContext context, String currency) {
  final format = NumberFormat.compactSimpleCurrency(
    locale: _locale(context),
    name: currency,
  );
  return (minor) => format.format(minor / 100);
}

class _BalanceChart extends ConsumerWidget {
  const _BalanceChart({
    required this.accountId,
    required this.currency,
    required this.history,
  });

  final String accountId;
  final String currency;
  final List<BalancePoint> history;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = _locale(context);
    final points = ref.watch(visibleBalanceHistoryProvider(accountId));
    // The first visible point's predecessor sits outside the range, but its
    // change is still real; only the very first month has none.
    final offset = history.length - points.length;
    final month = DateFormat.MMM(locale);
    final title = DateFormat.yMMMM(locale);

    return AreaLine(
      key: const Key('accountDetailBalanceChart'),
      color: AppColors.cyan,
      gridlines: 2,
      values: [for (final point in points) point.balanceMinor],
      labels: [
        for (var i = 0; i < points.length; i++)
          // An all-history chart labels every other month, anchored on the
          // latest, so the axis never crowds.
          points.length > 12 && (points.length - 1 - i).isOdd
              ? ''
              : month.format(points[i].monthEnd),
      ],
      valueLabel: _compactMoney(context, currency),
      tooltips: [
        for (var i = 0; i < points.length; i++)
          _tooltip(
            context,
            title: title.format(points[i].monthEnd),
            value: formatAmount(
              amountMinor: points[i].balanceMinor,
              currency: currency,
              locale: locale,
            ),
            delta: offset + i == 0
                ? null
                : points[i].balanceMinor - history[offset + i - 1].balanceMinor,
            currency: currency,
            l10n: l10n,
          ),
      ],
    );
  }

  InlineSpan _tooltip(
    BuildContext context, {
    required String title,
    required String value,
    required int? delta,
    required String currency,
    required AppLocalizations l10n,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final deltaColor = switch (delta) {
      null || 0 => AppColors.textSecondary,
      > 0 => AppColors.positive,
      _ => AppColors.negative,
    };
    return TextSpan(
      children: [
        TextSpan(
          text: '$title\n',
          style: textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
        ),
        TextSpan(
          text: '$value\n',
          style: tabularNumberStyle(textTheme.titleSmall!),
        ),
        TextSpan(
          text: delta == null
              ? l10n.accountDetailTooltipFirstMonth
              : l10n.accountDetailTooltipDelta(
                  formatAmount(
                    amountMinor: delta,
                    currency: currency,
                    locale: _locale(context),
                    showPositiveSign: true,
                  ),
                ),
          style: tabularNumberStyle(
            textTheme.labelSmall!,
          ).copyWith(color: deltaColor),
        ),
      ],
    );
  }
}

class _CycleChart extends StatelessWidget {
  const _CycleChart({required this.settlement, required this.currency});

  final CardSettlement settlement;
  final String currency;

  /// A year of cycles: the card's chart has no range control, and older
  /// cycles are on the transactions panel.
  static const _shown = 12;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final locale = _locale(context);
    final cycles = settlement.cycles.length > _shown
        ? settlement.cycles.sublist(settlement.cycles.length - _shown)
        : settlement.cycles;
    final month = DateFormat.MMM(locale);
    final day = DateFormat.yMMMd(locale);
    // The open cycle is labelled by the month it will be debited in, else
    // the month after the last settlement.
    String label(SettlementCycle cycle) {
      final date =
          cycle.settledOn ?? settlement.nextDebitDate ?? DateTime.now();
      return month.format(date);
    }

    return CycleBars(
      key: const Key('accountDetailCycleChart'),
      values: [for (final cycle in cycles) -cycle.amountMinor],
      labels: [for (final cycle in cycles) label(cycle)],
      lastInProgress: cycles.isNotEmpty && cycles.last.inProgress,
      valueLabel: _compactMoney(context, currency),
      tooltips: [
        for (final cycle in cycles)
          TextSpan(
            children: [
              TextSpan(
                text:
                    '${formatAmount(amountMinor: cycle.amountMinor, currency: currency, locale: locale)}\n',
                style: tabularNumberStyle(
                  textTheme.titleSmall!,
                ).copyWith(color: AppColors.negative),
              ),
              TextSpan(
                text: cycle.settledOn == null
                    ? l10n.accountDetailCycleOpen
                    : l10n.accountDetailCycleSettledOn(
                        day.format(cycle.settledOn!),
                      ),
                style: textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// The chart's own empty state, inside the card's silhouette, so the page
/// doesn't restructure when the second month arrives.
class _ChartEmpty extends StatelessWidget {
  const _ChartEmpty();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    return Center(
      key: const Key('accountDetailChartEmpty'),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const GlyphPlate(icon: Icons.show_chart_rounded),
            const SizedBox(height: 14),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Text(
                l10n.accountDetailChartEmpty,
                textAlign: TextAlign.center,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm + 2),
            TextButton.icon(
              key: const Key('accountDetailImportCta'),
              onPressed: () => context.go(ImportsScreen.path),
              style: TextButton.styleFrom(foregroundColor: AppColors.iris),
              icon: const Icon(Icons.download_rounded, size: 16),
              label: Text(l10n.accountDetailImportCta),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatRow {
  const _StatRow({
    required this.label,
    required this.amountMinor,
    this.rising = false,
  });

  final String label;

  /// `null` when there is nothing to measure yet.
  final int? amountMinor;
  final bool rising;
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({
    required this.title,
    required this.rows,
    required this.currency,
    this.note,
  });

  final String title;
  final List<_StatRow> rows;
  final String currency;

  /// An encouraging line, said only when it is true.
  final String? note;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final valueStyle = textTheme.headlineMedium!.copyWith(fontSize: 20);

    return AppCard(
      key: const Key('accountDetailStats'),
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 24,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                title.toUpperCase(),
                style: AppTextStyles.sectionLabel,
              ),
            ),
          ),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.borderSubtle),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rows[i].label,
                    style: textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (rows[i].rising) ...[
                        const Icon(
                          Icons.arrow_upward_rounded,
                          size: 16,
                          color: AppColors.positive,
                        ),
                        const SizedBox(width: 6),
                      ],
                      Flexible(
                        child: rows[i].amountMinor == null
                            ? Text(
                                l10n.accountDetailNoStats,
                                style: valueStyle.copyWith(
                                  color: AppColors.textDisabled,
                                ),
                              )
                            : AmountText(
                                amountMinor: rows[i].amountMinor!,
                                currency: currency,
                                showPositiveSign: true,
                                maxLines: 1,
                                style: valueStyle,
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const Spacer(),
          if (note case final note?)
            Row(
              key: const Key('accountDetailStreak'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.trending_up_rounded,
                    size: 14,
                    color: AppColors.iris,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    note,
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _PeriodStatsCard extends StatelessWidget {
  const _PeriodStatsCard({required this.overview});

  final AccountOverview overview;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final period = overview.period;
    // An account with no history yet has nothing to measure: dashes, not zeros
    // that would read as a year of standing still.
    final measured = overview.firstTransactionDate != null;

    return _StatsCard(
      title: l10n.accountDetailPeriodLabel,
      currency: overview.account.currency,
      rows: [
        _StatRow(
          label: l10n.accountDetailChange,
          amountMinor: measured ? period.changeMinor : null,
          rising: measured && period.changeMinor > 0,
        ),
        _StatRow(
          label: l10n.accountDetailInflow,
          amountMinor: measured ? period.inflowMinor : null,
        ),
        _StatRow(
          label: l10n.accountDetailOutflow,
          amountMinor: measured ? period.outflowMinor : null,
        ),
      ],
      note: period.isOnStreak
          ? l10n.accountDetailRisingStreak(period.consecutiveRisingMonths)
          : null,
    );
  }
}

class _CycleStatsCard extends StatelessWidget {
  const _CycleStatsCard({required this.settlement, required this.currency});

  final CardSettlement settlement;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final month = DateFormat.yMMM(_locale(context));
    final highest = settlement.highestClosed;
    final last = settlement.lastClosed;
    final falling = settlement.consecutiveFallingCycles;

    String monthOf(SettlementCycle? cycle) =>
        cycle?.settledOn == null ? '—' : month.format(cycle!.settledOn!);

    return _StatsCard(
      title: l10n.accountDetailCyclesPeriod,
      currency: currency,
      rows: [
        _StatRow(
          label: l10n.accountDetailCycleAverage,
          amountMinor: settlement.averageClosedMinor,
        ),
        _StatRow(
          label: l10n.accountDetailCycleHighest(monthOf(highest)),
          amountMinor: highest?.amountMinor,
        ),
        _StatRow(
          label: l10n.accountDetailCycleLast(monthOf(last)),
          amountMinor: last?.amountMinor,
        ),
      ],
      note: falling >= 2 ? l10n.accountDetailFallingStreak(falling) : null,
    );
  }
}

// ── Row 3: linked cards, or a card's settlement account ─────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    super.key,
    required this.title,
    required this.caption,
    required this.children,
  });

  final String title;
  final String caption;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      key: key,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppSpacing.md - 4,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              Text(
                title,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                caption,
                style: textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _LinkedCardsSection extends ConsumerWidget {
  const _LinkedCardsSection({required this.overview});

  final AccountOverview overview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final cards = overview.linkedCards;

    return _SectionCard(
      key: const Key('accountDetailLinkedCards'),
      title: l10n.accountDetailLinkedTitle,
      caption: l10n.accountDetailLinkedCaption,
      children: [
        if (cards.isEmpty)
          _DashedRow(
            key: const Key('accountDetailNoCards'),
            icon: Icons.credit_card_rounded,
            text: l10n.accountDetailNoCards,
          )
        else
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.borderSubtle),
            _LinkedCardRow(
              card: cards[i],
              currency: overview.account.currency,
              accountId: overview.account.id,
            ),
          ],
      ],
    );
  }
}

class _LinkedCardRow extends ConsumerWidget {
  const _LinkedCardRow({
    required this.card,
    required this.currency,
    required this.accountId,
  });

  final LinkedCard card;
  final String currency;

  /// The account being viewed — refreshed once a rule is saved for the card.
  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final digits = card.cardLastDigits;
    final debit = card.nextDebitDate;
    // Watched rather than read on tap, so the card's account is loaded by
    // the time the rule dialog needs it.
    final cardAccount = ref.watch(accountByIdProvider(card.accountId));

    return _HoverRow(
      key: Key('accountDetailLinkedCard-${card.accountId}'),
      onTap: () => context.go(AccountDetailScreen.location(card.accountId)),
      child: Row(
        children: [
          InstitutionAvatar(name: card.institution, size: 36),
          const SizedBox(width: 14),
          Expanded(
            child: Wrap(
              spacing: AppSpacing.sm + 2,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(card.name, style: textTheme.titleSmall),
                if (digits != null)
                  Text(
                    l10n.accountDetailMaskedNumber(digits),
                    style: tabularNumberStyle(
                      textTheme.bodyMedium!,
                    ).copyWith(color: AppColors.textSecondary),
                  ),
                AppChip(
                  label: accountTypeLabel(l10n, AccountType.deferredCard),
                ),
                if (!card.hasRule && cardAccount != null)
                  InkWell(
                    key: Key('accountDetailRuleMissing-${card.accountId}'),
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                    onTap: () => _openRule(context, ref, cardAccount),
                    child: AppChip(
                      label: l10n.accountDetailRuleMissing,
                      color: AppColors.warning,
                      icon: Icons.warning_amber_rounded,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    l10n.accountDetailThisCycle,
                    style: textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w400,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  AmountText(
                    amountMinor: card.cycleMinor,
                    currency: currency,
                    style: textTheme.titleMedium!.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                debit == null
                    ? l10n.accountDetailNoDebitScheduled
                    : l10n.accountDetailDebitOn(
                        DateFormat.MMMd(_locale(context)).format(debit),
                      ),
                style: textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.sm),
          Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: AppColors.textSecondary,
            semanticLabel: l10n.accountDetailOpenAccount(card.name),
          ),
        ],
      ),
    );
  }

  Future<void> _openRule(
    BuildContext context,
    WidgetRef ref,
    Account cardAccount,
  ) async {
    final saved = await showSettlementRuleDialog(context, cardAccount);
    if (saved) ref.invalidate(accountOverviewProvider(accountId));
  }
}

class _SettlementSection extends ConsumerWidget {
  const _SettlementSection({required this.card, required this.settlement});

  final Account card;
  final CardSettlement settlement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final paying = ref.watch(accountByIdProvider(settlement.payingAccountId));
    final rule = settlement.rule;
    final locale = _locale(context);

    final String ruleText;
    if (rule == null || !rule.enabled) {
      ruleText = l10n.accountDetailNoRule;
    } else if (rule.appliesFrom case final from?) {
      ruleText = l10n.accountDetailRuleSummary(
        rule.pattern,
        DateFormat.yMMMd(locale).format(from),
      );
    } else {
      ruleText = l10n.accountDetailRuleSummaryUndated(rule.pattern);
    }

    return _SectionCard(
      key: const Key('accountDetailSettlement'),
      title: l10n.accountDetailSettleTitle,
      caption: l10n.accountDetailSettleCaption,
      children: [
        if (paying == null)
          _DashedRow(
            icon: Icons.account_balance_outlined,
            text: l10n.accountDetailNoPayingAccount,
          )
        else
          _HoverRow(
            key: Key('accountDetailPayingAccount-${paying.id}'),
            onTap: () => context.go(AccountDetailScreen.location(paying.id)),
            child: Row(
              children: [
                InstitutionAvatar(name: paying.institution, size: 36),
                const SizedBox(width: 14),
                Expanded(
                  child: Wrap(
                    spacing: AppSpacing.sm + 2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(paying.name, style: textTheme.titleSmall),
                      AppChip(label: accountTypeLabel(l10n, paying.type)),
                    ],
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    AmountText(
                      amountMinor: paying.balanceMinor,
                      currency: paying.currency,
                      showPositiveSign: true,
                      style: textTheme.titleMedium!.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.accountDetailBalanceLabel,
                      style: textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: AppSpacing.sm),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppColors.textSecondary,
                  semanticLabel: l10n.accountDetailOpenAccount(paying.name),
                ),
              ],
            ),
          ),
        const Divider(height: 1, color: AppColors.borderSubtle),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              const Icon(
                Icons.sell_outlined,
                size: 14,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  ruleText,
                  key: const Key('accountDetailRuleSummary'),
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              TextButton(
                key: const Key('accountDetailEditRule'),
                onPressed: () async {
                  final saved = await showSettlementRuleDialog(context, card);
                  if (saved) ref.invalidate(accountOverviewProvider(card.id));
                },
                style: TextButton.styleFrom(foregroundColor: AppColors.iris),
                child: Text(
                  rule == null
                      ? l10n.accountDetailSetUpRule
                      : l10n.accountDetailEditRule,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Row 4: recent transactions ──────────────────────────────────────────────

class _RecentTransactionsCard extends ConsumerWidget {
  const _RecentTransactionsCard({required this.accountId});

  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final transactions = ref.watch(
      recentAccountTransactionsProvider(accountId),
    );

    return AppCard(
      key: const Key('accountDetailRecent'),
      padding: const EdgeInsets.fromLTRB(22, 18, 22, AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 28,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.accountDetailRecentTitle,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  key: const Key('accountDetailSeeAll'),
                  onPressed: () {
                    ref
                        .read(transactionFiltersProvider.notifier)
                        .setAccount(accountId);
                    context.go(TransactionsScreen.path);
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.iris,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(l10n.accountDetailSeeAll),
                      const Icon(Icons.chevron_right_rounded, size: 14),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // Matched on the value, not the state: a re-read after a category
          // edit keeps the rows on screen instead of a skeleton.
          switch (transactions) {
            AsyncValue(:final value?) when value.isEmpty => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _DashedRow(
                key: const Key('accountDetailNoTransactions'),
                icon: Icons.swap_vert_rounded,
                text: l10n.accountDetailNoTransactions,
              ),
            ),
            AsyncValue(:final value?) => Column(
              children: [
                for (final transaction in value) ...[
                  const Divider(height: 1, color: AppColors.borderSubtle),
                  // The account is the one on screen, so the row's second line
                  // keeps only the bank's memo.
                  TransactionRow(transaction: transaction, accountName: ''),
                ],
              ],
            ),
            AsyncError(:final error) => Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Text(
                localizeAccountError(l10n, error),
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            _ => SkeletonPulse(
              child: Column(
                children: [
                  for (var i = 0; i < 3; i++)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: SkeletonBlock(height: 32, radius: AppRadii.sm),
                    ),
                ],
              ),
            ),
          },
        ],
      ),
    );
  }
}

// ── Shared bits ─────────────────────────────────────────────────────────────

/// A 64px tappable row with the in-card hover wash.
class _HoverRow extends StatefulWidget {
  const _HoverRow({super.key, required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  State<_HoverRow> createState() => _HoverRowState();
}

class _HoverRowState extends State<_HoverRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.surfaceRowHover : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// A dashed, disabled-tone row: the section is there, it is just empty — never
/// hidden, never an alarm.
class _DashedRow extends StatelessWidget {
  const _DashedRow({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md - 4),
      child: DashedBorder(
        strokeWidth: 1.5,
        child: SizedBox(
          height: 56,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: AppColors.textDisabled),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textDisabled,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shimmer blocks on the silhouette of the populated panel, so nothing moves
/// when the data lands.
class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return const SkeletonPulse(
      key: Key('accountDetailLoading'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SkeletonBlock(height: 172),
          SizedBox(height: AppSpacing.gridGap),
          SizedBox(
            height: _chartRowHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 2,
                  child: SkeletonBlock(height: _chartRowHeight),
                ),
                SizedBox(width: AppSpacing.gridGap),
                Expanded(child: SkeletonBlock(height: _chartRowHeight)),
              ],
            ),
          ),
          SizedBox(height: AppSpacing.gridGap),
          SkeletonBlock(height: 190),
          SizedBox(height: AppSpacing.gridGap),
          SkeletonBlock(height: 478),
        ],
      ),
    );
  }
}
