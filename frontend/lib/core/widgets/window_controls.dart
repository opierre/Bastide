import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../l10n/app_localizations.dart';
import '../theme/tokens.dart';
import '../window/window_providers.dart';

/// Réduire, Agrandir / Restaurer and Fermer, drawn by the app on Windows and
/// Linux (`docs/design/00-design-system.md` §5, proposal v6 `window`).
///
/// Each is 46 × 48 with no border and no radius. While the window is
/// inactive the icons take `textTertiary`; hover and pressed keep their
/// colours. Like the OS's own caption buttons, they stay out of the keyboard
/// focus order; screen readers reach them by their labels.
class WindowControls extends ConsumerWidget {
  const WindowControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final status = ref.watch(windowStatusProvider);
    final chrome = ref.watch(windowChromeProvider);

    return Semantics(
      container: true,
      label: l10n.windowControls,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _WindowButton(
            key: const Key('windowMinimize'),
            icon: LucideIcons300.minus,
            label: l10n.windowMinimize,
            inactive: !status.focused,
            onPressed: chrome.minimize,
          ),
          _WindowButton(
            key: const Key('windowMaximize'),
            icon: status.maximized
                ? LucideIcons300.copy
                : LucideIcons300.square,
            label: status.maximized ? l10n.windowRestore : l10n.windowMaximize,
            inactive: !status.focused,
            onPressed: chrome.toggleMaximize,
          ),
          _WindowButton(
            key: const Key('windowClose'),
            icon: LucideIcons300.x,
            label: l10n.windowClose,
            inactive: !status.focused,
            destructive: true,
            onPressed: chrome.close,
          ),
        ],
      ),
    );
  }
}

class _WindowButton extends StatefulWidget {
  const _WindowButton({
    super.key,
    required this.icon,
    required this.label,
    required this.inactive,
    required this.onPressed,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final bool inactive;
  final VoidCallback onPressed;

  /// Fermer: `negative` ground on hover and press.
  final bool destructive;

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    // Hover and pressed change at once (`00` §13) and keep their colours
    // on an inactive window.
    final (Color ground, Color icon) = switch ((
      widget.destructive,
      _pressed,
      _hovered,
    )) {
      (true, true, _) => (
        Color.alphaBlend(c.negative.withValues(alpha: 0.85), c.text),
        c.bg,
      ),
      (true, false, true) => (c.negative, c.bg),
      (false, true, _) => (c.lineStrong, c.text),
      (false, false, true) => (c.hover, c.text),
      _ => (
        Colors.transparent,
        widget.inactive ? c.textTertiary : c.textSecondary,
      ),
    };

    return Semantics(
      button: true,
      label: widget.label,
      onTap: widget.onPressed,
      excludeSemantics: true,
      child: Tooltip(
        message: widget.label,
        excludeFromSemantics: true,
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() {
            _hovered = false;
            _pressed = false;
          }),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => setState(() => _pressed = true),
            onTapCancel: () => setState(() => _pressed = false),
            onTapUp: (_) => setState(() => _pressed = false),
            onTap: widget.onPressed,
            child: Container(
              width: AppSizes.windowControl,
              height: AppSizes.titleBar,
              color: ground,
              alignment: Alignment.center,
              child: Icon(widget.icon, size: AppSizes.icon, color: icon),
            ),
          ),
        ),
      ),
    );
  }
}

/// A stretch of the window's frame that moves the window: drag to move,
/// double-click to maximize or restore (`00` §5). Anything placed over it
/// that takes the pointer (a control, the title, the crumb) does not drag.
class WindowDragArea extends ConsumerWidget {
  const WindowDragArea({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chrome = ref.watch(windowChromeProvider);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (_) => chrome.startDragging(),
      onDoubleTap: chrome.toggleMaximize,
      child: child ?? const SizedBox.expand(),
    );
  }
}

/// The window frame of a screen without a title bar (the auth screens and
/// the startup screen): the top 48 px band moves the window, and on Windows
/// and Linux the three controls float in the top-right corner (`00` §5).
/// On macOS the system's buttons sit top left, outside the band.
class ChromelessWindowFrame extends ConsumerWidget {
  const ChromelessWindowFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final systemButtons = ref.watch(systemWindowButtonsProvider);
    return Stack(
      children: [
        Positioned.fill(child: child),
        Positioned(
          key: const Key('windowDragBand'),
          top: 0,
          left: systemButtons
              ? AppSizes.macWindowButtonsInset * 2 + AppSizes.macWindowButtons
              : 0,
          right: systemButtons ? 0 : AppSizes.windowControl * 3,
          height: AppSizes.titleBar,
          child: const WindowDragArea(),
        ),
        if (!systemButtons)
          const Positioned(top: 0, right: 0, child: WindowControls()),
      ],
    );
  }
}
