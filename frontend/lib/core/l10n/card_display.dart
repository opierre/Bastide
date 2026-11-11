import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// The glyph leading a linked card's transaction row, wherever the card's
/// purchases are listed with the account that settles them.
const IconData cardRowIcon = Icons.credit_card_rounded;

/// How a linked card's transaction row names its card: the card's name and,
/// when known, its masked number.
///
/// Lives in `core/l10n/` because both the account detail and the Transactions
/// panel mark these rows the same way — see the architecture skill's "logic
/// needed by two features? extract it" rule.
String cardRowLabel(AppLocalizations l10n, String name, String? lastDigits) =>
    lastDigits == null ? name : l10n.transactionRowCardLabel(name, lastDigits);
