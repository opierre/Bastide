import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_modal.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../l10n/app_localizations.dart';
import '../application/recovery_controllers.dart';
import 'auth_error_localizer.dart';
import 'password_field.dart';

/// « Nouveau code de récupération », the 480 px modal opened from the
/// recovery code row of Settings › Profil (`09-settings.md`, Profil). Two
/// steps in one modal:
///
/// 1. A form asking the password; a wrong one is refused under its field.
/// 2. The new code, shown once: a single way out (`00` §7) that Escape and
///    the scrim never close, focus on « Copier » so Enter cannot dismiss it,
///    a secondary « Enregistrer dans un fichier », and one primary
///    « Terminé ».
class RegenerateRecoveryCodeModal extends ConsumerStatefulWidget {
  const RegenerateRecoveryCodeModal({super.key});

  @override
  ConsumerState<RegenerateRecoveryCodeModal> createState() =>
      _RegenerateRecoveryCodeModalState();
}

class _RegenerateRecoveryCodeModalState
    extends ConsumerState<RegenerateRecoveryCodeModal> {
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // The generate button's enabled state follows the field.
    _passwordController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    if (_passwordController.text.isEmpty ||
        ref.read(recoveryCodeRegenerateControllerProvider).isLoading) {
      return;
    }
    await ref
        .read(recoveryCodeRegenerateControllerProvider.notifier)
        .regenerate(password: _passwordController.text);
  }

  static bool _isWrongPassword(Object? error) =>
      error is ApiFailure && error.code == 'INVALID_CREDENTIALS';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(recoveryCodeRegenerateControllerProvider);
    if (state.value case final code?) return _CodeShown(code: code);

    final isGenerating = state.isLoading;
    final wrongPassword = state.hasError && _isWrongPassword(state.error);

    return AppModal(
      key: const Key('recoveryModalAsk'),
      title: l10n.settingsRecoveryModalTitle,
      subtitle: Text(l10n.settingsRecoveryModalLead),
      width: AppModalSizes.w480,
      dirty: _passwordController.text.isNotEmpty,
      busy: isGenerating,
      saveError: state.hasError && !wrongPassword
          ? localizeAuthError(l10n, state.error)
          : null,
      onSubmit: _generate,
      actions: [
        const AppModalCancel(key: Key('recoveryModalCancel')),
        PrimaryButton(
          key: const Key('recoveryModalGenerate'),
          label: l10n.settingsRecoveryModalGenerate,
          isLoading: isGenerating,
          onPressed: _passwordController.text.isEmpty ? null : _generate,
        ),
      ],
      child: LabeledField(
        label: l10n.authPasswordLabel,
        errorText: wrongPassword ? l10n.settingsRecoveryWrongPassword : null,
        child: PasswordField(
          fieldKey: const Key('recoveryModalPasswordField'),
          controller: _passwordController,
          hasError: wrongPassword,
        ),
      ),
    );
  }
}

/// The second step: the code on a `field` well, « Copier » and
/// « Enregistrer dans un fichier » under it, « Terminé » in the footer.
///
/// Its own [AppModal] (a different key from the form's), so the frame starts
/// afresh as a single way out and puts focus on « Copier ».
class _CodeShown extends ConsumerStatefulWidget {
  const _CodeShown({required this.code});

  final String code;

  @override
  ConsumerState<_CodeShown> createState() => _CodeShownState();
}

class _CodeShownState extends ConsumerState<_CodeShown> {
  // Ephemeral feedback only; nothing outside this modal cares.
  bool _copied = false;
  bool _saved = false;
  bool _saveFailed = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (mounted) setState(() => _copied = true);
  }

  Future<void> _save() async {
    final name = AppLocalizations.of(context)!.settingsRecoveryFileName;
    setState(() => _saveFailed = false);
    try {
      final saved = await ref
          .read(recoveryCodeRegenerateControllerProvider.notifier)
          .saveToFile(suggestedName: name);
      if (mounted && saved) setState(() => _saved = true);
    } on Exception {
      if (mounted) setState(() => _saveFailed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;

    return AppModal(
      key: const Key('recoveryModalShown'),
      title: l10n.settingsRecoveryModalTitle,
      subtitle: Text(l10n.settingsRecoveryModalGenerated),
      width: AppModalSizes.w480,
      kind: AppModalKind.singleWayOut,
      saveError: _saveFailed ? l10n.settingsRecoveryModalSaveFailed : null,
      actions: [
        PrimaryButton(
          key: const Key('recoveryModalDone'),
          label: l10n.settingsRecoveryModalDone,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            key: const Key('recoveryModalCodeWell'),
            padding: const EdgeInsets.all(AppSpacing.smPlus),
            decoration: BoxDecoration(
              color: colors.field,
              borderRadius: BorderRadius.circular(AppRadii.container),
              border: Border.all(color: colors.lineStrong),
            ),
            // Plain text, not selectable: a selectable text would take the
            // initial focus that `00` §7 gives to « Copier ».
            child: Text(
              widget.code,
              key: const Key('recoveryCodeText'),
              style: context.textStyles.mono.copyWith(
                fontSize: Theme.of(context).textTheme.headlineSmall?.fontSize,
                fontWeight: FontWeight.w400,
                color: colors.text,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.fieldGap),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              AppButton(
                key: const Key('recoveryCodeCopyButton'),
                label: _copied
                    ? l10n.authRecoveryCodeCopied
                    : l10n.authRecoveryCodeCopy,
                icon: _copied ? LucideIcons300.check : LucideIcons300.copy,
                onPressed: _copy,
              ),
              AppButton(
                key: const Key('recoveryCodeSaveButton'),
                label: _saved
                    ? l10n.settingsRecoveryModalSaved
                    : l10n.settingsRecoveryModalSaveFile,
                icon: _saved ? LucideIcons300.check : LucideIcons300.download,
                onPressed: _save,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
