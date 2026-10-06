import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_modal.dart';
import '../../../core/widgets/app_select.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../l10n/app_localizations.dart';
import '../../categories/domain/category.dart';
import '../../rules/application/rule_preview_controller.dart';
import '../../rules/application/rules_controller.dart';
import '../../rules/domain/rule.dart';
import '../../rules/presentation/rule_error_localizer.dart';
import '../../rules/presentation/rule_labels.dart';
import '../../rules/presentation/rule_match_preview_banner.dart';
import '../application/transactions_controller.dart';
import '../domain/transaction.dart';

/// Opens « Toujours catégoriser ainsi » for [transaction]. Resolves to what
/// the rule changed, or `null` on cancel.
///
/// The caller reports the outcome: the toast and the list refresh belong to a
/// context that outlives this dialog, and the row the modal was opened from is
/// often the first thing the refresh removes.
Future<RuleFromTransactionResult?> showAlwaysCategorizeModal(
  BuildContext context, {
  required Transaction transaction,
}) {
  return showDialog<RuleFromTransactionResult>(
    context: context,
    builder: (_) => AlwaysCategorizeModal(transaction: transaction),
  );
}

/// The 520 px rule form the review queue's learning step opens
/// (`docs/design/07` frame ⑧): champ/condition/motif pre-filled from the
/// server's suggestion, the target category, « Appliquer aux transactions
/// existantes », and the live match count.
///
/// Deliberately the same widgets as the rules panel's editor — the selects,
/// the labels, and [RuleMatchPreviewBanner] — rather than a second form. Two
/// rule editors that drift apart is exactly the bug this shares code to avoid;
/// what differs here is only what this flow needs: no priority field (a rule
/// learned from a correction always files last), and an apply-now checkbox in
/// place of the active toggle.
class AlwaysCategorizeModal extends ConsumerStatefulWidget {
  const AlwaysCategorizeModal({super.key, required this.transaction});

  final Transaction transaction;

  @override
  ConsumerState<AlwaysCategorizeModal> createState() =>
      _AlwaysCategorizeModalState();
}

class _AlwaysCategorizeModalState extends ConsumerState<AlwaysCategorizeModal> {
  final _formKey = GlobalKey<FormState>();
  final _patternController = TextEditingController();

  RuleMatchField _matchField = RuleMatchField.descriptionClean;
  RuleMatchType _matchType = RuleMatchType.contains;
  late String? _categoryId = widget.transaction.category?.id;

  /// Checked by default (frame ⑧): the user is correcting a row *because* the
  /// pattern is already in their history, so leaving the rest of it uncorrected
  /// would be a surprising default.
  bool _applyNow = true;

  bool _isSubmitting = false;
  bool _prefilled = false;
  String? _errorText;

  @override
  void dispose() {
    _patternController.dispose();
    super.dispose();
  }

  /// Copies the server's suggestion into the form exactly once, so a rebuild
  /// never overwrites what the user has since typed.
  void _prefill(RuleSuggestion suggestion) {
    if (_prefilled) return;
    _prefilled = true;
    _matchField = suggestion.matchField;
    _matchType = suggestion.matchType;
    _patternController.text = suggestion.pattern;
    WidgetsBinding.instance.addPostFrameCallback((_) => _requestPreview());
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
    final l10n = AppLocalizations.of(context)!;
    final categoryId = _categoryId;
    if (categoryId == null) {
      setState(() => _errorText = l10n.ruleFormCategoryRequired);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      final result = await ref
          .read(rulesControllerProvider.notifier)
          .createFromTransaction(
            transactionId: widget.transaction.id,
            matchField: _matchField,
            matchType: _matchType,
            pattern: _patternController.text.trim(),
            categoryId: categoryId,
            applyNow: _applyNow,
          );
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorText = localizeRuleError(l10n, error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final categories =
        ref.watch(transactionCategoriesProvider).value ?? const <AppCategory>[];
    final suggestion = ref.watch(ruleSuggestionProvider(widget.transaction.id));
    final previewState = ref.watch(rulePreviewControllerProvider);
    final patternRejected = isRulePatternInvalid(previewState.error);

    suggestion.whenData(_prefill);

    return AppModal(
      title: l10n.reviewAlwaysCategorize,
      width: 520,
      actions: [
        OutlinedButton(
          key: const Key('alwaysRuleCancel'),
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.ruleFormCancel),
        ),
        PrimaryButton(
          key: const Key('alwaysRuleSubmit'),
          label: l10n.alwaysRuleSubmit,
          isLoading: _isSubmitting,
          onPressed: _isSubmitting ? null : _submit,
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.alwaysRuleSubtitle(widget.transaction.descriptionRaw),
              key: const Key('alwaysRuleSubtitle'),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            if (_errorText != null) ...[
              InlineBanner(
                key: const Key('alwaysRuleError'),
                message: _errorText!,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            // A pre-fill that didn't arrive is not a broken form: every field
            // it would have filled is editable, so the modal says so and stays
            // open.
            if (suggestion.hasError) ...[
              InlineBanner(
                key: const Key('alwaysRuleSuggestionFailed'),
                tone: BannerTone.warning,
                message: l10n.alwaysRuleSuggestionFailed,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: LabeledField(
                    label: l10n.ruleFormFieldLabel,
                    child: AppSelect<RuleMatchField>(
                      key: const Key('alwaysRuleField'),
                      value: _matchField,
                      onChanged: (value) {
                        setState(() => _matchField = value);
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
                ),
                const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
                Expanded(
                  child: LabeledField(
                    label: l10n.ruleFormConditionLabel,
                    child: AppSelect<RuleMatchType>(
                      key: const Key('alwaysRuleCondition'),
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
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            LabeledField(
              label: l10n.ruleFormPatternLabel,
              helper: rulePatternHelper(l10n, _matchType),
              errorText: patternRejected ? l10n.ruleErrorPatternInvalid : null,
              child: TextFormField(
                key: const Key('alwaysRulePattern'),
                controller: _patternController,
                autofocus: true,
                style: AppTextStyles.mono.copyWith(
                  color: AppColors.textPrimary,
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
            const SizedBox(height: AppSpacing.md),
            LabeledField(
              label: l10n.alwaysRuleCategoryLabel,
              child: AppSelect<String?>(
                key: const Key('alwaysRuleCategory'),
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
            _ApplyNowCheckbox(
              value: _applyNow,
              label: l10n.alwaysRuleApplyExisting,
              onChanged: (value) => setState(() => _applyNow = value),
            ),
            const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
            RuleMatchPreviewBanner(state: previewState),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}

/// The gradient checkbox frame ⑧ draws. Material's [Checkbox] paints a flat
/// fill and carries touch-sized padding, neither of which matches the spec.
class _ApplyNowCheckbox extends StatelessWidget {
  const _ApplyNowCheckbox({
    required this.value,
    required this.label,
    required this.onChanged,
  });

  final bool value;
  final String label;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        key: const Key('alwaysRuleApplyExisting'),
        onTap: () => onChanged(!value),
        behavior: HitTestBehavior.opaque,
        child: Row(
          children: [
            Semantics(
              checked: value,
              label: label,
              child: Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: value ? AppColors.irisGradient : null,
                  color: value ? null : AppColors.surfaceField,
                  borderRadius: BorderRadius.circular(AppRadii.xs + 1),
                  border: Border.all(
                    color: value ? Colors.transparent : AppColors.border,
                  ),
                ),
                child: value
                    ? const Icon(
                        Icons.check_rounded,
                        size: 13,
                        color: AppColors.irisInk,
                      )
                    : null,
              ),
            ),
            const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
            Flexible(
              child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
            ),
          ],
        ),
      ),
    );
  }
}
