import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'dashed_border.dart';

/// Category glyphs, one per pinned hue. Paired with the hue so a chip carries
/// its category twice over — meaning is never on color alone.
abstract final class CategoryIcons {
  static const bySlug = <String, IconData>{
    'logement': Icons.home_outlined,
    'alimentation': Icons.rice_bowl_outlined,
    'transport': Icons.directions_car_outlined,
    'loisirs': Icons.star_outline_rounded,
    'abonnements': Icons.autorenew_rounded,
    'sante': Icons.local_hospital_outlined,
    'autres': Icons.monetization_on_outlined,
    'epargne': Icons.monetization_on_outlined,
    'revenus': Icons.arrow_upward_rounded,
  };

  static const fallback = Icons.sell_outlined;

  static IconData forSlug(String? slug) => bySlug[slug] ?? fallback;
}

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
    final hue = CategoryHues.forSlug(slug);
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
          child: _content(context, AppColors.textSecondary),
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
              ? Icons.help_outline_rounded
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
