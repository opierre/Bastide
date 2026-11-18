import 'package:flutter/material.dart';

import 'tokens.dart';

/// The two themes of `docs/design/00-design-system.md`, at parity. Each
/// carries the [AppColors], [CategoryColors] and [AppTextStyles] extensions
/// widgets read through `context.colors`, `context.categoryColors` and
/// `context.textStyles`.
abstract final class AppTheme {
  /// The reference theme and the default.
  static final ThemeData dark = _build(
    AppColors.dark,
    CategoryColors.dark,
    Brightness.dark,
  );

  static final ThemeData light = _build(
    AppColors.light,
    CategoryColors.light,
    Brightness.light,
  );
}

ThemeData _build(
  AppColors c,
  CategoryColors categories,
  Brightness brightness,
) {
  final colorScheme = ColorScheme(
    brightness: brightness,
    surface: c.bg,
    onSurface: c.text,
    onSurfaceVariant: c.textSecondary,
    surfaceContainerLowest: c.rail,
    surfaceContainerLow: c.bg,
    surfaceContainer: c.surface,
    surfaceContainerHigh: c.surface,
    surfaceContainerHighest: c.hover,
    primary: c.accent,
    onPrimary: c.onAccent,
    primaryContainer: c.accentSoft,
    onPrimaryContainer: c.text,
    secondary: c.accent,
    onSecondary: c.onAccent,
    tertiary: c.accent,
    onTertiary: c.onAccent,
    error: c.negative,
    onError: c.onPrimary,
    outline: c.lineStrong,
    outlineVariant: c.line,
    shadow: Colors.black,
    scrim: c.scrim,
  );

  final textTheme = _appTextTheme(c);
  final textStyles = AppTextStyles.from(c);

  OutlinedBorder controlShape() => const RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(AppRadii.control)),
  );
  RoundedRectangleBorder containerShape() => RoundedRectangleBorder(
    borderRadius: const BorderRadius.all(Radius.circular(AppRadii.container)),
    side: BorderSide(color: c.lineStrong),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    extensions: [c, categories, textStyles],
    scaffoldBackgroundColor: c.bg,
    canvasColor: c.surface,
    fontFamily: AppFonts.geist,
    textTheme: textTheme,
    // Desktop-first: tighter than Material's touch defaults. Hover and pressed
    // states change at once (`00` §13), so the ripple is suppressed in favour
    // of the fills each component defines itself.
    visualDensity: VisualDensity.compact,
    splashFactory: NoSplash.splashFactory,
    focusColor: c.accentSoft,
    hoverColor: c.hover,
    dividerColor: c.line,

    cardTheme: CardThemeData(
      color: c.bg,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: containerShape().copyWith(side: BorderSide(color: c.line)),
    ),

    dividerTheme: DividerThemeData(color: c.line, thickness: 1, space: 1),

    inputDecorationTheme: _inputDecorationTheme(c, textTheme, textStyles),
    filledButtonTheme: FilledButtonThemeData(
      style: _rowAligned(_filledButtonStyle(c, textTheme, controlShape())),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: _rowAligned(_outlinedButtonStyle(c, textTheme, controlShape())),
    ),
    textButtonTheme: TextButtonThemeData(
      style: _rowAligned(_textButtonStyle(c, textTheme, controlShape())),
    ),

    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStatePropertyAll(c.textSecondary),
        overlayColor: WidgetStatePropertyAll(c.hover),
        shape: WidgetStatePropertyAll(controlShape()),
      ),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: textTheme.headlineSmall,
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: c.textSecondary),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadii.modal)),
      ),
      barrierColor: c.scrim,
    ),

    // The calendar behind every date field. Material's own surfaces are a
    // shade of the seed colour rather than this palette, so the picker's slots
    // are mapped onto the tokens here.
    datePickerTheme: DatePickerThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadii.modal)),
      ),
      headerBackgroundColor: c.surface,
      headerForegroundColor: c.textSecondary,
      weekdayStyle: textStyles.sectionLabel,
      dayForegroundColor: WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.selected) ? c.onAccent : c.text;
      }),
      dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return c.accent;
        if (states.contains(WidgetState.hovered)) return c.hover;
        return Colors.transparent;
      }),
      todayForegroundColor: WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.selected) ? c.onAccent : c.accent;
      }),
      todayBorder: BorderSide(color: c.accent),
      yearForegroundColor: WidgetStatePropertyAll(c.text),
      dividerColor: c.line,
    ),

    popupMenuTheme: PopupMenuThemeData(
      color: c.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      textStyle: textTheme.bodyMedium,
      shape: containerShape(),
    ),

    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(c.surface),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(0),
        shape: WidgetStatePropertyAll(containerShape()),
      ),
    ),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.surface,
      contentTextStyle: textTheme.bodyMedium,
      elevation: 0,
      shape: containerShape(),
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
    ),

    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.container),
        border: Border.all(color: c.lineStrong),
        boxShadow: c.shadow,
      ),
      textStyle: textTheme.bodySmall?.copyWith(color: c.text),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.smPlus,
        vertical: AppSpacing.xsPlus,
      ),
      waitDuration: const Duration(milliseconds: 500),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: c.surface,
      side: BorderSide(color: c.lineStrong),
      labelStyle: textTheme.labelSmall,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadii.pill)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
    ),

    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: c.accent,
      linearTrackColor: c.lineStrong,
      circularTrackColor: Colors.transparent,
      strokeCap: StrokeCap.round,
    ),

    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(c.lineStrong),
      thickness: const WidgetStatePropertyAll(6),
      radius: const Radius.circular(AppRadii.pill),
      crossAxisMargin: 2,
    ),
  );
}

/// Lands a dense 13 px text field on [AppSizes.formField].
const _fieldPaddingY = 10.5;

InputDecorationTheme _inputDecorationTheme(
  AppColors c,
  TextTheme textTheme,
  AppTextStyles textStyles,
) {
  OutlineInputBorder border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadii.control),
    borderSide: BorderSide(color: color),
  );

  return InputDecorationTheme(
    filled: true,
    fillColor: c.field,
    isDense: true,
    // 32 px with the 13 px value (`00` §4), padded 0 10. The dense decorator
    // lays the text out on the font's own metrics rather than the 1.45 line
    // height, hence the uneven vertical padding.
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm + AppSpacing.xxs,
      vertical: _fieldPaddingY,
    ),
    // Labels sit above the field rather than floating inside it: French labels
    // run longer than English and clip when squeezed into a notch.
    floatingLabelBehavior: FloatingLabelBehavior.never,
    labelStyle: textTheme.bodyMedium?.copyWith(color: c.textSecondary),
    hintStyle: textTheme.bodyMedium?.copyWith(color: c.textTertiary),
    errorStyle: textStyles.helper.copyWith(color: c.negative),
    prefixIconColor: c.textTertiary,
    suffixIconColor: c.textTertiary,
    border: border(c.lineStrong),
    enabledBorder: border(c.lineStrong),
    disabledBorder: border(c.lineStrong.withValues(alpha: 0.45)),
    // The 3 px `accentSoft` ring around a focused field is painted by
    // FocusGlow, since InputBorder can only draw the border itself.
    focusedBorder: border(c.accent),
    errorBorder: border(c.negative),
    focusedErrorBorder: border(c.negative),
  );
}

/// Pins a button to [AppSizes.button] whatever its label, so the buttons of
/// one row measure the same. A button under a tight parent constraint still
/// takes its parent's height.
ButtonStyle _rowAligned(ButtonStyle style) => style.copyWith(
  minimumSize: const WidgetStatePropertyAll(Size(0, AppSizes.button)),
  visualDensity: VisualDensity.standard,
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
);

/// Buttons are padded 0 10 (`00` §6).
const _buttonPaddingX = AppSpacing.sm + AppSpacing.xxs;

/// The focus outline of `00` §6, as a button side: 2 px `accent`.
BorderSide? _focusSide(AppColors c, Set<WidgetState> states) =>
    states.contains(WidgetState.focused)
    ? BorderSide(color: c.accent, width: 2)
    : null;

/// The primary button (`00` §6): `primary` ground, `onPrimary` label, no
/// border.
ButtonStyle _filledButtonStyle(
  AppColors c,
  TextTheme textTheme,
  OutlinedBorder shape,
) => ButtonStyle(
  backgroundColor: WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.disabled)) {
      return c.primary.withValues(alpha: 0.45);
    }
    return c.primary;
  }),
  foregroundColor: WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.disabled)) {
      return c.onPrimary.withValues(alpha: 0.45);
    }
    return c.onPrimary;
  }),
  overlayColor: WidgetStatePropertyAll(c.onPrimary.withValues(alpha: 0.08)),
  side: WidgetStateProperty.resolveWith((states) => _focusSide(c, states)),
  textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
  elevation: const WidgetStatePropertyAll(0),
  padding: const WidgetStatePropertyAll(
    EdgeInsets.symmetric(horizontal: _buttonPaddingX),
  ),
  shape: WidgetStatePropertyAll(shape),
  iconSize: const WidgetStatePropertyAll(AppSizes.iconSmall),
);

/// The secondary button (`00` §6): `surface` ground, 1 px `lineStrong`.
ButtonStyle _outlinedButtonStyle(
  AppColors c,
  TextTheme textTheme,
  OutlinedBorder shape,
) => ButtonStyle(
  foregroundColor: WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.disabled)) return c.textTertiary;
    return c.text;
  }),
  backgroundColor: WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.hovered)) return c.hover;
    return c.surface;
  }),
  side: WidgetStateProperty.resolveWith((states) {
    if (_focusSide(c, states) case final focus?) return focus;
    if (states.contains(WidgetState.disabled)) {
      return BorderSide(color: c.lineStrong.withValues(alpha: 0.45));
    }
    return BorderSide(color: c.lineStrong);
  }),
  textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
  padding: const WidgetStatePropertyAll(
    EdgeInsets.symmetric(horizontal: _buttonPaddingX),
  ),
  shape: WidgetStatePropertyAll(shape),
  iconSize: const WidgetStatePropertyAll(AppSizes.iconSmall),
);

/// The ghost button (`00` §6): no border, no ground, `textSecondary`.
ButtonStyle _textButtonStyle(
  AppColors c,
  TextTheme textTheme,
  OutlinedBorder shape,
) => ButtonStyle(
  foregroundColor: WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.disabled)) return c.textTertiary;
    if (states.contains(WidgetState.hovered)) return c.text;
    return c.textSecondary;
  }),
  overlayColor: WidgetStatePropertyAll(c.hover),
  side: WidgetStateProperty.resolveWith((states) => _focusSide(c, states)),
  textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
  padding: const WidgetStatePropertyAll(
    EdgeInsets.symmetric(horizontal: _buttonPaddingX),
  ),
  shape: WidgetStatePropertyAll(shape),
  iconSize: const WidgetStatePropertyAll(AppSizes.iconSmall),
);

/// The type scale of `00` §3, mapped onto the [TextTheme] slots.
///
/// One family, Geist at 400, 500 and 600. Figures take line height 1.1, text
/// 1.45. Nothing is smaller than 11.
TextTheme _appTextTheme(AppColors c) {
  TextStyle style(
    double size,
    FontWeight weight, {
    double trackingEm = 0,
    double height = 1.45,
  }) => TextStyle(
    fontFamily: AppFonts.geist,
    fontSize: size,
    fontWeight: weight,
    letterSpacing: trackingEm * size,
    height: height,
    color: c.text,
  );

  return TextTheme(
    // The panel's lead figure.
    displayLarge: style(40, FontWeight.w600, trackingEm: -0.03, height: 1.1),
    // Supporting figures of a summary line; an inspector's lead figure.
    displayMedium: style(28, FontWeight.w600, trackingEm: -0.02, height: 1.1),
    // Minor figures of a summary line.
    displaySmall: style(20, FontWeight.w600, trackingEm: -0.01, height: 1.1),
    headlineLarge: style(28, FontWeight.w600, trackingEm: -0.02, height: 1.1),
    headlineMedium: style(20, FontWeight.w600, trackingEm: -0.01, height: 1.1),
    // Inspector title, settings section title, modal title.
    headlineSmall: style(16, FontWeight.w600),
    titleLarge: style(16, FontWeight.w600),
    // Title-bar title, brand name.
    titleMedium: style(14, FontWeight.w600),
    // Section heading inside a panel.
    titleSmall: style(13, FontWeight.w600),
    // Body, table cells, nav items, field values.
    bodyLarge: style(13, FontWeight.w400),
    bodyMedium: style(13, FontWeight.w400),
    // Field labels, column headers, captions.
    bodySmall: style(12, FontWeight.w400),
    // Button label, emphasised cell, active tab.
    labelLarge: style(13, FontWeight.w500),
    labelMedium: style(12, FontWeight.w500),
    // Notes, chart axis labels, meter labels.
    labelSmall: style(11, FontWeight.w400),
  );
}

/// Tabular-figure variant of [base] so stacked amounts/balances align by column.
TextStyle tabularNumberStyle(TextStyle base) =>
    base.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
