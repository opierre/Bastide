import 'package:flutter/material.dart';

import '../theme/tokens.dart';

export 'category_icons.dart';

/// The category label of `docs/design/00-design-system.md` §7: an 8 px
/// square dot (radius 2) in the category hue, then the name in
/// `textSecondary`; a subcategory follows after « › » in `textTertiary`.
///
/// Two other states share the shape:
/// - [CategoryLabel.uncategorized]: « Non catégorisé » in `textTertiary`
///   over a 1 px dashed `lineStrong` underline, no dot, so a row missing its
///   category does not read as belonging to a grey one;
/// - [CategoryLabel.proposed]: an AI proposal, the same label followed by its
///   confidence (« confiance 78 % ») in 12 `textTertiary`. No gauge.
///
/// The hue never colours text (`00` §2.4); the name always sits beside it,
/// so the category is never told by colour alone.
class CategoryLabel extends StatelessWidget {
  const CategoryLabel({
    super.key,
    required this.label,
    required String this.slug,
    this.subcategory,
    this.onTap,
  }) : confidence = null;

  /// [label] is the localized « Non catégorisé »; this widget never invents
  /// copy.
  const CategoryLabel.uncategorized({
    super.key,
    required this.label,
    this.onTap,
  }) : slug = null,
       subcategory = null,
       confidence = null;

  /// A category the model proposed but did not assign, with its localized
  /// [confidence] caption.
  const CategoryLabel.proposed({
    super.key,
    required this.label,
    required String this.slug,
    required String this.confidence,
    this.subcategory,
    this.onTap,
  });

  final String label;

  /// Backend category slug; drives the hue. `null` is the uncategorized
  /// state.
  final String? slug;

  /// The subcategory's localized name, shown after « › ».
  final String? subcategory;

  /// The proposal's confidence caption.
  final String? confidence;

  final VoidCallback? onTap;

  static const dotSize = 8.0;

  @override
  Widget build(BuildContext context) {
    final label = slug == null
        ? _uncategorized(context)
        : _categorized(context);
    if (onTap == null) return label;

    return Semantics(
      button: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: label,
        ),
      ),
    );
  }

  Widget _categorized(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final confidence = this.confidence;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          key: const Key('categoryLabelDot'),
          width: dotSize,
          height: dotSize,
          decoration: BoxDecoration(
            color: context.categoryColors.forSlug(slug),
            borderRadius: BorderRadius.circular(AppRadii.bar),
          ),
        ),
        const SizedBox(width: AppSpacing.xsPlus),
        Flexible(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: label),
                if (subcategory case final sub?)
                  TextSpan(
                    text: ' › $sub',
                    style: TextStyle(color: colors.textTertiary),
                  ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
          ),
        ),
        if (confidence != null) ...[
          const SizedBox(width: AppSpacing.xsPlus),
          Text(
            confidence,
            key: const Key('categoryLabelConfidence'),
            maxLines: 1,
            style: textTheme.bodySmall?.copyWith(color: colors.textTertiary),
          ),
        ],
      ],
    );
  }

  Widget _uncategorized(BuildContext context) {
    final colors = context.colors;
    return CustomPaint(
      key: const Key('categoryLabelUnderline'),
      foregroundPainter: _DashedUnderlinePainter(colors.lineStrong),
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: colors.textTertiary),
        ),
      ),
    );
  }
}

/// A 1 px dashed line along the bottom edge, in the annotation dash rhythm
/// (5 on, 4 off).
class _DashedUnderlinePainter extends CustomPainter {
  const _DashedUnderlinePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    final y = size.height - 0.5;
    for (var x = 0.0; x < size.width; x += AppChart.dash + AppChart.dashGap) {
      final end = (x + AppChart.dash).clamp(0.0, size.width);
      canvas.drawLine(Offset(x, y), Offset(end, y), paint);
    }
  }

  @override
  bool shouldRepaint(_DashedUnderlinePainter oldDelegate) =>
      oldDelegate.color != color;
}
