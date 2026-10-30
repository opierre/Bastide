import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_modal.dart';
import '../../../core/widgets/date_field.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../l10n/app_localizations.dart';
import '../../rules/application/rule_preview_controller.dart';
import '../../rules/domain/rule.dart';
import '../../rules/presentation/rule_match_preview_banner.dart';
import '../application/settlement_rule_controller.dart';
import '../domain/account.dart';

/// Opens the settlement-rule dialog for [card] and, once a rule is saved, says
/// how many imported debits it filed. Resolves to whether one was saved.
Future<bool> showSettlementRuleDialog(
  BuildContext context,
  Account card,
) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final l10n = AppLocalizations.of(context)!;
  final moved = await showDialog<int>(
    context: context,
    builder: (_) => SettlementRuleDialog(card: card),
  );
  if (moved == null) return false;
  messenger?.showSnackBar(
    SnackBar(content: Text(l10n.settlementRuleSaved(moved))),
  );
  return true;
}

/// Proposes — or edits — the one rule that files [card]'s monthly debit as a
/// transfer.
///
/// The pattern comes pre-filled with what the card's paying account shows month
/// after month (`DEPENSES CARTE X4821`), and the live preview counts what it
/// catches, so the user confirms a rule they can see working rather than
/// writing one from scratch.
class SettlementRuleDialog extends ConsumerStatefulWidget {
  const SettlementRuleDialog({super.key, required this.card});

  final Account card;

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

  Future<void> _save() async {
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

    return AppModal(
      width: 480,
      title: l10n.settlementRuleTitle,
      actions: [
        TextButton(
          key: const Key('settlementRuleLaterButton'),
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.settlementRuleLater),
        ),
        PrimaryButton(
          key: const Key('settlementRuleSaveButton'),
          label: l10n.settlementRuleSave,
          isLoading: _isSaving,
          onPressed: loaded == null ? null : _save,
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.settlementRuleBody(widget.card.name),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          if (state.hasError)
            InlineBanner(
              key: const Key('settlementRuleLoadError'),
              message: l10n.settlementRuleLoadFailed,
            )
          else if (loaded == null)
            const Center(child: CircularProgressIndicator())
          else ...[
            LabeledField(
              label: l10n.settlementRulePatternLabel,
              helper: l10n.settlementRulePatternHelper,
              errorText: _patternError,
              child: TextField(
                key: const Key('settlementRulePatternField'),
                controller: _patternController,
                onChanged: (_) => _preview(),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            LabeledField(
              label: l10n.settlementRuleFromLabel,
              helper: l10n.settlementRuleFromHelper,
              errorText: _fromError,
              child: DateField(
                key: const Key('settlementRuleFromField'),
                controller: _fromController,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
                onChanged: (_) => _preview(),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            RuleMatchPreviewBanner(
              state: ref.watch(rulePreviewControllerProvider),
            ),
          ],
          if (_errorText != null) ...[
            const SizedBox(height: AppSpacing.md),
            InlineBanner(
              key: const Key('settlementRuleErrorText'),
              message: _errorText!,
            ),
          ],
        ],
      ),
    );
  }
}
