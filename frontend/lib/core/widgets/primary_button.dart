import 'package:flutter/material.dart';

import 'app_button.dart';

export 'app_button.dart';

/// The primary button: an [AppButton] in [AppButtonVariant.primary]
/// (`docs/design/00-design-system.md` §6). One per view.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.size = AppButtonSize.regular,
    this.expand = false,
    this.loadingLabel,
  });

  /// The 36 px full-width submit of the auth screens.
  const PrimaryButton.submit({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.loadingLabel,
  }) : icon = null,
       size = AppButtonSize.large,
       expand = true;

  final String label;

  /// `null` disables the button.
  final VoidCallback? onPressed;

  final IconData? icon;
  final bool isLoading;
  final AppButtonSize size;
  final bool expand;

  /// Replaces the label while loading.
  final String? loadingLabel;

  @override
  Widget build(BuildContext context) => AppButton(
    label: label,
    onPressed: onPressed,
    variant: AppButtonVariant.primary,
    size: size,
    icon: icon,
    isLoading: isLoading,
    loadingLabel: loadingLabel,
    expand: expand,
  );
}
