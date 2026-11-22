import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../../core/l10n/category_display.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_link.dart';
import '../../../core/widgets/app_select.dart';
import '../../../core/widgets/app_table.dart';
import '../../../core/widgets/category_label.dart';
import '../../../core/widgets/focus_ring.dart';
import '../../../core/widgets/institution_avatar.dart';
import '../../../l10n/app_localizations.dart';
import '../../accounts/application/accounts_controller.dart';
import '../../accounts/domain/account.dart';
import '../../categories/domain/category.dart';
import '../application/transaction_selection.dart';
import '../application/transactions_controller.dart';
import '../domain/transaction.dart';
import 'category_picker.dart';
import 'date_range_modal.dart';
import 'transaction_labels.dart';

/// The list pane of the « Toutes » tab (`07-transactions.md` §List pane): the
/// filter row, the table grouped by day, and the pager.
class TransactionsListPane extends StatelessWidget {
  const TransactionsListPane({super.key, required this.page});

  final TransactionsPage page;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('transactionsListPane'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FilterRow(page: page),
        Expanded(
          child: page.items.isEmpty
              ? const _NoResult()
              : _TransactionsTable(page: page),
        ),
        _Pager(page: page),
      ],
    );
  }
}

/// Padding 12 32, 8 px apart: accounts, period, categories, the import an
/// import history row narrowed the list to, then the count and the net.
class _FilterRow extends ConsumerWidget {
  const _FilterRow({required this.page});

  final TransactionsPage page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final filters = ref.watch(transactionFiltersProvider);
    final notifier = ref.read(transactionFiltersProvider.notifier);
    final accounts =
        ref.watch(accountsControllerProvider).value ?? const <Account>[];
    final categories = ref.watch(transactionFilterCategoriesProvider);
    final caption = tabularNumberStyle(
      Theme.of(context).textTheme.bodySmall!,
    ).copyWith(color: colors.textTertiary);
    final net = page.netMinor;
    final currency = page.items.firstOrNull?.currency;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageX,
        vertical: AppTransactions.filterRowY,
      ),
      child: Row(
        children: [
          _FilterSlot(
            child: AppSelect<String?>.toolbar(
              key: const Key('transactionsAccountFilter'),
              value: filters.accountId,
              onChanged: notifier.setAccount,
              items: [
                AppSelectItem(
                  value: null,
                  label: l10n.transactionsFilterAllAccounts,
                ),
                for (final account in accounts)
                  AppSelectItem(value: account.id, label: account.name),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _FilterSlot(
            child: _PeriodSelect(
              from: filters.dateFrom,
              to: filters.dateTo,
              onChanged: notifier.setDateRange,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _FilterSlot(
            child: AppSelect<String?>.toolbar(
              key: const Key('transactionsCategoryFilter'),
              value: filters.categoryId,
              onChanged: notifier.setCategory,
              items: [
                AppSelectItem(
                  value: null,
                  label: l10n.transactionsFilterAllCategories,
                ),
                for (final category in categories)
                  AppSelectItem(
                    value: category.id,
                    label: localizedCategoryName(l10n, category.name),
                    leading: _CategoryGlyph(category: category),
                  ),
              ],
            ),
          ),
          if (filters.importBatch case final batch?) ...[
            const SizedBox(width: AppSpacing.sm),
            _FilterSlot(
              child: _ImportFilterChip(
                fileName: batch.fileName,
                onRemove: notifier.clearImport,
              ),
            ),
          ],
          const Spacer(),
          if (net != null && currency != null) ...[
            const SizedBox(width: AppSpacing.sm),
            Text(
              '${l10n.transactionsCountNet(page.total)} ',
              key: const Key('transactionsCountNet'),
              style: caption,
            ),
            AmountText(
              key: const Key('transactionsNet'),
              amountMinor: net,
              currency: currency,
              showPositiveSign: true,
              style: caption,
            ),
          ],
        ],
      ),
    );
  }
}

/// A filter control's room in the row: up to [AppTransactions.filterMaxWidth],
/// less when the row runs short.
class _FilterSlot extends StatelessWidget {
  const _FilterSlot({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Flexible(
    child: ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: AppTransactions.filterMaxWidth,
      ),
      child: child,
    ),
  );
}

/// A main category's glyph in its hue, before its name in the filter menu.
class _CategoryGlyph extends StatelessWidget {
  const _CategoryGlyph({required this.category});

  final AppCategory category;

  @override
  Widget build(BuildContext context) {
    final slug = categorySlugFor(name: category.name, kind: category.kind);
    return Icon(
      CategoryIcons.forSlug(slug),
      size: AppSizes.iconSmall,
      color: context.categoryColors.forSlot(
        CategorySlot.fromWire(category.color),
      ),
    );
  }
}

/// The select look with a leading `calendar` (`07` §List pane): it opens the
/// period modal rather than a menu.
class _PeriodSelect extends StatefulWidget {
  const _PeriodSelect({
    required this.from,
    required this.to,
    required this.onChanged,
  });

  final DateTime? from;
  final DateTime? to;
  final void Function(DateTime? from, DateTime? to) onChanged;

  @override
  State<_PeriodSelect> createState() => _PeriodSelectState();
}

class _PeriodSelectState extends State<_PeriodSelect> {
  bool _hovered = false;
  bool _focused = false;

  Future<void> _open() async {
    final range = await showTransactionDateRange(
      context,
      from: widget.from,
      to: widget.to,
    );
    if (range != null) widget.onChanged(range.$1, range.$2);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final colors = context.colors;

    return FocusableActionDetector(
      key: const Key('transactionsPeriodFilter'),
      mouseCursor: SystemMouseCursors.click,
      onShowHoverHighlight: (value) => setState(() => _hovered = value),
      onShowFocusHighlight: (value) => setState(() => _focused = value),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            _open();
            return null;
          },
        ),
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _open,
        child: FocusRing(
          focused: _focused,
          radius: AppRadii.control,
          child: Container(
            height: AppSizes.toolbarSelect,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm + AppSpacing.xxs,
            ),
            decoration: BoxDecoration(
              color: _hovered ? colors.hover : colors.field,
              borderRadius: BorderRadius.circular(AppRadii.control),
              border: Border.all(color: colors.lineStrong),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons300.calendar,
                  size: AppSizes.iconSmall,
                  color: colors.textTertiary,
                ),
                const SizedBox(width: AppSpacing.xsPlus),
                Flexible(
                  child: Text(
                    periodLabel(l10n, locale, widget.from, widget.to),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tabularNumberStyle(
                      Theme.of(context).textTheme.bodyMedium!,
                    ),
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

/// The import an import history row narrowed the list to, with the means to
/// lift that filter: toolbar select geometry with the Imports icon and a
/// ghost `x` in place of the chevron.
class _ImportFilterChip extends StatelessWidget {
  const _ImportFilterChip({required this.fileName, required this.onRemove});

  final String fileName;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;

    return Container(
      key: const Key('transactionsImportFilter'),
      height: AppSizes.toolbarSelect,
      padding: const EdgeInsetsDirectional.only(
        start: AppSpacing.sm + AppSpacing.xxs,
        end: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: colors.field,
        borderRadius: BorderRadius.circular(AppRadii.control),
        border: Border.all(color: colors.lineStrong),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons300.download,
            size: AppSizes.iconSmall,
            color: colors.textTertiary,
          ),
          const SizedBox(width: AppSpacing.xsPlus),
          Flexible(
            child: Text(
              l10n.transactionsFilterImport(fileName),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: AppSpacing.xxs),
          IconButton(
            key: const Key('transactionsImportFilterRemove'),
            onPressed: onRemove,
            tooltip: l10n.transactionsFilterImportRemove,
            iconSize: AppSizes.iconSmall,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(
              width: AppSizes.iconSmall + AppSpacing.sm,
              height: AppSizes.iconSmall + AppSpacing.sm,
            ),
            icon: Icon(LucideIcons300.x, color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// No row for the filters: « Aucune opération pour ces filtres. » and the link
/// that lifts them.
class _NoResult extends ConsumerWidget {
  const _NoResult();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.transactionsNoResult,
            key: const Key('transactionsNoResult'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          AppLink(
            key: const Key('transactionsClearFilters'),
            label: l10n.transactionsClearFilters,
            small: false,
            onTap: ref.read(transactionFiltersProvider.notifier).clearFilters,
          ),
        ],
      ),
    );
  }
}

/// The table, edge to edge, rows grouped by day under a group row, newest
/// first. `↑` `↓` move the selection and `C` opens the category picker of the
/// selected row while the table has the focus.
class _TransactionsTable extends ConsumerStatefulWidget {
  const _TransactionsTable({required this.page});

  final TransactionsPage page;

  @override
  ConsumerState<_TransactionsTable> createState() => _TransactionsTableState();
}

class _TransactionsTableState extends ConsumerState<_TransactionsTable> {
  final _focusNode = FocusNode(debugLabel: 'transactionsTable');

  /// The selected row's category cell, the anchor `C` opens the picker under.
  final _selectedCategoryKey = GlobalKey();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final selection = ref.read(selectedTransactionProvider.notifier);
    final items = widget.page.items;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        selection.move(items, 1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        selection.move(items, -1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.keyC when event is KeyDownEvent:
        final selected = ref.read(selectedTransactionOnPageProvider);
        final anchor = _selectedCategoryKey.currentContext;
        if (selected == null || anchor == null) return KeyEventResult.ignored;
        showCategoryPicker(anchor, ref, transaction: selected);
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  static List<AppTableColumn> _columns(AppLocalizations l10n) => [
    AppTableColumn(label: l10n.transactionsColumnOperation),
    AppTableColumn(
      label: l10n.transactionsColumnCategory,
      width: AppTransactions.categoryColumn,
    ),
    AppTableColumn(
      label: l10n.transactionsColumnAmount,
      width: AppTransactions.amountColumn,
      numeric: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final selectedId = ref.watch(selectedTransactionProvider);
    final columns = _columns(l10n);
    final days = groupByDay(widget.page.items);

    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _onKey,
      child: ListView(
        key: const Key('transactionsList'),
        children: [
          AppTableHeader(columns: columns, inset: edgeTableInset),
          for (final day in days) ...[
            AppTableGroupRow(
              key: Key('transactionsDay-${day.date.toIso8601String()}'),
              label: dayLabel(locale, day.date),
              inset: edgeTableInset,
            ),
            for (final transaction in day.items)
              _TransactionRow(
                key: Key('transactionRow-${transaction.id}'),
                transaction: transaction,
                columns: columns,
                selected: transaction.id == selectedId,
                categoryKey: transaction.id == selectedId
                    ? _selectedCategoryKey
                    : null,
                onTap: () {
                  ref
                      .read(selectedTransactionProvider.notifier)
                      .select(transaction.id);
                  _focusNode.requestFocus();
                },
              ),
          ],
        ],
      ),
    );
  }
}

/// One operation: monogram and name, its top-level category, its signed
/// amount.
class _TransactionRow extends ConsumerWidget {
  const _TransactionRow({
    super.key,
    required this.transaction,
    required this.columns,
    required this.selected,
    required this.onTap,
    this.categoryKey,
  });

  final Transaction transaction;
  final List<AppTableColumn> columns;
  final bool selected;
  final VoidCallback onTap;
  final GlobalKey? categoryKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unnamed = isUnnamed(transaction);

    return AppTableRow(
      columns: columns,
      selected: selected,
      inset: edgeTableInset,
      onTap: onTap,
      cells: [
        Row(
          children: [
            InstitutionAvatar(
              name: unnamed ? '' : transactionName(transaction),
              logo: transaction.logo,
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                transactionName(transaction),
                key: const Key('transactionRowName'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: unnamed ? TextStyle(fontFamily: AppFonts.mono) : null,
              ),
            ),
          ],
        ),
        Builder(
          key: categoryKey,
          builder: (cellContext) => TransactionCategoryLabel(
            key: const Key('transactionRowCategory'),
            category: transaction.category,
            onTap: () =>
                showCategoryPicker(cellContext, ref, transaction: transaction),
          ),
        ),
        AmountText(
          amountMinor: transaction.amountMinor,
          currency: transaction.currency,
          showPositiveSign: true,
        ),
      ],
    );
  }
}

/// Padding 10 32 over a top hairline: « 1 – 50 sur 128 », then the previous
/// and next pages.
class _Pager extends ConsumerWidget {
  const _Pager({required this.page});

  final TransactionsPage page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final notifier = ref.read(transactionFiltersProvider.notifier);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageX,
        vertical: AppTransactions.pagerY,
      ),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.line)),
      ),
      child: Row(
        children: [
          Text(
            l10n.transactionsPager(page.firstIndex, page.lastIndex, page.total),
            key: const Key('transactionsPagerLabel'),
            style: tabularNumberStyle(
              Theme.of(context).textTheme.bodySmall!,
            ).copyWith(color: colors.textTertiary),
          ),
          const Spacer(),
          AppButton(
            key: const Key('transactionsPagerPrev'),
            label: l10n.transactionsPagerPrevious,
            icon: LucideIcons300.chevronLeft,
            iconOnly: true,
            onPressed: page.page > 1
                ? () => notifier.setPage(page.page - 1)
                : null,
          ),
          const SizedBox(width: AppSpacing.sm),
          AppButton(
            key: const Key('transactionsPagerNext'),
            label: l10n.transactionsPagerNext,
            icon: LucideIcons300.chevronRight,
            iconOnly: true,
            onPressed: page.page < page.totalPages
                ? () => notifier.setPage(page.page + 1)
                : null,
          ),
        ],
      ),
    );
  }
}
