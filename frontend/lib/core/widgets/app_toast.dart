import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'inline_banner.dart';

/// How long a toast stays before it leaves (`docs/design/00-design-system.md`
/// §7).
const toastDuration = Duration(seconds: 4);

/// Shows a toast in the bottom-right corner, 24 px from the edges: `surface`,
/// 1 px `lineStrong`, radius 8, `shadow`, padding 10 14; the status icon and
/// a 13 px [title], with an optional second line 12 `textSecondary`. It comes
/// in over 120 ms (opacity and 4 px of travel) and leaves after 4 s.
///
/// An [OverlayEntry] rather than a [SnackBar], for the position: Material pins
/// a snack bar to the bottom centre.
void showAppToast(
  BuildContext context, {
  required String title,
  String? message,
  BannerTone tone = BannerTone.success,
}) {
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;
  showAppToastOn(overlay, title: title, message: message, tone: tone);
}

/// [showAppToast] on an [overlay] looked up beforehand: for a caller that
/// awaits a dialog first and may no longer be mounted when the toast is due.
void showAppToastOn(
  OverlayState overlay, {
  required String title,
  String? message,
  BannerTone tone = BannerTone.success,
}) {
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

class _ToastState extends State<_Toast> with SingleTickerProviderStateMixin {
  Timer? _timer;
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: AppMotion.overlay,
  );

  /// How far the toast travels as it comes in.
  static const _travel = 4.0;

  @override
  void initState() {
    super.initState();
    _timer = Timer(toastDuration, widget.onDismiss);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_entrance.isDismissed) {
      // Reduced motion: every duration is 0 (`00` §13).
      if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
        _entrance.value = 1;
      } else {
        _entrance.forward();
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = context.colors;
    final curve = CurvedAnimation(parent: _entrance, curve: Curves.easeOut);

    return Positioned(
      right: AppSpacing.lg,
      bottom: AppSpacing.lg,
      child: AnimatedBuilder(
        animation: curve,
        builder: (context, child) => Opacity(
          opacity: curve.value,
          child: Transform.translate(
            offset: Offset(0, _travel * (1 - curve.value)),
            child: child,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: Container(
            key: const Key('appToast'),
            constraints: const BoxConstraints(maxWidth: 360),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(AppRadii.container),
              border: Border.all(color: colors.lineStrong),
              boxShadow: colors.shadow,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xxs),
                  child: Icon(
                    widget.tone.icon,
                    key: const Key('appToastIcon'),
                    size: AppSizes.iconSmall,
                    color: widget.tone.color(colors),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.title, style: textTheme.bodyMedium),
                      if (widget.message != null) ...[
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          widget.message!,
                          style: textTheme.bodySmall?.copyWith(
                            color: colors.textSecondary,
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
      ),
    );
  }
}
