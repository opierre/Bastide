import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../../core/l10n/category_display.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_popover.dart';
import '../../../core/widgets/app_table.dart';
import '../../../core/widgets/category_label.dart';
import '../../../core/widgets/institution_avatar.dart';
import '../../../core/widgets/status_text.dart';
import '../../../l10n/app_localizations.dart';
import '../../categories/domain/category.dart';
import '../application/series_sort.dart';
import '../domain/recurring_series.dart';
import '../domain/recurring_summary.dart';
import 'recurring_labels.dart';

/// The columns of the subscriptions table (`docs/design/10` §3), shared by the
/// header and the rows so the two never drift apart.
///
/// Abonnement and État share the free width; the others keep a fixed one,
/// sized on the French copy (« Prélèvement manquant depuis 9 jours » is the
/// longest État, and it takes the flexible column).
abstract final class SeriesColumns {
  static const _category = 160.0;
  static const _cadence = 110.0;
  static const _amount = 110.0;
  static const _next = 140.0;

  /// The `ellipsis` button and the cell gap after it.
  static const _menu = AppSizes.button + AppSpacing.smPlus;

  /// The sortable columns, by their index in [of].
  static const sortFields = {
    0: SeriesSortField.name,
    3: SeriesSortField.amount,
    4: SeriesSortField.nextCharge,
  };

  /// The header index of [field].
  static int indexOf(SeriesSortField field) =>
      sortFields.entries.firstWhere((entry) => entry.value == field).key;

  static List<AppTableColumn> of(AppLocalizations l10n) => [
    AppTableColumn(
      label: l10n.subscriptionsColumnName,
      flex: 3,
      sortable: true,
    ),
    AppTableColumn(label: l10n.subscriptionsColumnCategory, width: _category),
    AppTableColumn(label: l10n.subscriptionsColumnCadence, width: _cadence),
    AppTableColumn(
      label: l10n.subscriptionsColumnAmount,
      width: _amount,
      numeric: true,
      sortable: true,
    ),
    AppTableColumn(
      label: l10n.subscriptionsColumnNext,
      width: _next,
      numeric: true,
      sortable: true,
    ),
    AppTableColumn(label: l10n.subscriptionsColumnStatus, flex: 3),
    const AppTableColumn(label: '', width: _menu, numeric: true),
  ];
}

/// The table header: Abonnement, Montant and Prochain sort, the sorted one
/// showing its chevron. The header only reports the click; the ordering is
/// the controller's.
class SeriesTableHeader extends StatelessWidget {
  const SeriesTableHeader({super.key, required this.sort, this.onSort});

  final SeriesSort sort;

  /// Called with the column the user clicked; `null` makes the header inert.
  final ValueChanged<SeriesSortField>? onSort;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final onSort = this.onSort;
    return AppTableHeader(
      key: const Key('seriesTableHeader'),
      columns: SeriesColumns.of(l10n),
      sortColumn: SeriesColumns.indexOf(sort.field),
      ascending: sort.ascending,
      onSort: onSort == null
          ? null
          : (index) => onSort(SeriesColumns.sortFields[index]!),
    );
  }
}

/// What the row menu can do to a series: move it along the lifecycle, open it
/// in the form, or put it away and bring it back.
enum SeriesAction { confirm, dismiss, cancel, edit, archive, unarchive }

/// One 36 px row of the table: monogram and name · category · cadence ·
/// amount · next charge · état · `ellipsis` (`docs/design/10` §3).
///
/// A cancelled or archived row is dimmed. It stays listed because the
/// subscription is part of the history the user is reading, and its menu
/// stays reachable, which is the point of keeping it.
class SeriesRow extends StatelessWidget {
  const SeriesRow({
    super.key,
    required this.row,
    required this.category,
    required this.onOpen,
    required this.onAction,
  });

  final SubscriptionRow row;

  /// The series' category, or `null` when it has none, or when the catalog
  /// is still loading, which renders the same « Non catégorisé » label.
  final AppCategory? category;

  final VoidCallback onOpen;
  final ValueChanged<SeriesAction> onAction;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final series = row.series;

    return AppTableRow(
      key: Key('seriesRow-${series.id}'),
      columns: SeriesColumns.of(l10n),
      dimmed: row.isSettled,
      onTap: onOpen,
      cells: [
        Row(
          children: [
            InstitutionAvatar(name: series.label, logo: series.logo),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                series.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        _CategoryCell(category: category),
        Text(
          cadenceLabel(l10n, series.cadence),
          style: TextStyle(
            color: row.isSettled
                ? context.colors.textTertiary
                : context.colors.textSecondary,
          ),
        ),
        // Neutral and unsigned: an expected charge, not a transaction. The
        // money rule's red would state that this money has left the account,
        // which is exactly what has not happened yet.
        AmountText(
          key: Key('seriesAmount-${series.id}'),
          amountMinor: series.expectedAmountMinor.abs(),
          currency: series.currency,
          colorize: false,
        ),
        _NextChargeCell(row: row, locale: locale),
        _StatusCell(
          signal: row.signal,
          currency: series.currency,
          locale: locale,
        ),
        _SeriesMenu(series: series, onAction: onAction),
      ],
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
      return CategoryLabel.uncategorized(label: l10n.categoryUncategorized);
    }
    return CategoryLabel(
      label: localizedCategoryName(l10n, target.name),
      slug: categorySlugFor(name: target.name, kind: target.kind),
    );
  }
}

/// The Prochain cell. A missed charge replaces the date with what was
/// expected, in `warning`: an overdue date under a "next" header would state
/// something the row's own État contradicts. A settled series expects no
/// charge, so shows « — ».
class _NextChargeCell extends StatelessWidget {
  const _NextChargeCell({required this.row, required this.locale});

  final SubscriptionRow row;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final format = seriesShortDateFormat(locale);

    if (row.isSettled) return Text(l10n.subscriptionsValueNone);

    if (row.signal case MissedChargeSignal(:final expectedOn)) {
      return Text(
        l10n.subscriptionNextExpected(format.format(expectedOn)),
        key: Key('seriesNextExpected-${row.series.id}'),
        style: TextStyle(color: colors.warning),
      );
    }

    return Text(
      format.format(row.series.nextExpectedDate),
      style: TextStyle(color: colors.textSecondary),
    );
  }
}

/// The État cell: empty for a healthy subscription, by design.
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
    return switch (signal) {
      null => const SizedBox.shrink(),
      PriceIncreaseSignal(
        :final previousAmountMinor,
        :final currentAmountMinor,
      ) =>
        StatusText(
          key: const Key('seriesStatusIncrease'),
          tone: StatusTone.warning,
          icon: LucideIcons300.trendingUp,
          label: l10n.subscriptionSignalIncrease(
            _money(previousAmountMinor),
            _money(currentAmountMinor),
          ),
        ),
      MissedChargeSignal(:final daysLate) => StatusText(
        key: const Key('seriesStatusMissed'),
        tone: StatusTone.warning,
        icon: LucideIcons300.clockAlert,
        label: l10n.subscriptionSignalMissed(daysLate),
      ),
      // Neutral text with no icon, in the dimmed row's `textTertiary`: a
      // cancelled subscription is settled, not something to look at.
      CancelledSignal(:final lastChargeOn) => Text(
        l10n.subscriptionSignalCancelled(
          seriesLongDateFormat(locale).format(lastChargeOn),
        ),
        key: const Key('seriesStatusCancelled'),
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: context.colors.textTertiary),
      ),
    };
  }

  /// Both prices are unsigned for the reason the amount column is: they are
  /// what the subscription costs.
  String _money(int amountMinor) => formatAmount(
    amountMinor: amountMinor.abs(),
    currency: currency,
    locale: locale,
  );
}

/// The row's `ellipsis` menu: Confirmer · Ignorer · Marquer comme résilié ·
/// Modifier, then Archiver.
///
/// It offers only the transitions the lifecycle allows out of the current
/// status: a menu that can produce a 409 lies about what the subscription can
/// do. An archived series offers only « Désarchiver »: it is put away until
/// the user brings it back.
class _SeriesMenu extends StatefulWidget {
  const _SeriesMenu({required this.series, required this.onAction});

  final RecurringSeries series;
  final ValueChanged<SeriesAction> onAction;

  @override
  State<_SeriesMenu> createState() => _SeriesMenuState();
}

class _SeriesMenuState extends State<_SeriesMenu> {
  final _menu = MenuController();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final series = widget.series;
    final allowed = series.allowedTransitions;

    AppMenuItem item(SeriesAction action, String key, String label) =>
        AppMenuItem(
          key: Key('seriesAction$key-${series.id}'),
          label: label,
          onPressed: () => widget.onAction(action),
        );

    return MenuAnchor(
      controller: _menu,
      style: AppPopover.menuStyle(context),
      alignmentOffset: const Offset(0, AppSpacing.xs),
      menuChildren: [
        if (series.isArchived)
          item(
            SeriesAction.unarchive,
            'Unarchive',
            l10n.subscriptionActionUnarchive,
          )
        else ...[
          if (allowed.contains(SeriesStatus.confirmed))
            item(
              SeriesAction.confirm,
              'Confirm',
              l10n.subscriptionActionConfirm,
            ),
          if (allowed.contains(SeriesStatus.dismissed))
            item(
              SeriesAction.dismiss,
              'Dismiss',
              l10n.subscriptionActionDismiss,
            ),
          if (allowed.contains(SeriesStatus.cancelled))
            item(SeriesAction.cancel, 'Cancel', l10n.subscriptionActionCancel),
          item(SeriesAction.edit, 'Edit', l10n.subscriptionActionEdit),
          item(SeriesAction.archive, 'Archive', l10n.subscriptionActionArchive),
        ],
      ],
      child: AppButton(
        key: Key('seriesMenu-${series.id}'),
        label: l10n.subscriptionActionsTooltip,
        icon: LucideIcons300.ellipsis,
        iconOnly: true,
        variant: AppButtonVariant.ghost,
        onPressed: () => _menu.isOpen ? _menu.close() : _menu.open(),
      ),
    );
  }
}
