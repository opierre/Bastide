import 'package:flutter/material.dart';

import 'tokens.dart';

final ThemeData appDarkTheme = _buildDarkTheme();

ThemeData _buildDarkTheme() {
  const colorScheme = ColorScheme.dark(
    surface: AppColors.surfaceBase,
    onSurface: AppColors.textPrimary,
    onSurfaceVariant: AppColors.textSecondary,
    surfaceContainerLowest: AppColors.surfaceSunken,
    surfaceContainerLow: AppColors.surfaceBase,
    surfaceContainer: AppColors.surfaceRaised,
    surfaceContainerHigh: AppColors.surfaceOverlay,
    surfaceContainerHighest: AppColors.surfaceHover,
    primary: AppColors.iris,
    onPrimary: AppColors.irisInk,
    primaryContainer: AppColors.irisDeep,
    onPrimaryContainer: AppColors.irisInk,
    secondary: AppColors.cyan,
    onSecondary: AppColors.surfaceSunken,
    tertiary: AppColors.info,
    onTertiary: AppColors.surfaceSunken,
    error: AppColors.negative,
    onError: AppColors.surfaceSunken,
    outline: AppColors.border,
    outlineVariant: AppColors.borderSubtle,
  );

  final textTheme = _appTextTheme();

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.surfaceBase,
    canvasColor: AppColors.surfaceOverlay,
    fontFamily: AppFonts.manrope,
    textTheme: textTheme,
    // Desktop-first: tighter than Material's touch defaults. The spec allows no
    // data-view animation, so the ripple is suppressed in favour of the instant
    // hover fills each component defines itself.
    visualDensity: VisualDensity.compact,
    splashFactory: NoSplash.splashFactory,
    focusColor: AppColors.focusRing,
    hoverColor: AppColors.overlayWash,
    dividerColor: AppColors.border,

    cardTheme: const CardThemeData(
      color: AppColors.surfaceRaised,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadii.lg)),
        side: BorderSide(color: AppColors.borderCard),
      ),
    ),

    dividerTheme: const DividerThemeData(
      color: AppColors.borderSubtle,
      thickness: 1,
      space: 1,
    ),

    inputDecorationTheme: _inputDecorationTheme(textTheme),
    filledButtonTheme: FilledButtonThemeData(style: _filledButtonStyle(textTheme)),
    outlinedButtonTheme: OutlinedButtonThemeData(style: _outlinedButtonStyle(textTheme)),
    textButtonTheme: TextButtonThemeData(style: _textButtonStyle(textTheme)),

    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        foregroundColor: const WidgetStatePropertyAll(AppColors.textSecondary),
        overlayColor: const WidgetStatePropertyAll(AppColors.overlayWash),
        shape: const WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(AppRadii.sm)),
          ),
        ),
      ),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surfaceOverlay,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: textTheme.headlineMedium,
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadii.xl)),
        side: BorderSide(color: AppColors.border),
      ),
      barrierColor: AppColors.scrim,
    ),

    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.surfaceOverlay,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      textStyle: textTheme.bodyMedium,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadii.md)),
        side: BorderSide(color: AppColors.border),
      ),
    ),

    menuTheme: const MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(AppColors.surfaceOverlay),
        surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
        elevation: WidgetStatePropertyAll(0),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(AppRadii.md)),
            side: BorderSide(color: AppColors.border),
          ),
        ),
      ),
    ),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.surfaceOverlay,
      contentTextStyle: textTheme.bodyMedium,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadii.inset)),
        side: BorderSide(color: AppColors.border),
      ),
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
    ),

    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: AppColors.surfaceOverlay,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.border),
      ),
      textStyle: textTheme.bodySmall,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + AppSpacing.xs,
        vertical: AppSpacing.sm,
      ),
      waitDuration: const Duration(milliseconds: 500),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surfaceOverlay,
      side: const BorderSide(color: AppColors.border),
      labelStyle: textTheme.labelSmall,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadii.pill)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.iris,
      linearTrackColor: AppColors.surfaceHover,
      circularTrackColor: Colors.transparent,
      strokeCap: StrokeCap.round,
    ),

    scrollbarTheme: ScrollbarThemeData(
      thumbColor: const WidgetStatePropertyAll(AppColors.border),
      thickness: const WidgetStatePropertyAll(6),
      radius: const Radius.circular(AppRadii.pill),
      crossAxisMargin: 2,
    ),
  );
}

InputDecorationTheme _inputDecorationTheme(TextTheme textTheme) {
  OutlineInputBorder border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadii.md),
    borderSide: BorderSide(color: color),
  );

  return InputDecorationTheme(
    filled: true,
    fillColor: AppColors.surfaceField,
    isDense: true,
    // 13.5px at height 1.5 plus 12 top/bottom lands the field at the spec's
    // 42–44px without pinning an explicit height (which would clip helper text).
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm + AppSpacing.xs,
      vertical: AppSpacing.sm + AppSpacing.xs,
    ),
    // Labels sit above the field rather than floating inside it: French labels
    // run 15–20% longer than English and clip badly when squeezed into a notch.
    floatingLabelBehavior: FloatingLabelBehavior.never,
    labelStyle: textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
    hintStyle: textTheme.bodyLarge?.copyWith(color: AppColors.textDisabled),
    errorStyle: AppTextStyles.helper.copyWith(color: AppColors.negative),
    prefixIconColor: AppColors.textSecondary,
    suffixIconColor: AppColors.textSecondary,
    border: border(AppColors.border),
    enabledBorder: border(AppColors.border),
    disabledBorder: border(AppColors.borderSubtle),
    // The spec pairs the 1px iris border with a 3px outer glow; the glow is
    // painted by FocusGlow, since InputBorder can only draw the border itself.
    focusedBorder: border(AppColors.focusRing),
    errorBorder: border(const Color(0x8CFF5C6C)),
    focusedErrorBorder: border(AppColors.negative),
  );
}

/// Fallback solid-iris style. The spec's primary button is an iris *gradient*
/// with a glow, which [ButtonStyle] cannot express — [PrimaryButton] paints it.
/// This keeps any stray [FilledButton] on-palette rather than on Material's.
ButtonStyle _filledButtonStyle(TextTheme textTheme) => ButtonStyle(
  backgroundColor: WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.disabled)) return AppColors.surfaceHover;
    if (states.contains(WidgetState.pressed)) return AppColors.irisDeep;
    return AppColors.iris;
  }),
  foregroundColor: WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.disabled)) return AppColors.textDisabled;
    return AppColors.irisInk;
  }),
  overlayColor: const WidgetStatePropertyAll(Color(0x14000000)),
  textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
  elevation: const WidgetStatePropertyAll(0),
  padding: const WidgetStatePropertyAll(
    EdgeInsets.symmetric(horizontal: AppSpacing.md + AppSpacing.xs, vertical: 12),
  ),
  shape: const WidgetStatePropertyAll(
    RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppRadii.md)),
    ),
  ),
  iconSize: const WidgetStatePropertyAll(AppChrome.navIconSize),
);

ButtonStyle _outlinedButtonStyle(TextTheme textTheme) => ButtonStyle(
  foregroundColor: WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.disabled)) return AppColors.textDisabled;
    return AppColors.textPrimary;
  }),
  backgroundColor: WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.hovered)) return AppColors.surfaceHover;
    return Colors.transparent;
  }),
  side: WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.disabled)) {
      return const BorderSide(color: AppColors.borderSubtle);
    }
    return const BorderSide(color: AppColors.border);
  }),
  textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
  padding: const WidgetStatePropertyAll(
    EdgeInsets.symmetric(horizontal: AppSpacing.md + AppSpacing.xs, vertical: 12),
  ),
  shape: const WidgetStatePropertyAll(
    RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppRadii.md)),
    ),
  ),
  iconSize: const WidgetStatePropertyAll(AppChrome.navIconSize),
);

ButtonStyle _textButtonStyle(TextTheme textTheme) => ButtonStyle(
  foregroundColor: WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.disabled)) return AppColors.textDisabled;
    if (states.contains(WidgetState.hovered)) return AppColors.iris;
    return AppColors.textSecondary;
  }),
  overlayColor: const WidgetStatePropertyAll(AppColors.overlayWash),
  textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
  padding: const WidgetStatePropertyAll(
    EdgeInsets.symmetric(horizontal: AppSpacing.sm + AppSpacing.xs, vertical: AppSpacing.sm),
  ),
  shape: const WidgetStatePropertyAll(
    RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppRadii.sm)),
    ),
  ),
);

/// The type scale from `docs/design/00` §Typography.
///
/// Space Grotesk 700 carries the display role — wordmark, panel titles, headline
/// amounts, ring values — and Manrope everything else. The split is by *role*,
/// not by size, so a 14px card title stays Manrope while an 18px panel title is
/// Space Grotesk.
TextTheme _appTextTheme() {
  const base = TextTheme();
  return base
      .copyWith(
        // Headline stat values (29–32).
        displayLarge: _display(32, tracking: -0.8),
        displayMedium: _display(29, tracking: -0.6),
        // Account-card balance.
        headlineLarge: _display(21, tracking: -0.4),
        // Modal and empty-state titles (16–19).
        headlineMedium: _display(19, tracking: -0.3),
        headlineSmall: _display(16, tracking: -0.2),
        // Top-bar panel title.
        titleLarge: _display(18, tracking: -0.3),
        // Card title.
        titleMedium: _ui(14, FontWeight.w700, height: 1.35),
        // Row primary line (merchant, account name).
        titleSmall: _ui(13.5, FontWeight.w700, height: 1.35),
        bodyLarge: _ui(13.5, FontWeight.w400, height: 1.5),
        bodyMedium: _ui(13, FontWeight.w400, height: 1.5),
        // Secondary text.
        bodySmall: _ui(12.5, FontWeight.w400, height: 1.45),
        // Button label.
        labelLarge: _ui(13, FontWeight.w600, tracking: 0.1),
        // Form label.
        labelMedium: _ui(12.5, FontWeight.w600, tracking: 0.1),
        // Captions and badges.
        labelSmall: _ui(11.5, FontWeight.w600, tracking: 0.1),
      )
      .apply(bodyColor: AppColors.textPrimary, displayColor: AppColors.textPrimary);
}

/// Styles the [TextTheme] slots can't carry — an uppercase section label sits
/// below `labelSmall`, and the review queue needs a monospace face.
abstract final class AppTextStyles {
  /// 10px uppercase section label. Uppercase at the usage site, not here, so
  /// the localized string stays intact for screen readers.
  static const sectionLabel = TextStyle(
    fontFamily: AppFonts.manrope,
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.3,
    color: AppColors.textDisabled,
  );

  /// Field helper / validation line.
  static const helper = TextStyle(
    fontFamily: AppFonts.manrope,
    fontSize: 11.5,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: AppColors.textSecondary,
  );

  /// Raw bank labels in the review queue.
  static const mono = TextStyle(
    fontFamily: AppFonts.mono,
    fontSize: 12.5,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );
}

TextStyle _display(double size, {double tracking = 0}) => TextStyle(
  fontFamily: AppFonts.spaceGrotesk,
  fontSize: size,
  fontWeight: FontWeight.w700,
  letterSpacing: tracking,
  height: 1.2,
  color: AppColors.textPrimary,
);

TextStyle _ui(
  double size,
  FontWeight weight, {
  double tracking = 0,
  double? height,
}) => TextStyle(
  fontFamily: AppFonts.manrope,
  fontSize: size,
  fontWeight: weight,
  letterSpacing: tracking,
  height: height,
  color: AppColors.textPrimary,
);

/// Tabular-figure variant of [base] so stacked amounts/balances align by column.
TextStyle tabularNumberStyle(TextStyle base) =>
    base.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
