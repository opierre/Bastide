import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../../core/l10n/date_display.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/app_link.dart';
import '../../../core/widgets/app_table.dart';
import '../../../core/widgets/institution_avatar.dart';
import '../../../core/widgets/section_heading.dart';
import '../../../core/widgets/status_text.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/upcoming_charges.dart';

/// « À venir d’ici le {date} » (`docs/design/04-dashboard.md` §5c): the
/// recurring charges still due before the end of the current month, whatever
/// month the title bar shows.
///
/// The heading carries the total still due, missed charges left out. A table
/// without header, up to four 48 px rows: monogram or rule logo, the label
/// over its date line, the signed amount. A price rise and a missed charge
/// say so in `warning` status text; a missed amount is `textTertiary`. The
/// caller hides the block when there is nothing to show.
class UpcomingChargesSection extends StatelessWidget {
  const UpcomingChargesSection({
    super.key,
    required this.upcoming,
    required this.onViewAll,
    required this.onOpen,
  });

  final UpcomingCharges upcoming;

  /// « Tous les abonnements »: opens Abonnements.
  final VoidCallback onViewAll;

  /// Opens Abonnements with the row's series selected.
  final ValueChanged<String> onOpen;

  /// The label's widest extent, so a long one ellipsizes before the amount.
  static const labelMaxWidth = 150.0;

  /// One cell holding the whole row: the amount takes only its own width, so
  /// the date line, which can carry a price rise, keeps the rest of a column
  /// a quarter of the panel wide.
  static const _columns = [AppTableColumn(label: '')];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final dates = DayMonthFormat.MMMMd(locale);

    return Column(
      key: const Key('dashboardUpcoming'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeading(
          title: l10n.dashboardUpcomingTitle(dates.format(upcoming.through)),
          trailing: Text(
            formatAmount(
              amountMinor: upcoming.totalMinor,
              currency: upcoming.currency,
              locale: locale,
              showPositiveSign: true,
            ),
            key: const Key('dashboardUpcomingTotal'),
            maxLines: 1,
            style: tabularNumberStyle(
              textTheme.bodyMedium!,
            ).copyWith(color: colors.textSecondary),
          ),
        ),
        for (final row in upcoming.rows)
          _UpcomingRow(
            row: row,
            currency: upcoming.currency,
            dates: dates,
            columns: _columns,
            onTap: () => onOpen(row.seriesId),
          ),
        const SizedBox(height: AppSpacing.xs),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: AppLink(
            key: const Key('dashboardUpcomingViewAll'),
            label: l10n.dashboardUpcomingViewAll,
            onTap: onViewAll,
          ),
        ),
      ],
    );
  }
}

class _UpcomingRow extends StatelessWidget {
  const _UpcomingRow({
    required this.row,
    required this.currency,
    required this.dates,
    required this.columns,
    required this.onTap,
  });

  final UpcomingRow row;
  final String currency;
  final DayMonthFormat dates;
  final List<AppTableColumn> columns;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final key = row.seriesId;

    final Widget dateLine = switch (row) {
      UpcomingDue(:final dueOn, priceIncreaseMinor: final rise?) => StatusText(
        key: Key('dashboardUpcomingRise-$key'),
        tone: StatusTone.warning,
        icon: LucideIcons300.trendingUp,
        label: l10n.dashboardUpcomingPriceRise(
          dates.format(dueOn),
          // The wire step is signed (negative on an outflow that grew); the
          // sentence already says « hausse », so the figure goes unsigned.
          formatAmount(
            amountMinor: rise.abs(),
            currency: currency,
            locale: locale,
          ),
        ),
      ),
      UpcomingDue(:final dueOn) => Text(
        dates.format(dueOn),
        key: Key('dashboardUpcomingDate-$key'),
        maxLines: 1,
        style: textTheme.bodySmall?.copyWith(color: colors.textTertiary),
      ),
      UpcomingMissed(:final expectedOn) => StatusText(
        key: Key('dashboardUpcomingMissed-$key'),
        tone: StatusTone.warning,
        icon: LucideIcons300.clockAlert,
        label: l10n.dashboardUpcomingExpected(dates.format(expectedOn)),
      ),
    };

    return AppTableRow(
      key: Key('dashboardUpcomingRow-$key'),
      columns: columns,
      twoLines: true,
      onTap: onTap,
      cells: [
        Row(
          children: [
            InstitutionAvatar(name: row.label, logo: row.logo),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: UpcomingChargesSection.labelMaxWidth,
                    ),
                    child: Text(
                      row.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  dateLine,
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.smPlus),
            Text(
              formatAmount(
                amountMinor: row.amountMinor,
                currency: currency,
                locale: locale,
                showPositiveSign: true,
              ),
              key: Key('dashboardUpcomingAmount-$key'),
              maxLines: 1,
              // Signed but not sign-coloured (§5c): the only tone a row's amount
              // takes is `textTertiary`, for a charge left out of the total.
              style: row is UpcomingMissed
                  ? TextStyle(color: colors.textTertiary)
                  : null,
            ),
          ],
        ),
      ],
    );
  }
}
