import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme/tokens.dart';

/// Makes a small logo picture open larger when clicked.
///
/// Wraps only a picture that is actually shown: a monogram stays a plain,
/// inert chip, since there is nothing more to see by enlarging a letter.
class LogoZoomTarget extends StatelessWidget {
  const LogoZoomTarget({super.key, required this.bytes, required this.child});

  /// The picture the dialog shows, the same bytes the chip is drawn from.
  final Uint8List bytes;

  /// The small chip that opens the dialog.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Semantics(
      container: true,
      button: true,
      label: l10n.logoZoomOpen,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          key: const Key('logoZoomTarget'),
          behavior: HitTestBehavior.opaque,
          onTap: () => showLogoZoom(context, bytes),
          // The button's label says what it does; the chip's own monogram
          // letter, drawn while the picture decodes, would only add noise.
          child: ExcludeSemantics(child: child),
        ),
      ),
    );
  }
}

/// Shows [bytes] enlarged in a dialog; a click outside or Escape closes it.
Future<void> showLogoZoom(BuildContext context, Uint8List bytes) =>
    showDialog<void>(
      context: context,
      builder: (_) => LogoZoomDialog(bytes: bytes),
    );

/// The enlarged logo: the picture alone, cover-cropped to the modal's
/// rounded square like the chip it came from, with no plate behind it.
class LogoZoomDialog extends StatelessWidget {
  const LogoZoomDialog({super.key, required this.bytes});

  /// Large enough to read a wordmark, small enough to sit over the rule
  /// editor without hiding all of it.
  static const size = 240.0;

  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Not a [Dialog]: its 280 px minimum width would put a transparent strip
    // beside the picture that swallows the click meant to close it.
    return Center(
      key: const Key('logoZoomDialog'),
      child: Semantics(
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        label: l10n.logoZoomLabel,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.xl),
            boxShadow: AppShadows.modal,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.xl),
            child: Image.memory(
              bytes,
              width: size,
              height: size,
              fit: BoxFit.cover,
              excludeFromSemantics: true,
            ),
          ),
        ),
      ),
    );
  }
}
