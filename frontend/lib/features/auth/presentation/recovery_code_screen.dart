import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../l10n/app_localizations.dart';
import '../application/auth_controller.dart';
import 'auth_scaffold.dart';
import 'recovery_code_plate.dart';

/// Shows a newly issued recovery code — after registration or a password
/// reset — before the user reaches the app.
///
/// The router holds a signed-in user here while a code is pending, and only
/// the acknowledged « Continuer » releases them: the backend keeps just a hash,
/// so a code scrolled past is a code lost.
class RecoveryCodeScreen extends ConsumerStatefulWidget {
  const RecoveryCodeScreen({super.key});

  static const path = '/recovery-code';

  @override
  ConsumerState<RecoveryCodeScreen> createState() => _RecoveryCodeScreenState();
}

class _RecoveryCodeScreenState extends ConsumerState<RecoveryCodeScreen> {
  bool _acknowledged = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final code = ref.watch(pendingRecoveryCodeProvider);

    return AuthScaffold(
      lockup: const BrandLockup.register(),
      tagline: l10n.authRecoveryCodeTagline,
      cardWidth: 470,
      form: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.authRecoveryCodeIntro,
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // Null only for the frame in which the router is already leaving.
          if (code != null) RecoveryCodePlate(code: code),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.authRecoveryCodeShownOnce,
            style: AppTextStyles.helper.copyWith(color: AppColors.textDisabled),
          ),
          const SizedBox(height: AppSpacing.md + AppSpacing.xs),
          _AcknowledgeCheckbox(
            value: _acknowledged,
            label: l10n.authRecoveryCodeConfirm,
            onChanged: (value) => setState(() => _acknowledged = value),
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton.submit(
            key: const Key('recoveryCodeContinueButton'),
            label: l10n.authRecoveryCodeContinue,
            onPressed: _acknowledged
                ? () => ref
                      .read(pendingRecoveryCodeProvider.notifier)
                      .acknowledge()
                : null,
          ),
        ],
      ),
    );
  }
}

/// The spec's 18px iris checkbox; Material's [Checkbox] carries touch-sized
/// padding and a light-mode look.
class _AcknowledgeCheckbox extends StatelessWidget {
  const _AcknowledgeCheckbox({
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
        key: const Key('recoveryCodeAcknowledge'),
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
