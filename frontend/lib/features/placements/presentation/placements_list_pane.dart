import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_table.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../core/widgets/monogram_avatar.dart';
import '../../../core/widgets/note_line.dart';
import '../../../core/widgets/status_text.dart';
import '../../../core/widgets/summary_line.dart';
import '../../../l10n/app_localizations.dart';
import '../application/placements_controller.dart';
import '../domain/investment.dart';
import 'placement_labels.dart';
import 'valuation_modal.dart';

/// The list pane of the Placements panel (`17-placements.md` §List pane),
/// top to bottom 20 px apart: the summary line, the table, the stale-value
/// banners, and the note at the bottom.
class PlacementsListPane extends ConsumerWidget {
  const PlacementsListPane({
    super.key,
    required this.state,
    required this.selected,
  });

  final PlacementsState state;

  /// The placement the inspector shows.
  final Investment? selected;

  static List<AppTableColumn> _columns(AppLocalizations l10n) => [
    AppTableColumn(label: l10n.placementsColumnPlacement),
    AppTableColumn(
      label: l10n.placementsColumnNetPayments,
      width: AppPlacements.netPaymentsColumn,
      numeric: true,
    ),
    AppTableColumn(
      label: l10n.placementsColumnValue,
      width: AppPlacements.valueColumn,
      numeric: true,
    ),
    AppTableColumn(
      label: l10n.placementsColumnGain,
      width: AppPlacements.gainColumn,
      numeric: true,
    ),
    AppTableColumn(
      label: l10n.placementsColumnValuedOn,
      width: AppPlacements.valuedOnColumn,
      numeric: true,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final controller = ref.read(placementsControllerProvider.notifier);
    final select = ref.read(selectedPlacementProvider.notifier).select;
    final stale = state.stale;
    final columns = _columns(l10n);

    return Padding(
      key: const Key('placementsListPane'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageX,
        vertical: AppSpacing.pageY,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SummaryLine(summary: state.summary),
          if (state.actionError != null) ...[
            const SizedBox(height: AppPlacements.listGap),
            InlineBanner(
              key: const Key('placementsActionError'),
              message: localizePlacementError(l10n, state.actionError),
              onDismiss: controller.clearActionError,
              dismissTooltip: l10n.placementsDismissBanner,
            ),
          ],
          const SizedBox(height: AppPlacements.listGap),
          Expanded(
            child: ListView(
              key: const Key('placementsList'),
              children: [
                AppTableHeader(columns: columns),
                for (final investment in state.investments)
                  _PlacementRow(
                    investment: investment,
                    columns: columns,
                    selected: investment.id == selected?.id,
                    onTap: () => select(investment.id),
                  ),
                for (final investment in stale.take(staleBannerLimit)) ...[
                  const SizedBox(height: AppPlacements.listGap),
                  InlineBanner(
                    key: Key('placementStaleBanner-${investment.id}'),
                    tone: BannerTone.warning,
                    icon: LucideIcons300.clockAlert,
                    message: l10n.placementsStaleBanner(investment.name),
                    actions: [
                      AppButton(
                        key: Key('placementStaleAction-${investment.id}'),
                        label: l10n.placementsStaleAction,
                        onPressed: () =>
                            showValuationModal(context, investment: investment),
                      ),
                    ],
                  ),
                ],
                if (stale.length > staleBannerLimit) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n.placementsStaleMore(stale.length - staleBannerLimit),
                    key: const Key('placementsStaleMore'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppPlacements.listGap),
          NoteLine(
            key: const Key('placementsNote'),
            icon: LucideIcons300.lock,
            text: l10n.placementsNote,
          ),
        ],
      ),
    );
  }
}

/// « Valeur déclarée » at 40 px, then « Versements nets » and « Plus-value
/// latente » at 20 px behind a vertical hairline (`00` §7 Summary line).
/// Every figure is neutral; the gain carries its sign.
class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.summary});

  final InvestmentSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final textTheme = Theme.of(context).textTheme;
    String money(int minor, {bool signed = false}) =>
        placementMoney(minor, summary.currency, locale, signed: signed);
    final lastValued = summary.lastValuedOn;
    final gainBps = summary.gainBps;
    final hasValue = summary.valuedCount > 0;

    Widget item({
      required Key key,
      required String label,
      required String figure,
      required TextStyle style,
      String? caption,
      Key? captionKey,
      Widget? below,
    }) => SummaryItem(
      label: label,
      labelGap: AppSpacing.xs,
      caption: caption,
      captionKey: captionKey,
      below: below,
      figure: Text(
        figure,
        key: key,
        maxLines: 1,
        style: tabularNumberStyle(style),
      ),
    );

    return IntrinsicHeight(
      key: const Key('placementsSummary'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The lead figure takes the larger share; the minor ones give way.
          Flexible(
            flex: 2,
            child: item(
              key: const Key('placementsSummaryValue'),
              label: l10n.placementsSummaryValue,
              figure: money(summary.declaredValueMinor),
              style: textTheme.displayLarge!,
              caption: lastValued == null
                  ? l10n.placementsSummaryCount(summary.openCount)
                  : l10n.placementsSummaryCaption(
                      summary.openCount,
                      placementDateLabel(locale, lastValued),
                    ),
              captionKey: const Key('placementsSummaryCaption'),
            ),
          ),
          const SummaryHairline(),
          Flexible(
            child: item(
              key: const Key('placementsSummaryNetPayments'),
              label: l10n.placementsSummaryNetPayments,
              figure: money(summary.netPaymentsMinor),
              style: textTheme.displaySmall!,
              caption: l10n.placementsSummaryNetPaymentsCaption,
            ),
          ),
          const SizedBox(width: AppSpacing.xxl),
          Flexible(
            child: item(
              key: const Key('placementsSummaryGain'),
              label: l10n.placementsSummaryGain,
              figure: hasValue
                  ? money(summary.unrealisedGainMinor, signed: true)
                  : l10n.placementsNoValue,
              style: textTheme.displaySmall!,
              // A neutral trend line: a gain is not income until withdrawn.
              below: !hasValue || gainBps == null
                  ? null
                  : StatusText(
                      key: const Key('placementsSummaryGainShare'),
                      icon: switch (gainBps) {
                        > 0 => LucideIcons300.trendingUp,
                        < 0 => LucideIcons300.trendingDown,
                        _ => LucideIcons300.minus,
                      },
                      label: l10n.placementsSummaryGainShare(
                        gainPercentLabel(gainBps, locale),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlacementRow extends StatelessWidget {
  const _PlacementRow({
    required this.investment,
    required this.columns,
    required this.selected,
    required this.onTap,
  });

  final Investment investment;
  final List<AppTableColumn> columns;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final textTheme = Theme.of(context).textTheme;
    final colors = context.colors;
    final dimmed = investment.isClosed;
    final id = investment.id;
    final figure = tabularNumberStyle(
      textTheme.bodyMedium!,
    ).copyWith(color: dimmed ? colors.textTertiary : colors.text);
    String money(int minor, {bool signed = false}) =>
        placementMoney(minor, investment.currency, locale, signed: signed);
    final value = investment.lastValueMinor;
    final gain = investment.unrealisedGainMinor;
    final gainBps = investment.gainBps;
    final valuedOn = investment.lastValuedOn;

    return AppTableRow(
      key: Key('placementRow-$id'),
      columns: columns,
      twoLines: true,
      selected: selected,
      dimmed: dimmed,
      onTap: onTap,
      cells: [
        Row(
          children: [
            MonogramAvatar(name: investment.institution),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    investment.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelLarge?.copyWith(
                      color: dimmed ? colors.textTertiary : colors.text,
                    ),
                  ),
                  Text(
                    l10n.placementsRowSubtitle(
                      envelopeLabel(l10n, investment.envelope),
                      investment.institution,
                      placementMonthLabel(locale, investment.openedOn),
                    ),
                    key: Key('placementSubtitle-$id'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelSmall?.copyWith(
                      color: colors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        Text(
          money(investment.netPaymentsMinor),
          key: Key('placementNetPayments-$id'),
          maxLines: 1,
          style: figure,
        ),
        Text(
          value == null ? l10n.placementsNoValue : money(value),
          key: Key('placementValue-$id'),
          maxLines: 1,
          style: figure.copyWith(fontWeight: FontWeight.w500),
        ),
        Text.rich(
          key: Key('placementGain-$id'),
          TextSpan(
            children: [
              TextSpan(
                text: gain == null
                    ? l10n.placementsNoValue
                    : money(gain, signed: true),
              ),
              if (gain != null && gainBps != null)
                TextSpan(
                  text: ' ${gainPercentLabel(gainBps, locale)}',
                  style: TextStyle(color: colors.textTertiary),
                ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: figure,
        ),
        if (valuedOn != null && investment.valueStale && !dimmed)
          StatusText(
            key: Key('placementValuedOn-$id'),
            tone: StatusTone.warning,
            icon: LucideIcons300.clockAlert,
            label: placementDateLabel(locale, valuedOn),
          )
        else
          Text(
            valuedOn == null
                ? l10n.placementsNoValue
                : placementDateLabel(locale, valuedOn),
            key: Key('placementValuedOn-$id'),
            maxLines: 1,
            style: tabularNumberStyle(textTheme.bodyMedium!).copyWith(
              color: dimmed ? colors.textTertiary : colors.textSecondary,
            ),
          ),
      ],
    );
  }
}
