import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/core/theme/tokens.dart';
import 'package:bastide/core/widgets/app_modal.dart';
import 'package:bastide/core/widgets/app_popover.dart';
import 'package:bastide/core/widgets/app_toast.dart';
import 'package:bastide/core/widgets/category_label.dart';
import 'package:bastide/core/widgets/inline_banner.dart';
import 'package:bastide/core/widgets/monogram_avatar.dart';
import 'package:bastide/core/widgets/note_line.dart';
import 'package:bastide/core/widgets/status_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import 'host.dart';

const dark = AppColors.dark;

void main() {
  group('MonogramAvatar', () {
    testWidgets('22 px: radius 5, hover ground, line border, 10/600 '
        'textSecondary initials', (tester) async {
      await pumpHost(tester, const MonogramAvatar(name: 'Café du Port'));
      final box = find.byType(MonogramAvatar);
      expect(tester.getSize(box), const Size.square(22));
      final deco = firstDecorationUnder(tester, box);
      expect(deco.color, dark.hover);
      expect((deco.border! as Border).top.color, dark.line);
      expect(deco.borderRadius, BorderRadius.circular(5));
      final text = tester.widget<Text>(find.text('CD'));
      expect(text.style?.fontSize, 10);
      expect(text.style?.fontWeight, FontWeight.w600);
      expect(text.style?.color, dark.textSecondary);
    });

    testWidgets('32 px large: radius 7, 12/600', (tester) async {
      await pumpHost(
        tester,
        const MonogramAvatar(
          name: 'Banque Exemple',
          size: MonogramAvatar.large,
        ),
      );
      final deco = firstDecorationUnder(tester, find.byType(MonogramAvatar));
      expect(deco.borderRadius, BorderRadius.circular(7));
      expect(tester.widget<Text>(find.text('BE')).style?.fontSize, 12);
    });

    testWidgets('always neutral: two names share one ground', (tester) async {
      await pumpHost(
        tester,
        const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            MonogramAvatar(key: Key('a'), name: 'Streamflix'),
            MonogramAvatar(key: Key('b'), name: 'Épicerie Lune'),
          ],
        ),
      );
      expect(
        firstDecorationUnder(tester, find.byKey(const Key('a'))).color,
        firstDecorationUnder(tester, find.byKey(const Key('b'))).color,
      );
    });

    test('initials: one letter per word, two letters of a single word, '
        '« ? » with no name', () {
      expect(MonogramAvatar.initialsFor('Café du Port'), 'CD');
      expect(MonogramAvatar.initialsFor('Streamflix'), 'ST');
      expect(MonogramAvatar.initialsFor('  '), '?');
      expect(MonogramAvatar.initialsFor(''), '?');
    });
  });

  group('CategoryLabel', () {
    testWidgets('an 8 px dot in the category hue, the name in textSecondary', (
      tester,
    ) async {
      await pumpHost(
        tester,
        const CategoryLabel(label: 'Alimentation', slug: 'alimentation'),
      );
      final dot = find.byKey(const Key('categoryLabelDot'));
      expect(tester.getSize(dot), const Size.square(8));
      final deco = decorationOf(tester, dot);
      expect(deco.color, CategoryColors.dark.cat2);
      expect(deco.borderRadius, BorderRadius.circular(2));
      final name = tester.widget<Text>(find.byType(Text));
      expect(name.style?.color, dark.textSecondary);
    });

    testWidgets('a stored slot draws the dot in that hue', (tester) async {
      await pumpHost(
        tester,
        const CategoryLabel.slotted(label: 'Jardin', slot: CategorySlot.cat6),
      );
      final dot = find.byKey(const Key('categoryLabelDot'));
      expect(decorationOf(tester, dot).color, CategoryColors.dark.cat6);
      expect(find.byKey(const Key('categoryLabelUnderline')), findsNothing);
    });

    testWidgets('a subcategory follows after « › » in textTertiary', (
      tester,
    ) async {
      await pumpHost(
        tester,
        const CategoryLabel(
          label: 'Alimentation',
          slug: 'alimentation',
          subcategory: 'Restaurants',
        ),
      );
      final text = tester.widget<Text>(find.byType(Text));
      final sub = (text.textSpan! as TextSpan).children!.last as TextSpan;
      expect(sub.text, ' › Restaurants');
      expect(sub.style?.color, dark.textTertiary);
    });

    testWidgets('uncategorized: no dot, textTertiary over a dashed underline', (
      tester,
    ) async {
      await pumpHost(
        tester,
        const CategoryLabel.uncategorized(label: 'Non catégorisé'),
      );
      expect(find.byKey(const Key('categoryLabelDot')), findsNothing);
      expect(
        tester.widget<Text>(find.text('Non catégorisé')).style?.color,
        dark.textTertiary,
      );
      expect(
        find.byKey(const Key('categoryLabelUnderline')),
        paints..line(color: dark.lineStrong, strokeWidth: 1),
      );
    });

    testWidgets('a proposal adds its confidence in 12 textTertiary', (
      tester,
    ) async {
      await pumpHost(
        tester,
        const CategoryLabel.proposed(
          label: 'Transport',
          slug: 'transport',
          confidence: 'confiance 78 %',
        ),
      );
      final confidence = tester.widget<Text>(
        find.byKey(const Key('categoryLabelConfidence')),
      );
      expect(confidence.data, 'confiance 78 %');
      expect(confidence.style?.fontSize, 12);
      expect(confidence.style?.color, dark.textTertiary);
      expect(find.byKey(const Key('categoryLabelDot')), findsOneWidget);
    });

    testWidgets('a tap calls back', (tester) async {
      var taps = 0;
      await pumpHost(
        tester,
        CategoryLabel.uncategorized(
          label: 'Non catégorisé',
          onTap: () => taps++,
        ),
      );
      await tester.tap(find.text('Non catégorisé'));
      expect(taps, 1);
    });
  });

  group('StatusText', () {
    testWidgets('each tone sets a 13 px icon and 12 px text in one colour', (
      tester,
    ) async {
      final expected = {
        StatusTone.positive: (dark.positive, LucideIcons300.check),
        StatusTone.warning: (dark.warning, LucideIcons300.triangleAlert),
        StatusTone.negative: (dark.negative, LucideIcons300.circleX),
      };
      for (final MapEntry(key: tone, value: (colour, icon))
          in expected.entries) {
        await pumpHost(tester, StatusText(label: 'Statut', tone: tone));
        final glyph = tester.widget<Icon>(find.byType(Icon));
        expect(glyph.icon, icon, reason: '$tone');
        expect(glyph.size, 13);
        expect(glyph.color, colour);
        final text = tester.widget<Text>(find.text('Statut'));
        expect(text.style?.fontSize, 12);
        expect(text.style?.color, colour);
      }
    });

    testWidgets('neutral is textSecondary with no icon unless one is given', (
      tester,
    ) async {
      await pumpHost(tester, const StatusText(label: 'Système'));
      expect(find.byType(Icon), findsNothing);
      expect(
        tester.widget<Text>(find.text('Système')).style?.color,
        dark.textSecondary,
      );

      await pumpHost(
        tester,
        const StatusText(
          label: 'Hausse',
          tone: StatusTone.warning,
          icon: LucideIcons300.trendingUp,
        ),
      );
      expect(
        tester.widget<Icon>(find.byType(Icon)).icon,
        LucideIcons300.trendingUp,
      );
    });
  });

  group('InlineBanner', () {
    testWidgets('neutral box: surface, lineStrong, radius 8; only the icon '
        'takes the tone', (tester) async {
      await pumpHost(
        tester,
        const SizedBox(
          width: 400,
          child: InlineBanner(
            message: 'Le fichier est illisible.',
            tone: BannerTone.warning,
          ),
        ),
      );
      final deco = firstDecorationUnder(tester, find.byType(InlineBanner));
      expect(deco.color, dark.surface);
      expect((deco.border! as Border).top.color, dark.lineStrong);
      expect(deco.borderRadius, BorderRadius.circular(AppRadii.container));
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.color, dark.warning);
      expect(icon.size, 14);
      final text = tester.widget<Text>(find.text('Le fichier est illisible.'));
      expect(text.style?.fontSize, 13);
      expect(text.style?.color, dark.text);
    });

    testWidgets('info is neutral, error negative', (tester) async {
      await pumpHost(
        tester,
        const SizedBox(
          width: 400,
          child: InlineBanner(message: 'Info', tone: BannerTone.info),
        ),
      );
      expect(tester.widget<Icon>(find.byType(Icon)).color, dark.textSecondary);
      await pumpHost(
        tester,
        const SizedBox(width: 400, child: InlineBanner(message: 'Erreur')),
      );
      expect(tester.widget<Icon>(find.byType(Icon)).color, dark.negative);
    });

    testWidgets('actions sit on the right; the ghost close dismisses', (
      tester,
    ) async {
      var dismissed = 0;
      await pumpHost(
        tester,
        SizedBox(
          width: 500,
          child: InlineBanner(
            message: 'Deux séries se ressemblent.',
            tone: BannerTone.info,
            actions: [
              TextButton(onPressed: () {}, child: const Text('Fusionner')),
            ],
            onDismiss: () => dismissed++,
            dismissTooltip: 'Fermer',
          ),
        ),
      );
      expect(
        tester.getCenter(find.text('Fusionner')).dx,
        greaterThan(
          tester.getCenter(find.text('Deux séries se ressemblent.')).dx,
        ),
      );
      await tester.tap(find.byKey(const Key('inlineBannerDismiss')));
      expect(dismissed, 1);
    });

    testWidgets('no close without a dismiss handler', (tester) async {
      await pumpHost(
        tester,
        const SizedBox(width: 400, child: InlineBanner(message: 'Erreur')),
      );
      expect(find.byKey(const Key('inlineBannerDismiss')), findsNothing);
    });
  });

  testWidgets('a note is a 14 px textTertiary icon and 12 textSecondary '
      'text, no box', (tester) async {
    await pumpHost(tester, const NoteLine(text: 'Lecture indicative.'));
    final icon = tester.widget<Icon>(find.byType(Icon));
    expect(icon.size, 14);
    expect(icon.color, dark.textTertiary);
    final text = tester.widget<Text>(find.text('Lecture indicative.'));
    expect(text.style?.fontSize, 12);
    expect(text.style?.color, dark.textSecondary);
    expect(
      find.descendant(
        of: find.byType(NoteLine),
        matching: find.byType(DecoratedBox),
      ),
      findsNothing,
    );
  });

  group('AppPopover', () {
    testWidgets('surface, lineStrong, radius 8, shadow, padding 4', (
      tester,
    ) async {
      await pumpHost(tester, const AppPopover(child: Text('Menu')));
      final deco = firstDecorationUnder(tester, find.byType(AppPopover));
      expect(deco.color, dark.surface);
      expect((deco.border! as Border).top.color, dark.lineStrong);
      expect(deco.borderRadius, BorderRadius.circular(8));
      expect(deco.boxShadow, dark.shadow);
      expect(
        tester.getTopLeft(find.text('Menu')) -
            tester.getTopLeft(find.byType(AppPopover)),
        const Offset(4 + 1, 4 + 1),
      );
    });

    testWidgets('a menu item is 28 px; the selected one carries a check', (
      tester,
    ) async {
      var picked = 0;
      await pumpHost(
        tester,
        Builder(
          builder: (context) => MenuAnchor(
            style: AppPopover.menuStyle(context),
            menuChildren: [
              AppMenuItem(
                key: const Key('one'),
                width: 192,
                label: 'Mensuel',
                selected: true,
                onPressed: () => picked = 1,
              ),
              AppMenuItem(
                label: 'Annuel',
                width: 192,
                onPressed: () => picked = 2,
              ),
            ],
            builder: (context, controller, _) => TextButton(
              onPressed: controller.open,
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byKey(const Key('one'))).height, 28);
      expect(find.byKey(const Key('appMenuItemCheck')), findsOneWidget);
      await tester.tap(find.text('Annuel'));
      await tester.pumpAndSettle();
      expect(picked, 2);
    });
  });

  group('AppModal', () {
    testWidgets('surface, radius 12, shadow; title 16/600, lead 13 '
        'textSecondary; footer 8 px apart', (tester) async {
      await pumpHost(
        tester,
        AppModal(
          title: 'Nouveau compte',
          subtitle: const Text('Sous Logement'),
          width: 480,
          actions: [
            OutlinedButton(
              key: const Key('cancel'),
              onPressed: () {},
              child: const Text('Annuler'),
            ),
            FilledButton(
              key: const Key('save'),
              onPressed: () {},
              child: const Text('Créer'),
            ),
          ],
          child: const SizedBox(height: 40),
        ),
      );
      final deco = firstDecorationUnder(tester, find.byType(AppModal));
      expect(deco.color, dark.surface);
      expect(deco.borderRadius, BorderRadius.circular(12));
      expect(deco.boxShadow, dark.shadow);
      expect(deco.border, isNull);

      final title = tester.widget<Text>(find.text('Nouveau compte'));
      expect(title.style?.fontSize, 16);
      expect(title.style?.fontWeight, FontWeight.w600);
      final lead = DefaultTextStyle.of(
        tester.element(find.text('Sous Logement')),
      ).style;
      expect(lead.fontSize, 13);
      expect(lead.color, dark.textSecondary);

      final gap =
          tester.getRect(find.byKey(const Key('save'))).left -
          tester.getRect(find.byKey(const Key('cancel'))).right;
      expect(gap, AppSpacing.sm);
      // Padding 24 around the title.
      expect(
        tester.getTopLeft(find.text('Nouveau compte')) -
            tester.getTopLeft(find.byType(AppModal).first),
        isNot(Offset.zero),
      );
    });
  });

  group('toast', () {
    Future<void> show(
      WidgetTester tester, {
      BannerTone tone = BannerTone.success,
    }) async {
      await pumpHost(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showAppToast(
              context,
              title: 'Règles exécutées',
              message: 'Vos choix manuels sont conservés.',
              tone: tone,
            ),
            child: const Text('go'),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pump();
    }

    testWidgets('bottom-right, 24 px from the edges, in the toast recipe', (
      tester,
    ) async {
      await show(tester);
      await tester.pump(AppMotion.overlay);
      final toast = find.byKey(const Key('appToast'));
      final screen = tester.getSize(find.byType(MaterialApp));
      final rect = tester.getRect(toast);
      expect(screen.width - rect.right, 24);
      expect(screen.height - rect.bottom, 24);
      final deco = decorationOf(tester, toast);
      expect(deco.color, dark.surface);
      expect((deco.border! as Border).top.color, dark.lineStrong);
      expect(deco.borderRadius, BorderRadius.circular(8));
      expect(deco.boxShadow, dark.shadow);
      final icon = tester.widget<Icon>(find.byKey(const Key('appToastIcon')));
      expect(icon.color, dark.positive);
      expect(
        tester.widget<Text>(find.text('Règles exécutées')).style?.fontSize,
        13,
      );
      final second = tester.widget<Text>(
        find.text('Vos choix manuels sont conservés.'),
      );
      expect(second.style?.fontSize, 12);
      expect(second.style?.color, dark.textSecondary);
    });

    testWidgets('comes in over 120 ms and leaves after 4 s', (tester) async {
      await show(tester, tone: BannerTone.error);
      final opacity = find.ancestor(
        of: find.byKey(const Key('appToast')),
        matching: find.byType(Opacity),
      );
      expect(tester.widget<Opacity>(opacity.first).opacity, lessThan(1));
      await tester.pump(AppMotion.overlay);
      expect(tester.widget<Opacity>(opacity.first).opacity, 1);
      expect(
        tester.widget<Icon>(find.byKey(const Key('appToastIcon'))).color,
        dark.negative,
      );

      await tester.pump(toastDuration);
      expect(find.byKey(const Key('appToast')), findsNothing);
    });
  });

  testWidgets('labels follow the light theme', (tester) async {
    await pumpHost(
      tester,
      const CategoryLabel(label: 'Logement', slug: 'logement'),
      theme: AppTheme.light,
    );
    expect(
      decorationOf(tester, find.byKey(const Key('categoryLabelDot'))).color,
      CategoryColors.light.cat1,
    );
  });
}
