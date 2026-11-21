import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../../core/l10n/card_display.dart';
import '../../../core/l10n/category_display.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_segmented.dart';
import '../../../core/widgets/app_table.dart';
import '../../../core/widgets/bar_charts.dart';
import '../../../core/widgets/category_label.dart';
import '../../../core/widgets/institution_avatar.dart';
import '../../../core/widgets/line_area_chart.dart';
import '../../../core/widgets/monogram_avatar.dart';
import '../../../core/widgets/note_line.dart';
import '../../../core/widgets/section_heading.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_text.dart';
import '../../../l10n/app_localizations.dart';
import '../../imports/application/imports_controller.dart';
import '../../imports/presentation/imports_screen.dart';
import '../../transactions/application/transactions_controller.dart';
import '../../transactions/domain/transaction.dart';
import '../../transactions/presentation/transactions_screen.dart';
import '../application/account_detail_controller.dart';
import '../domain/account.dart';
import '../domain/account_overview.dart';
import 'account_error_localizer.dart';
import 'account_type_label.dart';
import 'link_card_dialog.dart';
import 'settlement_rule_dialog.dart';

/// One account, in depth (`docs/design/16-account-detail.md`): a summary
/// line, the month-end balance chart, the deferred cards on either side of
/// it, and its latest operations. Sections separated by space and a
/// hairline, no card around any of them (`00` §1).
///
/// A view *within* « Comptes »: the sidebar keeps that section selected and
/// the title bar names the account under a « Comptes / » crumb.
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
        horizontal: AppSpacing.pageX,
        vertical: AppSpacing.pageY,
      ),
      children: switch (overview) {
        AsyncData(:final value) => [
          _SummaryLine(overview: value),
          const _SectionBreak(),
          _ChartBlock(overview: value),
          if (value.settlement case final settlement?) ...[
            const _SectionBreak(),
            _SettlementBlock(card: value.account, settlement: settlement),
          ] else if (value.linkedCards.isNotEmpty) ...[
            const _SectionBreak(),
            _LinkedCardsBlock(overview: value),
          ],
          const _SectionBreak(),
          _OperationsBlock(accountId: accountId),
        ],
        AsyncError(:final error) => [
          SizedBox(
            height: 420,
            child: ErrorStateView(
              message: localizeAccountError(l10n, error),
              messageKey: const Key('accountDetailErrorText'),
              retryLabel: l10n.accountsRetry,
              retryKey: const Key('accountDetailRetryButton'),
              onRetry: () => ref.invalidate(accountOverviewProvider(accountId)),
            ),
          ),
        ],
        _ => const [_DetailSkeleton()],
      },
    );
  }
}

String _locale(BuildContext context) =>
    Localizations.localeOf(context).toString();

/// The chart's height, its 22 px category axis included.
const _chartHeight = 220.0;

/// The room the summary line keeps for its two right-hand lines, which wrap
/// within it.
const _factsMinWidth = 240.0;

/// The fixed widths of the tables' right-hand columns.
const _dateColumn = 96.0;
const _amountColumn = 136.0;
const _chevronColumn = AppSizes.icon + AppSpacing.smPlus;

/// 24 px, a hairline, 24 px: the gap between two sections (`00` §1.2).
class _SectionBreak extends StatelessWidget {
  const _SectionBreak();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.section),
    child: Divider(height: 1, thickness: 1, color: context.colors.line),
  );
}

// ── 1. Summary line ─────────────────────────────────────────────────────────

/// One item of the summary line (`00` §7): a 12 `textSecondary` label over
/// its figure.
class _SummaryItem extends StatelessWidget {
  const _SummaryItem({super.key, required this.label, required this.figure});

  final String label;
  final Widget figure;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.end,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: context.textStyles.statLabel),
      const SizedBox(height: AppSpacing.xs),
      figure,
    ],
  );
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.overview});

  final AccountOverview overview;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final locale = _locale(context);
    final account = overview.account;
    final currency = account.currency;
    final settlement = overview.settlement;
    final minor = tabularNumberStyle(textTheme.headlineMedium!);

    Widget amount(int? value) => value == null
        ? Text(l10n.accountDetailNoStats, style: minor)
        : AmountText(
            amountMinor: value,
            currency: currency,
            showPositiveSign: true,
            colorize: false,
            maxLines: 1,
            style: minor,
          );

    // The headline is the one place a positive balance takes `positive`
    // (`00` §2.3); a card's open cycle is spending, so it reads `negative`.
    final lead = _SummaryItem(
      key: const Key('accountDetailHeadline'),
      label: settlement == null
          ? l10n.accountDetailBalanceOn(
              DateFormat.yMMMMd(
                locale,
              ).format(overview.balanceDate ?? DateTime.now()),
            )
          : l10n.accountDetailCycleLabel,
      figure: AmountText(
        amountMinor: settlement?.currentCycleMinor ?? account.balanceMinor,
        currency: currency,
        showPositiveSign: true,
        maxLines: 1,
        style: tabularNumberStyle(textTheme.displayLarge!),
      ),
    );

    final List<Widget> items;
    if (settlement == null) {
      final month = DateFormat.MMMM(locale).format(overview.month.since);
      items = [
        _SummaryItem(
          key: const Key('accountDetailMonthInflow'),
          label: l10n.accountDetailMonthInflow(month),
          figure: amount(overview.month.inflowMinor),
        ),
        _SummaryItem(
          key: const Key('accountDetailMonthOutflow'),
          label: l10n.accountDetailMonthOutflow(month),
          figure: amount(overview.month.outflowMinor),
        ),
        _SummaryItem(
          key: const Key('accountDetailMonthNet'),
          label: l10n.accountDetailNet,
          figure: amount(overview.month.netMinor),
        ),
      ];
    } else {
      final debit = settlement.nextDebitDate;
      items = [
        _SummaryItem(
          key: const Key('accountDetailPreviousCycle'),
          label: l10n.accountDetailPreviousCycle,
          figure: amount(settlement.lastClosed?.amountMinor),
        ),
        _SummaryItem(
          key: const Key('accountDetailCycleAverage'),
          label: l10n.accountDetailCycleAverage(averagedCycles),
          figure: amount(settlement.averageClosedMinor),
        ),
        _SummaryItem(
          key: const Key('accountDetailDebitDate'),
          label: l10n.accountDetailDebitDateLabel,
          figure: Text(
            debit == null
                ? l10n.accountDetailNoStats
                : DateFormat.MMMd(locale).format(debit),
            style: minor,
          ),
        ),
      ];
    }

    // The figures share one height, so the hairlines between them run from
    // the top of the lead label to the foot of the figures.
    final figures = IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          lead,
          for (final item in items) ...[
            const SizedBox(width: AppSpacing.xxl / 2),
            VerticalDivider(width: 1, thickness: 1, color: context.colors.line),
            const SizedBox(width: AppSpacing.xxl / 2),
            item,
          ],
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) => Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // At 1440 px the figures fit at their size; a narrower window
          // shrinks them rather than truncating a figure.
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: constraints.maxWidth - _factsMinWidth - AppSpacing.xxl,
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.bottomLeft,
              child: figures,
            ),
          ),
          const SizedBox(width: AppSpacing.xxl),
          Expanded(child: _AccountFacts(overview: overview)),
        ],
      ),
    );
  }
}

/// The two right-aligned lines closing the summary line: the bank and type,
/// then how far the history goes and when it was last imported. French runs
/// long: they wrap, never truncate.
class _AccountFacts extends ConsumerWidget {
  const _AccountFacts({required this.overview});

  final AccountOverview overview;

  /// Opens Imports on this account's history alone.
  void _openImports(BuildContext context, WidgetRef ref) {
    final account = overview.account;
    ref
        .read(importHistoryAccountProvider.notifier)
        .show(ImportHistoryAccountFilter(id: account.id, name: account.name));
    context.go(ImportsScreen.path);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final style = context.textStyles.statLabel;
    final date = DateFormat.yMMMd(_locale(context));
    final account = overview.account;
    final first = overview.firstTransactionDate;
    final imported = overview.lastImportAt;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          l10n.accountDetailIdentity(
            account.institution,
            accountTypeLabel(l10n, account.type),
          ),
          textAlign: TextAlign.end,
          style: style,
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          key: const Key('accountDetailHistory'),
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              first == null
                  ? l10n.accountDetailNoHistory
                  : l10n.accountDetailHistorySince(date.format(first)),
              style: tabularNumberStyle(style),
            ),
            if (first != null && imported != null) ...[
              Text(l10n.accountDetailMetaSeparator, style: style),
              _Link(
                key: const Key('accountDetailLastImport'),
                label: l10n.accountDetailLastImport(
                  DateFormat.MMMd(_locale(context)).format(imported.toLocal()),
                ),
                small: true,
                onTap: () => _openImports(context, ref),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

// ── 2. Balance chart, or a card's cycles ────────────────────────────────────

class _ChartBlock extends ConsumerWidget {
  const _ChartBlock({required this.overview});

  final AccountOverview overview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final accountId = overview.account.id;
    final settlement = overview.settlement;
    final hasData = settlement == null
        ? overview.hasChartHistory
        : settlement.cycles.isNotEmpty;

    return Column(
      key: const Key('accountDetailChart'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeading(
          title: settlement == null
              ? l10n.accountDetailBalanceChartTitle
              : l10n.accountDetailCyclesChartTitle,
          trailing: hasData
              ? AppSegmented<BalanceRange>(
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
                  value: ref.watch(balanceRangeControllerProvider(accountId)),
                  onChanged: ref
                      .read(balanceRangeControllerProvider(accountId).notifier)
                      .select,
                )
              : null,
        ),
        const SizedBox(height: AppSpacing.xs),
        if (!hasData)
          const _ChartEmpty()
        else ...[
          SizedBox(
            height: _chartHeight,
            child: settlement == null
                ? _BalanceChart(
                    accountId: accountId,
                    currency: overview.account.currency,
                    history: overview.balanceHistory,
                  )
                : _CycleChart(
                    accountId: accountId,
                    settlement: settlement,
                    currency: overview.account.currency,
                  ),
          ),
          // Said only when true; never a sentence about a decline.
          if (settlement == null && overview.period.isOnStreak) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.accountDetailRisingStreak(
                overview.period.consecutiveRisingMonths,
              ),
              key: const Key('accountDetailStreak'),
              style: context.textStyles.statLabel,
            ),
          ],
        ],
      ],
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

/// Past a year the axis labels every other period, anchored on the latest,
/// so it never crowds.
String _axisLabel(int index, int count, String label) =>
    count > 12 && (count - 1 - index).isOdd ? '' : label;

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
    final textTheme = Theme.of(context).textTheme;
    final colors = context.colors;
    final locale = _locale(context);
    final points = ref.watch(visibleBalanceHistoryProvider(accountId));
    // The first visible point's predecessor sits outside the range, but its
    // change is still real; only the very first month has none.
    final offset = history.length - points.length;
    final month = DateFormat.MMM(locale);
    final title = DateFormat.yMMMM(locale);

    InlineSpan tooltip(int i) {
      final delta = offset + i == 0
          ? null
          : points[i].balanceMinor - history[offset + i - 1].balanceMinor;
      return TextSpan(
        children: [
          TextSpan(
            text: '${title.format(points[i].monthEnd)}\n',
            style: textTheme.labelSmall?.copyWith(color: colors.textSecondary),
          ),
          TextSpan(
            text:
                '${formatAmount(amountMinor: points[i].balanceMinor, currency: currency, locale: locale)}\n',
            style: tabularNumberStyle(textTheme.titleSmall!),
          ),
          TextSpan(
            text: delta == null
                ? l10n.accountDetailTooltipFirstMonth
                : l10n.accountDetailTooltipDelta(
                    formatAmount(
                      amountMinor: delta,
                      currency: currency,
                      locale: locale,
                      showPositiveSign: true,
                    ),
                  ),
            style: tabularNumberStyle(textTheme.labelSmall!).copyWith(
              color: switch (delta) {
                null || 0 => colors.textSecondary,
                > 0 => colors.positive,
                _ => colors.negative,
              },
            ),
          ),
        ],
      );
    }

    return LineAreaChart(
      key: const Key('accountDetailBalanceChart'),
      // Minor units: no gridline on cents.
      minStep: 100,
      values: [for (final point in points) point.balanceMinor],
      labels: [
        for (var i = 0; i < points.length; i++)
          _axisLabel(i, points.length, month.format(points[i].monthEnd)),
      ],
      valueLabel: _compactMoney(context, currency),
      tooltips: [for (var i = 0; i < points.length; i++) tooltip(i)],
    );
  }
}

class _CycleChart extends ConsumerWidget {
  const _CycleChart({
    required this.accountId,
    required this.settlement,
    required this.currency,
  });

  final String accountId;
  final CardSettlement settlement;
  final String currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final colors = context.colors;
    final locale = _locale(context);
    final cycles = ref
        .watch(balanceRangeControllerProvider(accountId))
        .slice(settlement.cycles);
    final month = DateFormat.MMM(locale);
    final day = DateFormat.yMMMd(locale);
    // The open cycle is labelled by the month it will be debited in, else
    // the month after the last settlement.
    String label(SettlementCycle cycle) => month.format(
      cycle.settledOn ?? settlement.nextDebitDate ?? DateTime.now(),
    );

    return SignedBarChart(
      key: const Key('accountDetailCycleChart'),
      minStep: 100,
      values: [for (final cycle in cycles) cycle.amountMinor],
      labels: [
        for (var i = 0; i < cycles.length; i++)
          _axisLabel(i, cycles.length, label(cycles[i])),
      ],
      // The cycle still open is not yet a fact: hatched.
      provisional: {
        for (var i = 0; i < cycles.length; i++)
          if (cycles[i].inProgress) i,
      },
      valueLabel: _compactMoney(context, currency),
      tooltips: [
        for (final cycle in cycles)
          TextSpan(
            children: [
              TextSpan(
                text: cycle.settledOn == null
                    ? '${l10n.accountDetailCycleOpen}\n'
                    : '${l10n.accountDetailCycleSettledOn(day.format(cycle.settledOn!))}\n',
                style: textTheme.labelSmall?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              TextSpan(
                text: formatAmount(
                  amountMinor: cycle.amountMinor,
                  currency: currency,
                  locale: locale,
                ),
                style: tabularNumberStyle(
                  textTheme.titleSmall!,
                ).copyWith(color: colors.negative),
              ),
            ],
          ),
      ],
    );
  }
}

/// Less than two months of history: a note saying when the chart appears,
/// and the way to get there.
class _ChartEmpty extends StatelessWidget {
  const _ChartEmpty();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      key: const Key('accountDetailChartEmpty'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NoteLine(text: l10n.accountDetailChartEmpty),
        const SizedBox(height: AppSpacing.smPlus),
        AppButton(
          key: const Key('accountDetailImportCta'),
          label: l10n.accountDetailImportCta,
          icon: LucideIcons300.download,
          onPressed: () => context.go(ImportsScreen.path),
        ),
      ],
    );
  }
}

// ── 3. Linked cards, or a card's settlement account ─────────────────────────

const _cardColumns = [
  AppTableColumn(label: '', flex: 3),
  AppTableColumn(label: '', flex: 2),
  AppTableColumn(label: '', width: 168, numeric: true),
  AppTableColumn(label: '', width: _chevronColumn, numeric: true),
];

class _LinkedCardsBlock extends ConsumerWidget {
  const _LinkedCardsBlock({required this.overview});

  final AccountOverview overview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    // Offered only when there is a card to link, and never on an archived
    // account, which can no longer settle one.
    final canLink =
        !overview.account.archived &&
        ref.watch(linkableCardsProvider).isNotEmpty;

    return Column(
      key: const Key('accountDetailLinkedCards'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeading(
          title: l10n.accountDetailLinkedTitle,
          trailing: canLink
              ? _Link(
                  key: const Key('accountDetailLinkCard'),
                  label: l10n.accountDetailLinkCard,
                  onTap: () => showLinkCardDialog(context, overview.account),
                )
              : null,
        ),
        for (final card in overview.linkedCards)
          _LinkedCardRow(
            card: card,
            currency: overview.account.currency,
            accountId: overview.account.id,
          ),
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

  /// The account being viewed, refreshed once a rule is saved for the card.
  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final colors = context.colors;
    final digits = card.cardLastDigits;
    final debit = card.nextDebitDate;
    // Watched rather than read on tap, so the card's account is loaded by
    // the time the rule dialog needs it.
    final cardAccount = ref.watch(accountByIdProvider(card.accountId));

    return AppTableRow(
      key: Key('accountDetailLinkedCard-${card.accountId}'),
      columns: _cardColumns,
      twoLines: true,
      onTap: () => context.go(AccountDetailScreen.location(card.accountId)),
      cells: [
        Row(
          children: [
            MonogramAvatar(name: card.name),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(card.name, maxLines: 1),
                  if (digits != null)
                    Text(
                      l10n.accountDetailMaskedNumber(digits),
                      maxLines: 1,
                      style: tabularNumberStyle(
                        textTheme.bodySmall!,
                      ).copyWith(color: colors.textTertiary),
                    ),
                ],
              ),
            ),
          ],
        ),
        Row(
          children: [
            Text(
              l10n.accountDetailDeferredDebit,
              style: textTheme.bodyMedium?.copyWith(
                color: colors.textSecondary,
              ),
            ),
            if (!card.hasRule && cardAccount != null) ...[
              const SizedBox(width: AppSpacing.smPlus),
              Flexible(
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    key: Key('accountDetailRuleMissing-${card.accountId}'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _openRule(context, ref, cardAccount),
                    child: StatusText(
                      label: l10n.accountDetailRuleMissing,
                      tone: StatusTone.warning,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            AmountText(
              amountMinor: card.cycleMinor,
              currency: currency,
              maxLines: 1,
              style: tabularNumberStyle(textTheme.bodyMedium!),
            ),
            Text(
              debit == null
                  ? l10n.accountDetailNoDebitScheduled
                  : l10n.accountDetailDebitOn(
                      DateFormat.MMMd(_locale(context)).format(debit),
                    ),
              maxLines: 1,
              style: context.textStyles.helper,
            ),
          ],
        ),
        Icon(
          LucideIcons300.chevronRight,
          size: AppSizes.icon,
          color: colors.textTertiary,
          semanticLabel: l10n.accountDetailOpenAccount(card.name),
        ),
      ],
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

const _payingColumns = [
  AppTableColumn(label: ''),
  AppTableColumn(label: '', width: _amountColumn, numeric: true),
  AppTableColumn(label: '', width: _chevronColumn, numeric: true),
];

class _SettlementBlock extends ConsumerWidget {
  const _SettlementBlock({required this.card, required this.settlement});

  final Account card;
  final CardSettlement settlement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final colors = context.colors;
    final paying = ref.watch(accountByIdProvider(settlement.payingAccountId));
    final rule = settlement.rule;
    final ruleActive = rule != null && rule.enabled;

    final String? ruleText;
    if (!ruleActive) {
      ruleText = null;
    } else if (rule.appliesFrom case final from?) {
      ruleText = l10n.accountDetailRuleSummary(
        rule.pattern,
        DateFormat.yMMMd(_locale(context)).format(from),
      );
    } else {
      ruleText = l10n.accountDetailRuleSummaryUndated(rule.pattern);
    }

    return Column(
      key: const Key('accountDetailSettlement'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeading(title: l10n.accountDetailSettleTitle),
        if (paying == null)
          NoteLine(text: l10n.accountDetailNoPayingAccount)
        else
          AppTableRow(
            key: Key('accountDetailPayingAccount-${paying.id}'),
            columns: _payingColumns,
            onTap: () => context.go(AccountDetailScreen.location(paying.id)),
            cells: [
              Row(
                children: [
                  MonogramAvatar(name: paying.name),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(child: Text(paying.name)),
                ],
              ),
              // A balance in a row is neutral unless negative (`00` §2.3).
              AmountText(
                amountMinor: paying.balanceMinor,
                currency: paying.currency,
                colorize: paying.balanceMinor < 0,
                maxLines: 1,
                style: tabularNumberStyle(
                  textTheme.bodyMedium!,
                ).copyWith(color: paying.balanceMinor < 0 ? null : colors.text),
              ),
              Icon(
                LucideIcons300.chevronRight,
                size: AppSizes.icon,
                color: colors.textTertiary,
                semanticLabel: l10n.accountDetailOpenAccount(paying.name),
              ),
            ],
          ),
        const SizedBox(height: AppSpacing.smPlus),
        Row(
          children: [
            Expanded(
              child: ruleText == null
                  ? Align(
                      alignment: Alignment.centerLeft,
                      child: StatusText(
                        key: const Key('accountDetailRuleSummary'),
                        label: l10n.accountDetailRuleMissing,
                        tone: StatusTone.warning,
                      ),
                    )
                  : Text(
                      ruleText,
                      key: const Key('accountDetailRuleSummary'),
                      style: context.textStyles.statLabel,
                    ),
            ),
            const SizedBox(width: AppSpacing.md),
            AppButton(
              key: const Key('accountDetailEditRule'),
              label: rule == null
                  ? l10n.accountDetailSetUpRule
                  : l10n.accountDetailEditRule,
              onPressed: () async {
                final saved = await showSettlementRuleDialog(context, card);
                if (saved) ref.invalidate(accountOverviewProvider(card.id));
              },
            ),
          ],
        ),
      ],
    );
  }
}

// ── 4. Operations ───────────────────────────────────────────────────────────

class _OperationsBlock extends ConsumerWidget {
  const _OperationsBlock({required this.accountId});

  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final transactions = ref.watch(
      recentAccountTransactionsProvider(accountId),
    );
    final cards = ref.watch(linkedCardsByIdProvider(accountId));
    final columns = [
      AppTableColumn(label: l10n.accountDetailColumnOperation, flex: 3),
      AppTableColumn(label: l10n.accountDetailColumnCategory, flex: 2),
      AppTableColumn(
        label: l10n.accountDetailColumnDate,
        width: _dateColumn,
        numeric: true,
      ),
      AppTableColumn(
        label: l10n.accountDetailColumnAmount,
        width: _amountColumn,
        numeric: true,
      ),
    ];

    return Column(
      key: const Key('accountDetailRecent'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeading(
          title: l10n.accountDetailRecentTitle,
          trailing: _Link(
            key: const Key('accountDetailSeeAll'),
            label: l10n.accountDetailSeeAll,
            small: true,
            onTap: () {
              ref.read(transactionFiltersProvider.notifier)
                ..setAccount(accountId)
                ..clearImport();
              context.go(TransactionsScreen.path);
            },
          ),
        ),
        // Matched on the value, not the state: a re-read after a category
        // edit elsewhere keeps the rows on screen instead of a skeleton.
        switch (transactions) {
          AsyncValue(:final value?) when value.isEmpty => NoteLine(
            key: const Key('accountDetailNoTransactions'),
            text: l10n.accountDetailNoTransactions,
          ),
          AsyncValue(:final value?) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTableHeader(columns: columns),
              for (final transaction in value)
                _OperationRow(
                  transaction: transaction,
                  columns: columns,
                  card: cards[transaction.accountId],
                ),
            ],
          ),
          AsyncError(:final error) => NoteLine(
            icon: LucideIcons300.triangleAlert,
            text: localizeAccountError(l10n, error),
          ),
          _ => SkeletonPulse(
            child: Column(
              children: [
                for (var i = 0; i < 4; i++)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    child: SkeletonBlock(height: AppSizes.tableRow / 2),
                  ),
              ],
            ),
          ),
        },
      ],
    );
  }
}

class _OperationRow extends StatelessWidget {
  const _OperationRow({
    required this.transaction,
    required this.columns,
    required this.card,
  });

  final Transaction transaction;
  final List<AppTableColumn> columns;

  /// The linked card the row was paid with; `null` for the account's own.
  final LinkedCard? card;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final colors = context.colors;
    final label = transaction.merchant?.trim().isNotEmpty ?? false
        ? transaction.merchant!
        : transaction.descriptionClean;
    final category = transaction.category;
    final card = this.card;

    return AppTableRow(
      key: Key('transactionRow-${transaction.id}'),
      columns: columns,
      // A linked card's purchase names its card under the label.
      twoLines: card != null,
      cells: [
        Row(
          children: [
            InstitutionAvatar(name: label, logo: transaction.logo),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, maxLines: 1),
                  if (card != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          cardRowIcon,
                          key: const Key('transactionRowAccountIcon'),
                          size: AppSizes.iconStatus,
                          color: colors.textTertiary,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Flexible(
                          child: Text(
                            cardRowLabel(l10n, card.name, card.cardLastDigits),
                            maxLines: 1,
                            style: textTheme.bodySmall?.copyWith(
                              color: colors.textTertiary,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
        if (category == null)
          CategoryLabel.uncategorized(label: l10n.categoryUncategorized)
        else
          CategoryLabel(
            label: localizedCategoryName(l10n, category.name),
            slug: categorySlugFor(name: category.name, kind: category.kind),
          ),
        Text(
          DateFormat.MMMd(_locale(context)).format(transaction.bookedDate),
          style: tabularNumberStyle(
            textTheme.bodyMedium!,
          ).copyWith(color: colors.textSecondary),
        ),
        AmountText(
          amountMinor: transaction.amountMinor,
          currency: transaction.currency,
          showPositiveSign: true,
          maxLines: 1,
          style: tabularNumberStyle(textTheme.bodyMedium!),
        ),
      ],
    );
  }
}

// ── Shared bits ─────────────────────────────────────────────────────────────

/// A link (`00` §6): `accent`, 13 or 12 px, underlined on hover.
class _Link extends StatefulWidget {
  const _Link({
    super.key,
    required this.label,
    required this.onTap,
    this.small = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool small;

  @override
  State<_Link> createState() => _LinkState();
}

class _LinkState extends State<_Link> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final base = widget.small ? textTheme.bodySmall! : textTheme.bodyMedium!;
    final color = context.colors.accent;

    return Semantics(
      link: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: Text(
            widget.label,
            style: tabularNumberStyle(base).copyWith(
              color: color,
              decoration: _hovered ? TextDecoration.underline : null,
              decorationColor: color,
            ),
          ),
        ),
      ),
    );
  }
}

/// The populated panel's silhouette in `hover` blocks, pulsing as one, so
/// nothing moves when the data lands (`00` §7).
class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return SkeletonPulse(
      key: const Key('accountDetailLoading'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              SkeletonBlock(width: 240, height: 64),
              SizedBox(width: AppSpacing.xxl),
              SkeletonBlock(width: 120, height: 48),
              SizedBox(width: AppSpacing.xxl),
              SkeletonBlock(width: 120, height: 48),
              SizedBox(width: AppSpacing.xxl),
              SkeletonBlock(width: 120, height: 48),
            ],
          ),
          const _SectionBreak(),
          const SkeletonBlock(width: 160, height: 16),
          const SizedBox(height: AppSpacing.smPlus),
          const SkeletonBlock(height: _chartHeight),
          const _SectionBreak(),
          const SkeletonBlock(width: 160, height: 16),
          const SizedBox(height: AppSpacing.smPlus),
          for (var i = 0; i < 6; i++)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: SkeletonBlock(height: AppSizes.tableRow / 2),
            ),
        ],
      ),
    );
  }
}
