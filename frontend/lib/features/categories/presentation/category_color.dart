import 'package:flutter/material.dart';

import '../../../core/l10n/category_display.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/category_chip.dart';
import '../domain/category.dart';

/// The hue a category is drawn in — its swatch here, its chip everywhere else.
///
/// Read from the row's own `color`, which the user picked for their categories
/// and which `backend/app/core/seed.py` keeps in lockstep with the pinned hues
/// for system ones, so a system row lands on exactly the [CategoryHues] value
/// `docs/design/00` pins. A colour that doesn't parse falls back to the pinned
/// hue for the category's bucket rather than to a neutral grey: a category
/// whose swatch differs between the panel and its chip reads as two categories.
Color categoryColor(AppCategory category) {
  final parsed = _parseHex(category.color);
  if (parsed != null) return parsed;
  return CategoryHues.forSlug(
    categorySlugFor(name: category.name, kind: category.kind),
  );
}

/// The glyph a category is drawn with on its card.
///
/// A system category takes its chip's glyph, so a category looks the same on
/// the panel as on every transaction row (`docs/design/08`). A user category
/// takes the icon chosen in its modal — the form stores one of the
/// [CategoryIcons] slugs — falling back to the chip's glyph for a slug the app
/// doesn't know.
IconData categoryIcon(AppCategory category) {
  final chipSlug = categorySlugFor(name: category.name, kind: category.kind);
  if (category.isSystem) return CategoryIcons.forSlug(chipSlug);
  return CategoryIcons.bySlug[category.icon] ?? CategoryIcons.forSlug(chipSlug);
}

/// The palette the create/edit form offers. The design system pins these hues
/// per category (`docs/design/00` §Palette), so a user category picks *from*
/// them rather than from an arbitrary colour wheel — that is what keeps the
/// donut, the legend and the chips one family.
const categoryPalette = <Color>[
  CategoryHues.logement,
  CategoryHues.alimentation,
  CategoryHues.transport,
  CategoryHues.loisirs,
  CategoryHues.abonnements,
  CategoryHues.sante,
  CategoryHues.revenus,
  CategoryHues.autres,
];

/// `#RRGGBB`, the format the API stores and the palette above is expressed in.
String hexOf(Color color) {
  final value = color.toARGB32() & 0xFFFFFF;
  return '#${value.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

Color? _parseHex(String value) {
  final hex = value.startsWith('#') ? value.substring(1) : value;
  if (hex.length != 6) return null;
  final parsed = int.tryParse(hex, radix: 16);
  if (parsed == null) return null;
  return Color(0xFF000000 | parsed);
}
