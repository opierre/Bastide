import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../../core/l10n/category_display.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/category_label.dart';
import '../../../core/widgets/focus_ring.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../l10n/app_localizations.dart';
import '../application/transaction_selection.dart';
import '../application/transactions_controller.dart';
import '../domain/transaction.dart';
import 'transaction_error_localizer.dart';

/// Opens the category picker under [anchorContext]'s widget
/// (`docs/design/07-transactions.md` §Category picker): a 230 px popover with
/// the 28 px « Changer de catégorie » search field, then every category and
/// subcategory as a category label, a `check` on the current one. Choosing
/// one closes it and applies it.
///
/// Assigning only. « Toujours catégoriser ainsi » is a rule form of its own
/// (`always_categorize_modal.dart`), because a rule needs a field, a condition
/// and a pattern the user can see and change.
Future<void> showCategoryPicker(
  BuildContext anchorContext,
  WidgetRef ref, {
  required Transaction transaction,
}) async {
  final anchor = anchorContext.findRenderObject()! as RenderBox;
  final overlay =
      Navigator.of(anchorContext).overlay!.context.findRenderObject()!
          as RenderBox;
  final topLeft = anchor.localToGlobal(
    Offset(0, anchor.size.height + AppSpacing.xs),
    ancestor: overlay,
  );
  final position = RelativeRect.fromRect(
    topLeft & const Size(AppTransactions.pickerWidth, 0),
    Offset.zero & overlay.size,
  );
  final colors = anchorContext.colors;

  await showMenu<void>(
    context: anchorContext,
    position: position,
    color: colors.surface,
    surfaceTintColor: Colors.transparent,
    shadowColor: colors.shadow.first.color,
    elevation: AppShadows.popoverElevation,
    menuPadding: const EdgeInsets.all(AppSpacing.xs),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.container),
      side: BorderSide(color: colors.lineStrong),
    ),
    constraints: const BoxConstraints.tightFor(
      width: AppTransactions.pickerWidth,
    ),
    items: [
      PopupMenuItem<void>(
        enabled: false,
        padding: EdgeInsets.zero,
        child: _CategoryPickerBody(transaction: transaction),
      ),
    ],
  );
}

class _CategoryPickerBody extends ConsumerStatefulWidget {
  const _CategoryPickerBody({required this.transaction});

  final Transaction transaction;

  @override
  ConsumerState<_CategoryPickerBody> createState() =>
      _CategoryPickerBodyState();
}

class _CategoryPickerBodyState extends ConsumerState<_CategoryPickerBody> {
  String _query = '';
  bool _isSaving = false;

  Future<void> _select(String categoryId) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    final l10n = AppLocalizations.of(context)!;
    final notifier = ref.read(transactionsControllerProvider.notifier);
    try {
      await notifier.updateCategory(widget.transaction, categoryId);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      showAppToast(
        context,
        title: localizeTransactionError(l10n, error),
        tone: BannerTone.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final categoriesAsync = ref.watch(transactionCategoriesProvider);
    final note = textTheme.bodySmall?.copyWith(color: colors.textSecondary);

    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.control),
      borderSide: BorderSide(color: color),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('categoryPickerSearchField'),
          autofocus: true,
          onChanged: (value) => setState(() => _query = value),
          style: textTheme.bodyMedium,
          textAlignVertical: TextAlignVertical.center,
          decoration: InputDecoration(
            hintText: l10n.categoryPickerSearchHint,
            isDense: true,
            filled: true,
            fillColor: colors.field,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm + AppSpacing.xxs,
            ),
            constraints: const BoxConstraints.tightFor(
              height: AppSizes.toolbarSelect,
            ),
            border: border(colors.lineStrong),
            enabledBorder: border(colors.lineStrong),
            focusedBorder: border(colors.accent),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        ConstrainedBox(
          constraints: const BoxConstraints(
            maxHeight: AppTransactions.pickerListHeight,
          ),
          child: switch (categoriesAsync) {
            AsyncData(:final value) => _CategoryList(
              entries: _filter(l10n, pickerOrder(value)),
              currentCategoryId: widget.transaction.category?.id,
              isSaving: _isSaving,
              onSelect: _select,
            ),
            AsyncError() => Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Text(l10n.categoryPickerLoadError, style: note),
            ),
            _ => const Padding(
              padding: EdgeInsets.all(AppSpacing.sm),
              child: Center(
                child: SizedBox.square(
                  dimension: AppSizes.iconSmall,
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                ),
              ),
            ),
          },
        ),
      ],
    );
  }

  /// Keeps the entries whose category or subcategory name holds the query.
  List<CategoryLineage> _filter(
    AppLocalizations l10n,
    List<CategoryLineage> entries,
  ) {
    final needle = _query.trim().toLowerCase();
    if (needle.isEmpty) return entries;
    bool hit(String name) =>
        localizedCategoryName(l10n, name).toLowerCase().contains(needle);
    return [
      for (final entry in entries)
        if (hit(entry.top.name) || (entry.sub != null && hit(entry.sub!.name)))
          entry,
    ];
  }
}

class _CategoryList extends StatelessWidget {
  const _CategoryList({
    required this.entries,
    required this.currentCategoryId,
    required this.isSaving,
    required this.onSelect,
  });

  final List<CategoryLineage> entries;
  final String? currentCategoryId;
  final bool isSaving;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Text(
          l10n.categoryPickerEmpty,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: context.colors.textSecondary),
        ),
      );
    }

    return ListView.builder(
      key: const Key('categoryPickerList'),
      shrinkWrap: true,
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final category = entry.sub ?? entry.top;
        return _PickerItem(
          key: Key('categoryPickerItem-${category.id}'),
          lineage: entry,
          selected: category.id == currentCategoryId,
          onTap: isSaving ? null : () => onSelect(category.id),
        );
      },
    );
  }
}

/// One 28 px item of the popover (`00` §7 Popover): radius 4, `hover` under
/// the pointer, a 14 px `check` on the current category.
class _PickerItem extends StatefulWidget {
  const _PickerItem({
    super.key,
    required this.lineage,
    required this.selected,
    required this.onTap,
  });

  final CategoryLineage lineage;
  final bool selected;
  final VoidCallback? onTap;

  @override
  State<_PickerItem> createState() => _PickerItemState();
}

class _PickerItemState extends State<_PickerItem> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final top = widget.lineage.top;
    final sub = widget.lineage.sub;

    return FocusableActionDetector(
      enabled: widget.onTap != null,
      mouseCursor: SystemMouseCursors.click,
      onShowHoverHighlight: (value) => setState(() => _hovered = value),
      onShowFocusHighlight: (value) => setState(() => _focused = value),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onTap?.call();
            return null;
          },
        ),
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: FocusRing(
          focused: _focused,
          radius: AppRadii.item,
          child: Container(
            height: AppSizes.popoverItem,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            decoration: BoxDecoration(
              color: _hovered ? colors.hover : null,
              borderRadius: BorderRadius.circular(AppRadii.item),
            ),
            child: Row(
              children: [
                Expanded(
                  child: CategoryLabel.slotted(
                    label: localizedCategoryName(l10n, top.name),
                    slot: CategorySlot.fromWire(top.color),
                    subcategory: sub == null
                        ? null
                        : localizedCategoryName(l10n, sub.name),
                  ),
                ),
                if (widget.selected) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Icon(
                    LucideIcons300.check,
                    key: const Key('categoryPickerCheck'),
                    size: AppSizes.iconSmall,
                    color: colors.text,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
