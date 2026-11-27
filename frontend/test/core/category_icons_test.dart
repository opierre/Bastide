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
        'category.shopping',
        'category.finance',
        'category.children',
        'category.pets',
        'category.other',
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
        expect(CategoryIcons.resolveKey(key), key, reason: slug);
        final icon = CategoryIcons.forSlug(slug);
        expect(_isLucide300(icon), isTrue, reason: slug);
        expect(icon, isNot(CategoryIcons.fallback), reason: slug);
      }
    });

    test('each top-level bucket wears a glyph of its own', () {
      expect(CategoryIcons.forSlug('logement'), LucideIcons300.house);
      expect(CategoryIcons.forSlug('alimentation'), LucideIcons300.utensils);
      expect(CategoryIcons.forSlug('transport'), LucideIcons300.car);
      expect(CategoryIcons.forSlug('loisirs'), LucideIcons300.ferrisWheel);
      expect(CategoryIcons.forSlug('abonnements'), LucideIcons300.refreshCw);
      expect(CategoryIcons.forSlug('sante'), LucideIcons300.heartPulse);
      expect(CategoryIcons.forSlug('achats'), LucideIcons300.shoppingBag);
      expect(CategoryIcons.forSlug('finances'), LucideIcons300.wallet);
      expect(CategoryIcons.forSlug('enfants'), LucideIcons300.baby);
      expect(CategoryIcons.forSlug('animaux'), LucideIcons300.pawPrint);
      expect(CategoryIcons.forSlug('autres'), LucideIcons300.shapes);
      expect(CategoryIcons.forSlug('epargne'), LucideIcons300.piggyBank);
      expect(CategoryIcons.forSlug('revenus'), LucideIcons300.banknoteArrowUp);
      final keys = CategoryIcons.slugKeys.values.toList();
      expect(keys.toSet(), hasLength(keys.length));
    });

    test('a system subcategory takes its bucket, whatever its kind', () {
      expect(
        categorySlugFor(name: 'category.finance.savings', kind: 'transfer'),
        'finances',
      );
      expect(
        categorySlugFor(name: 'category.finance.interest', kind: 'income'),
        'finances',
      );
    });

    test('an unknown or missing slug falls back to the tag', () {
      expect(CategoryIcons.forSlug('nope'), CategoryIcons.fallback);
      expect(CategoryIcons.forSlug(null), CategoryIcons.fallback);
      expect(CategoryIcons.fallback, LucideIcons300.tag);
    });
  });

  group('stored keys', () {
    test('every curated and catalog glyph is a weight-300 Lucide icon', () {
      for (final entry in {
        ...CategoryIcons.glyphs,
        ...CategoryIcons.catalogGlyphs,
      }.entries) {
        expect(_isLucide300(entry.value), isTrue, reason: entry.key);
      }
      expect(_isLucide300(CategoryIcons.uncategorized), isTrue);
      expect(_isLucide300(CategoryIcons.fallback), isTrue);
    });

    test('the catalog set never repeats a curated key', () {
      expect(
        CategoryIcons.catalogGlyphs.keys.where(
          CategoryIcons.glyphs.containsKey,
        ),
        isEmpty,
      );
    });

    test('the form starts on a curated glyph', () {
      expect(CategoryIcons.glyphs, contains(CategoryIcons.defaultKey));
    });

    test('a current Lucide key resolves to itself', () {
      for (final key in {
        ...CategoryIcons.glyphs.keys,
        ...CategoryIcons.catalogGlyphs.keys,
      }) {
        expect(CategoryIcons.resolveKey(key), key);
      }
      expect(CategoryIcons.forKey('piggy-bank'), LucideIcons300.piggyBank);
      expect(CategoryIcons.forKey('stethoscope'), LucideIcons300.stethoscope);
    });

    test('an unknown, empty or missing key falls back', () {
      expect(CategoryIcons.resolveKey('not-an-icon'), isNull);
      expect(CategoryIcons.forKey('not-an-icon'), CategoryIcons.fallback);
      expect(CategoryIcons.forKey(''), CategoryIcons.fallback);
      expect(CategoryIcons.forKey(null), CategoryIcons.fallback);
      // Neither a Material name nor a slug from before Lucide is stored
      // anywhere any more.
      expect(CategoryIcons.resolveKey('restaurant'), isNull);
      expect(CategoryIcons.resolveKey('loisirs'), isNull);
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
