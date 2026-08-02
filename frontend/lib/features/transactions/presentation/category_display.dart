import '../../../l10n/app_localizations.dart';

/// Resolves an embedded/picker category to one of the eight pinned
/// design-system hues (`CategoryHues`/`CategoryIcons` in `core/theme/tokens.dart`
/// and `core/widgets/category_chip.dart`).
///
/// The backend's system catalog (`backend/app/core/seed.py`) seeds ~30
/// categories and subcategories, each carrying its own hex `color` — richer
/// than, and different from, the eight hues `docs/design/00` pins. Per
/// product decision, chips stay on the pinned palette rather than the
/// backend's per-category color: every category (including subcategories) is
/// bucketed under its top-level parent's pinned slug instead.
///
/// System category names are i18n keys shaped `category.<bucket>` or
/// `category.<bucket>.<child>` (see seed.py) — the bucket segment is what we
/// key off, with no need for a `parent_id` the embedded transaction category
/// doesn't carry. User-created categories have no such key, so they fall back
/// to their `kind`.
String categorySlugFor({required String name, required String kind}) {
  // A savings-flavoured category reads as "épargne" regardless of which
  // bucket it lives under (e.g. `category.finance.savings`).
  if (kind == 'transfer') return 'epargne';

  if (name.startsWith('category.')) {
    final segments = name.split('.');
    final bucket = segments.length > 1 ? segments[1] : '';
    switch (bucket) {
      case 'housing':
        return 'logement';
      case 'food':
        return 'alimentation';
      case 'transport':
        return 'transport';
      case 'health':
        return 'sante';
      case 'leisure':
        return 'loisirs';
      case 'income':
        return 'revenus';
      default:
        return 'autres';
    }
  }

  return switch (kind) {
    'income' => 'revenus',
    _ => 'autres',
  };
}

/// Resolves a category's display name: system categories carry an i18n key
/// (`category.housing.rent`) that this maps to the matching ARB entry; user
/// categories carry free text, returned as-is — see the i18n-l10n skill.
String localizedCategoryName(AppLocalizations l10n, String name) => switch (name) {
  'category.housing' => l10n.categorySystemHousing,
  'category.housing.rent' => l10n.categorySystemHousingRent,
  'category.housing.mortgage' => l10n.categorySystemHousingMortgage,
  'category.housing.utilities' => l10n.categorySystemHousingUtilities,
  'category.housing.home_insurance' => l10n.categorySystemHousingHomeInsurance,
  'category.food' => l10n.categorySystemFood,
  'category.food.groceries' => l10n.categorySystemFoodGroceries,
  'category.food.restaurants' => l10n.categorySystemFoodRestaurants,
  'category.food.coffee' => l10n.categorySystemFoodCoffee,
  'category.transport' => l10n.categorySystemTransport,
  'category.transport.fuel' => l10n.categorySystemTransportFuel,
  'category.transport.public_transit' => l10n.categorySystemTransportPublicTransit,
  'category.transport.parking' => l10n.categorySystemTransportParking,
  'category.transport.car_maintenance' => l10n.categorySystemTransportCarMaintenance,
  'category.health' => l10n.categorySystemHealth,
  'category.health.doctor' => l10n.categorySystemHealthDoctor,
  'category.health.pharmacy' => l10n.categorySystemHealthPharmacy,
  'category.health.insurance' => l10n.categorySystemHealthInsurance,
  'category.leisure' => l10n.categorySystemLeisure,
  'category.leisure.subscriptions' => l10n.categorySystemLeisureSubscriptions,
  'category.leisure.outings' => l10n.categorySystemLeisureOutings,
  'category.leisure.travel' => l10n.categorySystemLeisureTravel,
  'category.shopping' => l10n.categorySystemShopping,
  'category.shopping.clothing' => l10n.categorySystemShoppingClothing,
  'category.shopping.electronics' => l10n.categorySystemShoppingElectronics,
  'category.shopping.home' => l10n.categorySystemShoppingHome,
  'category.finance' => l10n.categorySystemFinance,
  'category.finance.bank_fees' => l10n.categorySystemFinanceBankFees,
  'category.finance.taxes' => l10n.categorySystemFinanceTaxes,
  'category.finance.savings' => l10n.categorySystemFinanceSavings,
  'category.finance.interest' => l10n.categorySystemFinanceInterest,
  'category.income' => l10n.categorySystemIncome,
  'category.income.salary' => l10n.categorySystemIncomeSalary,
  'category.income.refunds' => l10n.categorySystemIncomeRefunds,
  'category.income.other' => l10n.categorySystemIncomeOther,
  'category.other' => l10n.categorySystemOther,
  'category.other.uncategorized' => l10n.categorySystemOtherUncategorized,
  _ => name,
};
