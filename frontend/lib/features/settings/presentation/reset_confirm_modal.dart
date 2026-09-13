import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/session/current_user_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_modal.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../l10n/app_localizations.dart';
import '../application/reset_controller.dart';
import '../domain/database_reset.dart';

/// State ⑩: what the reset would delete, and the one place its solid red
/// appears. Nothing is deleted until the confirmation word has been typed
/// exactly — a click alone cannot reach the delete.
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
    final textTheme = Theme.of(context).textTheme;
    final counts = ref.watch(databaseSummaryProvider);
    final isResetting = ref.watch(resetControllerProvider).isResetting;
    final word = l10n.settingsResetConfirmWord;
    final confirmed = _typed.text == word;

    return AppModal(
      title: l10n.settingsResetConfirmTitle,
      width: 500,
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.negative.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          size: 19,
          color: AppColors.negative,
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: isResetting ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.settingsBackupCancel),
        ),
        FilledButton(
          key: const Key('resetConfirmSubmit'),
          // Disabled until the word matches exactly, and while the delete runs.
          onPressed: confirmed && !isResetting ? _confirm : null,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.negative,
            foregroundColor: AppColors.negativeInk,
            disabledBackgroundColor: AppColors.negative.withValues(alpha: 0.45),
            disabledForegroundColor: AppColors.negativeInk.withValues(
              alpha: 0.45,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isResetting) ...[
                const SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.negativeInk,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              Text(l10n.settingsResetConfirmSubmit),
            ],
          ),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text.rich(
            TextSpan(
              children: _leadSpans(
                l10n.settingsResetConfirmLead,
                ref.watch(currentUserProvider)?.displayName ?? '',
              ),
            ),
            key: const Key('resetConfirmLead'),
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _CountsPlate(counts: counts.value),
          const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
          Text(
            l10n.settingsResetConfirmNote,
            style: AppTextStyles.helper.copyWith(
              fontSize: 11.5,
              color: AppColors.textDisabled,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          InlineBanner(
            key: const Key('resetConfirmWarning'),
            icon: Icons.warning_amber_rounded,
            message: l10n.settingsResetConfirmWarning,
          ),
          const SizedBox(height: AppSpacing.md),
          LabeledField(
            label: l10n.settingsResetConfirmLabel(word),
            child: SizedBox(
              height: 38,
              child: TextField(
                key: const Key('resetConfirmInput'),
                controller: _typed,
                enabled: !isResetting,
                autofocus: true,
                style: AppTextStyles.mono.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
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
List<TextSpan> _leadSpans(String Function(String) lead, String name) {
  final sentence = lead(name);
  final at = name.isEmpty ? -1 : sentence.indexOf(name);
  if (at < 0) return [TextSpan(text: sentence)];
  return [
    TextSpan(text: sentence.substring(0, at)),
    TextSpan(
      text: name,
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    ),
    TextSpan(text: sentence.substring(at + name.length)),
  ];
}

/// The inset plate listing what goes. Rows keep their labels while the counts
/// load, so the modal never reflows under the pointer as the figures arrive.
class _CountsPlate extends StatelessWidget {
  const _CountsPlate({required this.counts});

  final DatabaseCounts? counts;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final number = NumberFormat.decimalPattern(
      Localizations.localeOf(context).toString(),
    );
    final textTheme = Theme.of(context).textTheme;
    final valueStyle = tabularNumberStyle(
      textTheme.bodyMedium!.copyWith(color: AppColors.textPrimary),
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

    return Container(
      key: const Key('resetConfirmCounts'),
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceField,
        borderRadius: BorderRadius.circular(AppRadii.inset),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        children: [
          for (final (label, count) in rows)
            SizedBox(
              height: 34,
              child: Row(
                children: [
                  // Expanded, not a Spacer: the longest label (« Paramètres fiscaux
                  // personnalisés ») must shrink on a narrow modal, never overflow.
                  Expanded(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    count == null ? '—' : number.format(count),
                    style: valueStyle,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
