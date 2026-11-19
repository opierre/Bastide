import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/core/theme/tokens.dart';
import 'package:bastide/core/widgets/app_button.dart';
import 'package:bastide/core/widgets/app_checkbox.dart';
import 'package:bastide/core/widgets/app_segmented.dart';
import 'package:bastide/core/widgets/app_select.dart';
import 'package:bastide/core/widgets/app_slider.dart';
import 'package:bastide/core/widgets/app_tabs.dart';
import 'package:bastide/core/widgets/app_toggle.dart';
import 'package:bastide/core/widgets/focus_ring.dart';
import 'package:bastide/core/widgets/search_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'host.dart';

const dark = AppColors.dark;

/// The ground of the button's box.
Color? groundOf(WidgetTester tester, Key key) =>
    firstDecorationUnder(tester, find.byKey(key)).color;

void main() {
  group('AppButton', () {
    const key = Key('button');

    Widget button({
      AppButtonVariant variant = AppButtonVariant.secondary,
      AppButtonSize size = AppButtonSize.regular,
      VoidCallback? onPressed,
      bool loading = false,
      IconData? icon,
    }) => AppButton(
      key: key,
      label: 'Enregistrer',
      variant: variant,
      size: size,
      icon: icon,
      isLoading: loading,
      onPressed: onPressed,
    );

    testWidgets('stands 28 px, or 36 px when large', (tester) async {
      await pumpHost(tester, button(onPressed: () {}));
      expect(tester.getSize(find.byKey(key)).height, AppSizes.button);

      await pumpHost(
        tester,
        button(onPressed: () {}, size: AppButtonSize.large),
      );
      expect(tester.getSize(find.byKey(key)).height, AppSizes.buttonLarge);
    });

    testWidgets('each variant rests on its own ground and label', (
      tester,
    ) async {
      final expected = {
        AppButtonVariant.secondary: (dark.surface, dark.text),
        AppButtonVariant.primary: (dark.primary, dark.onPrimary),
        AppButtonVariant.ghost: (Colors.transparent, dark.textSecondary),
        AppButtonVariant.danger: (dark.surface, dark.negative),
        AppButtonVariant.destructive: (dark.negative, dark.onPrimary),
      };
      for (final MapEntry(key: variant, value: (ground, label))
          in expected.entries) {
        await pumpHost(tester, button(variant: variant, onPressed: () {}));
        expect(groundOf(tester, key), ground, reason: '$variant ground');
        final text = tester.widget<Text>(find.text('Enregistrer'));
        expect(text.style?.color, label, reason: '$variant label');
      }
    });

    testWidgets('the secondary button has a lineStrong border, the danger '
        'one a negative 45 % border', (tester) async {
      await pumpHost(tester, button(onPressed: () {}));
      final border =
          firstDecorationUnder(tester, find.byKey(key)).border! as Border;
      expect(border.top.color, dark.lineStrong);

      await pumpHost(
        tester,
        button(variant: AppButtonVariant.danger, onPressed: () {}),
      );
      final danger =
          firstDecorationUnder(tester, find.byKey(key)).border! as Border;
      expect(danger.top.color, dark.negative.withValues(alpha: 0.45));
    });

    testWidgets('an icon-only button is a 28 px square named by its label', (
      tester,
    ) async {
      await pumpHost(
        tester,
        AppButton(
          key: key,
          label: 'Plus d’actions',
          icon: Icons.more_horiz,
          iconOnly: true,
          onPressed: () {},
        ),
      );
      expect(
        tester.getSize(find.byKey(key)),
        const Size.square(AppSizes.button),
      );
      expect(find.text('Plus d’actions'), findsNothing);
      expect(find.bySemanticsLabel('Plus d’actions'), findsOneWidget);
    });

    testWidgets('hover takes the hover ground at once', (tester) async {
      await pumpHost(tester, button(onPressed: () {}));
      await hover(tester, find.byKey(key));
      expect(groundOf(tester, key), dark.hover);
    });

    testWidgets('hover lightens the primary ink in dark', (tester) async {
      await pumpHost(
        tester,
        button(variant: AppButtonVariant.primary, onPressed: () {}),
      );
      await hover(tester, find.byKey(key));
      expect(groundOf(tester, key), isNot(dark.primary));
    });

    testWidgets('pressing calls back; disabled is 45 % and inert', (
      tester,
    ) async {
      var taps = 0;
      await pumpHost(tester, button(onPressed: () => taps++));
      await tester.tap(find.byKey(key));
      expect(taps, 1);
      expect(opacityAbove(tester, find.text('Enregistrer')), 1);

      await pumpHost(tester, button());
      await tester.tap(find.byKey(key));
      expect(taps, 1);
      expect(opacityAbove(tester, find.text('Enregistrer')), 0.45);
    });

    testWidgets('loading swaps the icon for a spinner, keeps the label and '
        'the width, and does not press', (tester) async {
      var taps = 0;
      await pumpHost(tester, button(icon: Icons.add, onPressed: () => taps++));
      final width = tester.getSize(find.byKey(key)).width;

      await pumpHost(
        tester,
        button(icon: Icons.add, loading: true, onPressed: () => taps++),
      );
      expect(find.byKey(const Key('appButtonSpinner')), findsOneWidget);
      expect(find.byIcon(Icons.add), findsNothing);
      expect(find.text('Enregistrer'), findsOneWidget);
      expect(tester.getSize(find.byKey(key)).width, width);
      await tester.tap(find.byKey(key));
      expect(taps, 0);
      // Loading is not disabled: the button keeps its colour.
      expect(opacityAbove(tester, find.text('Enregistrer')), 1);
    });

    testWidgets('keyboard focus draws the ring and Enter presses', (
      tester,
    ) async {
      var taps = 0;
      await pumpHost(tester, button(onPressed: () => taps++));
      expect(find.byType(CustomPaint).evaluate().length, isNonZero);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(tester.widget<FocusRing>(find.byType(FocusRing)).focused, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(taps, 1);
    });
  });

  group('AppSegmented', () {
    Widget segmented(String value, ValueChanged<String>? onChanged) =>
        AppSegmented<String>(
          segments: const [
            AppSegment(value: 'system', label: 'Système', key: Key('s')),
            AppSegment(value: 'dark', label: 'Sombre', key: Key('d')),
          ],
          value: value,
          onChanged: onChanged,
        );

    testWidgets('the selected segment sits on hover in text 500', (
      tester,
    ) async {
      await pumpHost(tester, segmented('dark', (_) {}));
      final on = tester.widget<Text>(find.text('Sombre'));
      final off = tester.widget<Text>(find.text('Système'));
      expect(on.style?.color, dark.text);
      expect(on.style?.fontWeight, FontWeight.w500);
      expect(off.style?.color, dark.textSecondary);
      expect(
        firstDecorationUnder(tester, find.byKey(const Key('d'))).color,
        dark.hover,
      );
    });

    testWidgets('the well is field with a lineStrong border, radius 6', (
      tester,
    ) async {
      await pumpHost(tester, segmented('dark', (_) {}));
      final well = firstDecorationUnder(
        tester,
        find.byType(AppSegmented<String>),
      );
      expect(well.color, dark.field);
      expect((well.border! as Border).top.color, dark.lineStrong);
      expect(well.borderRadius, BorderRadius.circular(AppRadii.control));
    });

    testWidgets('a tap selects; disabled is 45 % and inert', (tester) async {
      String? picked;
      await pumpHost(tester, segmented('dark', (v) => picked = v));
      await tester.tap(find.text('Système'));
      expect(picked, 'system');

      picked = null;
      await pumpHost(tester, segmented('dark', null));
      await tester.tap(find.text('Système'));
      expect(picked, isNull);
      expect(opacityAbove(tester, find.text('Système')), 0.45);
    });
  });

  group('AppTabs', () {
    testWidgets('the selected tab is text 500 over a 2 px text underline, '
        'a count follows in tertiary', (tester) async {
      int? picked;
      await pumpHost(
        tester,
        SizedBox(
          width: 400,
          child: AppTabs<int>(
            tabs: const [
              AppTab(value: 0, label: 'Toutes', count: '12'),
              AppTab(value: 1, label: 'À revoir'),
            ],
            value: 0,
            onChanged: (v) => picked = v,
          ),
        ),
      );
      expect(tester.getSize(find.byType(AppTabs<int>)).height, AppSizes.tab);

      final selected = decorationOf(
        tester,
        find
            .descendant(
              of: find.byKey(const Key('appTab-0')),
              matching: find.byType(Container),
            )
            .first,
      );
      final underline = (selected.border! as Border).bottom;
      expect(underline.color, dark.text);
      expect(underline.width, 2);
      final other = decorationOf(
        tester,
        find
            .descendant(
              of: find.byKey(const Key('appTab-1')),
              matching: find.byType(Container),
            )
            .first,
      );
      expect((other.border! as Border).bottom.color, Colors.transparent);

      final label = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const Key('appTab-0')),
          matching: find.byType(Text),
        ),
      );
      expect(label.style?.fontWeight, FontWeight.w500);
      final count = (label.textSpan! as TextSpan).children!.last as TextSpan;
      expect(count.text, ' 12');
      expect(count.style?.color, dark.textTertiary);

      await tester.tap(find.text('À revoir'));
      expect(picked, 1);
    });
  });

  group('AppToggle', () {
    testWidgets('28 × 16, accent on and lineStrong off, a bg knob', (
      tester,
    ) async {
      await pumpHost(tester, AppToggle(value: true, onChanged: (_) {}));
      const track = Key('appToggleTrack');
      expect(tester.getSize(find.byKey(track)), const Size(28, 16));
      expect(decorationOf(tester, find.byKey(track)).color, dark.accent);

      await pumpHost(tester, AppToggle(value: false, onChanged: (_) {}));
      expect(decorationOf(tester, find.byKey(track)).color, dark.lineStrong);
      final knob = find.descendant(
        of: find.byKey(track),
        matching: find.byType(Container),
      );
      expect(tester.getSize(knob.last), const Size.square(AppToggle.knob));
      expect(decorationOf(tester, knob.last).color, dark.bg);
    });

    testWidgets('a tap flips it; disabled is 45 % and inert', (tester) async {
      bool? next;
      await pumpHost(
        tester,
        AppToggle(value: false, onChanged: (v) => next = v),
      );
      await tester.tap(find.byType(AppToggle));
      expect(next, isTrue);

      next = null;
      await pumpHost(tester, const AppToggle(value: false, onChanged: null));
      await tester.tap(find.byType(AppToggle));
      expect(next, isNull);
      expect(
        opacityAbove(tester, find.byKey(const Key('appToggleTrack'))),
        0.45,
      );
    });
  });

  group('AppCheckbox', () {
    const box = Key('appCheckboxBox');

    testWidgets('unchecked: 14 px, lineStrong border, no check', (
      tester,
    ) async {
      await pumpHost(tester, AppCheckbox(value: false, onChanged: (_) {}));
      expect(tester.getSize(find.byKey(box)), const Size.square(14));
      final deco = decorationOf(tester, find.byKey(box));
      expect((deco.border! as Border).top.color, dark.lineStrong);
      expect(deco.borderRadius, BorderRadius.circular(AppRadii.item));
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('checked: accent fill, onAccent check', (tester) async {
      await pumpHost(tester, AppCheckbox(value: true, onChanged: (_) {}));
      expect(decorationOf(tester, find.byKey(box)).color, dark.accent);
      expect(tester.widget<Icon>(find.byType(Icon)).color, dark.onAccent);
    });

    testWidgets('a tap flips it; disabled is 45 % and inert', (tester) async {
      bool? next;
      await pumpHost(
        tester,
        AppCheckbox(value: true, onChanged: (v) => next = v),
      );
      await tester.tap(find.byKey(box));
      expect(next, isFalse);

      next = null;
      await pumpHost(tester, const AppCheckbox(value: true, onChanged: null));
      await tester.tap(find.byKey(box));
      expect(next, isNull);
      expect(opacityAbove(tester, find.byKey(box)), 0.45);
    });
  });

  group('AppSlider', () {
    testWidgets('drawn in the slider tokens; disabled is 45 %', (tester) async {
      await pumpHost(tester, AppSlider(value: 40, onChanged: (_) {}));
      final theme = SliderTheme.of(tester.element(find.byType(Slider)));
      expect(theme.activeTrackColor, dark.accent);
      expect(theme.inactiveTrackColor, dark.lineStrong);
      expect(theme.thumbColor, dark.text);
      expect(theme.trackHeight, 4);
      expect(opacityAbove(tester, find.byType(Slider)), 1);

      await pumpHost(tester, const AppSlider(value: 40, onChanged: null));
      expect(opacityAbove(tester, find.byType(Slider)), 0.45);
    });
  });

  group('AppSelect', () {
    Widget select({ValueChanged<int>? onChanged, bool toolbar = false}) {
      const items = [
        AppSelectItem(value: 1, label: 'Un'),
        AppSelectItem(value: 2, label: 'Deux'),
      ];
      return SizedBox(
        width: 240,
        child: toolbar
            ? AppSelect<int>.toolbar(
                key: const Key('select'),
                value: 1,
                items: items,
                onChanged: onChanged,
              )
            : AppSelect<int>(
                key: const Key('select'),
                value: 1,
                items: items,
                onChanged: onChanged,
              ),
      );
    }

    testWidgets('32 px in a form, 28 px in a toolbar', (tester) async {
      await pumpHost(tester, select(onChanged: (_) {}));
      expect(
        tester.getSize(find.byKey(const Key('select'))).height,
        AppSizes.formField,
      );
      await pumpHost(tester, select(onChanged: (_) {}, toolbar: true));
      expect(
        tester.getSize(find.byKey(const Key('select'))).height,
        AppSizes.toolbarSelect,
      );
    });

    testWidgets('open: a check marks the current choice; a pick calls back', (
      tester,
    ) async {
      int? picked;
      await pumpHost(tester, select(onChanged: (v) => picked = v));
      await tester.tap(find.byKey(const Key('select')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('appMenuItemCheck')), findsOneWidget);
      await tester.tap(find.text('Deux'));
      await tester.pumpAndSettle();
      expect(picked, 2);
    });

    testWidgets('disabled is 45 % and does not open', (tester) async {
      await pumpHost(tester, select());
      expect(opacityAbove(tester, find.text('Un')), 0.45);
      await tester.tap(find.byKey(const Key('select')));
      await tester.pumpAndSettle();
      expect(find.text('Deux'), findsNothing);
    });
  });

  group('AppSearchField', () {
    Widget field(ValueChanged<String> onChanged) => AppSearchField(
      key: const Key('search'),
      hint: 'Rechercher',
      onChanged: onChanged,
    );

    testWidgets('240 × 28 with the Ctrl K hint while empty', (tester) async {
      await pumpHost(tester, field((_) {}));
      expect(
        tester.getSize(find.byKey(const Key('search'))),
        const Size(AppSizes.searchField, AppSizes.toolbarSelect),
      );
      expect(find.text('Ctrl K'), findsOneWidget);
      expect(find.text('Rechercher'), findsOneWidget);
    });

    testWidgets('Ctrl K focuses the field from anywhere', (tester) async {
      await pumpHost(tester, field((_) {}));
      final editable = find.byType(EditableText);
      expect(tester.widget<EditableText>(editable).focusNode.hasFocus, isFalse);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(tester.widget<EditableText>(editable).focusNode.hasFocus, isTrue);
    });

    testWidgets('typing reports the query and offers a clear button', (
      tester,
    ) async {
      final queries = <String>[];
      await pumpHost(tester, field(queries.add));
      await tester.enterText(find.byType(TextField), 'loyer');
      await tester.pump();
      expect(queries.last, 'loyer');
      expect(find.text('Ctrl K'), findsNothing);
      await tester.tap(find.byKey(const Key('searchFieldClear')));
      await tester.pump();
      expect(queries.last, '');
      expect(find.text('Ctrl K'), findsOneWidget);
    });
  });

  testWidgets('controls follow the light theme', (tester) async {
    await pumpHost(
      tester,
      AppToggle(value: true, onChanged: (_) {}),
      theme: AppTheme.light,
    );
    expect(
      decorationOf(tester, find.byKey(const Key('appToggleTrack'))).color,
      AppColors.light.accent,
    );
  });
}
