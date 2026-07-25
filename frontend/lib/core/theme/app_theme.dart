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
    primary: AppColors.brandAccent,
    onPrimary: AppColors.surfaceSunken,
    primaryContainer: AppColors.brandAccentDeep,
    onPrimaryContainer: AppColors.surfaceSunken,
    secondary: AppColors.accentViolet,
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
    fontFamily: AppFonts.openSans,
    textTheme: textTheme,
    // Desktop-first: tighter than Material's touch defaults, and a calm ripple
    // instead of M3's sparkle — see the design-system skill's motion rules.
    visualDensity: VisualDensity.compact,
    splashFactory: InkRipple.splashFactory,
    focusColor: AppColors.focusRing,
    hoverColor: AppColors.overlayWash,
    dividerColor: AppColors.border,

    cardTheme: const CardThemeData(
      color: AppColors.surfaceRaised,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadii.lg)),
        side: BorderSide(color: AppColors.border),
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
      titleTextStyle: textTheme.titleLarge,
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadii.xl)),
        side: BorderSide(color: AppColors.border),
      ),
      barrierColor: const Color(0xB3000000),
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
        borderRadius: BorderRadius.all(Radius.circular(AppRadii.md)),
        side: BorderSide(color: AppColors.border),
      ),
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
    ),

    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: AppColors.surfaceOverlay,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(color: AppColors.border),
      ),
      textStyle: textTheme.bodySmall,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
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
      color: AppColors.brandAccent,
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
  OutlineInputBorder border(Color color, {double width = 1}) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadii.md),
    borderSide: BorderSide(color: color, width: width),
  );

  return InputDecorationTheme(
    filled: true,
    fillColor: AppColors.surfaceField,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: 14,
    ),
    // Labels sit above the field rather than floating inside it: French labels
    // run 15–20% longer than English and clip badly when squeezed into a notch.
    floatingLabelBehavior: FloatingLabelBehavior.never,
    labelStyle: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
    hintStyle: textTheme.bodyMedium?.copyWith(color: AppColors.textDisabled),
    errorStyle: textTheme.bodySmall?.copyWith(color: AppColors.negative),
    prefixIconColor: AppColors.textSecondary,
    suffixIconColor: AppColors.textSecondary,
    border: border(AppColors.border),
    enabledBorder: border(AppColors.border),
    disabledBorder: border(AppColors.borderSubtle),
    focusedBorder: border(AppColors.focusRing, width: 1.5),
    errorBorder: border(AppColors.negative),
    focusedErrorBorder: border(AppColors.negative, width: 1.5),
  );
}

ButtonStyle _filledButtonStyle(TextTheme textTheme) => ButtonStyle(
  backgroundColor: WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.disabled)) return AppColors.surfaceHover;
    if (states.contains(WidgetState.pressed)) return AppColors.brandAccentDeep;
    return AppColors.brandAccent;
  }),
  foregroundColor: WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.disabled)) return AppColors.textDisabled;
    return AppColors.surfaceSunken;
  }),
  overlayColor: const WidgetStatePropertyAll(Color(0x14000000)),
  textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
  elevation: const WidgetStatePropertyAll(0),
  padding: const WidgetStatePropertyAll(
    EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 14),
  ),
  shape: const WidgetStatePropertyAll(
    RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppRadii.md)),
    ),
  ),
  iconSize: const WidgetStatePropertyAll(18),
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
    EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 14),
  ),
  shape: const WidgetStatePropertyAll(
    RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppRadii.md)),
    ),
  ),
  iconSize: const WidgetStatePropertyAll(18),
);

ButtonStyle _textButtonStyle(TextTheme textTheme) => ButtonStyle(
  foregroundColor: WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.disabled)) return AppColors.textDisabled;
    if (states.contains(WidgetState.hovered)) return AppColors.brandAccent;
    return AppColors.textSecondary;
  }),
  overlayColor: const WidgetStatePropertyAll(AppColors.overlayWash),
  textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
  padding: const WidgetStatePropertyAll(
    EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
  ),
  shape: const WidgetStatePropertyAll(
    RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppRadii.sm)),
    ),
  ),
);

TextTheme _appTextTheme() {
  const base = TextTheme();
  return base
      .copyWith(
        // Headings use slightly negative tracking — at large sizes Open Sans's
        // default spacing reads loose and dated.
        headlineLarge: _style(34, FontWeight.w700, tracking: -0.8, height: 1.15),
        headlineMedium: _style(28, FontWeight.w700, tracking: -0.6, height: 1.2),
        headlineSmall: _style(23, FontWeight.w700, tracking: -0.4, height: 1.25),
        titleLarge: _style(20, FontWeight.w700, tracking: -0.3, height: 1.3),
        titleMedium: _style(15, FontWeight.w600, tracking: -0.1, height: 1.35),
        titleSmall: _style(13, FontWeight.w600, height: 1.4),
        bodyLarge: _style(15, FontWeight.w400, height: 1.5),
        bodyMedium: _style(14, FontWeight.w400, height: 1.5),
        bodySmall: _style(12.5, FontWeight.w400, height: 1.45),
        labelLarge: _style(14, FontWeight.w600, tracking: 0.1),
        labelMedium: _style(12.5, FontWeight.w600, tracking: 0.1),
        // Section labels / overlines: small, wide-tracked, uppercase at usage.
        labelSmall: _style(11, FontWeight.w600, tracking: 0.6),
      )
      .apply(bodyColor: AppColors.textPrimary, displayColor: AppColors.textPrimary);
}

TextStyle _style(
  double size,
  FontWeight weight, {
  double tracking = 0,
  double? height,
}) => TextStyle(
  fontFamily: AppFonts.openSans,
  fontSize: size,
  fontWeight: weight,
  letterSpacing: tracking,
  height: height,
  color: AppColors.textPrimary,
);

/// Tabular-figure variant of [base] so stacked amounts/balances align by column.
TextStyle tabularNumberStyle(TextStyle base) =>
    base.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
