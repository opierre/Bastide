import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Dark-first palette. Binding values come from `docs/design/00-shared-design-block.md`;
/// that file is the source of truth and this one transcribes it.
///
/// The scale is built on an ink base with a slight blue cast rather than a
/// neutral grey, so raised surfaces read as *lifted* without needing heavy
/// borders. Never hardcode a hex in a widget — add a token here instead.
abstract final class AppColors {
  /// App chrome background (sidebar, auth page) — the deepest layer.
  static const surfaceSunken = Color(0xFF070910);

  /// Content region background.
  static const surfaceBase = Color(0xFF0A0D12);

  /// Cards and panels lifted off [surfaceBase].
  static const surfaceRaised = Color(0xFF111620);

  /// Dialogs, popovers, toasts — anything floating above the page.
  static const surfaceOverlay = Color(0xFF19202B);

  /// Pointer-hover wash; also inset plates and toggle tracks.
  static const surfaceHover = Color(0xFF1E2634);

  /// Menu/select popovers. The *same* fill as [surfaceField], because a select
  /// is a field the user opened: a popover in a lighter tone than the anchor it
  /// dropped from reads as a second material spliced into the form, where one
  /// tone reads as the field having grown. Separation from the modal behind it
  /// is carried by the hairline and the near-black [AppShadows.popoverShadow],
  /// not by the fill — a well sunk *below* the dialog surface is as legible a
  /// plane as one raised above it.
  static const surfacePopover = surfaceField;

  /// Row hover *inside* a raised card — sits between raised and hover, so a
  /// hovered row lifts without jumping to the full overlay tone.
  static const surfaceRowHover = Color(0xFF151B26);

  /// Inset wells: text fields, selects, search, read-only value slots.
  ///
  /// One tone for every well, editable or not — read-only is carried by the
  /// dashed border and lock glyph, not by the fill (amended twice; see
  /// `docs/design/00` §Palette).
  static const surfaceField = Color(0xFF0A0F15);

  /// Sidebar nav hover — quieter than [surfaceHover] because the sidebar sits
  /// on the sunken surface, where a lighter wash would read as selection.
  static const sidebarHover = Color(0xFF12161F);

  static const textPrimary = Color(0xFFEDF1F7);
  static const textSecondary = Color(0xFF97A3B6);
  static const textDisabled = Color(0xFF5A6579);

  /// Brand accent — iris violet. Reserved for the accent role: primary buttons,
  /// active nav, focus, links, the logomark. Deliberately *never* used for a
  /// category hue or for money, so an iris element is always chrome.
  static const iris = Color(0xFF8B8CF9);

  /// Deep end of the iris ramp — gradient terminus and pressed states.
  static const irisDeep = Color(0xFF6C6AF0);

  /// Iris at 12% — active nav pills, tinted chips, glyph plates.
  static const irisSoft = Color(0x1F8B8CF9);

  /// Iris at 35% — the savings-rate hero card's outline (`docs/design/00` §Components). The
  /// card's own ramp (#8B8CF9 → #6C6AF0) is only a few percent of lightness wide, so it is
  /// this border, not the fill, that separates the hero from the neutral cards beside it.
  static const irisBorderStrong = Color(0x598B8CF9);

  /// Foreground on an iris-gradient fill.
  static const irisInk = Color(0xFF0E1030);

  /// Leading chart/category hue.
  static const cyan = Color(0xFF4FD1E8);

  /// Money sign colors. Income green is deliberately yellower than [iris] so a
  /// balance never reads as a brand element.
  static const positive = Color(0xFF4ADE80);
  static const negative = Color(0xFFFF5C6C);

  /// Label ink on a solid [negative] fill — the destructive confirm button
  /// (`docs/design/09-settings.md` §Sauvegarde, state ⑧).
  static const negativeInk = Color(0xFF2A0A0F);
  static const warning = Color(0xFFFFB84D);

  /// Warning at 35% — the over-reference card border (`docs/design/00`
  /// §Phase 3 additions): the one edge a reading may tint, never red.
  static const warningBorder = Color(0x59FFB84D);
  static const info = Color(0xFF5AA9FF);

  /// Hairline between structural regions.
  static const border = Color(0xFF232B38);

  /// Quieter hairline, for separators *inside* a card.
  static const borderSubtle = Color(0xFF1A212C);

  /// Card outline — a touch lighter than [border] so a card edge reads against
  /// the base surface without the weight of a structural divider.
  static const borderCard = Color(0xFF242E3E);

  /// Dashed outline on read-only / uncategorized slots.
  static const borderDashed = Color(0xFF3A4556);

  static const focusRing = iris;

  /// Neutral wash used for hover/press overlays on dark surfaces.
  static const overlayWash = Color(0x0FFFFFFF);

  /// Modal scrim.
  static const scrim = Color(0x9E04060B);

  /// The iris gradient used by primary buttons, the logomark, and the
  /// savings-rate hero card — the spec's
  /// `linear-gradient(135deg, #8B8CF9, #6C6AF0)`.
  ///
  /// A true 45° axis, not `topLeft → bottomRight`. Flutter's corner alignments
  /// follow the box's aspect ratio, so on a wide, short card (the savings hero)
  /// that vector flattens to roughly 20° and the ramp reads as a horizontal
  /// wash instead of the drawn diagonal. Rotating a horizontal gradient by π/4
  /// pins the angle whatever box it paints.
  static const irisGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [iris, irisDeep],
    transform: GradientRotation(math.pi / 4),
  );

  /// The savings-rate hero's fill — the spec's
  /// `linear-gradient(160deg, rgba(139,140,249,.14), rgba(108,106,240,.05) 55%)` layered over
  /// the [surfaceRaised] card base.
  ///
  /// The two translucent stops are composited against that base here rather than stacked as a
  /// separate translucent layer, so the card paints one gradient and the hero stays a *tint* of
  /// the neutral cards beside it instead of a second, fully saturated material.
  ///
  /// CSS 160° points down and slightly right; Flutter measures a rotation from the left→right
  /// axis, which is CSS 90°, so the axis is turned the remaining 70°.
  static const irisTintGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF22273E), Color(0xFF161A2A)],
    stops: [0.0, 0.55],
    transform: GradientRotation(70 * math.pi / 180),
  );

  /// Iris at 30% — the dashboard's Objectifs card outline (`docs/design/04` §Row 3). A notch
  /// lighter than [irisBorderStrong] because that card's own tint is lighter too: the pair are
  /// drawn to keep the same border-to-fill relationship as the savings hero.
  static const irisBorder = Color(0x4D8B8CF9);

  /// The goal progress bar's fill — the spec's `linear-gradient(90deg,#6C6AF0,#8B8CF9)`
  /// (`docs/design/00` §Phase 2 additions).
  ///
  /// Deep end *first*, unlike [irisGradient]: a progress bar fills from the left, and starting
  /// on the darker stop is what makes a part-filled bar read as one that has been travelling
  /// rather than one that has been cropped.
  static const goalProgressGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [irisDeep, iris],
  );

  /// The dashboard Objectifs card's fill — the spec's
  /// `linear-gradient(160deg,rgba(139,140,249,.10),rgba(108,106,240,.03) 55%)` over
  /// [surfaceRaised], composited here for the same reason [irisTintGradient] is: one gradient,
  /// so the card stays a tint of the neutral cards beside it rather than a second material.
  static const irisTintGradientSoft = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF1D2236), Color(0xFF141926)],
    stops: [0.0, 0.55],
    transform: GradientRotation(70 * math.pi / 180),
  );

  /// The reached goal card's outline — the spec's `rgba(74,222,128,.35)`. Green rather than
  /// iris because reaching a target is the one state on this panel the design lets a card
  /// announce by its edge (`docs/design/11-goals.md` §Grid state).
  static const positiveBorder = Color(0x594ADE80);

  /// Glow beneath a primary button.
  static const irisGlow = [
    BoxShadow(color: Color(0x4D6C6AF0), blurRadius: 22, offset: Offset(0, 8)),
  ];
}

/// Category hues. Fixed per category so a hue means the same thing in the
/// donut, the legend, and every chip — the spec pins these rather than deriving
/// them, so charts and chips can never drift apart.
///
/// Iris is absent by design: it is the accent role, not a data hue.
abstract final class CategoryHues {
  static const logement = AppColors.cyan;
  static const alimentation = Color(0xFF5AA9FF);
  static const transport = Color(0xFF2DD4BF);
  static const loisirs = Color(0xFFF472B6);
  static const abonnements = AppColors.warning;
  static const sante = Color(0xFFA3E635);

  /// Shared by "Autres" and "Épargne" — both are catch-alls rather than
  /// spending categories, so they take the neutral slate.
  static const autres = Color(0xFF64748B);
  static const revenus = AppColors.positive;

  /// Fallback for a category with no pinned hue (user-created categories).
  static const fallback = autres;

  /// Keyed by the backend category slug.
  static const bySlug = <String, Color>{
    'logement': logement,
    'alimentation': alimentation,
    'transport': transport,
    'loisirs': loisirs,
    'abonnements': abonnements,
    'sante': sante,
    'autres': autres,
    'epargne': autres,
    'revenus': revenus,
  };

  static Color forSlug(String? slug) => bySlug[slug] ?? fallback;
}

/// Hues of the Synthèse asset composition and the property nature pills
/// (`docs/design/15-synthese.md` §Row 2, §Biens view).
///
/// The frame pins four; every other account type and property kind takes the
/// neutral slate, the same catch-all hue as « Autres » (decided in review).
abstract final class AssetHues {
  static const checking = Color(0xFF5AA9FF);
  static const savings = Color(0xFF2DD4BF);
  static const primaryResidence = AppColors.cyan;
  static const rental = Color(0xFFA3E635);
  static const unpinned = CategoryHues.autres;

  /// Keyed by the backend account `type`.
  static const byAccountType = <String, Color>{
    'checking': checking,
    'savings': savings,
  };

  /// Keyed by the backend property `kind`.
  static const byPropertyKind = <String, Color>{
    'primary_residence': primaryResidence,
    'rental': rental,
  };

  static Color forAccountType(String type) => byAccountType[type] ?? unpinned;

  static Color forPropertyKind(String kind) => byPropertyKind[kind] ?? unpinned;
}

/// Brand-ish hues for institution/merchant monogram chips.
///
/// Pinned per brand rather than hashed: an institution that changes color
/// between launches looks like a bug, and these specific hues are drawn in the
/// mockup. Unknown names fall back to a neutral plate with a `?` glyph.
abstract final class MonogramHues {
  static const unknownBackground = AppColors.surfaceHover;
  static const unknownForeground = AppColors.textSecondary;

  /// Lowercased, whitespace-collapsed brand name → hue.
  static const byBrand = <String, Color>{
    'bnp': Color(0xFF2FB574),
    'bnp paribas': Color(0xFF2FB574),
    'crédit agricole': Color(0xFF0AA396),
    'credit agricole': Color(0xFF0AA396),
    'revolut': Color(0xFF5AA9FF),
    'caisse locale': AppColors.cyan,
    "caisse locale d'épargne": AppColors.cyan,
    'carrefour': Color(0xFF3B82F6),
    'novatech': AppColors.irisDeep,
    'novatech sarl': AppColors.irisDeep,
  };
}

abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;

  // Values measured off the mockup (docs/design/00 §Layout invariant). They sit
  // beside the ramp above rather than replacing it: the drawn design uses a few
  // deliberate odd gaps that a 4pt ramp can't express without rounding the
  // layout away from the spec.

  /// Gap between a nav item's icon and its label.
  static const navGap = 11.0;

  /// Horizontal padding inside a nav pill.
  static const navInset = 13.0;

  /// Sidebar inner gutter.
  static const sidebarGutter = 12.0;

  /// Gap between cards in a grid (stat row, account grid).
  static const gridGap = 18.0;

  /// Card padding — the wide variant is for cards that carry a headline figure.
  static const cardPadding = 20.0;
  static const cardPaddingWide = 24.0;

  /// Content region padding: 24 vertical × 28 horizontal.
  static const contentX = 28.0;
  static const contentY = 24.0;

  /// Panels that open with a filter bar sit 20 from the top instead of 24.
  static const contentTopFiltered = 20.0;
}

abstract final class AppRadii {
  /// Category swatch, stacked-bar cap (`docs/design/00` §Components).
  static const xs = 4.0;

  static const sm = 8.0;
  static const monogram = 9.0;
  static const md = 12.0;

  /// Toasts and inset configuration plates.
  static const inset = 14.0;

  /// Card.
  static const lg = 16.0;

  /// Modal, glyph plate.
  static const xl = 20.0;

  /// Nav pill.
  static const navPill = 20.0;

  /// Fully rounded — status dots, round pager buttons.
  static const pill = 999.0;
}

/// Soft, wide shadows. On a dark UI these read as depth rather than as a
/// visible drop shadow, so they stay subtle and are reserved for surfaces
/// that genuinely float.
abstract final class AppShadows {
  static const card = [
    BoxShadow(color: Color(0x33000000), blurRadius: 16, offset: Offset(0, 4)),
  ];

  static const modal = [
    BoxShadow(color: Color(0x66000000), blurRadius: 60, offset: Offset(0, 24)),
  ];

  /// The popover shadow, expressed as an elevation rather than a [BoxShadow]
  /// because [MenuStyle] accepts only that.
  ///
  /// Heavy enough to separate a popover from the modal it usually opens over
  /// (amended from elevation 12; see `docs/design/00` §Components).
  static const popoverElevation = 24.0;
  static const popoverShadow = Color(0xCC000000);
}

/// Animation timings. Everything not listed here (hover fills, border changes,
/// selection) is an instant swap, so there is no `base`/`slow` duration to
/// reach for.
///
/// The spec's other keyframe, the button spinner, takes no duration here: it is
/// Flutter's own indeterminate progress arc, which runs on its built-in period
/// (amended; see `docs/design/00` §Motion).
abstract final class AppMotion {
  /// Skeleton opacity pulse.
  static const shimmer = Duration(milliseconds: 1600);
}

abstract final class AppFonts {
  /// UI family: 400 body, 600 emphasis/labels, 700 headings.
  ///
  /// Narrow enough for French labels at 11.5–14px, and its flat-sided figures
  /// hold an amount column under `tnum` (amended from Manrope; see
  /// `docs/design/00` §Typography).
  static const geist = 'Geist';

  /// Display family, 700 only: wordmark, panel titles, headline amounts.
  static const spaceGrotesk = 'Space Grotesk';

  /// Raw bank labels in the review queue, where character alignment matters.
  static const mono = 'monospace';
}

/// Fixed-chrome dimensions. The shell is the only place these are consumed;
/// they live here so the design docs and the app can't drift.
abstract final class AppChrome {
  static const sidebarWidth = 252.0;

  /// Icon-only rail when the sidebar is collapsed.
  static const sidebarCollapsedWidth = 76.0;

  static const topBarHeight = 72.0;

  /// Nav pill, top-bar control pill.
  static const navItemHeight = 40.0;
  static const controlPillHeight = 38.0;
  static const userPillHeight = 44.0;

  /// Every button in a footer or action row — primary, secondary, ghost — is
  /// this tall, so a « Annuler » sits exactly level with the « Appliquer »
  /// beside it. The spec's 38–46 range is a range for standalone CTAs; paired
  /// buttons have to agree on one number, and 38 is the low end the footers use.
  static const buttonHeight = 38.0;

  /// Flush-left active rail on a nav item.
  static const navRailWidth = 3.0;
  static const navRailHeight = 22.0;

  static const navIconSize = 18.0;
}

/// The luminous hairline across the top edge of every frame, and the film-grain
/// overlay tile size. Both are frame-level texture rather than component style,
/// so they live here and are applied once by the shell.
abstract final class AppTexture {
  /// Edge length of the repeating grain tile, in pixels.
  static const grainTile = 140;
  static const grainOpacity = 0.05;

  static const topHairline = LinearGradient(
    colors: [Color(0x008B8CF9), Color(0x8C8B8CF9), Color(0x008B8CF9)],
  );
}
