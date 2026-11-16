import '../../../l10n/app_localizations.dart';

/// The localized name of a category kind (`income` · `expense` · `transfer`).
///
/// A function over the wire value rather than an enum: `kind` is a string in
/// the API and a `switch` here fails loudly the day the backend grows a fourth
/// one, where a silent `_ =>` default would show an empty select.
String categoryKindLabel(AppLocalizations l10n, String kind) => switch (kind) {
  'income' => l10n.categoryKindIncome,
  'transfer' => l10n.categoryKindTransfer,
  _ => l10n.categoryKindExpense,
};

/// The localized name of a glyph in the form's icon picker.
///
/// The picker offers a curated Lucide set by key (see `CategoryIcons` in
/// `core/widgets/category_icons.dart`), so what is stored is a key the app can
/// always render — never a raw icon codepoint that a later icon-set change
/// would turn into a blank square. A key outside the set reads « Autre ».
String categoryIconLabel(AppLocalizations l10n, String key) => switch (key) {
  'house' => l10n.categoryIconHousing,
  'key-round' => l10n.categoryIconKey,
  'zap' => l10n.categoryIconEnergy,
  'wrench' => l10n.categoryIconRepairs,
  'sofa' => l10n.categoryIconFurniture,
  'soup' => l10n.categoryIconFood,
  'shopping-cart' => l10n.categoryIconGroceries,
  'utensils' => l10n.categoryIconRestaurant,
  'coffee' => l10n.categoryIconCoffee,
  'car' => l10n.categoryIconTransport,
  'bus' => l10n.categoryIconPublicTransport,
  'fuel' => l10n.categoryIconFuel,
  'plane' => l10n.categoryIconTravel,
  'star' => l10n.categoryIconLeisure,
  'ticket' => l10n.categoryIconOutings,
  'gamepad-2' => l10n.categoryIconGames,
  'book-open' => l10n.categoryIconReading,
  'dumbbell' => l10n.categoryIconSport,
  'refresh-cw' => l10n.categoryIconSubscriptions,
  'smartphone' => l10n.categoryIconPhone,
  'wifi' => l10n.categoryIconInternet,
  'cross' => l10n.categoryIconHealth,
  'pill' => l10n.categoryIconPharmacy,
  'piggy-bank' => l10n.categoryIconSavings,
  'credit-card' => l10n.categoryIconCard,
  'landmark' => l10n.categoryIconBank,
  'trending-up' => l10n.categoryIconInvestments,
  'receipt' => l10n.categoryIconBills,
  'arrow-up' => l10n.categoryIconIncome,
  'briefcase' => l10n.categoryIconSalary,
  'gift' => l10n.categoryIconGifts,
  'shirt' => l10n.categoryIconClothing,
  'shopping-bag' => l10n.categoryIconShopping,
  'graduation-cap' => l10n.categoryIconEducation,
  'baby' => l10n.categoryIconChildren,
  'paw-print' => l10n.categoryIconPets,
  'hand-heart' => l10n.categoryIconDonations,
  _ => l10n.categoryIconOther,
};
