import '../../../l10n/app_localizations.dart';
import '../domain/account.dart';

/// The localized label for an account type. Shared so the account form and
/// anything proposing an account (the imports panel, naming an account it read
/// out of a statement) name the same type the same way.
String accountTypeLabel(AppLocalizations l10n, AccountType type) =>
    switch (type) {
      AccountType.checking => l10n.accountTypeChecking,
      AccountType.savings => l10n.accountTypeSavings,
      AccountType.credit => l10n.accountTypeCredit,
      AccountType.deferredCard => l10n.accountTypeDeferredCard,
      AccountType.cash => l10n.accountTypeCash,
      AccountType.other => l10n.accountTypeOther,
    };
