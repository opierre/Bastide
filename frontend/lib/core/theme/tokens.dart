import 'package:flutter/material.dart';

/// The v2 design tokens. Binding values come from
/// `docs/design/00-design-system.md`; that file is the source of truth and
/// this one transcribes it. A value that is not written there does not exist:
/// add it to the design system first, then here.
///
/// Colours are theme-dependent, so they are never read as constants: a widget
/// reads them from the active theme through [AppThemeContext] —
/// `context.colors.text`, `context.categoryColors.forSlot(…)`,
/// `context.textStyles.helper`. Switching the theme then rebuilds every widget
/// that read one, with no restart. Never write a hex in a widget; the colour
/// literal test fails on one.

/// Surfaces, lines, text, accent and meaning (`00` §2.1, §2.2), one set per
/// theme. Read with `context.colors`.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.bg,
    required this.rail,
    required this.surface,
    required this.field,
    required this.hover,
    required this.line,
    required this.lineStrong,
    required this.text,
    required this.textSecondary,
    required this.textTertiary,
    required this.scrim,
    required this.shadow,
    required this.accent,
    required this.onAccent,
    required this.accentSoft,
    required this.primary,
    required this.onPrimary,
    required this.positive,
    required this.negative,
    required this.warning,
    required this.tomette,
  });

  /// Window and content ground.
  final Color bg;

  /// Sidebar, inspector panes, group rows. The auth ground stays [bg].
  final Color rail;

  /// Popover, modal, toast, banner, button ground.
  final Color surface;

  /// Input and select wells.
  final Color field;

  /// Row and item hover, active nav item, segmented "on", monogram ground.
  final Color hover;

  /// Hairline between sections and rows.
  final Color line;

  /// Control borders, meter and slider track, dashed outlines.
  final Color lineStrong;

  /// Primary text and figures.
  final Color text;

  /// Labels, captions, secondary cells.
  final Color textSecondary;

  /// Column headers, notes, axis labels, placeholders, disabled.
  final Color textTertiary;

  /// Behind a modal.
  final Color scrim;

  /// Popover, modal and toast only (`00` §4, Elevation).
  final List<BoxShadow> shadow;

  /// Selection, links, focus, meter and slider fill, toggle on, checkbox on,
  /// chart line.
  final Color accent;

  /// Glyph on an [accent] fill.
  final Color onAccent;

  /// [accent] at 14 %: selected row, focus ring halo.
  final Color accentSoft;

  /// Primary button fill: the ink, equal to [text].
  final Color primary;

  /// Primary button label, equal to [bg].
  final Color onPrimary;

  /// Money in, goal reached, success.
  final Color positive;

  /// Money out, failure, destructive.
  final Color negative;

  /// Worth a look: price rise, missed charge, above a reference, stale value.
  final Color warning;

  /// Stroke of the tomettes texture (`00` §12): white at 7 % in dark, black
  /// at 7 % in light.
  final Color tomette;

  /// The reference theme and the default (`00` §1.7).
  static const dark = AppColors(
    bg: Color(0xFF111214),
    rail: Color(0xFF0C0D0F),
    surface: Color(0xFF191A1D),
    field: Color(0xFF17181B),
    hover: Color(0xFF1F2125),
    line: Color(0xFF25272B),
    lineStrong: Color(0xFF35383E),
    text: Color(0xFFECEDEF),
    textSecondary: Color(0xFFA3A7AE),
    textTertiary: Color(0xFF8A8E96),
    scrim: Color(0x8C000000),
    shadow: [
      BoxShadow(
        color: Color(0x80000000),
        blurRadius: 32,
        offset: Offset(0, 12),
      ),
      BoxShadow(color: Color(0x66000000), blurRadius: 6, offset: Offset(0, 2)),
    ],
    accent: Color(0xFF7FA6FF),
    onAccent: Color(0xFF111214),
    accentSoft: Color(0x247FA6FF),
    primary: Color(0xFFECEDEF),
    onPrimary: Color(0xFF111214),
    positive: Color(0xFF4CC38A),
    negative: Color(0xFFF2777A),
    warning: Color(0xFFE0A44A),
    tomette: Color(0x12FFFFFF),
  );

  /// Complete in its own right, not derived by inversion (`00` §1.7).
  static const light = AppColors(
    bg: Color(0xFFFFFFFF),
    rail: Color(0xFFF6F6F7),
    surface: Color(0xFFFFFFFF),
    field: Color(0xFFFFFFFF),
    hover: Color(0xFFF0F1F2),
    line: Color(0xFFE6E7E9),
    lineStrong: Color(0xFFD0D2D6),
    text: Color(0xFF17181A),
    textSecondary: Color(0xFF5A5E65),
    textTertiary: Color(0xFF666A71),
    scrim: Color(0x5217181A),
    shadow: [
      BoxShadow(
        color: Color(0x2414161A),
        blurRadius: 32,
        offset: Offset(0, 12),
      ),
      BoxShadow(color: Color(0x1414161A), blurRadius: 6, offset: Offset(0, 2)),
    ],
    accent: Color(0xFF2B5CD0),
    onAccent: Color(0xFFFFFFFF),
    accentSoft: Color(0x242B5CD0),
    primary: Color(0xFF17181A),
    onPrimary: Color(0xFFFFFFFF),
    positive: Color(0xFF18794E),
    negative: Color(0xFFC4292E),
    warning: Color(0xFF8F5F00),
    tomette: Color(0x12000000),
  );

  /// The active theme's colours. Prefer `context.colors`.
  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>() ?? dark;

  @override
  AppColors copyWith({
    Color? bg,
    Color? rail,
    Color? surface,
    Color? field,
    Color? hover,
    Color? line,
    Color? lineStrong,
    Color? text,
    Color? textSecondary,
    Color? textTertiary,
    Color? scrim,
    List<BoxShadow>? shadow,
    Color? accent,
    Color? onAccent,
    Color? accentSoft,
    Color? primary,
    Color? onPrimary,
    Color? positive,
    Color? negative,
    Color? warning,
    Color? tomette,
  }) => AppColors(
    bg: bg ?? this.bg,
    rail: rail ?? this.rail,
    surface: surface ?? this.surface,
    field: field ?? this.field,
    hover: hover ?? this.hover,
    line: line ?? this.line,
    lineStrong: lineStrong ?? this.lineStrong,
    text: text ?? this.text,
    textSecondary: textSecondary ?? this.textSecondary,
    textTertiary: textTertiary ?? this.textTertiary,
    scrim: scrim ?? this.scrim,
    shadow: shadow ?? this.shadow,
    accent: accent ?? this.accent,
    onAccent: onAccent ?? this.onAccent,
    accentSoft: accentSoft ?? this.accentSoft,
    primary: primary ?? this.primary,
    onPrimary: onPrimary ?? this.onPrimary,
    positive: positive ?? this.positive,
    negative: negative ?? this.negative,
    warning: warning ?? this.warning,
    tomette: tomette ?? this.tomette,
  );

  /// Switching themes is instant (`00` §13), so there is nothing to
  /// interpolate: the target theme's colours apply at once.
  @override
  AppColors lerp(AppColors? other, double t) =>
      other == null || t < 0.5 ? this : other;
}

/// The category slots of `00` §2.4. A category stores its slot, never a hex;
/// the theme resolves it to a colour. A custom category picks one of
/// [cat1]–[cat6] or [cat0]. [income] is Revenus, drawn in `positive`.
enum CategorySlot {
  cat0,
  cat1,
  cat2,
  cat3,
  cat4,
  cat5,
  cat6,
  income;

  /// The slot a stored value names, [cat0] for anything else.
  static CategorySlot fromWire(String? value) => switch (value) {
    'cat1' => cat1,
    'cat2' => cat2,
    'cat3' => cat3,
    'cat4' => cat4,
    'cat5' => cat5,
    'cat6' => cat6,
    'income' => income,
    _ => cat0,
  };

  /// What the API stores.
  String get wire => name;

  /// The slots a custom category may pick, in the design system's order.
  static const pickable = [cat1, cat2, cat3, cat4, cat5, cat6, cat0];
}

/// The category palette of `00` §2.4, one set per theme. Read with
/// `context.categoryColors`. Category hues are marks (dots, bars), never text
/// colour; the net-worth composition reuses the slots in order.
@immutable
class CategoryColors extends ThemeExtension<CategoryColors> {
  const CategoryColors({
    required this.cat0,
    required this.cat1,
    required this.cat2,
    required this.cat3,
    required this.cat4,
    required this.cat5,
    required this.cat6,
    required this.income,
  });

  /// Autres, Épargne, any custom category without a hue.
  final Color cat0;

  /// Logement.
  final Color cat1;

  /// Alimentation.
  final Color cat2;

  /// Transport.
  final Color cat3;

  /// Abonnements.
  final Color cat4;

  /// Loisirs.
  final Color cat5;

  /// Santé.
  final Color cat6;

  /// Revenus, equal to the theme's `positive`.
  final Color income;

  static final dark = CategoryColors(
    cat0: const Color(0xFF6B7078),
    cat1: const Color(0xFF3987E5),
    cat2: const Color(0xFFD95926),
    cat3: const Color(0xFF199E70),
    cat4: const Color(0xFFC98500),
    cat5: const Color(0xFFD55181),
    cat6: const Color(0xFF9085E9),
    income: AppColors.dark.positive,
  );

  static final light = CategoryColors(
    cat0: const Color(0xFF9A9EA6),
    cat1: const Color(0xFF2A78D6),
    cat2: const Color(0xFFEB6834),
    cat3: const Color(0xFF1BAF7A),
    cat4: const Color(0xFFEDA100),
    cat5: const Color(0xFFE87BA4),
    cat6: const Color(0xFF6250D6),
    income: AppColors.light.positive,
  );

  /// The active theme's category colours. Prefer `context.categoryColors`.
  static CategoryColors of(BuildContext context) =>
      Theme.of(context).extension<CategoryColors>() ?? dark;

  Color forSlot(CategorySlot slot) => switch (slot) {
    CategorySlot.cat0 => cat0,
    CategorySlot.cat1 => cat1,
    CategorySlot.cat2 => cat2,
    CategorySlot.cat3 => cat3,
    CategorySlot.cat4 => cat4,
    CategorySlot.cat5 => cat5,
    CategorySlot.cat6 => cat6,
    CategorySlot.income => income,
  };

  /// The slot of a system category bucket, keyed by its slug
  /// (`core/l10n/category_display.dart`). Every other slug is [cat0].
  static CategorySlot slotForSlug(String? slug) => switch (slug) {
    'logement' => CategorySlot.cat1,
    'alimentation' => CategorySlot.cat2,
    'transport' => CategorySlot.cat3,
    'abonnements' => CategorySlot.cat4,
    'loisirs' => CategorySlot.cat5,
    'sante' => CategorySlot.cat6,
    'revenus' => CategorySlot.income,
    _ => CategorySlot.cat0,
  };

  Color forSlug(String? slug) => forSlot(slotForSlug(slug));

  /// The colour of the [index]-th segment of a composition bar: [cat1]
  /// onward in rank order, [cat0] once the six hues run out (`00` §9).
  Color forRank(int index) =>
      index < 6 ? forSlot(CategorySlot.values[index + 1]) : cat0;

  @override
  CategoryColors copyWith({
    Color? cat0,
    Color? cat1,
    Color? cat2,
    Color? cat3,
    Color? cat4,
    Color? cat5,
    Color? cat6,
    Color? income,
  }) => CategoryColors(
    cat0: cat0 ?? this.cat0,
    cat1: cat1 ?? this.cat1,
    cat2: cat2 ?? this.cat2,
    cat3: cat3 ?? this.cat3,
    cat4: cat4 ?? this.cat4,
    cat5: cat5 ?? this.cat5,
    cat6: cat6 ?? this.cat6,
    income: income ?? this.income,
  );

  @override
  CategoryColors lerp(CategoryColors? other, double t) =>
      other == null || t < 0.5 ? this : other;
}

/// Spacing (`00` §4). The v2 ramp is 2, 4, 6, 8, 12, 16, 24, 32, 40.
abstract final class AppSpacing {
  static const xxs = 2.0;
  static const xs = 4.0;
  static const xsPlus = 6.0;
  static const sm = 8.0;
  static const smPlus = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 40.0;

  /// Between sections of a page.
  static const section = lg;

  /// Page margin: 32 horizontal, 24 vertical.
  static const pageX = xl;
  static const pageY = lg;

  /// Two-column gutter.
  static const gutter = xxl;

  /// Shell (`00` §5): gap between a nav item's icon and its label.
  static const navIconGap = 9.0;

  /// Shell (`00` §5): space under the brand row and above a group label.
  static const sidebarBrandBottom = 14.0;
  static const sidebarLabelTop = 14.0;

  /// Drop target (`00` §7): padding 18 vertical, 20 horizontal.
  static const dropTargetY = 18.0;
  static const dropTargetX = 20.0;

  /// Fields 14 px apart: in a modal (`00` §7) and down the auth column
  /// (`02-login.md`, `03-register.md`).
  static const fieldGap = 14.0;

  // v1 layout values, kept only so the panels compile until each panel's v2
  // ticket replaces them. Nothing new reads these.

  /// v1: gap between cards in a grid.
  static const gridGap = 18.0;

  /// v1: card padding.
  static const cardPadding = 20.0;
  static const cardPaddingWide = 24.0;

  /// v1: content region padding, 24 × 28.
  static const contentX = 28.0;
  static const contentY = 24.0;

  /// v1: panels that open with a filter bar.
  static const contentTopFiltered = 20.0;
}

/// Corner radii (`00` §4).
abstract final class AppRadii {
  /// Meter and bar ends.
  static const bar = 2.0;

  /// Items inside a control or popover, checkboxes.
  static const xs = 4.0;
  static const item = xs;

  /// Monogram, 22 px and 32 px.
  static const monogramSmall = 5.0;
  static const monogramLarge = 7.0;

  /// Controls: buttons, fields, nav items, segmented, tabs' focus.
  static const control = 6.0;

  /// Containers: banner, popover, toast, drop target, account-type header.
  static const sm = 8.0;
  static const container = sm;

  /// Modals.
  static const md = 12.0;
  static const modal = md;

  /// Avatars and toggles.
  static const pill = 999.0;
  static const full = pill;

  // v1 radii, kept only until #200 and the panels' v2 tickets replace them.

  /// v1: monogram.
  static const monogram = 9.0;

  /// v1: toasts and inset plates.
  static const inset = 14.0;

  /// v1: card.
  static const lg = 16.0;

  /// v1: modal, glyph plate.
  static const xl = 20.0;
}

/// Heights and widths of `00` §4 and §5. The shell (#201) and the shared
/// widgets (#200) build on these.
abstract final class AppSizes {
  static const titleBar = 48.0;

  /// A window control (Réduire, Agrandir, Fermer): 46 wide, as tall as the
  /// title bar (`00` §5).
  static const windowControl = 46.0;

  /// macOS: the system's three window buttons, 16 px from the window's left
  /// edge, span 52 px; the brand row starts 14 px after them (`00` §5).
  static const macWindowButtonsInset = 16.0;
  static const macWindowButtons = 52.0;
  static const macBrandAfterButtons = 14.0;

  static const navItem = 30.0;
  static const button = 28.0;
  static const buttonLarge = 36.0;
  static const toolbarSelect = 28.0;
  static const formField = 32.0;
  static const tableRow = 36.0;
  static const tableRowTwoLines = 48.0;
  static const groupRow = 30.0;
  static const tab = 40.0;
  static const popoverItem = 28.0;
  static const sidebar = 224.0;
  static const sidebarCollapsed = 56.0;
  static const inspector = 440.0;
  static const searchField = 240.0;

  /// The single form column of the auth screens (`02-login.md`).
  static const authColumn = 320.0;

  /// Icons: 16 by default, 14 inside buttons, selects and notes, 13 in status
  /// text (`00` §10).
  static const icon = 16.0;
  static const iconSmall = 14.0;
  static const iconStatus = 13.0;

  /// The user's avatar in the sidebar foot (`00` §5).
  static const avatarSmall = 22.0;
}

/// The legacy elevation of Material menus. A [MenuStyle] takes an elevation,
/// not a [BoxShadow]; the v2 `shadow` token is painted wherever a widget can
/// draw its own box.
abstract final class AppShadows {
  static const popoverElevation = 12.0;
}

/// Timings (`00` §13). Hover and pressed states change at once, so there is no
/// duration for them.
abstract final class AppMotion {
  /// Popover, menu, modal, toast and inspector content, ease-out.
  static const overlay = Duration(milliseconds: 120);

  /// A meter's fill when its value changes, ease-out, once.
  static const meter = Duration(milliseconds: 240);

  /// Loading silhouette pulse.
  static const shimmer = Duration(milliseconds: 1600);
}

abstract final class AppFonts {
  /// The one UI family, at 400, 500 and 600.
  static const geist = 'Geist';

  /// Raw bank labels, rule patterns, file names, file paths and URLs only.
  static const mono = 'Geist Mono';
}

/// The modal frame of `00` §7 « Modal ».
abstract final class AppModalSizes {
  /// The widths a modal may take; each panel spec names its own.
  static const w420 = 420.0;
  static const w440 = 440.0;
  static const w480 = 480.0;
  static const w500 = 500.0;
  static const w520 = 520.0;
  static const w560 = 560.0;
  static const w600 = 600.0;
  static const w620 = 620.0;
  static const widths = [w420, w440, w480, w500, w520, w560, w600, w620];

  /// Between the frame and the window edge, above, below and on the sides.
  static const windowInset = AppSpacing.lg;

  /// The frame's padding: header 24 24 14, body 0 24, footer 24.
  static const padding = AppSpacing.lg;
  static const headerBottom = AppSpacing.fieldGap;

  /// Between the title and the lead.
  static const leadGap = AppSpacing.xs;

  /// Between a scrolling body's content and the hairline above or below it.
  static const scrollEdge = AppSpacing.fieldGap;

  /// The gutter of a two-column row of fields.
  static const columnGutter = AppSpacing.md;

  /// The crop variant: a square window, the zoom range of its slider.
  static const cropSquare = 320.0;
  static const cropMinZoom = 1.0;
  static const cropMaxZoom = 5.0;

  /// The zoom variant: the picture alone.
  static const zoomPicture = 240.0;
}

/// The avatar crop's circle (`00` §7 « Modal », Crop). It sits on the
/// photo, not on the theme, so it keeps these colours in both themes.
abstract final class AppCropGuide {
  /// 1 px white at 80 %.
  static const ring = Color(0xCCFFFFFF);

  /// 1 px black at 30 %, outside the white ring.
  static const ringShadow = Color(0x4D000000);

  static const width = 1.0;
}

/// The goal banner of `docs/design/11-goals.md` §Inspector pane: the
/// picture (or tomettes) edge to edge at the top of the inspector, and the
/// thumbnail the table shows of it.
abstract final class AppGoalBanner {
  /// With an image.
  static const height = 190.0;

  /// Without an image: tomettes on `rail`.
  static const heightEmpty = 120.0;

  /// The bottom fade under the title, over the picture.
  static const fadeHeight = 100.0;

  /// The fade's bottom colour, `rgba(12,14,24,.82)`. Fixed in both themes
  /// because it sits on the picture, as do the two text colours below.
  static const fade = Color(0xD10C0E18);

  /// The name and the percent over the fade.
  static const title = Color(0xFFFFFFFF);

  /// The deadline line over the fade.
  static const caption = Color(0xFFD9DCE6);

  /// Top padding of the inspector content under the banner (18 24 24).
  static const contentTop = 18.0;

  /// The table thumbnail, radius `AppRadii.item`.
  static const thumbWidth = 36.0;
  static const thumbHeight = 24.0;

  /// The picture's proportions, also the crop step's (44:19).
  static const aspectRatio = 44 / 19;
}

/// The account-type section of `docs/design/05-accounts.md` §Section: a
/// header bar (radius `AppRadii.container`, `rail` ground) over its table.
abstract final class AppAccountSection {
  /// The header bar's padding: 10 vertical, 12 horizontal.
  static const headerPaddingY = 10.0;
  static const headerPaddingX = AppSpacing.smPlus;

  /// Between the header bar and its table.
  static const tableGap = 10.0;

  /// The right-aligned slot the subtotal sits in.
  static const subtotalWidth = 120.0;
}

/// The Crédits panel of `docs/design/12-credits.md`.
abstract final class AppLoans {
  /// The debt ratio item of the summary line.
  static const ratioWidth = 360.0;

  /// The repère's fixed scale, in basis points: 0–60 % (`00` §8), so the
  /// 35 % mark sits at the same x in every state.
  static const ratioScaleBps = 6000;

  /// The amortisation table's dense rows.
  static const scheduleRow = 28.0;

  /// The select listing every year of the schedule: a four-digit year and
  /// its chevron.
  static const yearSelectWidth = 96.0;

  /// The « Remboursé » column takes 22 % of the loans table's width: its
  /// flex against the other columns' 78 shares.
  static const repaidFlex = 22;

  /// The loan form's « Mensualité calculée » line (`proposal_v6` m-loans):
  /// 4 px more than the field gap above it, 10 px between its label and
  /// the figures, on one baseline.
  static const instalmentLineTop = AppSpacing.xs;
  static const instalmentLabelGap = 10.0;
}

/// The Synthèse panel of `docs/design/15-synthese.md` §Layout.
abstract final class AppNetworth {
  /// The equation line: its items and operators sit 28 px apart.
  static const equationGap = 28.0;

  /// Block 3: « Composition de l’actif » is 440 px wide, then a 48 px
  /// gutter before « Patrimoine net ».
  static const compositionWidth = 440.0;
  static const compositionGutter = 48.0;

  /// The series chart's height, axis included (mockup `#panel=networth`).
  static const chartHeight = 230.0;

  /// Column widths of the composition table: the share and the amount.
  static const shareColumn = 72.0;
  static const amountColumn = 140.0;

  /// Column widths of the properties table: the share, the held value and
  /// the row menu.
  static const propertyShareColumn = 96.0;
  static const propertyValueColumn = 140.0;
  static const menuColumn = AppSizes.button + AppSpacing.smPlus;

  /// « Historique déclaré » (mockup `#panel=m-networth`): the month field of
  /// the entry row, then the month and icon-button columns of the list.
  static const declaredMonthField = 130.0;
  static const declaredMonthColumn = 100.0;
  static const declaredActionsColumn = 72.0;
}

/// The Placements panel of `docs/design/17-placements.md`.
abstract final class AppPlacements {
  /// The list pane's blocks sit 20 px apart (§List pane).
  static const listGap = 20.0;

  /// The inspector chart's height, axis included (§Inspector pane 5).
  static const chartHeight = 170.0;

  /// Column widths of the investments table; « Placement » takes the rest.
  static const netPaymentsColumn = 112.0;
  static const valueColumn = 112.0;
  static const gainColumn = 160.0;
  static const valuedOnColumn = 108.0;

  /// Column widths of the movements table; the label takes the rest.
  static const historyDateColumn = 96.0;
  static const historyAmountColumn = 116.0;
}

/// The Catégories et règles panel of `docs/design/08-categories-rules.md`.
abstract final class AppCategoriesPanel {
  /// The category tree on the left, with its right hairline.
  static const treeWidth = 340.0;

  /// A subcategory's indent in the tree: past the chevron, the dot and the
  /// icon of its parent.
  static const subcategoryIndent = 52.0;

  /// The rules table's « Ordre » column: the grip and the position.
  static const orderColumn = 60.0;

  /// The « Correspondances » and « Active » columns.
  static const matchesColumn = 120.0;
  static const activeColumn = 56.0;

  /// The rule editor, the category form and the rule pack modals.
  static const ruleEditorWidth = 520.0;
  static const categoryFormWidth = 480.0;
  static const packModalWidth = 560.0;

  /// A cell of the category form's icon grid, and a colour square.
  static const iconCell = 32.0;
  static const colorSquare = 20.0;
}

/// The Transactions panel of `docs/design/07-transactions.md`.
abstract final class AppTransactions {
  /// The filter row: padding 12 32, controls 8 px apart.
  static const filterRowY = AppSpacing.smPlus;

  /// The pager: padding 10 32.
  static const pagerY = 10.0;

  /// The width a toolbar select of the filter row may grow to.
  static const filterMaxWidth = 220.0;

  /// The table's « Catégorie » and « Montant » columns.
  static const categoryColumn = 240.0;
  static const amountColumn = 128.0;

  /// The category picker popover, its list's height, and the inspector's
  /// 28 px category select.
  static const pickerWidth = 230.0;
  static const pickerListHeight = 280.0;

  /// The period modal and the rule modal.
  static const periodModalWidth = 420.0;
  static const ruleModalWidth = 520.0;

  /// The review tab: the progress block of its first row, the Note beside
  /// it, and the table's columns (date, proposal, actions, amount).
  static const progressWidth = 260.0;
  static const noteMaxWidth = 420.0;
  static const reviewDateColumn = 88.0;
  static const reviewActionsColumn = 380.0;
}

/// v1: the 38 px control pill some panels still put in the title bar, kept
/// until each panel's v2 ticket moves it to the 28 px controls of [AppSizes].
abstract final class AppChrome {
  static const controlPillHeight = 38.0;
}

/// The one chart frame (`00` §9). Colours come from the theme: gridlines in
/// `line`, the zero line in `lineStrong`, the series in `accent`.
abstract final class AppChart {
  /// Width left of the plot for the value axis.
  static const valueGutter = 56.0;

  /// Height beneath the plot for the category axis.
  static const axisHeight = 22.0;

  /// Clear space between a value label and the plot it names.
  static const labelGap = AppSpacing.sm;

  static const gridStroke = 1.0;

  /// The series line, round-joined.
  static const lineStroke = 2.0;

  /// The area under a line, in the line's own hue.
  static const areaAlpha = 0.10;

  /// The area under zero when a series crosses it.
  static const negativeAreaAlpha = 0.10;

  /// A dot on every point while there are at most [dotCeiling] of them.
  static const pointDotRadius = 3.0;

  /// The dot on the last point and on the hovered one.
  static const currentDotRadius = 4.0;

  /// The `bg` ring around a dot.
  static const dotRing = 2.0;

  /// How far the largest dot reaches past its point: the plot's inset, so an
  /// extreme point isn't clipped, and what a hover card keeps clear of.
  static const dotReach = currentDotRadius + dotRing;

  static const dotCeiling = 24;

  /// Dashed annotation lines, 5 on / 4 off.
  static const dash = 5.0;
  static const dashGap = 4.0;

  static const baselineStroke = 1.0;

  /// Hatching, for what is not yet a fact: 45° lines of [hatchStroke] on a
  /// [hatchPitch] pitch, inside a [hatchOutline] outline.
  static const hatchStroke = 1.5;
  static const hatchPitch = 5.0;
  static const hatchOutline = 1.0;

  /// Bars by sign: at most this wide, radius [barRadius] on the outer end.
  static const barMaxWidth = 18.0;
  static const barRadius = 3.0;

  /// Stacked bars: the gap between two segments, radius [stackRadius] on top.
  static const stackGap = 2.0;
  static const stackRadius = 2.0;

  /// Composition bar: 8 px high, segments 2 px apart, radius
  /// [AppRadii.bar].
  static const compositionBarHeight = 8.0;
  static const compositionBarGap = 2.0;

  /// The second series under a line: a thinner step line, no area.
  static const secondLineStroke = 1.5;

  /// The guide under a step line's change of value: `warning` at this alpha.
  static const changeGuideAlpha = 0.35;
}

/// Theme lookups for widgets: `context.colors`, `context.categoryColors`,
/// `context.textStyles`.
extension AppThemeContext on BuildContext {
  AppColors get colors => AppColors.of(this);
  CategoryColors get categoryColors => CategoryColors.of(this);
  AppTextStyles get textStyles => AppTextStyles.of(this);
}

/// Styles the [TextTheme] slots can't carry, coloured for the active theme.
/// Read with `context.textStyles`.
@immutable
class AppTextStyles extends ThemeExtension<AppTextStyles> {
  const AppTextStyles({
    required this.sectionLabel,
    required this.statLabel,
    required this.helper,
    required this.mono,
    required this.reviewNoProposal,
  });

  factory AppTextStyles.from(AppColors colors) => AppTextStyles(
    sectionLabel: TextStyle(
      fontFamily: AppFonts.geist,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.45,
      color: colors.textTertiary,
    ),
    statLabel: TextStyle(
      fontFamily: AppFonts.geist,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.45,
      color: colors.textSecondary,
    ),
    helper: TextStyle(
      fontFamily: AppFonts.geist,
      fontSize: 11,
      fontWeight: FontWeight.w400,
      height: 1.45,
      color: colors.textTertiary,
    ),
    mono: TextStyle(
      fontFamily: AppFonts.mono,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.45,
      color: colors.textSecondary,
    ),
    reviewNoProposal: TextStyle(
      fontFamily: AppFonts.geist,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.45,
      color: colors.textTertiary,
    ),
  );

  /// Group label: 12/400 `textTertiary`, sentence case (`00` §5).
  final TextStyle sectionLabel;

  /// The label above a figure of a summary line: 12 `textSecondary`.
  final TextStyle statLabel;

  /// Field helper and notes: 11 `textTertiary`.
  final TextStyle helper;

  /// Geist Mono 12, for raw bank labels, rule patterns and file names.
  final TextStyle mono;

  /// A review row the model had nothing for.
  final TextStyle reviewNoProposal;

  static AppTextStyles of(BuildContext context) =>
      Theme.of(context).extension<AppTextStyles>() ??
      AppTextStyles.from(AppColors.dark);

  @override
  AppTextStyles copyWith({
    TextStyle? sectionLabel,
    TextStyle? statLabel,
    TextStyle? helper,
    TextStyle? mono,
    TextStyle? reviewNoProposal,
  }) => AppTextStyles(
    sectionLabel: sectionLabel ?? this.sectionLabel,
    statLabel: statLabel ?? this.statLabel,
    helper: helper ?? this.helper,
    mono: mono ?? this.mono,
    reviewNoProposal: reviewNoProposal ?? this.reviewNoProposal,
  );

  @override
  AppTextStyles lerp(AppTextStyles? other, double t) =>
      other == null || t < 0.5 ? this : other;
}
