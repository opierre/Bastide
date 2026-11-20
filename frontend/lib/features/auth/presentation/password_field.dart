import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../l10n/app_localizations.dart';

/// A text field of the signed-out column (`00` §6, Text field): 32 px,
/// `field` well, `lineStrong` border; focus takes the `accent` border and the
/// `accentSoft` ring; [hasError] takes the `negative` border. The label and
/// the helper belong to the surrounding [LabeledField].
class AuthTextField extends StatelessWidget {
  const AuthTextField({
    super.key,
    required this.fieldKey,
    required this.controller,
    this.autofillHints = const [],
    this.keyboardType,
    this.hasError = false,
    this.enabled = true,
    this.obscureText = false,
    this.suffix,
    this.style,
    this.focusNode,
    this.textCapitalization = TextCapitalization.none,
    this.autocorrect = true,
    this.onChanged,
    this.onSubmitted,
  });

  /// Key on the input itself, so tests target the field rather than its shell.
  final Key fieldKey;
  final TextEditingController controller;
  final List<String> autofillHints;
  final TextInputType? keyboardType;
  final bool hasError;
  final bool enabled;
  final bool obscureText;
  final Widget? suffix;
  final TextStyle? style;
  final FocusNode? focusNode;
  final TextCapitalization textCapitalization;
  final bool autocorrect;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final base = hasError
        ? errorFieldDecoration(context)
        : const InputDecoration();

    return FocusGlow(
      child: TextField(
        key: fieldKey,
        controller: controller,
        focusNode: focusNode,
        enabled: enabled,
        obscureText: obscureText,
        autocorrect: autocorrect && !obscureText,
        enableSuggestions: autocorrect && !obscureText,
        textCapitalization: textCapitalization,
        keyboardType: keyboardType,
        autofillHints: enabled ? autofillHints : null,
        style: style,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        decoration: base.copyWith(
          suffixIcon: suffix,
          suffixIconConstraints: suffix == null
              ? null
              : const BoxConstraints(
                  minWidth: AppSizes.formField - AppSpacing.xs,
                  maxHeight: AppSizes.formField - AppSpacing.xxs,
                ),
        ),
      ),
    );
  }
}

/// A password input with a trailing 14 px `eye` / `eye-off` button that shows
/// or hides it (`02-login.md`). Shared by login, registration and the reset
/// so the reveal affordance and the error treatment match on all three.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.fieldKey,
    this.autofillHint = AutofillHints.password,
    this.hasError = false,
    this.enabled = true,
    this.focusNode,
    this.onSubmitted,
    this.onChanged,
  });

  final TextEditingController controller;
  final Key fieldKey;
  final String autofillHint;
  final bool hasError;
  final bool enabled;
  final FocusNode? focusNode;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AuthTextField(
      fieldKey: widget.fieldKey,
      controller: widget.controller,
      focusNode: widget.focusNode,
      obscureText: _obscured,
      autofillHints: [widget.autofillHint],
      hasError: widget.hasError,
      enabled: widget.enabled,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      suffix: IconButton(
        key: const Key('passwordVisibilityToggle'),
        onPressed: () => setState(() => _obscured = !_obscured),
        icon: Icon(_obscured ? LucideIcons300.eye : LucideIcons300.eyeOff),
        iconSize: AppSizes.iconSmall,
        padding: EdgeInsets.zero,
        color: context.colors.textTertiary,
        tooltip: _obscured ? l10n.authPasswordShow : l10n.authPasswordHide,
      ),
    );
  }
}
