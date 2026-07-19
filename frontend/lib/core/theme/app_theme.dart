import 'package:flutter/material.dart';

import 'tokens.dart';

final ThemeData appDarkTheme = _buildDarkTheme();

ThemeData _buildDarkTheme() {
  const colorScheme = ColorScheme.dark(
    surface: AppColors.surfaceBase,
    onSurface: AppColors.textPrimary,
    primary: AppColors.brandAccent,
    onPrimary: AppColors.surfaceBase,
    secondary: AppColors.info,
    onSecondary: AppColors.surfaceBase,
    error: AppColors.negative,
    onError: AppColors.textPrimary,
    outline: AppColors.border,
  );

  final textTheme = _appTextTheme();

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.surfaceBase,
    fontFamily: AppFonts.openSans,
    textTheme: textTheme,
    cardTheme: CardThemeData(
      color: AppColors.surfaceRaised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: AppColors.surfaceRaised,
      selectedIconTheme: const IconThemeData(color: AppColors.brandAccent),
      selectedLabelTextStyle: textTheme.labelLarge?.copyWith(
        color: AppColors.brandAccent,
      ),
      unselectedIconTheme: const IconThemeData(color: AppColors.textSecondary),
      unselectedLabelTextStyle: textTheme.labelLarge?.copyWith(
        color: AppColors.textSecondary,
      ),
    ),
    focusColor: AppColors.focusRing,
  );
}

TextTheme _appTextTheme() {
  const base = TextTheme();
  return base
      .copyWith(
        headlineLarge: _style(32, FontWeight.w700),
        headlineMedium: _style(28, FontWeight.w700),
        headlineSmall: _style(24, FontWeight.w700),
        titleLarge: _style(20, FontWeight.w600),
        titleMedium: _style(16, FontWeight.w600),
        titleSmall: _style(14, FontWeight.w600),
        bodyLarge: _style(16, FontWeight.w400),
        bodyMedium: _style(14, FontWeight.w400),
        bodySmall: _style(12, FontWeight.w400),
        labelLarge: _style(14, FontWeight.w600),
      )
      .apply(bodyColor: AppColors.textPrimary, displayColor: AppColors.textPrimary);
}

TextStyle _style(double size, FontWeight weight) => TextStyle(
  fontFamily: AppFonts.openSans,
  fontSize: size,
  fontWeight: weight,
  color: AppColors.textPrimary,
);

/// Tabular-figure variant of [base] so stacked amounts/balances align by column.
TextStyle tabularNumberStyle(TextStyle base) =>
    base.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
