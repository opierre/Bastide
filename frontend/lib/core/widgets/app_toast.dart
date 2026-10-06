import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'inline_banner.dart';

/// How long a toast stays before it withdraws. Long enough to read two lines
/// in French, which run some 15–20 % past their English counterparts.
const _toastDuration = Duration(seconds: 6);

/// Shows a bottom-right toast: an overlay-surface card, radius 14, with a
/// semantic leading disc (`docs/design/00` §Components).
///
/// An [OverlayEntry] rather than a [SnackBar], for the position: Material pins
/// a snack bar to the bottom centre and gives no honest way to park a
/// fixed-width card in the corner the design draws it in.
///
/// [message] is the second line — the reassurance beneath the headline. The
/// « Exécuter les règles » toast needs both: the count alone leaves the user
/// wondering whether the run also overwrote the categories they chose by hand.
void showAppToast(
  BuildContext context, {
  required String title,
  String? message,
  BannerTone tone = BannerTone.success,
}) {
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _Toast(
      title: title,
      message: message,
      tone: tone,
      onDismiss: () {
        if (entry.mounted) entry.remove();
      },
    ),
  );
  overlay.insert(entry);
}

/// The card itself. Stateful so it owns its withdrawal timer and cancels it on
/// dispose: a toast whose timer outlived the overlay would fire into a torn-down
/// tree — harmless in the app, but it is exactly the leak a widget test catches
/// and the reason to hold the timer here rather than beside the insert.
class _Toast extends StatefulWidget {
  const _Toast({
    required this.title,
    required this.message,
    required this.tone,
    required this.onDismiss,
  });

  final String title;
  final String? message;
  final BannerTone tone;
  final VoidCallback onDismiss;

  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(_toastDuration, widget.onDismiss);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Positioned(
      right: AppSpacing.lg,
      bottom: AppSpacing.lg,
      child: Material(
        color: Colors.transparent,
        child: Container(
          key: const Key('appToast'),
          constraints: const BoxConstraints(maxWidth: 360),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceOverlay,
            borderRadius: BorderRadius.circular(AppRadii.inset),
            border: Border.all(color: AppColors.border),
            boxShadow: AppShadows.card,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 5),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: widget.tone.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title, style: textTheme.titleSmall),
                    if (widget.message != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.message!,
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
