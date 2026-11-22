import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_checkbox.dart';
import '../../../core/widgets/app_modal.dart';
import '../../../core/widgets/app_select.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/modal_parts.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../categories/domain/category.dart';
import '../../rules/application/rule_preview_controller.dart';
import '../../rules/application/rules_controller.dart';
import '../../rules/domain/rule.dart';
import '../../rules/presentation/rule_error_localizer.dart';
import '../../rules/presentation/rule_labels.dart';
import '../../rules/presentation/rule_match_preview_banner.dart';
import '../../rules/presentation/rule_row.dart';
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
  return showAppModal<RuleFromTransactionResult>(
    context: context,
    builder: (_) => AlwaysCategorizeModal(transaction: transaction),
  );
}

/// The 520 px rule form the review queue's learning step opens
/// (`proposal_v6` `m-transactions`, `docs/design/07` §Rule modal): the lead,
/// Champ · Condition side by side, Motif pre-filled from the server's
/// suggestion, the target category, « Appliquer aux opérations existantes »,
/// the live match count, and « Annuler » · ink « Créer la règle ».
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

  /// Motif takes the focus (`docs/design/07` §Rule modal) once the form
  /// replaces the loading silhouette.
  final _patternFocus = FocusNode(debugLabel: 'alwaysRulePattern');
  bool _formShown = false;

  RuleMatchField _matchField = RuleMatchField.descriptionClean;
  RuleMatchType _matchType = RuleMatchType.contains;
  late String? _categoryId = widget.transaction.category?.id;

  /// Checked by default (frame ⑧): the user is correcting a row *because* the
  /// pattern is already in their history, so leaving the rest of it uncorrected
  /// would be a surprising default.
  bool _applyNow = true;

  bool _isSubmitting = false;
  bool _prefilled = false;

  /// The user has changed something since the pre-fill: Escape then asks
  /// before dropping the rule.
  bool _dirty = false;
  bool _categoryMissing = false;
  String? _saveError;

  @override
  void dispose() {
    _patternController.dispose();
    _patternFocus.dispose();
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

  void _touch() {
    if (!_dirty) setState(() => _dirty = true);
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
    if (_isSubmitting) return;
    final patternValid = _formKey.currentState?.validate() ?? false;
    final categoryId = _categoryId;
    setState(() => _categoryMissing = categoryId == null);
    if (!patternValid || categoryId == null) return;
    final l10n = AppLocalizations.of(context)!;

    setState(() {
      _isSubmitting = true;
      _saveError = null;
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
      // The input stays as it was; the frame shows the banner.
      setState(() {
        _isSubmitting = false;
        _saveError = localizeRuleError(l10n, error);
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

    suggestion.whenData(_prefill);
    if (!suggestion.isLoading && !_formShown) {
      _formShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _patternFocus.requestFocus();
      });
    }

    return AppModal(
      key: const Key('alwaysRuleModal'),
      title: l10n.reviewAlwaysCategorize,
      subtitle: Text(l10n.alwaysRuleLead, key: const Key('alwaysRuleLead')),
      width: AppModalSizes.w520,
      dirty: _dirty,
      busy: _isSubmitting,
      saveError: _saveError,
      onSubmit: _submit,
      actions: [
        const AppModalCancel(key: Key('alwaysRuleCancel')),
        PrimaryButton(
          key: const Key('alwaysRuleSubmit'),
          label: l10n.alwaysRuleSubmit,
          isLoading: _isSubmitting,
          onPressed: _isSubmitting ? null : _submit,
        ),
      ],
      // The pre-fill is the body's content: while it loads the body is its
      // silhouette (`00` §7 « Modal », States), so nothing typed is
      // overwritten when the suggestion lands.
      child: suggestion.isLoading
          ? const ModalLoadingBody(
              children: [
                Row(
                  children: [
                    Expanded(child: SkeletonBlock(height: AppSizes.formField)),
                    SizedBox(width: AppModalSizes.columnGutter),
                    Expanded(child: SkeletonBlock(height: AppSizes.formField)),
                  ],
                ),
                SkeletonBlock(height: AppSizes.formField),
                SkeletonBlock(height: AppSizes.formField),
                FractionallySizedBox(
                  alignment: AlignmentDirectional.centerStart,
                  widthFactor: 0.55,
                  child: SkeletonBlock(height: AppSpacing.smPlus),
                ),
              ],
            )
          : _form(l10n, categories, previewState, suggestion.hasError),
    );
  }

  Widget _form(
    AppLocalizations l10n,
    List<AppCategory> categories,
    RulePreviewState previewState,
    bool suggestionFailed,
  ) {
    final patternRejected = isRulePatternInvalid(previewState.error);
    const gap = SizedBox(height: AppSpacing.fieldGap);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // A pre-fill that didn't arrive is not a broken form: every field
          // it would have filled is editable, so the modal says so and stays
          // open.
          if (suggestionFailed) ...[
            InlineBanner(
              key: const Key('alwaysRuleSuggestionFailed'),
              tone: BannerTone.warning,
              message: l10n.alwaysRuleSuggestionFailed,
            ),
            gap,
          ],
          ModalFieldRow(
            start: ModalFieldCell(
              label: l10n.ruleFormFieldLabel,
              input: AppSelect<RuleMatchField>(
                key: const Key('alwaysRuleField'),
                value: _matchField,
                onChanged: (value) {
                  setState(() {
                    _matchField = value;
                    _dirty = true;
                  });
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
            end: ModalFieldCell(
              label: l10n.ruleFormConditionLabel,
              input: AppSelect<RuleMatchType>(
                key: const Key('alwaysRuleCondition'),
                value: _matchType,
                onChanged: (value) {
                  setState(() {
                    _matchType = value;
                    _dirty = true;
                  });
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
          gap,
          LabeledField(
            label: l10n.ruleFormPatternLabel,
            helper: rulePatternHelper(l10n, _matchType),
            errorText: patternRejected ? l10n.ruleErrorPatternInvalid : null,
            child: TextFormField(
              key: const Key('alwaysRulePattern'),
              controller: _patternController,
              focusNode: _patternFocus,
              style: context.textStyles.mono.copyWith(
                color: context.colors.text,
              ),
              decoration: InputDecoration(
                hintText: rulePatternHint(l10n, _matchType),
              ),
              onChanged: (_) {
                _touch();
                _requestPreview();
              },
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? l10n.ruleFormPatternRequired
                  : null,
            ),
          ),
          gap,
          LabeledField(
            label: l10n.alwaysRuleCategoryLabel,
            errorText: _categoryMissing ? l10n.ruleFormCategoryRequired : null,
            child: AppSelect<String?>(
              key: const Key('alwaysRuleCategory'),
              value: _categoryId,
              onChanged: (value) => setState(() {
                _categoryId = value;
                _dirty = true;
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
          _ApplyNowCheckbox(
            value: _applyNow,
            label: l10n.alwaysRuleApplyExisting,
            onChanged: (value) => setState(() {
              _applyNow = value;
              _dirty = true;
            }),
          ),
          gap,
          RuleMatchPreviewBanner(state: previewState),
        ],
      ),
    );
  }
}

/// « Appliquer aux opérations existantes »: the design system's checkbox
/// (`00` §6) with its label, both of which toggle it.
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
            AppCheckbox(
              value: value,
              onChanged: onChanged,
              semanticLabel: label,
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
            ),
          ],
        ),
      ),
    );
  }
}
