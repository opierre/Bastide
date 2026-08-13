import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/category_display.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_modal.dart';
import '../../../core/widgets/app_select.dart';
import '../../../core/widgets/category_chip.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../l10n/app_localizations.dart';
import '../application/categories_controller.dart';
import '../domain/category.dart';
import 'category_color.dart';
import 'category_error_localizer.dart';
import 'category_labels.dart';

/// Opens the create/edit category modal. Resolves to the saved category, or
/// `null` when the user cancelled.
Future<AppCategory?> showCategoryForm(BuildContext context, {AppCategory? initial}) {
  return showDialog<AppCategory>(
    context: context,
    builder: (_) => CategoryFormModal(initial: initial),
  );
}

/// Create/edit modal for a user category — Nom, Kind, Parent, icône, couleur,
/// following the 05 modal pattern at 480 px (`docs/design/08`).
///
/// System categories never reach it: they have no edit affordance, and the API
/// would 404 the patch anyway. The form only ever writes the user's own rows.
class CategoryFormModal extends ConsumerStatefulWidget {
  const CategoryFormModal({super.key, this.initial});

  final AppCategory? initial;

  @override
  ConsumerState<CategoryFormModal> createState() => _CategoryFormModalState();
}

class _CategoryFormModalState extends ConsumerState<CategoryFormModal> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.initial?.name);

  late String _kind = widget.initial?.kind ?? 'expense';
  late String? _parentId = widget.initial?.parentId;
  late String _icon = widget.initial?.icon ?? 'autres';
  late Color _color = widget.initial == null
      ? categoryPalette.last
      : categoryColor(widget.initial!);

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
      if (category.parentId == null && category.id != widget.initial?.id) category,
  ];

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    final controller = ref.read(categoriesControllerProvider.notifier);
    try {
      final saved = _isEditing
          ? await controller.updateCategory(
              widget.initial!.id,
              name: _nameController.text.trim(),
              kind: _kind,
              icon: _icon,
              color: hexOf(_color),
              parentId: _parentId,
              clearParent: _parentId == null,
            )
          : await controller.create(
              name: _nameController.text.trim(),
              kind: _kind,
              icon: _icon,
              color: hexOf(_color),
              parentId: _parentId,
            );
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorText = localizeCategoryError(AppLocalizations.of(context)!, error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final categories = ref.watch(categoriesControllerProvider).value ?? const <AppCategory>[];

    return AppModal(
      title: _isEditing ? l10n.categoryFormEditTitle : l10n.categoryFormCreateTitle,
      width: 480,
      actions: [
        OutlinedButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.categoryFormCancel),
        ),
        PrimaryButton(
          key: const Key('categoryFormSubmit'),
          label: l10n.categoryFormSave,
          isLoading: _isSubmitting,
          onPressed: _isSubmitting ? null : _submit,
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_errorText != null) ...[
              InlineBanner(key: const Key('categoryFormError'), message: _errorText!),
              const SizedBox(height: AppSpacing.md),
            ],
            LabeledField(
              label: l10n.categoryFormNameLabel,
              child: TextFormField(
                key: const Key('categoryFormName'),
                controller: _nameController,
                autofocus: true,
                decoration: InputDecoration(hintText: l10n.categoryFormNameHint),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? l10n.categoryFormNameRequired
                    : null,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            LabeledField(
              label: l10n.categoryFormKindLabel,
              helper: l10n.categoryFormKindHelper,
              child: AppSelect<String>(
                key: const Key('categoryFormKind'),
                value: _kind,
                onChanged: (value) => setState(() => _kind = value),
                items: [
                  for (final kind in const ['expense', 'income', 'transfer'])
                    AppSelectItem(value: kind, label: categoryKindLabel(l10n, kind)),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            LabeledField(
              label: l10n.categoryFormParentLabel,
              child: AppSelect<String?>(
                key: const Key('categoryFormParent'),
                value: _parentId,
                onChanged: (value) => setState(() => _parentId = value),
                items: [
                  AppSelectItem(value: null, label: l10n.categoryFormParentNone),
                  for (final parent in _parentOptions(categories))
                    AppSelectItem(
                      value: parent.id,
                      label: localizedCategoryName(l10n, parent.name),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            LabeledField(
              label: l10n.categoryFormIconLabel,
              child: AppSelect<String>(
                key: const Key('categoryFormIcon'),
                value: _icon,
                onChanged: (value) => setState(() => _icon = value),
                items: [
                  for (final slug in CategoryIcons.bySlug.keys)
                    AppSelectItem(
                      value: slug,
                      label: categoryIconLabel(l10n, slug),
                      leading: Icon(
                        CategoryIcons.forSlug(slug),
                        size: 15,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            LabeledField(
              label: l10n.categoryFormColorLabel,
              helper: l10n.categoryFormColorHelper,
              child: _ColorPicker(
                selected: _color,
                onSelected: (color) => setState(() => _color = color),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}

/// The pinned palette as a row of 28 px swatches. A picker rather than a colour
/// wheel: the hues are fixed by the design system so a category means the same
/// colour in the donut, the legend and its chip.
class _ColorPicker extends StatelessWidget {
  const _ColorPicker({required this.selected, required this.onSelected});

  final Color selected;
  final ValueChanged<Color> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final color in categoryPalette)
          GestureDetector(
            key: Key('categoryFormColor-${hexOf(color)}'),
            onTap: () => onSelected(color),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  border: Border.all(
                    color: color.toARGB32() == selected.toARGB32()
                        ? color
                        : AppColors.border,
                    width: color.toARGB32() == selected.toARGB32() ? 2 : 1,
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(AppRadii.xs),
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
