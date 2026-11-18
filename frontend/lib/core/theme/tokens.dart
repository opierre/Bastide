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

  /// The hue of an asset in the Synthèse composition and the property nature
  /// pills, keyed by the backend account `type` or property `kind`. Reuses the
  /// slots (`00` §2.4); every other type or kind takes [cat0].
  Color forAccountType(String type) => switch (type) {
    'checking' => cat1,
    'savings' => cat3,
    _ => cat0,
  };

  Color forPropertyKind(String kind) => switch (kind) {
    'primary_residence' => cat2,
    'rental' => cat6,
    _ => cat0,
  };

  /// The plate of a preset user avatar, keyed by the backend preset key.
  Color forAvatarPreset(String preset, AppColors colors) => switch (preset) {
    'cyan' => cat1,
    'blue' => cat6,
    'teal' => cat3,
    'pink' => cat5,
    'amber' => cat4,
    'lime' => cat2,
    'green' => income,
    _ => colors.accent,
  };

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

  // v1 layout values, kept only so the panels compile until the shell (#201),
  // the shared widgets (#200) and each panel's v2 ticket replace them. Nothing
  // new reads these.

  /// v1: gap between a nav item's icon and its label.
  static const navGap = 11.0;

  /// v1: horizontal padding inside a nav pill.
  static const navInset = 13.0;

  /// v1: sidebar inner gutter.
  static const sidebarGutter = 12.0;

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

  /// v1: nav pill.
  static const navPill = 20.0;
}

/// Heights and widths of `00` §4 and §5. The shell (#201) and the shared
/// widgets (#200) build on these.
abstract final class AppSizes {
  static const titleBar = 48.0;
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

  /// Icons: 16 by default, 14 inside buttons, selects and notes, 13 in status
  /// text (`00` §10).
  static const icon = 16.0;
  static const iconSmall = 14.0;
  static const iconStatus = 13.0;
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

/// v1 fixed-chrome dimensions, kept until the shell is rebuilt (#201); the v2
/// values are in [AppSizes].
abstract final class AppChrome {
  static const sidebarWidth = 252.0;
  static const sidebarCollapsedWidth = 76.0;
  static const topBarHeight = 72.0;
  static const navItemHeight = 40.0;
  static const controlPillHeight = 38.0;
  static const userPillHeight = 44.0;
  static const buttonHeight = 38.0;
  static const navRailWidth = 3.0;
  static const navRailHeight = 22.0;
  static const navIconSize = 18.0;
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
