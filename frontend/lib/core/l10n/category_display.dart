import '../../l10n/app_localizations.dart';

/// Resolves an embedded/picker category to one of the eight pinned
/// design-system hues (`CategoryHues`/`CategoryIcons` in `core/theme/tokens.dart`
/// and `core/widgets/category_chip.dart`).
///
/// The backend's system catalog (`backend/app/core/seed.py`) seeds ~70
/// categories and subcategories — more than the eight hues `docs/design/00`
/// pins, since several categories (Achats, Finances, Divers) intentionally
/// share the neutral "Autres/Épargne" catch-all. `seed.py`'s `color` is kept
/// in lockstep with the pinned hues (the design spec is the single source of
/// truth for color), so this bucketing and the backend's own `color` field
/// agree — the bucket is still needed here because a slug, not a hex string,
/// is what picks the matching glyph from `CategoryIcons`.
///
/// System category names are i18n keys shaped `category.<bucket>` or
/// `category.<bucket>.<child>` (see seed.py) — the bucket segment is what we
/// key off, with no need for a `parent_id` the embedded transaction category
/// doesn't carry. User-created categories have no such key, so they fall back
/// to their `kind`.
///
/// Lives in `core/l10n/` rather than a feature folder because both the
/// transactions and dashboard features resolve category display names — see
/// the architecture skill's "logic needed by two features? extract it" rule.
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
      case 'subscriptions':
        return 'abonnements';
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
String localizedCategoryName(
  AppLocalizations l10n,
  String name,
) => switch (name) {
  'category.housing' => l10n.categorySystemHousing,
  'category.housing.rent' => l10n.categorySystemHousingRent,
  'category.housing.mortgage' => l10n.categorySystemHousingMortgage,
  'category.housing.utilities' => l10n.categorySystemHousingUtilities,
  'category.housing.home_insurance' => l10n.categorySystemHousingHomeInsurance,
  'category.housing.condo_fees' => l10n.categorySystemHousingCondoFees,
  'category.housing.maintenance' => l10n.categorySystemHousingMaintenance,
  'category.housing.home_services' => l10n.categorySystemHousingHomeServices,
  'category.food' => l10n.categorySystemFood,
  'category.food.groceries' => l10n.categorySystemFoodGroceries,
  'category.food.restaurants' => l10n.categorySystemFoodRestaurants,
  'category.food.coffee' => l10n.categorySystemFoodCoffee,
  'category.food.takeaway' => l10n.categorySystemFoodTakeaway,
  'category.food.canteen' => l10n.categorySystemFoodCanteen,
  'category.transport' => l10n.categorySystemTransport,
  'category.transport.fuel' => l10n.categorySystemTransportFuel,
  'category.transport.public_transit' =>
    l10n.categorySystemTransportPublicTransit,
  'category.transport.parking' => l10n.categorySystemTransportParking,
  'category.transport.car_maintenance' =>
    l10n.categorySystemTransportCarMaintenance,
  'category.transport.car_insurance' =>
    l10n.categorySystemTransportCarInsurance,
  'category.transport.tolls' => l10n.categorySystemTransportTolls,
  'category.transport.taxi' => l10n.categorySystemTransportTaxi,
  'category.transport.rental' => l10n.categorySystemTransportRental,
  'category.health' => l10n.categorySystemHealth,
  'category.health.doctor' => l10n.categorySystemHealthDoctor,
  'category.health.pharmacy' => l10n.categorySystemHealthPharmacy,
  'category.health.insurance' => l10n.categorySystemHealthInsurance,
  'category.health.dentist' => l10n.categorySystemHealthDentist,
  'category.health.optician' => l10n.categorySystemHealthOptician,
  'category.leisure' => l10n.categorySystemLeisure,
  'category.leisure.outings' => l10n.categorySystemLeisureOutings,
  'category.leisure.travel' => l10n.categorySystemLeisureTravel,
  'category.leisure.accommodation' => l10n.categorySystemLeisureAccommodation,
  'category.leisure.sports' => l10n.categorySystemLeisureSports,
  'category.leisure.culture' => l10n.categorySystemLeisureCulture,
  'category.subscriptions' => l10n.categorySystemSubscriptions,
  'category.shopping' => l10n.categorySystemShopping,
  'category.shopping.clothing' => l10n.categorySystemShoppingClothing,
  'category.shopping.electronics' => l10n.categorySystemShoppingElectronics,
  'category.shopping.home' => l10n.categorySystemShoppingHome,
  'category.shopping.personal_care' => l10n.categorySystemShoppingPersonalCare,
  'category.shopping.gifts' => l10n.categorySystemShoppingGifts,
  'category.finance' => l10n.categorySystemFinance,
  'category.finance.bank_fees' => l10n.categorySystemFinanceBankFees,
  'category.finance.taxes' => l10n.categorySystemFinanceTaxes,
  'category.finance.savings' => l10n.categorySystemFinanceSavings,
  'category.finance.card_settlement' =>
    l10n.categorySystemFinanceCardSettlement,
  'category.finance.interest' => l10n.categorySystemFinanceInterest,
  'category.finance.investments' => l10n.categorySystemFinanceInvestments,
  'category.finance.loans' => l10n.categorySystemFinanceLoans,
  'category.income' => l10n.categorySystemIncome,
  'category.income.salary' => l10n.categorySystemIncomeSalary,
  'category.income.pension' => l10n.categorySystemIncomePension,
  'category.income.dividends' => l10n.categorySystemIncomeDividends,
  'category.income.refunds' => l10n.categorySystemIncomeRefunds,
  'category.income.benefits' => l10n.categorySystemIncomeBenefits,
  'category.income.rental' => l10n.categorySystemIncomeRental,
  'category.income.sales' => l10n.categorySystemIncomeSales,
  'category.income.other' => l10n.categorySystemIncomeOther,
  'category.other' => l10n.categorySystemOther,
  'category.other.uncategorized' => l10n.categorySystemOtherUncategorized,
  'category.other.cash' => l10n.categorySystemOtherCash,
  'category.other.donations' => l10n.categorySystemOtherDonations,
  'category.children' => l10n.categorySystemChildren,
  'category.children.childcare' => l10n.categorySystemChildrenChildcare,
  'category.children.school' => l10n.categorySystemChildrenSchool,
  'category.children.activities' => l10n.categorySystemChildrenActivities,
  'category.pets' => l10n.categorySystemPets,
  'category.pets.food' => l10n.categorySystemPetsFood,
  'category.pets.vet' => l10n.categorySystemPetsVet,
  _ => name,
};
