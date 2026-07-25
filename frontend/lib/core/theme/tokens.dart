import 'package:flutter/material.dart';

/// Dark-first palette. See `PROJECT.md` §9 and the design-system skill.
///
/// The scale is built on an ink base with a slight blue cast rather than a
/// neutral grey, so raised surfaces read as *lifted* without needing heavy
/// borders. Never hardcode a hex in a widget — add a token here instead.
abstract final class AppColors {
  /// App chrome background (sidebar, bottom bar) — the deepest layer.
  static const surfaceSunken = Color(0xFF070910);

  /// Content region background.
  static const surfaceBase = Color(0xFF0A0D12);

  /// Cards and panels lifted off [surfaceBase].
  static const surfaceRaised = Color(0xFF111620);

  /// Dialogs, menus, and anything floating above the page.
  static const surfaceOverlay = Color(0xFF19202B);

  /// Pointer-hover wash for interactive rows and cards.
  static const surfaceHover = Color(0xFF1E2634);

  /// Inset wells: text fields, search, read-only value slots.
  static const surfaceField = Color(0xFF0D1219);

  static const textPrimary = Color(0xFFEDF1F7);
  static const textSecondary = Color(0xFF97A3B6);
  static const textDisabled = Color(0xFF5A6579);

  /// Brand accent — jade/mint, signalling growth and savings.
  static const brandAccent = Color(0xFF2FE0A6);

  /// Deeper end of the brand ramp, for gradients and pressed states.
  static const brandAccentDeep = Color(0xFF14B989);

  /// Brand accent at low alpha, for selected nav pills and tinted chips.
  static const brandAccentSoft = Color(0x1F2FE0A6);

  /// Secondary accent — used for charts, categories, and decorative pairing
  /// with [brandAccent]. Never used for money, so it can't be confused with
  /// the income/expense rule below.
  static const accentViolet = Color(0xFF8B7CF6);

  /// Money sign colors. Income/positive is a leaf green, deliberately yellower
  /// than [brandAccent] so a balance never reads as a brand element.
  static const positive = Color(0xFF4ADE80);
  static const negative = Color(0xFFFF5C6C);
  static const warning = Color(0xFFFFB84D);
  static const info = Color(0xFF5AA9FF);

  /// Hairline between structural regions.
  static const border = Color(0xFF232B38);

  /// Quieter hairline, for separators *inside* a card.
  static const borderSubtle = Color(0xFF1A212C);

  static const focusRing = brandAccent;

  /// Neutral wash used for hover/press overlays on dark surfaces.
  static const overlayWash = Color(0x0FFFFFFF);
}

abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
}

abstract final class AppRadii {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;

  /// Fully rounded — pills, avatars, status dots.
  static const pill = 999.0;
}

/// Soft, wide shadows. On a dark UI these read as depth rather than as a
/// visible drop shadow, so they stay subtle and are reserved for surfaces
/// that genuinely float.
abstract final class AppShadows {
  static const card = [
    BoxShadow(color: Color(0x33000000), blurRadius: 16, offset: Offset(0, 4)),
  ];

  static const overlay = [
    BoxShadow(color: Color(0x66000000), blurRadius: 40, offset: Offset(0, 16)),
  ];
}

/// Restrained motion — one duration per intent, so transitions across the app
/// stay in step. See the design-system skill's motion rules.
abstract final class AppMotion {
  static const fast = Duration(milliseconds: 120);
  static const base = Duration(milliseconds: 200);
  static const slow = Duration(milliseconds: 320);

  static const curve = Curves.easeOutCubic;
}

abstract final class AppFonts {
  static const openSans = 'Open Sans';
}

/// Fixed-chrome dimensions. The shell is the only place these are consumed;
/// they live here so the design docs and the app can't drift.
abstract final class AppChrome {
  static const sidebarWidth = 252.0;
  static const topBarHeight = 72.0;
  static const bottomBarHeight = 30.0;
}
