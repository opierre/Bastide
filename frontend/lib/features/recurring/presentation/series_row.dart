import 'package:flutter/material.dart';

import '../../../core/l10n/category_display.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/category_chip.dart';
import '../../../core/widgets/monogram_avatar.dart';
import '../../../core/widgets/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../../categories/domain/category.dart';
import '../domain/recurring_series.dart';
import '../domain/recurring_summary.dart';
import 'recurring_labels.dart';

/// Column geometry of the subscriptions table (`docs/design/10` §Table Card).
/// Shared by the header and the rows so the two can never drift apart.
abstract final class SeriesColumns {
  static const monogram = 36.0;
  static const category = 150.0;
  static const cadence = 90.0;
  static const amount = 100.0;
  static const next = 150.0;
  static const status = 230.0;
  static const kebab = 28.0;
  static const gap = AppSpacing.sm + AppSpacing.xs;
  static const rowHeight = 56.0;
  static const headerHeight = 32.0;
}

/// One line of the table, header or data, laid out on [SeriesColumns].
Widget seriesRowLayout({
  required Widget monogram,
  required Widget name,
  required Widget category,
  required Widget cadence,
  required Widget amount,
  required Widget next,
  required Widget status,
  required Widget trailing,
}) => Row(
  children: [
    SizedBox(width: SeriesColumns.monogram, child: monogram),
    const SizedBox(width: SeriesColumns.gap),
    Expanded(child: name),
    const SizedBox(width: SeriesColumns.gap),
    SizedBox(width: SeriesColumns.category, child: category),
    SizedBox(width: SeriesColumns.cadence, child: cadence),
    SizedBox(width: SeriesColumns.amount, child: amount),
    const SizedBox(width: SeriesColumns.gap),
    SizedBox(width: SeriesColumns.next, child: next),
    const SizedBox(width: SeriesColumns.gap),
    SizedBox(width: SeriesColumns.status, child: status),
    const SizedBox(width: SeriesColumns.gap),
    SizedBox(width: SeriesColumns.kebab, child: trailing),
  ],
);

/// The 32 px uppercase header over the table.
class SeriesTableHeader extends StatelessWidget {
  const SeriesTableHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    Widget cell(String label, {TextAlign align = TextAlign.start}) => Text(
      label.toUpperCase(),
      textAlign: align,
      overflow: TextOverflow.ellipsis,
      style: AppTextStyles.sectionLabel,
    );

    return SizedBox(
      height: SeriesColumns.headerHeight,
      child: Align(
        alignment: Alignment.centerLeft,
        child: seriesRowLayout(
          monogram: const SizedBox.shrink(),
          name: cell(l10n.subscriptionsColumnName),
          category: cell(l10n.subscriptionsColumnCategory),
          cadence: cell(l10n.subscriptionsColumnCadence),
          amount: cell(l10n.subscriptionsColumnAmount, align: TextAlign.end),
          next: cell(l10n.subscriptionsColumnNext, align: TextAlign.end),
          status: cell(l10n.subscriptionsColumnStatus, align: TextAlign.end),
          trailing: const SizedBox.shrink(),
        ),
      ),
    );
  }
}

/// What the kebab can do to a row: move it along the lifecycle, or open it in
/// the form.
enum SeriesAction { confirm, dismiss, cancel, edit }

/// A 56 px subscription row: monogram · label · category · cadence · amount ·
/// next charge · status pill · kebab (`docs/design/10` frame ①).
///
/// A cancelled row renders at .55 opacity with no next date. It stays listed
/// rather than disappearing because the subscription is part of the history the
/// user is reading — and opacity does not affect hit testing, so its kebab
/// stays reachable, which is the point of keeping it.
class SeriesRow extends StatefulWidget {
  const SeriesRow({
    super.key,
    required this.row,
    required this.category,
    required this.onOpen,
    required this.onAction,
  });

  final SubscriptionRow row;

  /// The series' category, or `null` when it has none — or when the catalog is
  /// still loading, which renders the same dashed "uncategorized" chip.
  final AppCategory? category;

  final VoidCallback onOpen;
  final ValueChanged<SeriesAction> onAction;

  @override
  State<SeriesRow> createState() => _SeriesRowState();
}

class _SeriesRowState extends State<SeriesRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final textTheme = Theme.of(context).textTheme;
    final series = widget.row.series;
    final isCancelled = series.status == SeriesStatus.cancelled;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        key: Key('seriesRow-${series.id}'),
        height: SeriesColumns.rowHeight,
        color: _hovered ? AppColors.surfaceRowHover : Colors.transparent,
        child: Opacity(
          opacity: isCancelled ? 0.55 : 1,
          child: seriesRowLayout(
            monogram: Center(
              child: MonogramAvatar(name: series.label, size: SeriesColumns.monogram),
            ),
            name: GestureDetector(
              key: Key('seriesOpen-${series.id}'),
              behavior: HitTestBehavior.opaque,
              onTap: widget.onOpen,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Text(
                  series.label,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall,
                ),
              ),
            ),
            category: Align(
              alignment: Alignment.centerLeft,
              child: _CategoryCell(category: widget.category),
            ),
            cadence: Text(
              cadenceLabel(l10n, series.cadence),
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
            amount: Align(
              alignment: Alignment.centerRight,
              // Neutral and unsigned, unlike every other amount in the app.
              // These are expected charges, not ledger entries: the money
              // rule's red would state that this money has left the account,
              // which is exactly what has not happened yet.
              child: AmountText(
                key: Key('seriesAmount-${series.id}'),
                amountMinor: series.expectedAmountMinor.abs(),
                currency: series.currency,
                colorize: false,
                style: textTheme.bodyMedium,
              ),
            ),
            next: Align(
              alignment: Alignment.centerRight,
              child: _NextChargeCell(
                row: widget.row,
                locale: locale,
                isCancelled: isCancelled,
              ),
            ),
            status: Align(
              alignment: Alignment.centerRight,
              child: _StatusCell(
                signal: widget.row.signal,
                currency: series.currency,
                locale: locale,
              ),
            ),
            trailing: _SeriesKebab(series: series, onAction: widget.onAction),
          ),
        ),
      ),
    );
  }
}

class _CategoryCell extends StatelessWidget {
  const _CategoryCell({required this.category});

  final AppCategory? category;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final target = category;
    if (target == null) {
      return CategoryChip.uncategorized(label: l10n.subscriptionFormCategoryNone);
    }
    return CategoryChip(
      label: localizedCategoryName(l10n, target.name),
      slug: categorySlugFor(name: target.name, kind: target.kind),
    );
  }
}

/// The Prochain cell. A missed charge replaces the date with what *was*
/// expected, in amber: printing an overdue date under a "next" header would
/// state something the row's own pill contradicts.
class _NextChargeCell extends StatelessWidget {
  const _NextChargeCell({
    required this.row,
    required this.locale,
    required this.isCancelled,
  });

  final SubscriptionRow row;
  final String locale;
  final bool isCancelled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final dateFormat = seriesDateFormat(locale);

    if (isCancelled) {
      return Text(
        l10n.subscriptionsValueNone,
        textAlign: TextAlign.end,
        style: textTheme.bodyMedium?.copyWith(color: AppColors.textDisabled),
      );
    }

    if (row.signal case MissedChargeSignal(:final expectedOn)) {
      return Text(
        l10n.subscriptionNextExpected(dateFormat.format(expectedOn)),
        key: Key('seriesNextExpected-${row.series.id}'),
        textAlign: TextAlign.end,
        overflow: TextOverflow.ellipsis,
        style: tabularNumberStyle(
          textTheme.bodyMedium!,
        ).copyWith(color: AppColors.warning),
      );
    }

    return Text(
      dateFormat.format(row.series.nextExpectedDate),
      textAlign: TextAlign.end,
      style: tabularNumberStyle(
        textTheme.bodyMedium!,
      ).copyWith(color: AppColors.textSecondary),
    );
  }
}

/// The Statut cell — empty for a healthy subscription, by design.
class _StatusCell extends StatelessWidget {
  const _StatusCell({
    required this.signal,
    required this.currency,
    required this.locale,
  });

  final SeriesSignal? signal;
  final String currency;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentSignal = signal;
    if (currentSignal == null) return const SizedBox.shrink();

    return switch (currentSignal) {
      PriceIncreaseSignal(:final previousAmountMinor, :final currentAmountMinor) =>
        StatusPill(
          tone: StatusPillTone.warning,
          label: l10n.subscriptionSignalIncrease(
            _money(previousAmountMinor),
            _money(currentAmountMinor),
          ),
        ),
      MissedChargeSignal(:final daysLate) => StatusPill(
        tone: StatusPillTone.warning,
        label: l10n.subscriptionSignalMissed(daysLate),
      ),
      CancelledSignal(:final lastChargeOn) => StatusPill(
        tone: StatusPillTone.neutral,
        label: l10n.subscriptionSignalCancelled(
          seriesDateFormat(locale).format(lastChargeOn),
        ),
      ),
    };
  }

  /// The pill states both prices, so both are unsigned magnitudes for the same
  /// reason the amount column is: they are what the subscription costs.
  String _money(int amountMinor) =>
      formatAmount(amountMinor: amountMinor.abs(), currency: currency, locale: locale);
}

/// The row's kebab. It offers only the transitions the lifecycle allows out of
/// the current status — a menu that can produce a 409 is a menu that lies about
/// what the subscription can do.
class _SeriesKebab extends StatelessWidget {
  const _SeriesKebab({required this.series, required this.onAction});

  final RecurringSeries series;
  final ValueChanged<SeriesAction> onAction;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final allowed = series.allowedTransitions;

    return PopupMenuButton<SeriesAction>(
      key: Key('seriesMenu-${series.id}'),
      icon: const Icon(Icons.more_horiz_rounded, size: 18),
      iconColor: AppColors.textSecondary,
      tooltip: l10n.subscriptionActionsTooltip,
      position: PopupMenuPosition.under,
      padding: EdgeInsets.zero,
      onSelected: onAction,
      itemBuilder: (context) => [
        if (allowed.contains(SeriesStatus.confirmed))
          PopupMenuItem(
            key: Key('seriesActionConfirm-${series.id}'),
            value: SeriesAction.confirm,
            child: _MenuRow(
              icon: Icons.check_rounded,
              label: l10n.subscriptionActionConfirm,
              color: AppColors.positive,
            ),
          ),
        if (allowed.contains(SeriesStatus.dismissed))
          PopupMenuItem(
            key: Key('seriesActionDismiss-${series.id}'),
            value: SeriesAction.dismiss,
            child: _MenuRow(
              icon: Icons.visibility_off_outlined,
              label: l10n.subscriptionActionDismiss,
            ),
          ),
        if (allowed.contains(SeriesStatus.cancelled))
          PopupMenuItem(
            key: Key('seriesActionCancel-${series.id}'),
            value: SeriesAction.cancel,
            child: _MenuRow(
              icon: Icons.block_outlined,
              label: l10n.subscriptionActionCancel,
            ),
          ),
        PopupMenuItem(
          key: Key('seriesActionEdit-${series.id}'),
          value: SeriesAction.edit,
          child: _MenuRow(
            icon: Icons.edit_outlined,
            label: l10n.subscriptionActionEdit,
          ),
        ),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    this.color = AppColors.textSecondary,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: AppSpacing.sm),
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}
