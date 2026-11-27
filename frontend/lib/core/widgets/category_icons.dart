import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

/// Category glyphs, drawn from Lucide (ISC — see
/// `frontend/assets/licenses/lucide/LICENSE`).
///
/// Every glyph comes from the package's weight-300 font: its stroke is 1.5 px
/// on Lucide's 24-unit grid with round caps and joins, the line style
/// `docs/design/00` §Iconography pins. The default Lucide font draws 2 px,
/// which reads heavier than the rest of the UI.
///
/// Stored icons are **keys**, never codepoints: a codepoint turns into a blank
/// square the day the font changes, a key can always be resolved. A key is the
/// Lucide icon name (`house`, `piggy-bank`). The system catalog
/// (`backend/app/core/seed.py`) stores one per entry and rewrites its rows at
/// boot when the catalog changes, so every key a row carries is one of
/// [glyphs] or [catalogGlyphs].
abstract final class CategoryIcons {
  /// The curated set the category form offers, by Lucide name. Grouped by
  /// theme so the picker reads in the order a user scans for a category.
  static const glyphs = <String, IconData>{
    // Housing
    'house': LucideIcons300.house,
    'key-round': LucideIcons300.keyRound,
    'zap': LucideIcons300.zap,
    'wrench': LucideIcons300.wrench,
    'sofa': LucideIcons300.sofa,
    // Food
    'soup': LucideIcons300.soup,
    'shopping-cart': LucideIcons300.shoppingCart,
    'utensils': LucideIcons300.utensils,
    'coffee': LucideIcons300.coffee,
    // Transport
    'car': LucideIcons300.car,
    'bus': LucideIcons300.bus,
    'fuel': LucideIcons300.fuel,
    'plane': LucideIcons300.plane,
    // Leisure
    'star': LucideIcons300.star,
    'ticket': LucideIcons300.ticket,
    'gamepad-2': LucideIcons300.gamepad2,
    'book-open': LucideIcons300.bookOpen,
    'dumbbell': LucideIcons300.dumbbell,
    // Subscriptions
    'refresh-cw': LucideIcons300.refreshCw,
    'smartphone': LucideIcons300.smartphone,
    'wifi': LucideIcons300.wifi,
    // Health
    'cross': LucideIcons300.cross,
    'pill': LucideIcons300.pill,
    // Money
    'coins': LucideIcons300.coins,
    'piggy-bank': LucideIcons300.piggyBank,
    'credit-card': LucideIcons300.creditCard,
    'landmark': LucideIcons300.landmark,
    'trending-up': LucideIcons300.trendingUp,
    'receipt': LucideIcons300.receipt,
    // Income
    'arrow-up': LucideIcons300.arrowUp,
    'briefcase': LucideIcons300.briefcase,
    'gift': LucideIcons300.gift,
    // Everyday life
    'shirt': LucideIcons300.shirt,
    'shopping-bag': LucideIcons300.shoppingBag,
    'graduation-cap': LucideIcons300.graduationCap,
    'baby': LucideIcons300.baby,
    'paw-print': LucideIcons300.pawPrint,
    'hand-heart': LucideIcons300.handHeart,
  };

  /// The glyphs the system catalog draws its categories with beyond
  /// [glyphs]: one fitting glyph per catalog entry. Resolved like the curated
  /// set, but not offered by the picker, which stays a short list a user can
  /// scan.
  static const catalogGlyphs = <String, IconData>{
    // Logement
    'umbrella': LucideIcons300.umbrella,
    'building-2': LucideIcons300.building2,
    'hammer': LucideIcons300.hammer,
    'spray-can': LucideIcons300.sprayCan,
    // Alimentation
    'utensils-crossed': LucideIcons300.utensilsCrossed,
    'pizza': LucideIcons300.pizza,
    'sandwich': LucideIcons300.sandwich,
    // Transport
    'square-parking': LucideIcons300.squareParking,
    'shield-check': LucideIcons300.shieldCheck,
    'route': LucideIcons300.route,
    'car-taxi-front': LucideIcons300.carTaxiFront,
    'car-front': LucideIcons300.carFront,
    // Santé
    'heart-pulse': LucideIcons300.heartPulse,
    'stethoscope': LucideIcons300.stethoscope,
    'shield-plus': LucideIcons300.shieldPlus,
    'smile': LucideIcons300.smile,
    'glasses': LucideIcons300.glasses,
    // Loisirs
    'ferris-wheel': LucideIcons300.ferrisWheel,
    'bed-double': LucideIcons300.bedDouble,
    // Achats
    'monitor-smartphone': LucideIcons300.monitorSmartphone,
    'scissors': LucideIcons300.scissors,
    // Finances
    'wallet': LucideIcons300.wallet,
    'scroll-text': LucideIcons300.scrollText,
    'badge-percent': LucideIcons300.badgePercent,
    'chart-line': LucideIcons300.chartLine,
    'hand-coins': LucideIcons300.handCoins,
    // Revenus
    'banknote-arrow-up': LucideIcons300.banknoteArrowUp,
    'armchair': LucideIcons300.armchair,
    'rotate-ccw': LucideIcons300.rotateCcw,
    'hand-helping': LucideIcons300.handHelping,
    'building': LucideIcons300.building,
    'tag': LucideIcons300.tag,
    'circle-plus': LucideIcons300.circlePlus,
    // Divers
    'shapes': LucideIcons300.shapes,
    'circle-help': LucideIcons300.circleHelp,
    'banknote': LucideIcons300.banknote,
    // Enfants
    'heart-handshake': LucideIcons300.heartHandshake,
    'school': LucideIcons300.school,
    'puzzle': LucideIcons300.puzzle,
    // Animaux
    'bone': LucideIcons300.bone,
    'syringe': LucideIcons300.syringe,
  };

  /// The Lucide key each category slug is drawn with when a row's own key is
  /// unknown: its top-level bucket's glyph, the one the system catalog stores
  /// for it. Paired with the slug's hue, so a category carries its identity
  /// twice over: meaning is never on color alone.
  static const slugKeys = <String, String>{
    'logement': 'house',
    'alimentation': 'utensils',
    'transport': 'car',
    'loisirs': 'ferris-wheel',
    'abonnements': 'refresh-cw',
    'sante': 'heart-pulse',
    'achats': 'shopping-bag',
    'finances': 'wallet',
    'enfants': 'baby',
    'animaux': 'paw-print',
    'autres': 'shapes',
    'epargne': 'piggy-bank',
    'revenus': 'banknote-arrow-up',
  };

  /// The key a new custom category starts on in the form: a curated glyph,
  /// so the picker shows it selected.
  static const defaultKey = 'coins';

  /// The glyph for a key nothing resolves: Lucide's tag, the categories
  /// destination's own glyph.
  static const fallback = LucideIcons300.tag;

  /// The « Non catégorisé » glyph.
  static const uncategorized = LucideIcons300.circleHelp;

  /// The stored icon key itself when this set draws it, `null` otherwise.
  static String? resolveKey(String? key) =>
      glyphs.containsKey(key) || catalogGlyphs.containsKey(key) ? key : null;

  /// The glyph for a stored icon key, [fallback] when it resolves to nothing.
  static IconData forKey(String? key) {
    final resolved = resolveKey(key);
    return glyphs[resolved] ?? catalogGlyphs[resolved] ?? fallback;
  }

  /// The glyph for a category slug, [fallback] for an unknown one.
  static IconData forSlug(String? slug) => forKey(slugKeys[slug]);
}
