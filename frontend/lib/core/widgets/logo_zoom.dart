import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme/tokens.dart';
import 'app_modal.dart';

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

/// Shows [bytes] enlarged; any click or Escape closes it (`00` §7
/// « Modal », Zoom).
Future<void> showLogoZoom(BuildContext context, Uint8List bytes) =>
    showAppModal<void>(
      context: context,
      builder: (_) => LogoZoomDialog(bytes: bytes),
    );

/// The enlarged logo: the picture alone, 240 × 240, radius 12, `shadow`, on
/// the `scrim`, cover-cropped like the chip it came from, with no plate
/// behind it. Any click, on the picture or beside it, closes it, as does
/// Escape.
class LogoZoomDialog extends StatelessWidget {
  const LogoZoomDialog({super.key, required this.bytes});

  static const size = AppModalSizes.zoomPicture;

  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    void close() => Navigator.of(context).pop();
    return Actions(
      actions: {
        DismissIntent: CallbackAction<DismissIntent>(
          onInvoke: (_) {
            close();
            return null;
          },
        ),
      },
      child: Focus(
        autofocus: true,
        child: GestureDetector(
          key: const Key('logoZoomScrim'),
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: close,
          child: Center(
            key: const Key('logoZoomDialog'),
            child: Semantics(
              scopesRoute: true,
              namesRoute: true,
              explicitChildNodes: true,
              label: l10n.logoZoomLabel,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadii.modal),
                  boxShadow: context.colors.shadow,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.modal),
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
          ),
        ),
      ),
    );
  }
}
