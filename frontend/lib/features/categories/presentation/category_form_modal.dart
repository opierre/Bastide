import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../../core/l10n/category_display.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_modal.dart';
import '../../../core/widgets/app_segmented.dart';
import '../../../core/widgets/app_select.dart';
import '../../../core/widgets/category_label.dart';
import '../../../core/widgets/focus_ring.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../l10n/app_localizations.dart';
import '../application/categories_controller.dart';
import '../domain/category.dart';
import 'category_color.dart';
import 'category_delete.dart';
import 'category_error_localizer.dart';
import 'category_labels.dart';

/// Opens the create/edit category modal. Resolves to the saved category, or
/// `null` when the user cancelled or deleted it.
///
/// [parent] presets a new category's parent — the « + Sous-catégorie » chip on
/// a card. A subcategory always takes its parent's kind, icon and colour, so
/// while a parent is set none of them is shown: the header names the parent.
Future<AppCategory?> showCategoryForm(
  BuildContext context, {
  AppCategory? initial,
  AppCategory? parent,
}) {
  return showAppModal<AppCategory>(
    context: context,
    builder: (_) => CategoryFormModal(initial: initial, parent: parent),
  );
}

/// Create/edit modal for a user category, 480 px (`docs/design/08` §Category
/// form, proposal v6 `m-categories`): Nom · Type (a segmented control) ·
/// Catégorie parente · Icône (a grid of the curated Lucide set) · Couleur
/// (the seven category slots). With a parent set, Type, Icône and Couleur are
/// hidden and the lead repeats the parent's category label.
///
/// System categories never reach it: they have no edit affordance, and the API
/// would 404 the patch anyway. The form only ever writes the user's own rows.
class CategoryFormModal extends ConsumerStatefulWidget {
  const CategoryFormModal({super.key, this.initial, this.parent});

  final AppCategory? initial;
  final AppCategory? parent;

  @override
  ConsumerState<CategoryFormModal> createState() => _CategoryFormModalState();
}

class _CategoryFormModalState extends ConsumerState<CategoryFormModal> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.initial?.name,
  );

  late String _kind = widget.initial?.kind ?? widget.parent?.kind ?? 'expense';
  late String? _parentId = widget.initial?.parentId ?? widget.parent?.id;
  // A row saved before Lucide carries a legacy key: the form shows (and saves
  // back) its Lucide equivalent rather than an empty select.
  late String _icon =
      CategoryIcons.resolveKey(widget.initial?.icon) ??
      CategoryIcons.slugKeys['autres']!;
  late CategorySlot _slot = switch ((widget.initial, widget.parent)) {
    (final AppCategory initial, _) => categorySlot(initial),
    (null, final AppCategory parent) => categorySlot(parent),
    _ => CategorySlot.cat0,
  };

  bool _dirty = false;
  bool _isSubmitting = false;
  String? _errorText;

  bool get _isEditing => widget.initial != null;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// Every category that could hold this one: top-level rows only (the data
  /// model is two levels deep), and never the category being edited — a
  /// category parented to itself would vanish from the tree.
  List<AppCategory> _parentOptions(List<AppCategory> categories) => [
    for (final category in categories)
      if (category.parentId == null && category.id != widget.initial?.id)
        category,
  ];

  /// The chosen parent, looked up in the loaded list — falling back to the
  /// preset one, so the lock holds even before the list has arrived.
  AppCategory? _selectedParent(List<AppCategory> categories) {
    final id = _parentId;
    if (id == null) return null;
    for (final category in categories) {
      if (category.id == id) return category;
    }
    return widget.parent?.id == id ? widget.parent : null;
  }

  /// A choice outside a text field: it counts as unsaved input too.
  void _edit(VoidCallback change) => setState(() {
    change();
    _dirty = true;
  });

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    final categories =
        ref.read(categoriesControllerProvider).value ?? const <AppCategory>[];
    final parent = _selectedParent(categories);
    final kind = parent?.kind ?? _kind;
    final icon = parent == null ? _icon : categoryIconKey(parent);
    final color = (parent == null ? _slot : categorySlot(parent)).wire;
    final controller = ref.read(categoriesControllerProvider.notifier);
    try {
      final saved = _isEditing
          ? await controller.updateCategory(
              widget.initial!.id,
              name: _nameController.text.trim(),
              kind: kind,
              icon: icon,
              color: color,
              parentId: _parentId,
              clearParent: _parentId == null,
            )
          : await controller.create(
              name: _nameController.text.trim(),
              kind: kind,
              icon: icon,
              color: color,
              parentId: _parentId,
            );
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorText = localizeCategoryError(
          AppLocalizations.of(context)!,
          error,
        );
      });
    }
  }

  /// Deletes the category being edited, after the same confirmation the card's
  /// ⋯ menu asks. The subcategory chips have no menu of their own, so this is
  /// where a user's subcategory is removed.
  Future<void> _delete() async {
    final category = widget.initial!;
    if (!await confirmCategoryDelete(context, category)) return;
    if (!mounted) return;
    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });
    try {
      await ref.read(categoriesControllerProvider.notifier).delete(category.id);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorText = localizeCategoryError(
          AppLocalizations.of(context)!,
          error,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final categories =
        ref.watch(categoriesControllerProvider).value ?? const <AppCategory>[];
    // A subcategory's kind, icon and colour are its parent's, so the form drops
    // those fields and names the parent under the title instead.
    final parent = _selectedParent(categories);

    return AppModal(
      key: const Key('categoryFormModal'),
      title: _isEditing
          ? l10n.categoryFormEditTitle
          : l10n.categoryFormCreateTitle,
      subtitle: parent == null ? null : _ParentLine(parent: parent),
      width: AppCategoriesPanel.categoryFormWidth,
      dirty: _dirty,
      busy: _isSubmitting,
      saveError: _errorText,
      onSubmit: _submit,
      // On the footer's left, as in the rule editor: furthest from
      // « Enregistrer ».
      leadingAction: _isEditing
          ? AppButton(
              key: const Key('categoryFormDelete'),
              label: l10n.categoryDelete,
              variant: AppButtonVariant.ghost,
              onPressed: _isSubmitting ? null : _delete,
            )
          : null,
      actions: [
        const AppModalCancel(key: Key('categoryFormCancel')),
        PrimaryButton(
          key: const Key('categoryFormSubmit'),
          label: l10n.categoryFormSave,
          isLoading: _isSubmitting,
          onPressed: _isSubmitting ? null : _submit,
        ),
      ],
      child: Form(
        key: _formKey,
        // Typed input makes the form dirty: the scrim no longer closes it.
        onChanged: () {
          if (!_dirty) setState(() => _dirty = true);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LabeledField(
              label: l10n.categoryFormNameLabel,
              child: TextFormField(
                key: const Key('categoryFormName'),
                controller: _nameController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l10n.categoryFormNameHint,
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? l10n.categoryFormNameRequired
                    : null,
              ),
            ),
            if (parent == null) ...[
              const SizedBox(height: AppSpacing.fieldGap),
              LabeledField(
                label: l10n.categoryFormKindLabel,
                helper: l10n.categoryFormKindHelper,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: AppSegmented<String>(
                    key: const Key('categoryFormKind'),
                    value: _kind,
                    onChanged: (value) => _edit(() => _kind = value),
                    segments: [
                      for (final kind in const [
                        'expense',
                        'income',
                        'transfer',
                      ])
                        AppSegment(
                          key: Key('categoryFormKind-$kind'),
                          value: kind,
                          label: categoryKindLabel(l10n, kind),
                        ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.fieldGap),
            LabeledField(
              label: l10n.categoryFormParentLabel,
              child: AppSelect<String?>(
                key: const Key('categoryFormParent'),
                value: _parentId,
                onChanged: (value) => _edit(() => _parentId = value),
                items: [
                  AppSelectItem(
                    value: null,
                    label: l10n.categoryFormParentNone,
                  ),
                  // Each parent as its category label: the hue's dot, then
                  // the name.
                  for (final parent in _parentOptions(categories))
                    AppSelectItem(
                      value: parent.id,
                      label: localizedCategoryName(l10n, parent.name),
                      leading: _SlotDot(slot: categorySlot(parent)),
                    ),
                ],
              ),
            ),
            if (parent == null) ...[
              const SizedBox(height: AppSpacing.fieldGap),
              LabeledField(
                label: l10n.categoryFormIconLabel,
                child: _IconGrid(
                  selected: _icon,
                  onSelected: (key) => _edit(() => _icon = key),
                ),
              ),
              const SizedBox(height: AppSpacing.fieldGap),
              LabeledField(
                label: l10n.categoryFormColorLabel,
                helper: l10n.categoryFormColorHelper,
                child: _ColorPicker(
                  selected: _slot,
                  onSelected: (slot) => _edit(() => _slot = slot),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}

/// The lead of a subcategory's modal: the parent's category label (`00`
/// §7), standing in for the kind, icon and colour the subcategory inherits.
class _ParentLine extends StatelessWidget {
  const _ParentLine({required this.parent});

  final AppCategory parent;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Align(
      key: const Key('categoryFormParentLine'),
      alignment: AlignmentDirectional.centerStart,
      child: CategoryLabel.slotted(
        label: localizedCategoryName(l10n, parent.name),
        slot: categorySlot(parent),
      ),
    );
  }
}

/// The curated Lucide set as a grid of 32 px cells, 2 px apart; the selected
/// cell takes the `hover` ground and a 2 px `accent` outline inside its edge. Each cell names its glyph in a
/// tooltip, which is also its semantic label.
class _IconGrid extends StatelessWidget {
  const _IconGrid({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;

    return Wrap(
      key: const Key('categoryFormIcon'),
      spacing: AppSpacing.xxs,
      runSpacing: AppSpacing.xxs,
      children: [
        for (final key in CategoryIcons.glyphs.keys)
          Tooltip(
            message: categoryIconLabel(l10n, key),
            child: Semantics(
              button: true,
              selected: key == selected,
              label: categoryIconLabel(l10n, key),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  key: Key('categoryFormIcon-$key'),
                  onTap: () => onSelected(key),
                  child: Container(
                    width: AppCategoriesPanel.iconCell,
                    height: AppCategoriesPanel.iconCell,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: key == selected ? colors.hover : null,
                      borderRadius: BorderRadius.circular(AppRadii.control),
                      border: key == selected
                          ? Border.all(
                              color: colors.accent,
                              width: FocusRing.width,
                            )
                          : null,
                    ),
                    child: Icon(
                      CategoryIcons.forKey(key),
                      size: AppSizes.icon,
                      color: key == selected
                          ? colors.text
                          : colors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The seven category slots as 20 px squares, 8 px apart, each named (« Bleu »)
/// in a tooltip that is also its semantic label. A picker rather than a colour
/// wheel: the hues are fixed by the design system so a category means the same
/// colour in every chart, legend and label (`00` §2.4). The selected square
/// takes the 2 px `accent` outline and a 12 px `check`, in `bg` on the dark
/// theme and `text` on the light one, so the choice does not rest on colour
/// alone.
class _ColorPicker extends StatelessWidget {
  const _ColorPicker({required this.selected, required this.onSelected});

  final CategorySlot selected;
  final ValueChanged<CategorySlot> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final check = Theme.of(context).brightness == Brightness.dark
        ? colors.bg
        : colors.text;

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final slot in CategorySlot.pickable)
          Tooltip(
            message: l10n.categoryColorName(slot.wire),
            child: Semantics(
              button: true,
              selected: slot == selected,
              label: l10n.categoryColorName(slot.wire),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  key: Key('categoryFormColor-${slot.wire}'),
                  onTap: () => onSelected(slot),
                  child: FocusRing(
                    focused: slot == selected,
                    radius: AppRadii.item,
                    child: Container(
                      width: AppCategoriesPanel.colorSquare,
                      height: AppCategoriesPanel.colorSquare,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: context.categoryColors.forSlot(slot),
                        borderRadius: BorderRadius.circular(AppRadii.item),
                      ),
                      child: slot == selected
                          ? Icon(
                              LucideIcons300.check,
                              key: const Key('categoryFormColorCheck'),
                              size: AppCategoriesPanel.colorCheck,
                              color: check,
                            )
                          : null,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The 8 px dot of a category label (`00` §7), before a parent's name in the
/// parent select.
class _SlotDot extends StatelessWidget {
  const _SlotDot({required this.slot});

  final CategorySlot slot;

  @override
  Widget build(BuildContext context) => Container(
    width: CategoryLabel.dotSize,
    height: CategoryLabel.dotSize,
    decoration: BoxDecoration(
      color: context.categoryColors.forSlot(slot),
      borderRadius: BorderRadius.circular(AppRadii.bar),
    ),
  );
}
