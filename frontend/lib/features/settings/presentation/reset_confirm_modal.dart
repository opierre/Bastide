import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/session/current_user_provider.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_modal.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/key_value_list.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/note_line.dart';
import '../../../l10n/app_localizations.dart';
import '../application/reset_controller.dart';
import '../domain/database_reset.dart';
import 'export_first_action.dart';

/// « Réinitialiser la base de données ? »: what the reset would delete, and
/// one of the two places the solid destructive red appears. Nothing is
/// deleted until the confirmation word has been typed, in any case: a click alone
/// cannot reach the delete.
class ResetConfirmModal extends ConsumerStatefulWidget {
  const ResetConfirmModal({super.key});

  @override
  ConsumerState<ResetConfirmModal> createState() => _ResetConfirmModalState();
}

class _ResetConfirmModalState extends ConsumerState<ResetConfirmModal> {
  final _typed = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Rebuilds the footer as the word is typed: the confirm button's enabled
    // state *is* the guard, so it has to follow every keystroke.
    _typed.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await ref.read(resetControllerProvider.notifier).reset();
      if (!mounted) return;
      Navigator.of(context).pop();
      showAppToast(context, title: l10n.settingsResetDone);
    } catch (_) {
      // ⑪ rules: the refusal is reported by the card, which the controller has
      // already put into its failure state — leaving the modal open would show
      // the same reason twice and invite a retry that will be refused again.
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final counts = ref.watch(databaseSummaryProvider);
    final isResetting = ref.watch(resetControllerProvider).isResetting;
    final word = l10n.settingsResetConfirmWord;
    // Any case matches (`09-settings.md` §Données): the guard is the act of
    // typing the word, not its capitalisation.
    final confirmed = _typed.text.trim().toLowerCase() == word.toLowerCase();

    return AppModal(
      title: l10n.settingsResetConfirmTitle,
      width: AppModalSizes.w500,
      kind: AppModalKind.destructive,
      busy: isResetting,
      subtitle: Text.rich(
        TextSpan(
          children: _leadSpans(
            context,
            l10n.settingsResetConfirmLead,
            ref.watch(currentUserProvider)?.displayName ?? '',
          ),
        ),
        key: const Key('resetConfirmLead'),
      ),
      leadingAction: const ExportFirstAction(),
      actions: [
        const AppModalCancel(),
        AppButton(
          key: const Key('resetConfirmSubmit'),
          label: l10n.settingsResetConfirmSubmit,
          variant: AppButtonVariant.destructive,
          isLoading: isResetting,
          // Disabled until the word matches.
          onPressed: confirmed ? _confirm : null,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Counts(counts: counts.value),
          const SizedBox(height: AppSpacing.fieldGap),
          NoteLine(text: l10n.settingsResetConfirmNote),
          const SizedBox(height: AppSpacing.fieldGap),
          LabeledField(
            label: l10n.settingsResetConfirmLabel(word),
            helper: l10n.settingsResetConfirmHelper,
            child: FocusGlow(
              child: TextField(
                key: const Key('resetConfirmInput'),
                controller: _typed,
                enabled: !isResetting,
                autofocus: true,
                style: context.textStyles.mono.copyWith(
                  fontSize: Theme.of(context).textTheme.bodyMedium?.fontSize,
                  color: context.colors.text,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The lead sentence with the profile name in bold.
///
/// Built by locating the name inside the localized sentence rather than by
/// concatenating fragments: the placeholder sits mid-sentence in French and at
/// the head in English, and only the translation knows where.
List<TextSpan> _leadSpans(
  BuildContext context,
  String Function(String) lead,
  String name,
) {
  final sentence = lead(name);
  final at = name.isEmpty ? -1 : sentence.indexOf(name);
  if (at < 0) return [TextSpan(text: sentence)];
  return [
    TextSpan(text: sentence.substring(0, at)),
    TextSpan(
      text: name,
      style: TextStyle(fontWeight: FontWeight.w600, color: context.colors.text),
    ),
    TextSpan(text: sentence.substring(at + name.length)),
  ];
}

/// The key/value list of what goes. Rows keep their labels while the counts
/// load, so the modal never reflows under the pointer as the figures arrive.
class _Counts extends StatelessWidget {
  const _Counts({required this.counts});

  final DatabaseCounts? counts;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final number = NumberFormat.decimalPattern(
      Localizations.localeOf(context).toString(),
    );

    final rows = <(String, int?)>[
      (l10n.settingsBackupConfirmAccounts, counts?.accounts),
      (l10n.settingsBackupConfirmTransactions, counts?.transactions),
      (l10n.settingsResetConfirmCategories, counts?.categories),
      (l10n.settingsBackupConfirmRules, counts?.rules),
      (l10n.settingsBackupConfirmSubscriptions, counts?.recurring),
      (l10n.settingsBackupConfirmGoals, counts?.goals),
      (l10n.settingsBackupConfirmMortgages, counts?.mortgages),
      (l10n.settingsBackupConfirmProperties, counts?.properties),
      (l10n.settingsBackupConfirmSimulations, counts?.simulations),
    ];

    return KeyValueList(
      key: const Key('resetConfirmCounts'),
      entries: [
        for (final (label, count) in rows)
          // The dash is the empty-value placeholder (`00` §14).
          KeyValue(label, count == null ? '—' : number.format(count)),
      ],
    );
  }
}
