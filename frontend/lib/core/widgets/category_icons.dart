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
/// Lucide icon name (`house`, `piggy-bank`). Older rows carry keys from before
/// Lucide — a pinned category slug (`logement`) chosen in the form, or a
/// Material icon name (`home`, `restaurant`) written by the system seed — and
/// [resolveKey] maps both onto their Lucide equivalent, so no stored row needs
/// rewriting.
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

  /// The Lucide key each pinned category slug is drawn with — the glyphs
  /// `docs/design/00` names for the chips (house, bowl, car, star, refresh,
  /// cross, coin, up-arrow). Paired with the slug's pinned hue, so a chip
  /// carries its category twice over: meaning is never on color alone.
  static const slugKeys = <String, String>{
    'logement': 'house',
    'alimentation': 'soup',
    'transport': 'car',
    'loisirs': 'star',
    'abonnements': 'refresh-cw',
    'sante': 'cross',
    'autres': 'coins',
    'epargne': 'coins',
    'revenus': 'arrow-up',
  };

  /// Material icon names stored before Lucide, mapped to the nearest Lucide
  /// key. Covers the glyphs the chips used and every name the backend's
  /// system seed (`backend/app/core/seed.py`) writes.
  static const legacyMaterialKeys = <String, String>{
    // The former chip glyphs.
    'home_outlined': 'house',
    'rice_bowl_outlined': 'soup',
    'directions_car_outlined': 'car',
    'star_outline_rounded': 'star',
    'autorenew_rounded': 'refresh-cw',
    'local_hospital_outlined': 'cross',
    'monetization_on_outlined': 'coins',
    'arrow_upward_rounded': 'arrow-up',
    'sell_outlined': 'tag',
    // The system seed.
    'home': 'house',
    'key': 'key-round',
    'home_work': 'house',
    'bolt': 'zap',
    'shield_home': 'house',
    'apartment': 'house',
    'handyman': 'wrench',
    'cleaning_services': 'house',
    'chair': 'sofa',
    'restaurant': 'utensils',
    'shopping_cart': 'shopping-cart',
    'local_cafe': 'coffee',
    'lunch_dining': 'utensils',
    'takeout_dining': 'utensils',
    'directions_car': 'car',
    'directions_bus': 'bus',
    'local_gas_station': 'fuel',
    'local_parking': 'car',
    'local_taxi': 'car',
    'car_rental': 'car',
    'car_repair': 'wrench',
    'shield_car': 'car',
    'toll': 'car',
    'flight': 'plane',
    'hotel': 'plane',
    'celebration': 'star',
    'local_activity': 'ticket',
    'fitness_center': 'dumbbell',
    'menu_book': 'book-open',
    'spa': 'star',
    'toys': 'gamepad-2',
    'subscriptions': 'refresh-cw',
    'devices': 'smartphone',
    'health_and_safety': 'cross',
    'medical_services': 'cross',
    'local_pharmacy': 'pill',
    'dentistry': 'cross',
    'vaccines': 'pill',
    'visibility': 'cross',
    'shield_health': 'cross',
    'elderly': 'cross',
    'account_balance': 'landmark',
    'credit_card': 'credit-card',
    'credit_score': 'credit-card',
    'atm': 'credit-card',
    'payments': 'coins',
    'receipt_long': 'receipt',
    'real_estate_agent': 'house',
    'savings': 'piggy-bank',
    'show_chart': 'trending-up',
    'trending_up': 'trending-up',
    'attach_money': 'coins',
    'work': 'briefcase',
    'add_circle': 'arrow-up',
    'replay': 'refresh-cw',
    'redeem': 'gift',
    'sell': 'tag',
    'shopping_bag': 'shopping-bag',
    'checkroom': 'shirt',
    'child_care': 'baby',
    'child_friendly': 'baby',
    'family_restroom': 'baby',
    'school': 'graduation-cap',
    'pets': 'paw-print',
    'pet_supplies': 'paw-print',
    'volunteer_activism': 'hand-heart',
    'category': 'tag',
    'help': 'tag',
  };

  /// The glyph for a key nothing resolves: Lucide's tag, the categories
  /// destination's own glyph.
  static const fallback = LucideIcons300.tag;

  /// The « Non catégorisé » glyph.
  static const uncategorized = LucideIcons300.circleHelp;

  /// The Lucide key a stored icon key stands for, or `null` when it names
  /// nothing this set knows. A current key resolves to itself; a pre-Lucide
  /// slug or Material name to its mapped equivalent.
  static String? resolveKey(String? key) {
    if (key == null) return null;
    if (glyphs.containsKey(key)) return key;
    final mapped = slugKeys[key] ?? legacyMaterialKeys[key];
    return mapped != null && glyphs.containsKey(mapped) ? mapped : null;
  }

  /// The glyph for a stored icon key, [fallback] when it resolves to nothing.
  static IconData forKey(String? key) => glyphs[resolveKey(key)] ?? fallback;

  /// The glyph for a pinned category slug, [fallback] for an unknown one.
  static IconData forSlug(String? slug) => forKey(slugKeys[slug]);
}
