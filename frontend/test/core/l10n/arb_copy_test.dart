import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The voice rules of `docs/design/00-design-system.md` §14 that a string
/// can break on its own, checked over every value of both ARB files.
void main() {
  final locales = {
    for (final locale in const ['fr', 'en']) locale: _messages(locale),
  };

  test('fr and en declare the same keys', () {
    final fr = locales['fr']!.keys.toSet();
    final en = locales['en']!.keys.toSet();
    expect(fr.difference(en), isEmpty, reason: 'missing from app_en.arb');
    expect(en.difference(fr), isEmpty, reason: 'missing from app_fr.arb');
  });

  for (final MapEntry(key: locale, value: messages) in locales.entries) {
    group('app_$locale.arb', () {
      test('uses the em dash only as the bare empty-value placeholder', () {
        final offenders = [
          for (final MapEntry(:key, :value) in messages.entries)
            if (value.contains('—') && value.trim() != '—') key,
        ];
        expect(offenders, isEmpty);
      });

      test('types no arrow or check glyph outside {a} → {b} notation', () {
        final offenders = [
          for (final MapEntry(:key, :value) in messages.entries)
            if (_glyph.hasMatch(value.replaceAll(_dataArrow, ''))) key,
        ];
        expect(offenders, isEmpty);
      });

      test('carries no exclamation mark', () {
        final offenders = [
          for (final MapEntry(:key, :value) in messages.entries)
            if (value.contains('!')) key,
        ];
        expect(offenders, isEmpty);
      });

      test('types the curly apostrophe, never the straight one', () {
        final offenders = [
          for (final MapEntry(:key, :value) in messages.entries)
            if (value.contains("'")) key,
        ];
        expect(offenders, isEmpty);
      });

      test('joins a figure and its unit with a no-break space', () {
        final offenders = [
          for (final MapEntry(:key, :value) in messages.entries)
            if (_figureSpaceUnit.hasMatch(value)) key,
        ];
        expect(offenders, isEmpty);
      });

      test('never says « pour l’instant »', () {
        final offenders = [
          for (final MapEntry(:key, :value) in messages.entries)
            if (_forNow.hasMatch(value)) key,
        ];
        expect(offenders, isEmpty);
      });
    });
  }

  test('the checks catch what they are meant to catch', () {
    expect(
      _glyph.hasMatch('Nouveau bien →'.replaceAll(_dataArrow, '')),
      isTrue,
    );
    expect(
      _glyph.hasMatch('{from} → {to}'.replaceAll(_dataArrow, '')),
      isFalse,
    );
    expect(
      _glyph.hasMatch(
        'Hausse : {from} → {to} le {date}'.replaceAll(_dataArrow, ''),
      ),
      isFalse,
    );
    expect(_forNow.hasMatch("Aucun import pour l'instant"), isTrue);
    expect(_figureSpaceUnit.hasMatch('{amount} k€'), isTrue);
    expect(_figureSpaceUnit.hasMatch('il y a 3 h'), isTrue);
    expect(_figureSpaceUnit.hasMatch('{amount}\u00A0k€'), isFalse);
    expect(_figureSpaceUnit.hasMatch('{count} hausses'), isFalse);
  });
}

/// `{from} → {to}` is data notation, not a typed link arrow.
final _dataArrow = RegExp(r'\{\w+\} → \{\w+\}');

final _glyph = RegExp('[→←↑↓↗↘⟶➔➜✓✔✗✘]');

final _forNow = RegExp('pour l[\'’]instant', caseSensitive: false);

/// A figure or a placeholder, an ordinary space, then a unit: `00` §3 asks
/// for U+00A0 there (« 320 k€ », « 35 % »).
final _figureSpaceUnit = RegExp(
  r'(\{\w+\}|\d) (%|€|k€|M€|×|Ko|Mo|Go|kB|KB|MB|GB|pts?|min|h)(?![\wÀ-ɏ])',
);

/// Every message of one ARB file, without its `@` metadata.
Map<String, String> _messages(String locale) {
  final decoded =
      jsonDecode(File('l10n/app_$locale.arb').readAsStringSync())
          as Map<String, dynamic>;
  return {
    for (final MapEntry(:key, :value) in decoded.entries)
      if (!key.startsWith('@')) key: value as String,
  };
}
