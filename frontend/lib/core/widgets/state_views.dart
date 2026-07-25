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
    this.accent = AppColors.brandAccent,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _GlyphPlate(icon: icon, accent: accent),
            const SizedBox(height: AppSpacing.lg),
            Text(title, style: textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: AppSpacing.xl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Failure state with a retry affordance. Same silhouette as [EmptyStateView]
/// so a load failure doesn't restructure the page.
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

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _GlyphPlate(
              icon: Icons.cloud_off_rounded,
              accent: AppColors.negative,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              message,
              key: messageKey,
              style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            OutlinedButton.icon(
              key: retryKey,
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(retryLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlyphPlate extends StatelessWidget {
  const _GlyphPlate({required this.icon, required this.accent});

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
        border: Border.all(color: accent.withValues(alpha: 0.24)),
      ),
      child: Icon(icon, size: 28, color: accent),
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
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, _) => SkeletonBlock(height: itemHeight),
    );
  }
}

/// A single pulsing placeholder block.
class SkeletonBlock extends StatefulWidget {
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
  State<SkeletonBlock> createState() => _SkeletonBlockState();
}

class _SkeletonBlockState extends State<SkeletonBlock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
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
    final plate = Container(
      height: widget.height,
      width: widget.width,
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(widget.radius),
        border: Border.all(color: AppColors.borderSubtle),
      ),
    );

    // Reduced-motion users get the plate without the pulse.
    if (MediaQuery.disableAnimationsOf(context)) return plate;

    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 0.9).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: plate,
    );
  }
}
