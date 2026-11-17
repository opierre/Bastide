import 'dart:io';
import 'dart:math' as math;

import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/core/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('colour literals', () {
    // A colour belongs to the theme (`docs/design/00-design-system.md` §2): a
    // hex in a widget would not follow a theme switch. Only the token files
    // may spell one.
    final literal = RegExp(
      r'\bColor\(\s*0x|\bColor\.from(ARGB|RGBO)\(|\bColors\.(?!transparent\b)\w+',
    );

    List<String> offenders(Directory root) {
      final found = <String>[];
      for (final entity in root.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final path = '/${entity.path.replaceAll(r'\', '/')}';
        if (path.contains('/lib/core/theme/') || path.contains('/lib/l10n/')) {
          continue;
        }
        final lines = entity.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final code = lines[i].split('//').first;
          if (literal.hasMatch(code)) found.add('$path:${i + 1}');
        }
      }
      return found;
    }

    test('no widget file contains a colour literal', () {
      expect(offenders(Directory('lib')), isEmpty);
    });

    test('the check catches a literal', () {
      final dir = Directory.systemTemp.createTempSync('colour_literal');
      addTearDown(() => dir.deleteSync(recursive: true));
      File('${dir.path}/lib/a.dart')
        ..createSync(recursive: true)
        ..writeAsStringSync('final a = Color(0xFF123456);\n');
      File('${dir.path}/lib/b.dart').writeAsStringSync(
        'final b = Colors.white;\nfinal c = Colors.transparent;\n',
      );
      File(
        '${dir.path}/lib/c.dart',
      ).writeAsStringSync('/// Color(0xFF123456) in a comment is fine.\n');

      expect(offenders(Directory('${dir.path}/lib')), hasLength(2));
    });
  });

  group('contrast (`00` §2.2)', () {
    double luminance(Color c) {
      double channel(double v) => v <= 0.03928
          ? v / 12.92
          : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
      return 0.2126 * channel(c.r) +
          0.7152 * channel(c.g) +
          0.0722 * channel(c.b);
    }

    double ratio(Color a, Color b) {
      final la = luminance(a);
      final lb = luminance(b);
      return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
    }

    for (final (name, colors) in [
      ('dark', AppColors.dark),
      ('light', AppColors.light),
    ]) {
      final surfaces = {
        'bg': colors.bg,
        'rail': colors.rail,
        'hover': colors.hover,
      };

      test('$name: every text token is at least 4.5:1', () {
        for (final MapEntry(key: surface, value: ground) in surfaces.entries) {
          for (final (token, ink) in [
            ('text', colors.text),
            ('textSecondary', colors.textSecondary),
            ('textTertiary', colors.textTertiary),
          ]) {
            expect(
              ratio(ink, ground),
              greaterThanOrEqualTo(4.5),
              reason: '$token on $surface',
            );
          }
        }
      });

      test('$name: meaning colours used as text are at least 4.7:1', () {
        for (final MapEntry(key: surface, value: ground) in surfaces.entries) {
          for (final (token, ink) in [
            ('positive', colors.positive),
            ('negative', colors.negative),
            ('warning', colors.warning),
            ('accent', colors.accent),
          ]) {
            expect(
              ratio(ink, ground),
              greaterThanOrEqualTo(4.7),
              reason: '$token on $surface',
            );
          }
        }
      });
    }
  });

  group('themes', () {
    test('each theme carries its own extensions', () {
      expect(AppTheme.dark.brightness, Brightness.dark);
      expect(AppTheme.light.brightness, Brightness.light);
      expect(AppTheme.dark.extension<AppColors>(), AppColors.dark);
      expect(AppTheme.light.extension<AppColors>(), AppColors.light);
      expect(AppTheme.dark.extension<CategoryColors>(), CategoryColors.dark);
      expect(AppTheme.light.extension<CategoryColors>(), CategoryColors.light);
      expect(AppTheme.light.extension<AppTextStyles>(), isNotNull);
    });

    test('Revenus takes the theme\'s positive colour', () {
      expect(CategoryColors.dark.income, AppColors.dark.positive);
      expect(CategoryColors.light.income, AppColors.light.positive);
    });

    test('a stored slot resolves through the theme', () {
      expect(CategorySlot.fromWire('cat3'), CategorySlot.cat3);
      expect(CategorySlot.fromWire('#64748B'), CategorySlot.cat0);
      expect(
        CategoryColors.light.forSlot(CategorySlot.cat1),
        isNot(CategoryColors.dark.forSlot(CategorySlot.cat1)),
      );
    });

    testWidgets('a widget re-reads its colours when the theme changes', (
      tester,
    ) async {
      final mode = ValueNotifier(ThemeMode.dark);
      addTearDown(mode.dispose);
      await tester.pumpWidget(
        ValueListenableBuilder<ThemeMode>(
          valueListenable: mode,
          builder: (_, value, _) => MaterialApp(
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: value,
            home: Builder(
              builder: (context) => ColoredBox(
                key: const Key('ground'),
                color: context.colors.bg,
              ),
            ),
          ),
        ),
      );
      Color ground() =>
          tester.widget<ColoredBox>(find.byKey(const Key('ground'))).color;

      expect(ground(), AppColors.dark.bg);
      mode.value = ThemeMode.light;
      await tester.pumpAndSettle();
      expect(ground(), AppColors.light.bg);
    });
  });
}
