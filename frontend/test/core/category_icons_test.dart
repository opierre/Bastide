import 'package:bastide/core/l10n/category_display.dart';
import 'package:bastide/core/widgets/category_icons.dart';
import 'package:bastide/features/categories/presentation/category_labels.dart';
import 'package:bastide/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

/// Every glyph must come from the weight-300 Lucide font: that is the 1.5 px
/// stroke `docs/design/00` pins. A glyph from another family is a regression.
bool _isLucide300(IconData icon) =>
    icon.fontFamily == 'Lucide300' &&
    icon.fontPackage == 'lucide_icons_flutter';

void main() {
  group('system slugs', () {
    // Every slug `categorySlugFor` can return — the system catalog's buckets
    // and the user-category fallbacks.
    final slugs = {
      for (final name in const [
        'category.housing',
        'category.food',
        'category.transport',
        'category.health',
        'category.leisure',
        'category.subscriptions',
        'category.income',
        'category.misc',
      ])
        categorySlugFor(name: name, kind: 'expense'),
      categorySlugFor(name: 'Mine', kind: 'income'),
      categorySlugFor(name: 'Mine', kind: 'expense'),
      categorySlugFor(name: 'Mine', kind: 'transfer'),
    };

    test('every slug the app derives has a Lucide glyph of its own', () {
      expect(slugs, unorderedEquals(CategoryIcons.slugKeys.keys));
      for (final slug in slugs) {
        final key = CategoryIcons.slugKeys[slug];
        expect(CategoryIcons.glyphs, contains(key), reason: slug);
        final icon = CategoryIcons.forSlug(slug);
        expect(_isLucide300(icon), isTrue, reason: slug);
        expect(icon, isNot(CategoryIcons.fallback), reason: slug);
      }
    });

    test('the chips wear the glyphs the spec names', () {
      expect(CategoryIcons.forSlug('logement'), LucideIcons300.house);
      expect(CategoryIcons.forSlug('alimentation'), LucideIcons300.soup);
      expect(CategoryIcons.forSlug('transport'), LucideIcons300.car);
      expect(CategoryIcons.forSlug('loisirs'), LucideIcons300.star);
      expect(CategoryIcons.forSlug('abonnements'), LucideIcons300.refreshCw);
      expect(CategoryIcons.forSlug('sante'), LucideIcons300.cross);
      expect(CategoryIcons.forSlug('autres'), LucideIcons300.coins);
      expect(CategoryIcons.forSlug('epargne'), LucideIcons300.coins);
      expect(CategoryIcons.forSlug('revenus'), LucideIcons300.arrowUp);
    });

    test('an unknown or missing slug falls back to the tag', () {
      expect(CategoryIcons.forSlug('nope'), CategoryIcons.fallback);
      expect(CategoryIcons.forSlug(null), CategoryIcons.fallback);
      expect(CategoryIcons.fallback, LucideIcons300.tag);
    });
  });

  group('stored keys', () {
    test('every curated glyph is a weight-300 Lucide icon', () {
      for (final entry in CategoryIcons.glyphs.entries) {
        expect(_isLucide300(entry.value), isTrue, reason: entry.key);
      }
      expect(_isLucide300(CategoryIcons.uncategorized), isTrue);
      expect(_isLucide300(CategoryIcons.fallback), isTrue);
    });

    test('a current Lucide key resolves to itself', () {
      for (final key in CategoryIcons.glyphs.keys) {
        expect(CategoryIcons.resolveKey(key), key);
      }
      expect(CategoryIcons.forKey('piggy-bank'), LucideIcons300.piggyBank);
    });

    test('a slug saved by the pre-Lucide form maps to its chip glyph', () {
      expect(CategoryIcons.resolveKey('loisirs'), 'star');
      expect(CategoryIcons.forKey('logement'), LucideIcons300.house);
      expect(CategoryIcons.forKey('epargne'), LucideIcons300.coins);
    });

    test('a Material name maps to its Lucide equivalent', () {
      expect(CategoryIcons.forKey('restaurant'), LucideIcons300.utensils);
      expect(CategoryIcons.forKey('savings'), LucideIcons300.piggyBank);
      expect(CategoryIcons.forKey('local_pharmacy'), LucideIcons300.pill);
      expect(CategoryIcons.forKey('rice_bowl_outlined'), LucideIcons300.soup);
    });

    test('every legacy Material name lands on a glyph or the fallback', () {
      for (final entry in CategoryIcons.legacyMaterialKeys.entries) {
        final target = entry.value;
        expect(
          CategoryIcons.glyphs.containsKey(target) || target == 'tag',
          isTrue,
          reason: '${entry.key} → $target',
        );
      }
    });

    test('an unknown, empty or missing key falls back', () {
      expect(CategoryIcons.resolveKey('not-an-icon'), isNull);
      expect(CategoryIcons.forKey('not-an-icon'), CategoryIcons.fallback);
      expect(CategoryIcons.forKey(''), CategoryIcons.fallback);
      expect(CategoryIcons.forKey(null), CategoryIcons.fallback);
      // Mapped to the tag, which the picker does not offer: renders as the
      // fallback rather than resolving to a key the form can't select.
      expect(CategoryIcons.resolveKey('sell'), isNull);
      expect(CategoryIcons.forKey('sell'), LucideIcons300.tag);
    });
  });

  group('picker labels', () {
    for (final locale in const [Locale('fr'), Locale('en')]) {
      test('every curated glyph has its own ${locale.languageCode} label', () {
        final l10n = lookupAppLocalizations(locale);
        final labels = [
          for (final key in CategoryIcons.glyphs.keys)
            categoryIconLabel(l10n, key),
        ];
        expect(labels.toSet(), hasLength(labels.length));
        expect(labels, everyElement(isNotEmpty));
      });
    }
  });
}
