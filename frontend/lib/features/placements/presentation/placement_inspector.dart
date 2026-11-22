import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_popover.dart';
import '../../../core/widgets/app_table.dart';
import '../../../core/widgets/category_label.dart';
import '../../../core/widgets/inspector_pane.dart';
import '../../../core/widgets/monogram_avatar.dart';
import '../../../core/widgets/note_line.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/repere_meter.dart';
import '../../../core/widgets/section_heading.dart';
import '../../../l10n/app_localizations.dart';
import '../application/placements_controller.dart';
import '../domain/investment.dart';
import '../domain/placement_timeline.dart';
import 'close_placement_modal.dart';
import 'delete_placement_modal.dart';
import 'movement_modal.dart';
import 'placement_chart.dart';
import 'placement_form_modal.dart';
import 'placement_labels.dart';
import 'valuation_modal.dart';

/// The age repère's scale: 0 to 8 years (`00` §8).
const _ageScaleMonths = 8 * 12;

/// The inspector pane of the Placements panel (`17-placements.md`
/// §Inspector pane): the header, the figures and their two actions, the
/// chart, the repères, and the movements.
///
/// A closed placement keeps its history and figures, without the two
/// actions: nothing can be dated after its closing.
class PlacementInspector extends ConsumerWidget {
  const PlacementInspector({super.key, required this.investment});

  final Investment investment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(placementDetailProvider(investment.id));
    final hasRepere =
        investment.paymentCeilingMinor != null ||
        investment.milestoneYears != null;

    return InspectorPane(
      key: const Key('placementInspector'),
      selection: investment.id,
      blocks: [
        _Overview(investment: investment, detail: detail),
        if (hasRepere) _Reperes(investment: investment),
        _Movements(investment: investment, detail: detail),
      ],
    );
  }
}

/// Header, figures, actions, legend and chart: one block, 16 px apart.
class _Overview extends StatelessWidget {
  const _Overview({required this.investment, required this.detail});

  final Investment investment;
  final AsyncValue<InvestmentDetail> detail;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final textTheme = Theme.of(context).textTheme;
    final colors = context.colors;
    final id = investment.id;
    String money(int minor, {bool signed = false}) =>
        placementMoney(minor, investment.currency, locale, signed: signed);
    final value = investment.lastValueMinor;
    final valuedOn = investment.lastValuedOn;
    final gain = investment.unrealisedGainMinor;
    final gainBps = investment.gainBps;
    final closedOn = investment.closedOn;
    const gap = SizedBox(height: InspectorPane.blockGap);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            MonogramAvatar(
              name: investment.institution,
              size: MonogramAvatar.large,
            ),
            const SizedBox(width: AppSpacing.smPlus),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    investment.name,
                    key: Key('placementInspectorName-$id'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.headlineSmall,
                  ),
                  Text(
                    closedOn == null
                        ? l10n.placementOpenedOn(
                            investment.institution,
                            placementDateLabel(locale, investment.openedOn),
                          )
                        : l10n.placementClosedOn(
                            investment.institution,
                            placementDateLabel(locale, closedOn),
                          ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      color: colors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _PlacementMenu(investment: investment),
          ],
        ),
        gap,
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Flexible(
                    flex: 3,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        value == null ? l10n.placementsNoValue : money(value),
                        key: Key('placementInspectorValue-$id'),
                        style: tabularNumberStyle(textTheme.displayMedium!),
                      ),
                    ),
                  ),
                  if (valuedOn != null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      flex: 2,
                      child: Text(
                        l10n.placementValueAt(
                          placementDateLabel(locale, valuedOn),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text.rich(
              key: Key('placementInspectorGain-$id'),
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
              style: tabularNumberStyle(textTheme.bodyMedium!),
            ),
          ],
        ),
        if (!investment.isClosed) ...[
          gap,
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              PrimaryButton(
                key: const Key('placementEnterValue'),
                label: l10n.placementEnterValue,
                icon: LucideIcons300.pencil,
                onPressed: () =>
                    showValuationModal(context, investment: investment),
              ),
              AppButton(
                key: const Key('placementAddMovement'),
                label: l10n.placementAddMovement,
                icon: LucideIcons300.plus,
                onPressed: () =>
                    showMovementModal(context, investment: investment),
              ),
            ],
          ),
        ],
        gap,
        Wrap(
          spacing: AppSpacing.smPlus,
          runSpacing: AppSpacing.xs,
          children: [
            _LegendLabel(
              color: colors.accent,
              label: l10n.placementLegendValue,
            ),
            _LegendLabel(
              color: colors.textTertiary,
              label: l10n.placementLegendNetPayments,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: AppPlacements.chartHeight,
          child: switch (detail) {
            AsyncData(:final value) => _Chart(detail: value),
            _ => const SizedBox.shrink(),
          },
        ),
        if (!investment.hasValue) ...[
          const SizedBox(height: AppSpacing.sm),
          NoteLine(
            key: const Key('placementNoValueNote'),
            icon: LucideIcons300.info,
            text: l10n.placementNoValueNote,
          ),
        ],
      ],
    );
  }
}

class _Chart extends StatelessWidget {
  const _Chart({required this.detail});

  final InvestmentDetail detail;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final colors = context.colors;
    final investment = detail.investment;
    String money(int minor) =>
        placementMoney(minor, investment.currency, locale);

    return PlacementChart(
      key: Key('placementChart-${investment.id}'),
      points: placementTimeline(detail, DateTime.now()),
      semanticLabel: l10n.placementChartLabel(investment.name),
      valueLabel: (minor) => NumberFormat.compactSimpleCurrency(
        locale: locale,
        name: investment.currency,
      ).format(minor / 100).replaceAll('-', '−'),
      tooltipFor: (point) => TextSpan(
        children: [
          TextSpan(
            text: placementDateLabel(locale, point.date),
            style: TextStyle(color: colors.textSecondary),
          ),
          TextSpan(
            text:
                '\n${l10n.placementChartValue(point.valueMinor == null ? l10n.placementsNoValue : money(point.valueMinor!))}',
          ),
          TextSpan(
            text:
                '\n${l10n.placementChartNetPayments(money(point.netPaymentsMinor))}',
          ),
        ],
      ),
    );
  }
}

/// A category-style legend label (`00` §9): the 8 px dot in the series'
/// colour, then its name in 12 `textSecondary`.
class _LegendLabel extends StatelessWidget {
  const _LegendLabel({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: CategoryLabel.dotSize,
          height: CategoryLabel.dotSize,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppRadii.bar),
          ),
        ),
        const SizedBox(width: AppSpacing.xsPlus),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: context.colors.textSecondary),
        ),
      ],
    );
  }
}

/// The two repères: the payment ceiling and the age, each only for an
/// envelope that has one (`17-placements.md` §Inspector 6).
class _Reperes extends StatelessWidget {
  const _Reperes({required this.investment});

  final Investment investment;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final textTheme = Theme.of(context).textTheme;
    final colors = context.colors;
    final id = investment.id;
    final ceiling = investment.paymentCeilingMinor;
    final milestone = investment.milestoneYears;
    final milestoneOn = investment.milestoneOn;
    final caption = textTheme.bodySmall?.copyWith(color: colors.textTertiary);
    String money(int minor) =>
        placementMoney(minor, investment.currency, locale);
    final ageCaption = milestoneCaption(l10n, investment.envelope);

    Widget heading(String label, InlineSpan value, Key key) => Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(label, style: context.textStyles.statLabel),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text.rich(
            key: key,
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: tabularNumberStyle(textTheme.bodyMedium!),
          ),
        ),
      ],
    );

    return Column(
      key: Key('placementReperes-$id'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (ceiling != null && ceiling > 0) ...[
          heading(
            l10n.placementCeilingLabel,
            TextSpan(
              children: [
                TextSpan(text: money(investment.netPaymentsMinor)),
                TextSpan(
                  text: ' ${l10n.placementCeilingOf(money(ceiling))}',
                  style: TextStyle(color: colors.textTertiary),
                ),
              ],
            ),
            Key('placementCeilingValue-$id'),
          ),
          const SizedBox(height: AppSpacing.xsPlus),
          RepereMeter(
            key: Key('placementCeilingMeter-$id'),
            fraction: investment.netPaymentsMinor / ceiling,
            tone: investment.ceilingReached
                ? RepereTone.over
                : RepereTone.normal,
          ),
          if (investment.ceilingReached) ...[
            const SizedBox(height: AppSpacing.xsPlus),
            Text(
              l10n.placementCeilingReached,
              key: Key('placementCeilingReached-$id'),
              style: caption,
            ),
          ],
          if (milestone != null) const SizedBox(height: AppSpacing.md),
        ],
        if (milestone != null) ...[
          heading(
            l10n.placementAgeLabel,
            TextSpan(text: placementAgeLabel(l10n, investment.ageMonths)),
            Key('placementAgeValue-$id'),
          ),
          const SizedBox(height: AppSpacing.xsPlus),
          RepereMeter(
            key: Key('placementAgeMeter-$id'),
            fraction: investment.ageMonths / _ageScaleMonths,
            tone: investment.milestoneReached
                ? RepereTone.done
                : RepereTone.normal,
            markFraction: milestone * 12 / _ageScaleMonths,
            markLabel: milestoneOn == null
                ? null
                : l10n.placementMilestoneMark(
                    milestone,
                    placementMonthLabel(locale, milestoneOn),
                  ),
            semanticLabel: placementAgeLabel(l10n, investment.ageMonths),
          ),
          if (ageCaption != null) ...[
            const SizedBox(height: AppSpacing.xsPlus),
            Text(
              ageCaption,
              key: Key('placementMilestoneCaption-$id'),
              style: caption,
            ),
          ],
        ],
      ],
    );
  }
}

/// « Mouvements »: payments, withdrawals and declared values in one list,
/// newest first. A row opens its edit modal.
class _Movements extends StatelessWidget {
  const _Movements({required this.investment, required this.detail});

  final Investment investment;
  final AsyncValue<InvestmentDetail> detail;

  static const _columns = [
    AppTableColumn(label: '', width: AppPlacements.historyDateColumn),
    AppTableColumn(label: ''),
    AppTableColumn(
      label: '',
      width: AppPlacements.historyAmountColumn,
      numeric: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final hint = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: colors.textTertiary);
    final linked = investment.linkedMovementCount;

    return Column(
      key: Key('placementMovements-${investment.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeading(
          title: l10n.placementMovementsTitle,
          trailing: linked == 0
              ? null
              : Text(
                  l10n.placementMovementsLinked(linked),
                  key: const Key('placementMovementsLinked'),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colors.textTertiary),
                ),
        ),
        switch (detail) {
          AsyncData(:final value) when value.history.isEmpty => Text(
            l10n.placementMovementsEmpty,
            key: const Key('placementMovementsEmpty'),
            style: hint,
          ),
          AsyncData(:final value) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final entry in value.history)
                _HistoryRow(
                  entry: entry,
                  investment: investment,
                  columns: _columns,
                ),
            ],
          ),
          AsyncError() => Text(
            l10n.placementMovementsFailed,
            key: const Key('placementMovementsFailed'),
            style: hint,
          ),
          _ => const SizedBox(height: AppSizes.tableRow),
        },
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.entry,
    required this.investment,
    required this.columns,
  });

  final HistoryEntry entry;
  final Investment investment;
  final List<AppTableColumn> columns;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final textTheme = Theme.of(context).textTheme;
    final colors = context.colors;
    final entry = this.entry;
    final figure = tabularNumberStyle(textTheme.bodyMedium!);

    final (label, note, amount, amountColor) = switch (entry) {
      MovementEntry(:final movement) => (
        movement.isWithdrawal
            ? l10n.placementEntryWithdrawal
            : l10n.placementEntryPayment,
        movement.note,
        placementMoney(
          movement.amountMinor,
          investment.currency,
          locale,
          signed: true,
        ),
        colors.text,
      ),
      ValuationEntry(:final valuation) => (
        l10n.placementEntryValuation,
        valuation.note,
        placementMoney(valuation.valueMinor, investment.currency, locale),
        colors.textSecondary,
      ),
    };

    return AppTableRow(
      key: Key('placementHistoryRow-${entry.id}'),
      columns: columns,
      onTap: () => switch (entry) {
        MovementEntry(:final movement) => showMovementModal(
          context,
          investment: investment,
          initial: movement,
        ),
        ValuationEntry(:final valuation) => showValuationModal(
          context,
          investment: investment,
          initial: valuation,
        ),
      },
      cells: [
        Text(
          placementDateLabel(locale, entry.date),
          maxLines: 1,
          style: figure.copyWith(color: colors.textSecondary),
        ),
        Text(
          note == null ? label : l10n.placementEntryWithNote(label, note),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(amount, maxLines: 1, style: figure.copyWith(color: amountColor)),
      ],
    );
  }
}

/// The header's `ellipsis` menu: Modifier, Clôturer (Rouvrir once closed),
/// Supprimer.
class _PlacementMenu extends ConsumerStatefulWidget {
  const _PlacementMenu({required this.investment});

  final Investment investment;

  @override
  ConsumerState<_PlacementMenu> createState() => _PlacementMenuState();
}

class _PlacementMenuState extends ConsumerState<_PlacementMenu> {
  final _menu = MenuController();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final investment = widget.investment;

    AppMenuItem item(
      String name,
      String label,
      VoidCallback onPressed, {
      bool destructive = false,
    }) => AppMenuItem(
      key: Key('placementMenu-$name'),
      label: label,
      destructive: destructive,
      onPressed: onPressed,
    );

    return MenuAnchor(
      controller: _menu,
      style: AppPopover.menuStyle(context),
      alignmentOffset: const Offset(0, AppSpacing.xs),
      menuChildren: [
        item(
          'edit',
          l10n.placementMenuEdit,
          () => showPlacementForm(context, initial: investment),
        ),
        if (investment.isClosed)
          item(
            'reopen',
            l10n.placementMenuReopen,
            () => ref
                .read(placementsControllerProvider.notifier)
                .reopen(investment.id),
          )
        else
          item(
            'close',
            l10n.placementMenuClose,
            () => showClosePlacementModal(context, investment: investment),
          ),
        item(
          'delete',
          l10n.placementMenuDelete,
          () => showDeletePlacementModal(context, investment: investment),
          destructive: true,
        ),
      ],
      child: AppButton(
        key: const Key('placementMenu'),
        label: l10n.placementMenuTooltip,
        icon: LucideIcons300.ellipsis,
        iconOnly: true,
        onPressed: () => _menu.isOpen ? _menu.close() : _menu.open(),
      ),
    );
  }
}
