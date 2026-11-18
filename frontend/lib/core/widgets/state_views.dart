import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../theme/tokens.dart';

/// The empty state of a panel (`docs/design/00-design-system.md` §7, States
/// of a panel): centred in the content region, a title that states the fact
/// (16/600), one sentence (13 `textSecondary`, at most 44 characters wide)
/// and one button. No icon plate.
///
/// The spec puts the tomettes texture behind it, faded toward the edges
/// (`00` §12). [background] is that slot: it fills the state's whole area
/// behind the sentence. Nothing fills it yet; the texture lands with the
/// brand work.
class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    super.key,
    required this.title,
    required this.message,
    this.action,
    this.background,
  });

  final String title;
  final String message;

  /// The one button.
  final Widget? action;

  /// Painted behind the state, filling its area: the faded tomettes.
  final Widget? background;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final state = CenteredStatePane(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: textTheme.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            style: textTheme.bodyMedium?.copyWith(
              color: context.colors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          if (action != null) ...[
            const SizedBox(height: AppSpacing.md),
            action!,
          ],
        ],
      ),
    );

    final background = this.background;
    if (background == null) return state;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(child: ExcludeSemantics(child: background)),
        state,
      ],
    );
  }
}

/// Centres a state in whatever room it is given, and lets it scroll rather
/// than overflow when that room runs short.
///
/// These states sit in the flexible part of a panel, so their height is what
/// the sections above them leave over. Centring alone turns a short window
/// into a RenderFlex overflow; scrolling keeps the state readable.
class CenteredStatePane extends StatelessWidget {
  const CenteredStatePane({
    super.key,
    required this.child,
    this.maxWidth = maxSentenceWidth,
  });

  final Widget child;
  final double maxWidth;

  /// The sentence of an empty or error state: at most 44 characters of
  /// 13 px Geist per line (`00` §7).
  static const maxSentenceWidth = 300.0;

  @override
  Widget build(BuildContext context) {
    final content = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedHeight) return Center(child: content);
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(child: content),
          ),
        );
      },
    );
  }
}

/// The error state of a panel (`00` §7): as empty, with a 16 px `warning`
/// `triangle-alert` before the title and a secondary « Réessayer ». The
/// sentence says what failed and that nothing was modified.
///
/// Without a [title], the icon leads the sentence instead.
class ErrorStateView extends StatelessWidget {
  const ErrorStateView({
    super.key,
    required this.message,
    required this.retryLabel,
    required this.onRetry,
    this.title,
    this.messageKey,
    this.retryKey,
  });

  final String? title;
  final String message;
  final String retryLabel;
  final VoidCallback onRetry;
  final Key? messageKey;
  final Key? retryKey;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = context.colors;
    final icon = Icon(
      LucideIcons300.triangleAlert,
      key: const Key('errorStateIcon'),
      size: AppSizes.icon,
      color: colors.warning,
    );
    final sentence = Text(
      message,
      key: messageKey,
      style: textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
      textAlign: TextAlign.center,
    );
    final title = this.title;

    return CenteredStatePane(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null) ...[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                icon,
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    title,
                    style: textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            sentence,
          ] else
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                icon,
                const SizedBox(width: AppSpacing.sm),
                Flexible(child: sentence),
              ],
            ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(
            key: retryKey,
            onPressed: onRetry,
            child: Text(retryLabel),
          ),
        ],
      ),
    );
  }
}

/// Placeholder rows shown while a list loads: the layout's own silhouette in
/// `hover` blocks, pulsing together. No spinner for a whole panel (`00` §7).
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.itemCount = 4, this.itemHeight = 76});

  final int itemCount;
  final double itemHeight;

  @override
  Widget build(BuildContext context) {
    return SkeletonPulse(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (_, _) => SkeletonBlock(height: itemHeight),
      ),
    );
  }
}

/// Pulses everything beneath it as one unit, opacity 1 → .5 over 1.6 s.
///
/// A whole-silhouette pulse rather than a per-block one: blocks fading
/// independently read as several things loading at different speeds, when
/// one request is in flight. Reduced motion keeps the silhouette still.
class SkeletonPulse extends StatefulWidget {
  const SkeletonPulse({super.key, required this.child});

  final Widget child;

  /// The low point of the pulse.
  static const minOpacity = 0.5;

  @override
  State<SkeletonPulse> createState() => _SkeletonPulseState();
}

class _SkeletonPulseState extends State<SkeletonPulse>
    with SingleTickerProviderStateMixin {
  // One cycle goes 1 → .5 → 1 over the shimmer duration.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.shimmer ~/ 2,
  );

  @override
  void initState() {
    super.initState();
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;

    return FadeTransition(
      opacity: Tween<double>(
        begin: 1,
        end: SkeletonPulse.minOpacity,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: widget.child,
    );
  }
}

/// A single placeholder silhouette: a `hover` block, radius 4. Static on its
/// own; wrap a group in [SkeletonPulse] to animate them together.
class SkeletonBlock extends StatelessWidget {
  const SkeletonBlock({
    super.key,
    required this.height,
    this.width,
    this.radius = AppRadii.item,
  });

  final double height;
  final double? width;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: context.colors.hover,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
