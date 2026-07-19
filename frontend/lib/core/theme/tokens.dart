import 'package:flutter/material.dart';

/// Dark-first palette. See `PROJECT.md` §9 and the design-system skill.
abstract final class AppColors {
  static const surfaceBase = Color(0xFF0E1116);
  static const surfaceRaised = Color(0xFF161B22);
  static const surfaceOverlay = Color(0xFF1F2630);

  static const textPrimary = Color(0xFFE6EAF0);
  static const textSecondary = Color(0xFF9AA4B2);
  static const textDisabled = Color(0xFF5B6573);

  static const brandAccent = Color(0xFF2BD9A8);

  static const positive = Color(0xFF3FB950);
  static const negative = Color(0xFFF85149);
  static const warning = Color(0xFFD29922);
  static const info = Color(0xFF58A6FF);

  static const border = Color(0xFF2A313C);
  static const focusRing = brandAccent;
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
  static const sm = 6.0;
  static const md = 10.0;
  static const lg = 16.0;
}

abstract final class AppFonts {
  static const openSans = 'Open Sans';
}
