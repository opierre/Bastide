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
/// The picker offers the design system's pinned category glyphs by slug (see
/// `CategoryIcons` in `core/widgets/category_chip.dart`), so what is stored is
/// a slug the app can always render — never a raw icon codepoint that a later
/// icon-set change would turn into a blank square.
String categoryIconLabel(AppLocalizations l10n, String slug) => switch (slug) {
  'logement' => l10n.categoryIconHousing,
  'alimentation' => l10n.categoryIconFood,
  'transport' => l10n.categoryIconTransport,
  'loisirs' => l10n.categoryIconLeisure,
  'abonnements' => l10n.categoryIconSubscriptions,
  'sante' => l10n.categoryIconHealth,
  'revenus' => l10n.categoryIconIncome,
  'epargne' => l10n.categoryIconSavings,
  _ => l10n.categoryIconOther,
};
