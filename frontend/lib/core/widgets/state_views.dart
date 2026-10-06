import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Encouraging empty state: a tinted glyph, a title that names the next step,
/// a short reassurance, and a single clear action. Shared so "nothing here yet"
/// looks the same on every panel (see the design-system skill).
class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.accent = AppColors.iris,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return CenteredStatePane(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GlyphPlate(icon: icon, accent: accent),
          const SizedBox(height: AppSpacing.lg),
          Text(
            title,
            style: textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          Text(
            message,
            style: textTheme.bodyLarge?.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          if (action != null) ...[
            const SizedBox(height: AppSpacing.lg + AppSpacing.xs),
            action!,
          ],
        ],
      ),
    );
  }
}

/// Centres an empty/error state in whatever room it is given, and lets it
/// scroll rather than overflow when that room runs short.
///
/// These states sit in the flexible half of a panel, so their height is
/// whatever the cards above them leave over — and a card grows (the imports
/// panel gains a detected-account notice, say) without asking. Centring alone
/// turns that into a RenderFlex overflow; scrolling keeps the state readable
/// and the layout quiet.
class CenteredStatePane extends StatelessWidget {
  const CenteredStatePane({
    super.key,
    required this.child,
    this.maxWidth = 420,
  });

  final Widget child;
  final double maxWidth;

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

/// Failure state with a retry affordance. Same silhouette as [EmptyStateView]
/// so a load failure doesn't restructure the page — only the plate's hue and
/// glyph change, which is what tells the two apart.
class ErrorStateView extends StatelessWidget {
  const ErrorStateView({
    super.key,
    required this.message,
    required this.retryLabel,
    required this.onRetry,
    this.messageKey,
    this.retryKey,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;
  final Key? messageKey;
  final Key? retryKey;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return CenteredStatePane(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const GlyphPlate(
            icon: Icons.warning_amber_rounded,
            accent: AppColors.warning,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            message,
            key: messageKey,
            style: textTheme.bodyLarge?.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg + AppSpacing.xs),
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

/// The 64px tinted plate that heads an empty or error state.
class GlyphPlate extends StatelessWidget {
  const GlyphPlate({
    super.key,
    required this.icon,
    this.accent = AppColors.iris,
  });

  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.xl),
      ),
      child: Icon(icon, size: 27, color: accent),
    );
  }
}

/// Placeholder rows shown while a list loads. A skeleton that matches the shape
/// of the incoming content avoids the layout jump a centered spinner causes.
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
        separatorBuilder: (_, _) =>
            const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
        itemBuilder: (_, _) => SkeletonBlock(height: itemHeight),
      ),
    );
  }
}

/// Pulses everything beneath it as one unit.
///
/// The spec asks for a whole-card opacity pulse rather than a per-block one:
/// blocks fading independently reads as several things loading at different
/// speeds, when in fact one request is in flight.
class SkeletonPulse extends StatefulWidget {
  const SkeletonPulse({super.key, required this.child});

  final Widget child;

  @override
  State<SkeletonPulse> createState() => _SkeletonPulseState();
}

class _SkeletonPulseState extends State<SkeletonPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.shimmer,
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
    // Reduced-motion users get the silhouettes without the pulse.
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;

    return FadeTransition(
      opacity: Tween<double>(
        begin: 0.45,
        end: 0.9,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: widget.child,
    );
  }
}

/// A single placeholder silhouette. Static on its own — wrap a group in
/// [SkeletonPulse] to animate them together.
class SkeletonBlock extends StatelessWidget {
  const SkeletonBlock({
    super.key,
    required this.height,
    this.width,
    this.radius = AppRadii.lg,
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
        color: AppColors.surfaceHover,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.borderSubtle),
      ),
    );
  }
}
