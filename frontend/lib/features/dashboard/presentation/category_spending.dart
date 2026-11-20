import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n/category_display.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/category_label.dart';
import '../../../core/widgets/note_line.dart';
import '../../../core/widgets/section_heading.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/dashboard_summary.dart';

/// « Dépenses par catégorie » (`docs/design/04-dashboard.md` §3a): the
/// month's total on the heading line, then ranked bars, one 30 px row per
/// top-level category, largest first, each in the hue slot the API returns
/// for it. No row borders. A month without spending shows the note « Aucune
/// dépense ce mois. ».
class CategorySpending extends StatelessWidget {
  const CategorySpending({
    super.key,
    required this.summary,
    required this.onCategoryTap,
  });

  final DashboardSummary summary;

  /// Opens Transactions on the row's category; `null` for « Autres ».
  final void Function(String? categoryId) onCategoryTap;

  /// The row and its columns (`04` §3a).
  static const rowHeight = 30.0;
  static const labelWidth = 130.0;
  static const amountWidth = 90.0;
  static const shareWidth = 56.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final rows = summary.rankedSpending;

    return Column(
      key: const Key('dashboardCategorySpending'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeading(
          title: l10n.dashboardCategoryBreakdownTitle,
          trailing: rows.isEmpty
              ? null
              : AmountText(
                  key: const Key('dashboardCategoryTotal'),
                  amountMinor: summary.expenseMinor,
                  currency: summary.currency,
                  colorize: false,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
        ),
        const SizedBox(height: AppSpacing.xs),
        if (rows.isEmpty)
          NoteLine(
            key: const Key('dashboardCategoryEmpty'),
            text: l10n.dashboardCategoryNoSpending,
          )
        else
          for (final row in rows)
            _SpendingRowView(
              row: row,
              currency: summary.currency,
              onTap: () => onCategoryTap(row.category?.categoryId),
            ),
      ],
    );
  }
}

class _SpendingRowView extends StatefulWidget {
  const _SpendingRowView({
    required this.row,
    required this.currency,
    required this.onTap,
  });

  final SpendingRow row;
  final String currency;
  final VoidCallback onTap;

  @override
  State<_SpendingRowView> createState() => _SpendingRowViewState();
}

class _SpendingRowViewState extends State<_SpendingRowView> {
  /// Hover ephemera, not panel state.
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final textTheme = Theme.of(context).textTheme;
    final colors = context.colors;
    final row = widget.row;
    final category = row.category;
    // « Autres » folds several categories, so it takes the neutral slot.
    final slot = category == null
        ? CategorySlot.cat0
        : CategorySlot.fromWire(category.hue);
    final label = switch (category) {
      null => CategoryLabel.slotted(
        label: l10n.dashboardCategoryOthers,
        slot: slot,
      ),
      CategoryBreakdown(categoryId: null) => CategoryLabel.uncategorized(
        label: localizedCategoryName(l10n, category.name),
      ),
      _ => CategoryLabel.slotted(
        label: localizedCategoryName(l10n, category.name),
        slot: slot,
      ),
    };

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Semantics(
          button: true,
          child: Container(
            key: Key(
              'dashboardSpendingRow-${category?.categoryId ?? 'others'}',
            ),
            height: CategorySpending.rowHeight,
            color: _hovered ? colors.hover : null,
            child: Row(
              children: [
                SizedBox(
                  width: CategorySpending.labelWidth,
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: label,
                  ),
                ),
                const SizedBox(width: AppSpacing.smPlus),
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: FractionallySizedBox(
                      widthFactor: row.barFraction,
                      child: Container(
                        key: const Key('dashboardSpendingBar'),
                        height: _barHeight,
                        decoration: BoxDecoration(
                          color: context.categoryColors.forSlot(slot),
                          borderRadius: BorderRadius.circular(
                            AppChart.barRadius,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: CategorySpending.amountWidth,
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: AmountText(
                      amountMinor: row.amountMinor,
                      currency: widget.currency,
                      colorize: false,
                      maxLines: 1,
                      style: textTheme.bodyMedium,
                    ),
                  ),
                ),
                SizedBox(
                  width: CategorySpending.shareWidth,
                  child: Text(
                    formatSharePct(row.pct, locale),
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    style: tabularNumberStyle(
                      textTheme.bodyMedium!,
                    ).copyWith(color: colors.textTertiary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Ranked bars are 6 px tall (`00` §9).
const _barHeight = 6.0;

/// A category's share of the month, to one decimal: « 42,9 % ».
String formatSharePct(double pct, String locale) =>
    NumberFormat.decimalPercentPattern(
      locale: locale,
      decimalDigits: 1,
    ).format(pct / 100);
