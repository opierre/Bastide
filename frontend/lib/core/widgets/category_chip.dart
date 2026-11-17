import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'category_icons.dart';
import 'dashed_border.dart';

export 'category_icons.dart';

/// A category label: 22px pill, the category's pinned hue at 14% with the
/// full-strength hue for text and glyph.
///
/// The uncategorized case is a deliberately different shape — a dashed neutral
/// outline — so an unreviewed transaction reads as *missing a category* rather
/// than as belonging to a grey one.
class CategoryChip extends StatelessWidget {
  const CategoryChip({
    super.key,
    required this.label,
    required this.slug,
    this.onTap,
  });

  /// The "not categorized yet" variant. [label] is the localized
  /// « Non catégorisé » string — this widget never invents copy.
  const CategoryChip.uncategorized({super.key, required this.label, this.onTap})
    : slug = null;

  final String label;

  /// Backend category slug; drives both hue and glyph. `null` renders the
  /// uncategorized variant.
  final String? slug;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final chip = slug == null
        ? _buildUncategorized(context)
        : _buildCategorized(context);
    if (onTap == null) return chip;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: onTap, child: chip),
    );
  }

  Widget _buildCategorized(BuildContext context) {
    final hue = context.categoryColors.forSlug(slug);
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm + 2),
      decoration: BoxDecoration(
        color: hue.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: _content(context, hue),
    );
  }

  Widget _buildUncategorized(BuildContext context) {
    return DashedBorder(
      radius: AppRadii.pill,
      child: SizedBox(
        height: 22,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm + 2),
          child: _content(context, context.colors.textSecondary),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, Color foreground) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          slug == null
              ? CategoryIcons.uncategorized
              : CategoryIcons.forSlug(slug),
          size: 11,
          color: foreground,
        ),
        const SizedBox(width: AppSpacing.xs + 1),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: foreground),
        ),
      ],
    );
  }
}
