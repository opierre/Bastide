import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/core/theme/tokens.dart';
import 'package:bastide/core/widgets/inspector_pane.dart';
import 'package:bastide/core/widgets/state_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import 'host.dart';

const dark = AppColors.dark;

Widget region(Widget child) => SizedBox(width: 800, height: 500, child: child);

void main() {
  group('EmptyStateView', () {
    Widget empty({Widget? background}) => region(
      EmptyStateView(
        title: 'Aucun objectif',
        message: 'Créez un objectif pour réserver une somme.',
        action: OutlinedButton(onPressed: () {}, child: const Text('Créer')),
        background: background,
      ),
    );

    testWidgets('title 16/600, one sentence 13 textSecondary, one button, '
        'no icon', (tester) async {
      await pumpHost(tester, empty());
      final title = tester.widget<Text>(find.text('Aucun objectif'));
      expect(title.style?.fontSize, 16);
      expect(title.style?.fontWeight, FontWeight.w600);
      final sentence = tester.widget<Text>(
        find.text('Créez un objectif pour réserver une somme.'),
      );
      expect(sentence.style?.fontSize, 13);
      expect(sentence.style?.color, dark.textSecondary);
      expect(find.text('Créer'), findsOneWidget);
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('centred, the sentence at most 44 characters wide', (
      tester,
    ) async {
      await pumpHost(tester, empty());
      expect(
        tester.getCenter(find.text('Aucun objectif')).dx,
        tester.getCenter(find.byType(EmptyStateView)).dx,
      );
      expect(
        tester
            .getSize(find.text('Créez un objectif pour réserver une somme.'))
            .width,
        lessThanOrEqualTo(CenteredStatePane.maxSentenceWidth),
      );
    });

    testWidgets('a background fills the state behind the sentence', (
      tester,
    ) async {
      await pumpHost(
        tester,
        empty(
          background: const ColoredBox(
            key: Key('bg'),
            color: Colors.transparent,
          ),
        ),
      );
      expect(
        tester.getSize(find.byKey(const Key('bg'))),
        tester.getSize(find.byType(EmptyStateView)),
      );
      // Painted under the sentence.
      final stack = tester.widget<Stack>(
        find
            .descendant(
              of: find.byType(EmptyStateView),
              matching: find.byType(Stack),
            )
            .first,
      );
      expect(stack.children.first, isA<Positioned>());
    });

    testWidgets('a short region scrolls instead of overflowing', (
      tester,
    ) async {
      await pumpHost(
        tester,
        SizedBox(
          width: 400,
          height: 60,
          child: EmptyStateView(
            title: 'Aucun objectif',
            message: 'Créez un objectif pour réserver une somme.',
            action: OutlinedButton(
              onPressed: () {},
              child: const Text('Créer'),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('ErrorStateView', () {
    testWidgets('a 16 px warning triangle before the title, the sentence, '
        'a secondary retry', (tester) async {
      var retries = 0;
      await pumpHost(
        tester,
        region(
          ErrorStateView(
            title: 'Chargement impossible',
            message:
                'Les objectifs n’ont pas pu être lus. Rien n’a été modifié.',
            retryLabel: 'Réessayer',
            onRetry: () => retries++,
          ),
        ),
      );
      final icon = tester.widget<Icon>(find.byKey(const Key('errorStateIcon')));
      expect(icon.icon, LucideIcons300.triangleAlert);
      expect(icon.size, 16);
      expect(icon.color, dark.warning);
      expect(
        tester.getCenter(find.byKey(const Key('errorStateIcon'))).dx,
        lessThan(tester.getRect(find.text('Chargement impossible')).left),
      );
      expect(find.byType(OutlinedButton), findsOneWidget);
      await tester.tap(find.text('Réessayer'));
      expect(retries, 1);
    });

    testWidgets('without a title the icon leads the sentence', (tester) async {
      await pumpHost(
        tester,
        region(
          ErrorStateView(
            message: 'Rien n’a été modifié.',
            retryLabel: 'Réessayer',
            onRetry: () {},
          ),
        ),
      );
      expect(
        tester.getCenter(find.byKey(const Key('errorStateIcon'))).dx,
        lessThan(tester.getRect(find.text('Rien n’a été modifié.')).left),
      );
    });
  });

  group('loading silhouette', () {
    testWidgets('hover blocks, radius 4, no border, no spinner', (
      tester,
    ) async {
      await pumpHost(tester, region(const SkeletonList(itemCount: 2)));
      final deco = firstDecorationUnder(tester, find.byType(SkeletonList));
      expect(deco.color, dark.hover);
      expect(deco.borderRadius, BorderRadius.circular(AppRadii.item));
      expect(deco.border, isNull);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('pulses 1 → .5 over 1.6 s', (tester) async {
      await pumpHost(tester, region(const SkeletonList(itemCount: 1)));
      FadeTransition fade() => tester.widget<FadeTransition>(
        find.descendant(
          of: find.byType(SkeletonPulse),
          matching: find.byType(FadeTransition),
        ),
      );
      expect(fade().opacity.value, 1);
      await tester.pump(AppMotion.shimmer ~/ 2);
      expect(fade().opacity.value, closeTo(SkeletonPulse.minOpacity, 0.01));
      await tester.pump(AppMotion.shimmer ~/ 2);
      expect(fade().opacity.value, closeTo(1, 0.01));
    });

    testWidgets('reduced motion keeps the silhouette still', (tester) async {
      await pumpHost(
        tester,
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: SizedBox(width: 400, height: 300, child: SkeletonList()),
        ),
      );
      expect(
        find.descendant(
          of: find.byType(SkeletonPulse),
          matching: find.byType(FadeTransition),
        ),
        findsNothing,
      );
    });
  });

  group('InspectorPane', () {
    Widget pane(Object selection, {List<Widget>? blocks}) => SizedBox(
      height: 500,
      child: InspectorPane(
        selection: selection,
        blocks:
            blocks ??
            const [
              Text('Bloc A', key: Key('a')),
              Text('Bloc B', key: Key('b')),
            ],
      ),
    );

    testWidgets('440 px on rail behind a left line hairline, padding 24, '
        'blocks separated by hairlines', (tester) async {
      await pumpHost(tester, pane('t1'));
      final box = find.byType(InspectorPane);
      expect(tester.getSize(box).width, AppSizes.inspector);
      final deco = firstDecorationUnder(tester, box);
      expect(deco.color, dark.rail);
      expect((deco.border! as Border).left.color, dark.line);
      expect(
        tester.getTopLeft(find.byKey(const Key('a'))) - tester.getTopLeft(box),
        const Offset(AppSpacing.lg + 1, AppSpacing.lg),
      );
      expect(find.byType(Divider), findsOneWidget);
      final gap =
          tester.getTopLeft(find.byKey(const Key('b'))).dy -
          tester.getBottomLeft(find.byKey(const Key('a'))).dy;
      expect(gap, InspectorPane.blockGap * 2 + 1);
    });

    testWidgets('a new selection fades in over 120 ms', (tester) async {
      await pumpHost(tester, pane('t1'));
      await pumpHost(
        tester,
        pane('t2', blocks: const [Text('Autre', key: Key('c'))]),
      );
      await tester.pump(AppMotion.overlay ~/ 2);
      final fading = tester.widget<FadeTransition>(
        find
            .ancestor(
              of: find.byKey(const Key('c')),
              matching: find.byType(FadeTransition),
            )
            .first,
      );
      expect(fading.opacity.value, inExclusiveRange(0, 1));
      await tester.pumpAndSettle();
      expect(find.text('Bloc A'), findsNothing);
      expect(find.text('Autre'), findsOneWidget);
    });
  });

  testWidgets('states follow the light theme', (tester) async {
    await pumpHost(
      tester,
      region(
        ErrorStateView(
          message: 'Rien n’a été modifié.',
          retryLabel: 'Réessayer',
          onRetry: () {},
        ),
      ),
      theme: AppTheme.light,
    );
    expect(
      tester.widget<Icon>(find.byKey(const Key('errorStateIcon'))).color,
      AppColors.light.warning,
    );
  });
}
