import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_modal.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/date_field.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/modal_parts.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../rules/application/rule_preview_controller.dart';
import '../../rules/domain/rule.dart';
import '../../rules/presentation/rule_match_preview_banner.dart';
import '../application/settlement_rule_controller.dart';
import '../domain/account.dart';

/// Opens the settlement-rule dialog for [card] and, once a rule is saved, says
/// how many imported debits it filed. Resolves to whether one was saved.
///
/// [proposed] says Bastide raised the task itself (a card just created, a
/// « Règle de règlement à configurer » warning): the secondary then reads
/// « Plus tard » rather than « Annuler » (`00` §7 « Modal », Footer).
Future<bool> showSettlementRuleDialog(
  BuildContext context,
  Account card, {
  bool proposed = false,
}) async {
  // Looked up before the await: the menu or form that opened the dialog may
  // be rebuilt away by the time the rule is saved.
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  final l10n = AppLocalizations.of(context)!;
  final moved = await showAppModal<int>(
    context: context,
    builder: (_) => SettlementRuleDialog(card: card, proposed: proposed),
  );
  if (moved == null) return false;
  if (overlay != null && overlay.mounted) {
    showAppToastOn(overlay, title: l10n.settlementRuleSaved(moved));
  }
  return true;
}

/// Proposes — or edits — the one rule that files [card]'s monthly debit as a
/// transfer (`05-accounts.md`, proposal v6 `m-accounts`).
///
/// The pattern comes pre-filled with what the card's paying account shows month
/// after month (`DEPENSES CARTE X4821`), and the live preview counts what it
/// catches, so the user confirms a rule they can see working rather than
/// writing one from scratch.
class SettlementRuleDialog extends ConsumerStatefulWidget {
  const SettlementRuleDialog({
    super.key,
    required this.card,
    this.proposed = false,
  });

  final Account card;

  /// Bastide proposed the task: the secondary reads « Plus tard ».
  final bool proposed;

  @override
  ConsumerState<SettlementRuleDialog> createState() =>
      _SettlementRuleDialogState();
}

class _SettlementRuleDialogState extends ConsumerState<SettlementRuleDialog> {
  final _patternController = TextEditingController();
  final _fromController = TextEditingController();

  /// Guards the one-time fill of the field from the loaded state.
  bool _filled = false;
  bool _isSaving = false;
  bool _dirty = false;
  String? _patternError;
  String? _fromError;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    // The preview is shared with the rule editor; start from a blank banner.
    Future.microtask(
      () => ref.read(rulePreviewControllerProvider.notifier).clear(),
    );
  }

  @override
  void dispose() {
    _patternController.dispose();
    _fromController.dispose();
    super.dispose();
  }

  /// The start date as typed, or `null` when the field is empty or unreadable
  /// — an unreadable one is refused on save, never sent as "no limit".
  DateTime? _appliesFrom() => parseDateInput(
    _fromController.text,
    Localizations.localeOf(context).toString(),
  );

  void _preview() {
    ref
        .read(rulePreviewControllerProvider.notifier)
        .request(
          matchField: RuleMatchField.descriptionClean,
          matchType: RuleMatchType.contains,
          pattern: _patternController.text,
          appliesFrom: _appliesFrom(),
        );
  }

  void _edited() {
    if (!_dirty) setState(() => _dirty = true);
    _preview();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    final l10n = AppLocalizations.of(context)!;
    final pattern = _patternController.text.trim();
    final appliesFrom = _appliesFrom();
    final fromUnreadable =
        _fromController.text.trim().isNotEmpty && appliesFrom == null;
    setState(() {
      _patternError = pattern.isEmpty
          ? l10n.settlementRulePatternRequired
          : null;
      _fromError = fromUnreadable ? l10n.settlementRuleFromInvalid : null;
    });
    if (_patternError != null || _fromError != null) return;
    setState(() {
      _isSaving = true;
      _errorText = null;
    });
    try {
      final moved = await ref
          .read(settlementRuleControllerProvider)
          .save(widget.card.id, pattern, appliesFrom);
      if (mounted) Navigator.of(context).pop(moved);
    } catch (_) {
      if (mounted) setState(() => _errorText = l10n.settlementRuleSaveFailed);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(settlementRuleProvider(widget.card.id));
    final loaded = state.value;
    if (loaded != null && !_filled) {
      _filled = true;
      _patternController.text = loaded.pattern ?? loaded.suggestedPattern ?? '';
      // A saved rule keeps its date, even none: the user chose it.
      final from = loaded.hasRule
          ? loaded.appliesFrom
          : loaded.suggestedAppliesFrom;
      final locale = Localizations.localeOf(context).toString();
      _fromController.text = from == null
          ? ''
          : appDateFormat(locale).format(from);
      Future.microtask(_preview);
    }

    final Widget body;
    if (state.hasError) {
      body = ModalLoadError(
        message: l10n.settlementRuleLoadFailed,
        onRetry: () => ref.invalidate(settlementRuleProvider(widget.card.id)),
      );
    } else if (loaded == null) {
      // The proposal is the body's content: while it loads the body is its
      // silhouette (`00` §7 « Modal », States).
      body = const ModalLoadingBody(
        children: [
          SkeletonBlock(height: AppSizes.formField),
          SkeletonBlock(height: AppSizes.formField),
        ],
      );
    } else {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LabeledField(
            label: l10n.settlementRulePatternLabel,
            helper: l10n.settlementRulePatternHelper,
            errorText: _patternError,
            child: TextField(
              key: const Key('settlementRulePatternField'),
              controller: _patternController,
              autofocus: true,
              // A bank label, in Geist Mono (`05-accounts.md`).
              style: context.textStyles.mono.copyWith(
                color: context.colors.text,
              ),
              onChanged: (_) => _edited(),
            ),
          ),
          const SizedBox(height: AppSpacing.fieldGap),
          LabeledField(
            label: l10n.settlementRuleFromLabel,
            helper: l10n.settlementRuleFromHelper,
            errorText: _fromError,
            child: DateField(
              key: const Key('settlementRuleFromField'),
              controller: _fromController,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
              onChanged: (_) => _edited(),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          RuleMatchPreviewBanner(
            state: ref.watch(rulePreviewControllerProvider),
          ),
        ],
      );
    }

    return AppModal(
      key: const Key('settlementRuleModal'),
      width: AppModalSizes.w480,
      title: l10n.settlementRuleTitle,
      subtitle: Text(l10n.settlementRuleBody(widget.card.name)),
      dirty: _dirty,
      busy: _isSaving,
      saveError: _errorText,
      onSubmit: loaded == null ? null : _save,
      actions: [
        // « Annuler » by default.
        AppModalCancel(
          key: const Key('settlementRuleSecondaryButton'),
          label: widget.proposed ? l10n.settlementRuleLater : null,
        ),
        PrimaryButton(
          key: const Key('settlementRuleSaveButton'),
          label: l10n.settlementRuleSave,
          isLoading: _isSaving,
          onPressed: loaded == null || _isSaving ? null : _save,
        ),
      ],
      child: body,
    );
  }
}
