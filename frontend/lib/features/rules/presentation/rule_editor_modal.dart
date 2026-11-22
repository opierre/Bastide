import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_modal.dart';
import '../../../core/widgets/app_select.dart';
import '../../../core/widgets/app_toggle.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/modal_parts.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../l10n/app_localizations.dart';
import '../../categories/application/categories_controller.dart';
import '../../categories/domain/category.dart';
import '../application/rule_preview_controller.dart';
import '../application/rules_controller.dart';
import '../domain/rule.dart';
import 'rule_error_localizer.dart';
import 'rule_logo_field.dart';
import 'rule_labels.dart';
import 'rule_match_preview_banner.dart';
import 'rule_row.dart';

/// Opens the rule editor. Resolves to the saved rule, or `null` on cancel or
/// delete.
///
/// [initialCategoryId] presets a new rule's target: the category the rules
/// pane is filtered on.
Future<Rule?> showRuleEditor(
  BuildContext context, {
  Rule? initial,
  String? initialCategoryId,
}) {
  return showAppModal<Rule>(
    context: context,
    builder: (_) =>
        RuleEditorModal(initial: initial, initialCategoryId: initialCategoryId),
  );
}

/// The 520 px rule editor (`docs/design/08` §Rule editor, proposal v6
/// `m-rules`): one row of Champ · Condition · Priorité, then Motif, Catégorie
/// cible, the live match note, Logo and « Active »; « Supprimer » on the
/// footer's left when editing.
class RuleEditorModal extends ConsumerStatefulWidget {
  const RuleEditorModal({super.key, this.initial, this.initialCategoryId});

  final Rule? initial;
  final String? initialCategoryId;

  @override
  ConsumerState<RuleEditorModal> createState() => _RuleEditorModalState();
}

class _RuleEditorModalState extends ConsumerState<RuleEditorModal> {
  final _formKey = GlobalKey<FormState>();
  late final _patternController = TextEditingController(
    text: widget.initial?.pattern,
  );
  late final _priorityController = TextEditingController(
    text: '${widget.initial?.priority ?? _nextPriority}',
  );

  late RuleMatchField _matchField =
      widget.initial?.matchField ?? RuleMatchField.descriptionClean;
  late RuleMatchType _matchType =
      widget.initial?.matchType ?? RuleMatchType.contains;
  late String? _categoryId =
      widget.initial?.categoryId ?? widget.initialCategoryId;
  late bool _enabled = widget.initial?.enabled ?? true;

  bool _dirty = false;
  bool _categoryMissing = false;
  bool _isSubmitting = false;
  String? _saveError;

  bool get _isEditing => widget.initial != null;

  int get _nextPriority =>
      (ref.read(rulesControllerProvider).value?.length ?? 0) + 1;

  @override
  void initState() {
    super.initState();
    // An existing rule shows its count on open: the user came here to change a
    // rule that is already matching something, and starting from a blank note
    // would make them retype the pattern to learn what it does today.
    if (_isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _requestPreview());
    }
  }

  @override
  void dispose() {
    _patternController.dispose();
    _priorityController.dispose();
    super.dispose();
  }

  /// A choice made outside a text field: it marks the form dirty too, so the
  /// scrim no longer closes it.
  void _edit(VoidCallback change) => setState(() {
    change();
    _dirty = true;
  });

  void _requestPreview() {
    if (!mounted) return;
    ref
        .read(rulePreviewControllerProvider.notifier)
        .request(
          matchField: _matchField,
          matchType: _matchType,
          pattern: _patternController.text,
        );
  }

  Future<void> _submit() async {
    final valid = _formKey.currentState?.validate() ?? false;
    final categoryId = _categoryId;
    setState(() => _categoryMissing = categoryId == null);
    if (!valid || categoryId == null) return;

    setState(() {
      _isSubmitting = true;
      _saveError = null;
    });

    final controller = ref.read(rulesControllerProvider.notifier);
    final priority = int.tryParse(_priorityController.text.trim());
    try {
      final saved = _isEditing
          ? await controller.updateRule(
              widget.initial!.id,
              matchField: _matchField,
              matchType: _matchType,
              pattern: _patternController.text.trim(),
              categoryId: categoryId,
              enabled: _enabled,
              priority: priority,
            )
          : await controller.create(
              matchField: _matchField,
              matchType: _matchType,
              pattern: _patternController.text.trim(),
              categoryId: categoryId,
              enabled: _enabled,
              priority: priority,
            );
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _saveError = localizeRuleError(AppLocalizations.of(context)!, error);
      });
    }
  }

  Future<void> _delete() async {
    final rule = widget.initial!;
    final confirmed = await showAppModal<bool>(
      context: context,
      builder: (_) => RuleDeleteModal(pattern: rule.pattern),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _isSubmitting = true;
      _saveError = null;
    });
    try {
      await ref.read(rulesControllerProvider.notifier).delete(rule.id);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _saveError = localizeRuleError(AppLocalizations.of(context)!, error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final categories =
        ref.watch(categoriesControllerProvider).value ?? const <AppCategory>[];
    final previewState = ref.watch(rulePreviewControllerProvider);
    final patternRejected = isRulePatternInvalid(previewState.error);
    const gap = SizedBox(height: AppSpacing.fieldGap);

    return AppModal(
      key: const Key('ruleEditorModal'),
      title: _isEditing ? l10n.ruleFormEditTitle : l10n.ruleFormCreateTitle,
      width: AppCategoriesPanel.ruleEditorWidth,
      dirty: _dirty,
      busy: _isSubmitting,
      saveError: _saveError,
      onSubmit: _submit,
      leadingAction: _isEditing
          ? AppButton(
              key: const Key('ruleFormDelete'),
              label: l10n.ruleFormDelete,
              variant: AppButtonVariant.ghost,
              onPressed: _isSubmitting ? null : _delete,
            )
          : null,
      actions: [
        const AppModalCancel(key: Key('ruleFormCancel')),
        PrimaryButton(
          key: const Key('ruleFormSubmit'),
          label: l10n.ruleFormSave,
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
            ModalFieldRow(
              endWidth: AppCategoriesPanel.priorityColumn,
              start: ModalFieldCell(
                label: l10n.ruleFormFieldLabel,
                input: AppSelect<RuleMatchField>(
                  key: const Key('ruleFormField'),
                  value: _matchField,
                  onChanged: (value) {
                    _edit(() => _matchField = value);
                    _requestPreview();
                  },
                  items: [
                    for (final field in RuleMatchField.values)
                      AppSelectItem(
                        value: field,
                        label: ruleFieldLabel(l10n, field),
                      ),
                  ],
                ),
              ),
              middle: ModalFieldCell(
                label: l10n.ruleFormConditionLabel,
                input: AppSelect<RuleMatchType>(
                  key: const Key('ruleFormCondition'),
                  value: _matchType,
                  onChanged: (value) {
                    _edit(() => _matchType = value);
                    _requestPreview();
                  },
                  items: [
                    for (final type in RuleMatchType.values)
                      AppSelectItem(
                        value: type,
                        label: ruleConditionLabel(l10n, type),
                      ),
                  ],
                ),
              ),
              end: ModalFieldCell(
                label: l10n.ruleFormPriorityLabel,
                input: TextFormField(
                  key: const Key('ruleFormPriority'),
                  controller: _priorityController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.end,
                  validator: (value) {
                    final parsed = int.tryParse((value ?? '').trim());
                    return (parsed == null || parsed < 1)
                        ? l10n.ruleFormPriorityInvalid
                        : null;
                  },
                ),
              ),
            ),
            gap,
            LabeledField(
              label: l10n.ruleFormPatternLabel,
              helper: rulePatternHelper(l10n, _matchType),
              // A rejected pattern is a property of *this field*, not a count
              // of zero: see `isRulePatternInvalid`.
              errorText: patternRejected ? l10n.ruleErrorPatternInvalid : null,
              child: TextFormField(
                key: const Key('ruleFormPattern'),
                controller: _patternController,
                autofocus: true,
                style: context.textStyles.mono.copyWith(
                  color: context.colors.text,
                ),
                decoration: InputDecoration(
                  hintText: rulePatternHint(l10n, _matchType),
                ),
                onChanged: (_) => _requestPreview(),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? l10n.ruleFormPatternRequired
                    : null,
              ),
            ),
            gap,
            LabeledField(
              label: l10n.ruleFormCategoryLabel,
              errorText: _categoryMissing
                  ? l10n.ruleFormCategoryRequired
                  : null,
              child: AppSelect<String?>(
                key: const Key('ruleFormCategory'),
                value: _categoryId,
                onChanged: (value) => _edit(() {
                  _categoryId = value;
                  if (value != null) _categoryMissing = false;
                }),
                items: [
                  AppSelectItem(value: null, label: l10n.ruleFormCategoryNone),
                  for (final category in categories)
                    AppSelectItem(
                      value: category.id,
                      label: categoryPath(l10n, category, categories),
                      leading: RuleCategoryDot(category: category),
                    ),
                ],
              ),
            ),
            gap,
            RuleMatchPreviewBanner(state: previewState),
            gap,
            RuleLogoField(
              ruleId: widget.initial?.id,
              name: widget.initial?.pattern ?? '',
            ),
            gap,
            _EnabledToggle(
              value: _enabled,
              onChanged: (value) => _edit(() => _enabled = value),
            ),
          ],
        ),
      ),
    );
  }
}

/// « Active »: the toggle and its label, 8 px apart.
class _EnabledToggle extends StatelessWidget {
  const _EnabledToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final label = AppLocalizations.of(context)!.ruleFormEnabledLabel;
    return Row(
      children: [
        AppToggle(
          key: const Key('ruleFormEnabled'),
          value: value,
          semanticLabel: label,
          onChanged: onChanged,
        ),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    );
  }
}

/// « Supprimer la règle « … » ? » (`08-categories-rules.md` §Other modals,
/// proposal v6 `m-rules`), 480 px: a destructive confirmation without a body
/// whose lead says the operations it classed keep their category. Focus
/// lands on « Annuler ». Resolves to `true` on « Supprimer ».
class RuleDeleteModal extends StatelessWidget {
  const RuleDeleteModal({super.key, required this.pattern});

  /// The saved rule's pattern, which names it in the title.
  final String pattern;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AppModal(
      key: const Key('ruleDeleteModal'),
      title: l10n.ruleDeleteConfirmTitle(pattern),
      subtitle: Text(l10n.ruleDeleteConfirmLead),
      width: AppModalSizes.w480,
      kind: AppModalKind.destructive,
      actions: [
        const AppModalCancel(key: Key('ruleDeleteCancel')),
        AppButton(
          key: const Key('ruleDeleteConfirmButton'),
          label: l10n.ruleFormDelete,
          variant: AppButtonVariant.destructive,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}
