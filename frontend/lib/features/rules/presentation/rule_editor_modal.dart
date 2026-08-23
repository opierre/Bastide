import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_modal.dart';
import '../../../core/widgets/app_select.dart';
import '../../../core/widgets/app_toggle.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../l10n/app_localizations.dart';
import '../../categories/application/categories_controller.dart';
import '../../categories/domain/category.dart';
import '../application/rule_preview_controller.dart';
import '../application/rules_controller.dart';
import '../domain/rule.dart';
import 'rule_error_localizer.dart';
import 'rule_labels.dart';
import 'rule_match_preview_banner.dart';

/// Opens the rule editor. Resolves to the saved rule, or `null` on cancel or
/// delete.
Future<Rule?> showRuleEditor(BuildContext context, {Rule? initial}) {
  return showDialog<Rule>(
    context: context,
    builder: (_) => RuleEditorModal(initial: initial),
  );
}

/// The 520 px rule editor: Champ/Condition/Priorité row, pattern, target
/// category, active toggle, and the live match preview (`docs/design/08` ③).
class RuleEditorModal extends ConsumerStatefulWidget {
  const RuleEditorModal({super.key, this.initial});

  final Rule? initial;

  @override
  ConsumerState<RuleEditorModal> createState() => _RuleEditorModalState();
}

class _RuleEditorModalState extends ConsumerState<RuleEditorModal> {
  final _formKey = GlobalKey<FormState>();
  late final _patternController = TextEditingController(text: widget.initial?.pattern);
  late final _priorityController = TextEditingController(
    text: '${widget.initial?.priority ?? _nextPriority}',
  );

  late RuleMatchField _matchField =
      widget.initial?.matchField ?? RuleMatchField.descriptionClean;
  late RuleMatchType _matchType = widget.initial?.matchType ?? RuleMatchType.contains;
  late String? _categoryId = widget.initial?.categoryId;
  late bool _enabled = widget.initial?.enabled ?? true;

  bool _isSubmitting = false;
  String? _errorText;

  bool get _isEditing => widget.initial != null;

  int get _nextPriority => (ref.read(rulesControllerProvider).value?.length ?? 0) + 1;

  @override
  void initState() {
    super.initState();
    // An existing rule shows its count on open: the user came here to change a
    // rule that is already matching something, and starting from a blank banner
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
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final categoryId = _categoryId;
    if (categoryId == null) {
      setState(() => _errorText = AppLocalizations.of(context)!.ruleFormCategoryRequired);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
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
        _errorText = localizeRuleError(AppLocalizations.of(context)!, error);
      });
    }
  }

  Future<void> _delete() async {
    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });
    try {
      await ref.read(rulesControllerProvider.notifier).delete(widget.initial!.id);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorText = localizeRuleError(AppLocalizations.of(context)!, error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final categories = ref.watch(categoriesControllerProvider).value ?? const <AppCategory>[];
    final previewState = ref.watch(rulePreviewControllerProvider);
    final patternRejected = isRulePatternInvalid(previewState.error);

    return AppModal(
      title: _isEditing ? l10n.ruleFormEditTitle : l10n.ruleFormCreateTitle,
      width: 520,
      actions: [
        if (_isEditing)
          TextButton(
            key: const Key('ruleFormDelete'),
            onPressed: _isSubmitting ? null : _delete,
            child: Text(l10n.ruleFormDelete),
          ),
        OutlinedButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.ruleFormCancel),
        ),
        PrimaryButton(
          key: const Key('ruleFormSubmit'),
          label: l10n.ruleFormSave,
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
              InlineBanner(key: const Key('ruleFormError'), message: _errorText!),
              const SizedBox(height: AppSpacing.md),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: LabeledField(
                    label: l10n.ruleFormFieldLabel,
                    child: AppSelect<RuleMatchField>(
                      key: const Key('ruleFormField'),
                      value: _matchField,
                      onChanged: (value) {
                        setState(() => _matchField = value);
                        _requestPreview();
                      },
                      items: [
                        for (final field in RuleMatchField.values)
                          AppSelectItem(value: field, label: ruleFieldLabel(l10n, field)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
                Expanded(
                  flex: 3,
                  child: LabeledField(
                    label: l10n.ruleFormConditionLabel,
                    child: AppSelect<RuleMatchType>(
                      key: const Key('ruleFormCondition'),
                      value: _matchType,
                      onChanged: (value) {
                        setState(() => _matchType = value);
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
                ),
                const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
                Expanded(
                  flex: 2,
                  child: LabeledField(
                    label: l10n.ruleFormPriorityLabel,
                    child: TextFormField(
                      key: const Key('ruleFormPriority'),
                      controller: _priorityController,
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        final parsed = int.tryParse((value ?? '').trim());
                        return (parsed == null || parsed < 1)
                            ? l10n.ruleFormPriorityInvalid
                            : null;
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            LabeledField(
              label: l10n.ruleFormPatternLabel,
              helper: rulePatternHelper(l10n, _matchType),
              // A rejected pattern is a property of *this field*, not a count
              // of zero — see `isRulePatternInvalid`.
              errorText: patternRejected ? l10n.ruleErrorPatternInvalid : null,
              child: TextFormField(
                key: const Key('ruleFormPattern'),
                controller: _patternController,
                autofocus: true,
                style: AppTextStyles.mono.copyWith(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: rulePatternHint(l10n, _matchType),
                ),
                onChanged: (_) => _requestPreview(),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? l10n.ruleFormPatternRequired
                    : null,
              ),
            ),
            const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
            RuleMatchPreviewBanner(state: previewState),
            const SizedBox(height: AppSpacing.md),
            LabeledField(
              label: l10n.ruleFormCategoryLabel,
              child: AppSelect<String?>(
                key: const Key('ruleFormCategory'),
                value: _categoryId,
                onChanged: (value) => setState(() => _categoryId = value),
                items: [
                  AppSelectItem(value: null, label: l10n.ruleFormCategoryNone),
                  for (final category in categories)
                    AppSelectItem(
                      value: category.id,
                      label: categoryPath(l10n, category, categories),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                AppToggle(
                  key: const Key('ruleFormEnabled'),
                  value: _enabled,
                  semanticLabel: l10n.ruleFormEnabledLabel,
                  onChanged: (value) => setState(() => _enabled = value),
                ),
                const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
                Text(
                  l10n.ruleFormEnabledLabel,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}
