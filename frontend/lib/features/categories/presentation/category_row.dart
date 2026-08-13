import 'package:flutter/material.dart';

import '../../../core/l10n/category_display.dart';
import '../../../core/l10n/percent_format.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/category.dart';
import '../domain/category_spend.dart';
import 'category_color.dart';
import 'category_spend_bar.dart';

/// Width of the ownership-badge column. Wide enough for the longest label —
/// French `Personnalisée` — so parents and subcategories share one grid.
const double badgeColumnWidth = 120;

/// Width of the share column beside the bar — « 42,9 % » with room for the
/// French non-breaking space before the sign.
const double sharePctColumnWidth = 52;

/// Width of the month-amount column. Sized for a five-figure French amount
/// (« 12 345,67 € »): amounts are right-aligned in a fixed column so the
/// decimal points line up down the panel, which is the whole point of tabular
/// figures.
const double spendAmountColumnWidth = 104;

/// Width of the trailing-affordance column: two compact 40 px icon buttons.
/// A system row's lock is right-aligned inside the same box, so every row's
/// affordances end on the same edge.
const double actionsColumnWidth = 80;

/// An [IconButton]'s box at this density; the lock borrows it to sit on the
/// same axis as the ⋯ it replaces.
const double _iconButtonExtent = 40;

/// A parent category row: 41 px, swatch · name · ownership badge · trailing
/// affordances (`docs/design/08-categories-rules.md`).
///
/// The system/custom distinction is encoded three times over — badge text,
/// badge tint, and lock glyph vs ⋯ menu — because any one of them alone fails
/// somebody: the tint alone fails a colour-blind reader, and hiding the ⋯ alone
/// would leave a keyboard user no way to learn *why* nothing is offered. The
/// API's refusal to patch a system row is the fourth, and the only binding one.
class CategoryRow extends StatelessWidget {
  const CategoryRow({
    super.key,
    required this.category,
    required this.onEdit,
    required this.onDelete,
    this.spend,
    this.currency,
  });

  final AppCategory category;

  /// This category's month, subcategories included. `null` when it spent
  /// nothing — which the row states, rather than drawing a zero.
  final CategorySpend? spend;

  /// The currency the month's figures are in, and the panel's signal that they
  /// arrived at all: `null` while the summary is loading or after it failed, and
  /// the spend columns then render as reserved space rather than as zeroes.
  final String? currency;

  /// Both `null` for system categories — this widget never decides that; the
  /// screen does, from `isSystem`.
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;

    return SizedBox(
      height: 41,
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: categoryColor(category),
              borderRadius: BorderRadius.circular(AppRadii.xs),
            ),
          ),
          const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
          Expanded(
            child: Text(
              localizedCategoryName(l10n, category.name),
              overflow: TextOverflow.ellipsis,
              style: textTheme.titleSmall,
            ),
          ),
          const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
          // Fixed-width slot so every badge starts at the same x whatever the
          // name above it runs to — a ragged column of pills reads as noise.
          SizedBox(
            width: badgeColumnWidth,
            child: Align(
              alignment: Alignment.centerLeft,
              child: category.isSystem
                  ? AppChip(
                      key: const Key('categoryBadgeSystem'),
                      label: l10n.categoryBadgeSystem,
                    )
                  : AppChip(
                      key: const Key('categoryBadgeCustom'),
                      label: l10n.categoryBadgeCustom,
                      color: AppColors.iris,
                    ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          CategorySpendColumns(
            key: Key('categorySpend-${category.id}'),
            spend: spend,
            currency: currency,
            barColor: categoryColor(category),
          ),
          const SizedBox(width: AppSpacing.md),
          CategoryRowActions(category: category, onEdit: onEdit, onDelete: onDelete),
        ],
      ),
    );
  }
}

/// A subcategory row: indented 30 px and set a step quieter, so the hierarchy
/// is carried by position and weight rather than by a tree line.
class CategorySubRow extends StatelessWidget {
  const CategorySubRow({
    super.key,
    required this.category,
    required this.onEdit,
    required this.onDelete,
    this.spend,
    this.currency,
  });

  final AppCategory category;

  /// This subcategory's own month. It carries the amount but no bar and no
  /// share: its parent's bar already places the group in the month, and eleven
  /// subcategory bars measured against the same month would say far less than
  /// the eight group bars above them.
  final CategorySpend? spend;
  final String? currency;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return SizedBox(
      height: 41,
      child: Row(
        children: [
          const SizedBox(width: 30),
          Expanded(
            child: Text(
              localizedCategoryName(l10n, category.name),
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
          // Empty badge slot: a subrow carries no pill, but keeping the column
          // reserved keeps its actions on the same edge as the parent's.
          const SizedBox(width: badgeColumnWidth),
          const SizedBox(width: AppSpacing.md),
          CategorySpendColumns(
            key: Key('categorySpend-${category.id}'),
            spend: spend,
            currency: currency,
            // No hue: a subrow shows the amount alone (frame 08), so the bar's
            // slot stays reserved and empty rather than drawn.
            barColor: null,
          ),
          const SizedBox(width: AppSpacing.md),
          // A system subcategory carries no lock of its own: its parent row
          // already states the group is read-only, and a column of repeated
          // padlocks would read as six separate refusals instead of one.
          if (category.isSystem)
            const SizedBox(width: actionsColumnWidth)
          else
            CategoryRowActions(category: category, onEdit: onEdit, onDelete: onDelete),
        ],
      ),
    );
  }
}

/// The three spend columns shared by both row kinds: bar · share · amount.
///
/// One widget for parents and subcategories so the amounts stay in one column
/// down the whole panel — a subrow that laid its own amount out would drift off
/// the parent's decimal point the moment either changed.
class CategorySpendColumns extends StatelessWidget {
  const CategorySpendColumns({
    super.key,
    required this.spend,
    required this.currency,
    required this.barColor,
  });

  final CategorySpend? spend;
  final String? currency;

  /// The category's hue, or `null` on rows that show the amount alone.
  final Color? barColor;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final textTheme = Theme.of(context).textTheme;
    final quiet = textTheme.bodySmall!.copyWith(color: AppColors.textSecondary);
    final amount = spend;
    final currencyCode = currency;

    return Row(
      children: [
        SizedBox(
          width: CategorySpendBar.width,
          child: barColor == null || currencyCode == null
              ? null
              : CategorySpendBar(fraction: amount?.fraction ?? 0, color: barColor!),
        ),
        const SizedBox(width: AppSpacing.md),
        SizedBox(
          width: sharePctColumnWidth,
          child: currencyCode == null || amount == null
              ? null
              : Text(
                  formatSharePct(amount.pct, locale),
                  textAlign: TextAlign.end,
                  style: tabularNumberStyle(quiet),
                ),
        ),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(
          width: spendAmountColumnWidth,
          child: switch ((currencyCode, amount)) {
            (null, _) => null,
            // Nothing spent here this month. The dash sits in the amount column
            // only: repeating it in the share column would state the same
            // absence twice, and « 0,0 % » would state it as a measurement.
            (_, null) => Text(
              l10n.categorySpendNone,
              key: const Key('categorySpendNone'),
              textAlign: TextAlign.end,
              style: quiet,
            ),
            (final String code, final CategorySpend value) => Align(
              alignment: Alignment.centerRight,
              child: AmountText(
                amountMinor: value.amountMinor,
                currency: code,
                // A month's total for a category is a figure, not a movement:
                // it stays in the primary ink rather than turning red for
                // being spending, which every row here is.
                colorize: false,
                style: textTheme.bodySmall,
              ),
            ),
          },
        ),
      ],
    );
  }
}

/// The trailing pair: a lock on system rows, or delete + ⋯ on the user's own.
///
/// Delete is its own glyph rather than a second entry in the ⋯ menu because it
/// is the action a user reaches for by name — and keeping it visible means the
/// row's two outcomes, edit and remove, are both legible without opening
/// anything. It still asks for confirmation before it fires (see the screen).
class CategoryRowActions extends StatelessWidget {
  const CategoryRowActions({
    super.key,
    required this.category,
    required this.onEdit,
    required this.onDelete,
  });

  final AppCategory category;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (category.isSystem) {
      return SizedBox(
        width: actionsColumnWidth,
        child: Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            // The lock takes the footprint of one icon button, so it centres on
            // the same axis as the ⋯ it stands in for.
            width: _iconButtonExtent,
            child: Tooltip(
              message: l10n.categorySystemLockedTooltip,
              child: Icon(
                Icons.lock_outline_rounded,
                key: Key('categoryLock-${category.id}'),
                size: 16,
                color: AppColors.textDisabled,
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: actionsColumnWidth,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          IconButton(
            key: Key('categoryDelete-${category.id}'),
            onPressed: onDelete,
            tooltip: l10n.categoryDelete,
            iconSize: 16,
            visualDensity: VisualDensity.compact,
            color: AppColors.textSecondary,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
          IconButton(
            key: Key('categoryEdit-${category.id}'),
            onPressed: onEdit,
            tooltip: l10n.categoryEdit,
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            color: AppColors.textSecondary,
            icon: const Icon(Icons.more_horiz_rounded),
          ),
        ],
      ),
    );
  }
}
