import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/password_rule.dart';

/// The 11 px line under a new password (`03-register.md`), in place of the
/// v1 strength meter:
///
/// * not yet long enough: « 12 caractères minimum. » in `textTertiary`;
/// * left too short ([flagShort]): « Encore {n} caractères. » in `negative`,
///   with the field's error border set by the caller;
/// * long enough: a 14 px `positive` check and « {n} caractères. Le minimum
///   est de 12. »
class NewPasswordHelper extends StatelessWidget {
  const NewPasswordHelper({
    super.key,
    required this.password,
    this.flagShort = false,
  });

  final String password;

  /// Whether a too-short password is reported as an error rather than as
  /// guidance: the user has moved on from the field without meeting the rule.
  final bool flagShort;

  /// Whether this helper is in its error form, for the caller's border.
  static bool isError(String password, {required bool flagShort}) =>
      flagShort && password.isNotEmpty && !isLongEnoughPassword(password);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (isLongEnoughPassword(password)) {
      final style = context.textStyles.helper.copyWith(
        color: context.colors.textTertiary,
      );
      return Padding(
        key: const Key('newPasswordHelperValid'),
        padding: const EdgeInsets.only(top: AppSpacing.xs),
        child: Row(
          children: [
            Icon(
              LucideIcons300.check,
              size: AppSizes.iconSmall,
              color: context.colors.positive,
            ),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                l10n.authPasswordLengthOk(password.length, minPasswordLength),
                style: style,
              ),
            ),
          ],
        ),
      );
    }

    if (isError(password, flagShort: flagShort)) {
      return FieldHelper(
        key: const Key('newPasswordHelperShort'),
        text: l10n.authPasswordTooShort(missingPasswordCharacters(password)),
        isError: true,
      );
    }

    return FieldHelper(
      key: const Key('newPasswordHelperMinimum'),
      text: l10n.authPasswordMinimum(minPasswordLength),
    );
  }
}
