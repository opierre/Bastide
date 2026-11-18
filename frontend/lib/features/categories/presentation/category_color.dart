import 'package:flutter/material.dart';

import '../../../core/l10n/category_display.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/category_label.dart';
import '../domain/category.dart';

/// The slot a category is drawn in (`docs/design/00-design-system.md` §2.4).
///
/// The row stores its slot, not a hex: the theme resolves it to a colour, so a
/// category keeps its identity across the dark and light palettes. A value the
/// app doesn't know (a row from before slots) is the neutral [CategorySlot.cat0].
CategorySlot categorySlot(AppCategory category) =>
    CategorySlot.fromWire(category.color);

/// The hue a category is drawn in — its swatch here, its chip everywhere else.
Color categoryColor(BuildContext context, AppCategory category) =>
    context.categoryColors.forSlot(categorySlot(category));

/// The glyph a category is drawn with on its card.
///
/// A system category takes its chip's glyph, so a category looks the same on
/// the panel as on every transaction row (`docs/design/08`). A user category
/// takes the icon chosen in its modal — a [CategoryIcons] key, or a pre-Lucide
/// key [CategoryIcons.resolveKey] maps — falling back to the chip's glyph for
/// a key the app doesn't know.
IconData categoryIcon(AppCategory category) =>
    CategoryIcons.forKey(categoryIconKey(category));

/// The [CategoryIcons] key behind [categoryIcon] — what a subcategory stores
/// to wear its parent's glyph.
String categoryIconKey(AppCategory category) {
  final chipKey = CategoryIcons
      .slugKeys[categorySlugFor(name: category.name, kind: category.kind)]!;
  if (category.isSystem) return chipKey;
  return CategoryIcons.resolveKey(category.icon) ?? chipKey;
}
