import 'package:flutter/material.dart';

import '../../../core/widgets/labeled_field.dart';
import '../../../l10n/app_localizations.dart';

/// A password input with a trailing show/hide eye.
///
/// Shared by login and register so the reveal affordance, the obscured
/// letter-spacing and the error treatment stay identical on both screens.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.fieldKey,
    this.autofillHint = AutofillHints.password,
    this.hasError = false,
    this.onSubmitted,
    this.onChanged,
    this.validator,
  });

  final TextEditingController controller;

  /// Key on the input itself, so tests target the field rather than this shell.
  final Key fieldKey;

  final String autofillHint;

  /// Paints the error border without an inline message — used when the failure
  /// belongs to the form as a whole and is already stated in a banner above.
  final bool hasError;

  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final errorDecoration = errorFieldDecoration();

    return TextFormField(
      key: widget.fieldKey,
      controller: widget.controller,
      obscureText: _obscured,
      autofillHints: [widget.autofillHint],
      onFieldSubmitted: widget.onSubmitted,
      onChanged: widget.onChanged,
      validator: widget.validator,
      // Obscured text packs the dots too tightly to be countable at a glance;
      // the extra tracking only applies while they're dots.
      style: _obscured ? const TextStyle(letterSpacing: 2) : null,
      decoration: InputDecoration(
        enabledBorder: widget.hasError ? errorDecoration.enabledBorder : null,
        focusedBorder: widget.hasError ? errorDecoration.focusedBorder : null,
        suffixIcon: IconButton(
          key: const Key('passwordVisibilityToggle'),
          onPressed: () => setState(() => _obscured = !_obscured),
          icon: Icon(
            _obscured
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            size: 17,
          ),
          tooltip: _obscured ? l10n.authPasswordShow : l10n.authPasswordHide,
        ),
      ),
    );
  }
}
