import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/category_display.dart';
import '../../../core/l10n/date_display.dart';
import '../../../core/widgets/category_label.dart';
import '../../../core/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../application/transaction_selection.dart';
import '../application/transactions_controller.dart';
import '../domain/transaction.dart';

/// Whether no rule or import named this operation's merchant: the panel then
/// shows the raw bank label in Geist Mono beside the « ? » monogram
/// (`07-transactions.md` §List pane).
bool isUnnamed(Transaction transaction) =>
    transaction.merchant?.trim().isEmpty ?? true;

/// The operation's name: its merchant, or its raw bank label when nothing
/// named it.
String transactionName(Transaction transaction) => isUnnamed(transaction)
    ? transaction.descriptionRaw
    : transaction.merchant!.trim();

/// The period select's label: « 1 – 31 mai 2026 », « 3 avr. – 2 mai 2026 »,
/// or both dates in full across two years; « Toutes les dates » unset.
String periodLabel(
  AppLocalizations l10n,
  String locale,
  DateTime? from,
  DateTime? to,
) {
  if (from == null || to == null) return l10n.transactionsFilterAllDates;
  final full = DayMonthFormat.yMMMd(locale);
  final String start;
  if (from.year == to.year && from.month == to.month) {
    start = DayMonthFormat.d(locale).format(from);
  } else if (from.year == to.year) {
    start = DayMonthFormat.MMMd(locale).format(from);
  } else {
    start = full.format(from);
  }
  return l10n.transactionsPeriodRange(start, full.format(to));
}

/// The group row's day: « 14 mai 2026 ».
String dayLabel(String locale, DateTime date) =>
    DayMonthFormat.yMMMMd(locale).format(date);

/// « Classée par »: the rule's pattern, the local AI and its confidence,
/// « vous », or « non classée ».
String classifiedByLabel(
  AppLocalizations l10n,
  Transaction transaction,
  TransactionContext? context,
) {
  final confidence = transaction.categorizationConfidence;
  return switch (transaction.categorizationSource) {
    // The rule that filed a row is resolved when read; one since edited away
    // leaves the source standing without a pattern to name.
    CategorizationSource.rule => l10n.transactionClassifiedByRule(
      context?.rule?.pattern ?? '—',
    ),
    CategorizationSource.model when confidence != null =>
      l10n.transactionClassifiedByModel(confidence),
    CategorizationSource.user => l10n.transactionClassifiedByUser,
    _ => l10n.transactionClassifiedByNone,
  };
}

/// An operation's category as a category label (`00` §7): the top-level
/// category in its hue, and, when [full], the subcategory after « › ». Tapping
/// it calls [onTap]. Uncategorised: « Non catégorisé » on its dashed
/// underline.
class TransactionCategoryLabel extends ConsumerWidget {
  const TransactionCategoryLabel({
    super.key,
    required this.category,
    this.full = false,
    this.onTap,
    this.confidence,
  });

  final TransactionCategory? category;
  final bool full;
  final VoidCallback? onTap;

  /// A proposal's caption (« confiance 78 % »), for the review table.
  final String? confidence;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final category = this.category;
    if (category == null) {
      return CategoryLabel.uncategorized(
        label: l10n.categoryUncategorized,
        onTap: onTap,
      );
    }
    final catalog = ref.watch(transactionCategoriesProvider).value;
    final lineage = catalog == null
        ? null
        : categoryLineage(catalog, category.id);
    final topName = lineage?.top.name ?? category.name;
    final sub = full ? lineage?.sub : null;
    final slot = lineage == null
        ? CategoryColors.slotForSlug(
            categorySlugFor(name: category.name, kind: category.kind),
          )
        : CategorySlot.fromWire(lineage.top.color);
    final label = CategoryLabel.slotted(
      label: localizedCategoryName(l10n, topName),
      slot: slot,
      subcategory: sub == null ? null : localizedCategoryName(l10n, sub.name),
      onTap: confidence == null ? onTap : null,
    );
    if (confidence == null) return label;
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: label),
          const SizedBox(width: AppSpacing.sm),
          Text(
            confidence!,
            key: const Key('categoryLabelConfidence'),
            maxLines: 1,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: context.colors.textTertiary),
          ),
        ],
      ),
    );
  }
}
