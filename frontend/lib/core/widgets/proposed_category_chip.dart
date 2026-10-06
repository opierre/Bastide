import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'category_chip.dart';
import 'dashed_border.dart';

/// A category the model *proposed* but did not assign — the review queue's
/// stage-2 chip (`docs/design/00` §Gestion & AI additions).
///
/// Same geometry as [CategoryChip], with a dashed outline in the category hue
/// over a transparent fill. That makes it a third, distinct state rather than a
/// variant of either neighbour: an assigned chip is a solid hue tint, and the
/// « Non catégorisé » chip is a dashed *neutral*. A proposal is neither
/// settled nor empty, and the chip has to say so at a glance — the user is
/// about to accept or reject exactly this.
///
/// Always paired with a `ConfidenceGauge`: a proposal without its confidence
/// asks the user to judge a guess without telling them how good it is.
class ProposedCategoryChip extends StatelessWidget {
  const ProposedCategoryChip({
    super.key,
    required this.label,
    required this.slug,
  });

  /// The localized category name. This widget never invents copy.
  final String label;

  /// Backend category slug; drives both hue and glyph.
  final String slug;

  @override
  Widget build(BuildContext context) {
    final hue = CategoryHues.forSlug(slug);

    return DashedBorder(
      color: hue,
      radius: AppRadii.pill,
      child: SizedBox(
        height: 22,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm + 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CategoryIcons.forSlug(slug), size: 11, color: hue),
              const SizedBox(width: AppSpacing.xs + 1),
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: hue),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
