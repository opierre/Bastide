import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_modal.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../l10n/app_localizations.dart';
import '../application/recovery_controllers.dart';
import 'password_field.dart';
import 'recovery_code_plate.dart';

/// The « Code de récupération » card in Settings › Profil: replaces a lost
/// code, and gives users registered before codes existed their first one.
class RecoveryCodeCard extends StatelessWidget {
  const RecoveryCodeCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AppCard(
      key: const Key('settingsRecoveryCard'),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.settingsRecoveryTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.settingsRecoverySubtitle,
                  style: AppTextStyles.helper.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          OutlinedButton(
            key: const Key('settingsRecoveryButton'),
            onPressed: () => showDialog<void>(
              context: context,
              // The code is shown once; a stray click outside must not close
              // the modal before it has been noted.
              barrierDismissible: false,
              builder: (_) => const RegenerateRecoveryCodeModal(),
            ),
            child: Text(l10n.settingsRecoveryButton),
          ),
        ],
      ),
    );
  }
}

/// Two steps in one modal: confirm the password, then show the new code.
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

  Future<void> _generate() => ref
      .read(recoveryCodeRegenerateControllerProvider.notifier)
      .regenerate(password: _passwordController.text);

  String _errorMessage(AppLocalizations l10n, Object? error) =>
      error is ApiFailure && error.code == 'INVALID_CREDENTIALS'
      ? l10n.settingsRecoveryWrongPassword
      : l10n.authErrorGeneric;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final state = ref.watch(recoveryCodeRegenerateControllerProvider);
    final code = state.value;
    final isGenerating = state.isLoading;

    return AppModal(
      title: l10n.settingsRecoveryModalTitle,
      width: 480,
      actions: code != null
          ? [
              PrimaryButton(
                key: const Key('recoveryModalDone'),
                label: l10n.settingsRecoveryModalDone,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ]
          : [
              OutlinedButton(
                onPressed: isGenerating
                    ? null
                    : () => Navigator.of(context).pop(),
                child: Text(l10n.settingsRecoveryModalCancel),
              ),
              PrimaryButton(
                key: const Key('recoveryModalGenerate'),
                label: l10n.settingsRecoveryModalGenerate,
                isLoading: isGenerating,
                onPressed: _passwordController.text.isEmpty ? null : _generate,
              ),
            ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            code != null
                ? l10n.settingsRecoveryModalGenerated
                : l10n.settingsRecoveryModalLead,
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (code != null)
            RecoveryCodePlate(code: code)
          else ...[
            if (state.hasError) ...[
              InlineBanner(
                key: const Key('recoveryModalError'),
                message: _errorMessage(l10n, state.error),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            LabeledField(
              label: l10n.authPasswordLabel,
              child: PasswordField(
                fieldKey: const Key('recoveryModalPasswordField'),
                controller: _passwordController,
                hasError: state.hasError,
                onSubmitted: (_) =>
                    isGenerating || _passwordController.text.isEmpty
                    ? null
                    : _generate(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
