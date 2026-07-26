// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'FinStride';

  @override
  String get navDashboard => 'Dashboard';

  @override
  String get navAccounts => 'Accounts';

  @override
  String get navTransactions => 'Transactions';

  @override
  String get navImports => 'Imports';

  @override
  String get navCategories => 'Categories';

  @override
  String get navSettings => 'Settings';

  @override
  String get navSectionOverview => 'Overview';

  @override
  String get navSectionManage => 'Manage';

  @override
  String get navDashboardSubtitle => 'Your month at a glance';

  @override
  String get navAccountsSubtitle => 'All your accounts, one currency';

  @override
  String get navTransactionsSubtitle => 'Every transaction, in a single feed';

  @override
  String get navImportsSubtitle =>
      'OFX, QFX and CSV statements — processed on this computer';

  @override
  String get navCategoriesSubtitle =>
      'Organize your spending, automate it with rules';

  @override
  String get navSettingsSubtitle => 'Profile, preferences and your local data';

  @override
  String get sidebarPrivacyBadge => 'All data stays on this device';

  @override
  String get sidebarCollapse => 'Collapse menu';

  @override
  String get sidebarExpand => 'Expand menu';

  @override
  String get userMenuLogout => 'Log out';

  @override
  String get comingSoonTitle => 'Coming soon';

  @override
  String get comingSoonBody =>
      'This screen arrives in a later step. In the meantime, add your accounts to get set up.';

  @override
  String get authLoginTitle => 'Log in';

  @override
  String get authRegisterTitle => 'Create an account';

  @override
  String get authTagline => 'Your money, clearly.';

  @override
  String get authPrivacyLine =>
      'Local and private — your data never leaves this computer.';

  @override
  String get authLoginSubmitting => 'Signing in…';

  @override
  String get authPasswordShow => 'Show password';

  @override
  String get authPasswordHide => 'Hide password';

  @override
  String get authEmailLabel => 'Email address';

  @override
  String get authPasswordLabel => 'Password';

  @override
  String get authDisplayNameLabel => 'Display name';

  @override
  String get authPasswordStrengthWeak => 'Too weak';

  @override
  String get authPasswordStrengthFair => 'Fair';

  @override
  String get authPasswordStrengthStrong => 'Strong';

  @override
  String get authPasswordStrengthHint =>
      'Add a few more characters, a digit and a capital letter.';

  @override
  String get authPreferencesNote =>
      'You can change the language later; the currency applies to all your accounts and cannot be changed in this version.';

  @override
  String get authEmailTaken =>
      'That email is already in use — sign in instead.';

  @override
  String get authEmailInvalid => 'Enter a valid email address.';

  @override
  String get currencyNameEUR => 'Euro';

  @override
  String get currencyNameUSD => 'US Dollar';

  @override
  String get currencyNameGBP => 'British Pound';

  @override
  String get currencyNameCHF => 'Swiss Franc';

  @override
  String get currencyNameCAD => 'Canadian Dollar';

  @override
  String get currencyNameJPY => 'Japanese Yen';

  @override
  String get currencyNameAUD => 'Australian Dollar';

  @override
  String get currencyNameCNY => 'Chinese Yuan';

  @override
  String get currencyNameINR => 'Indian Rupee';

  @override
  String get currencyNameBRL => 'Brazilian Real';

  @override
  String get currencyNameMXN => 'Mexican Peso';

  @override
  String get currencyNameSEK => 'Swedish Krona';

  @override
  String get currencyNameNOK => 'Norwegian Krone';

  @override
  String get currencyNameDKK => 'Danish Krone';

  @override
  String get currencyNamePLN => 'Polish Zloty';

  @override
  String get currencyNameCZK => 'Czech Koruna';

  @override
  String get currencyNameHUF => 'Hungarian Forint';

  @override
  String get currencyNameRON => 'Romanian Leu';

  @override
  String get currencyNameZAR => 'South African Rand';

  @override
  String get currencyNameAED => 'UAE Dirham';

  @override
  String get currencyNameSGD => 'Singapore Dollar';

  @override
  String get currencyNameHKD => 'Hong Kong Dollar';

  @override
  String get currencyNameNZD => 'New Zealand Dollar';

  @override
  String get currencyNameTRY => 'Turkish Lira';

  @override
  String get currencyNameILS => 'Israeli Shekel';

  @override
  String get currencyNameKRW => 'South Korean Won';

  @override
  String get currencyNameTHB => 'Thai Baht';

  @override
  String get currencyNameMAD => 'Moroccan Dirham';

  @override
  String get currencyNameXOF => 'West African CFA Franc';

  @override
  String get currencyNameXAF => 'Central African CFA Franc';

  @override
  String get authLocaleLabel => 'Language';

  @override
  String get authLocaleFrench => 'Français';

  @override
  String get authLocaleEnglish => 'English';

  @override
  String get authCurrencyLabel => 'Currency';

  @override
  String get authLoginSubmit => 'Log in';

  @override
  String get authRegisterSubmit => 'Create account';

  @override
  String get authGoToRegister => 'Don\'t have an account? Register';

  @override
  String get authGoToLogin => 'Already have an account? Log in';

  @override
  String get authEmailRequired => 'Email is required.';

  @override
  String get authPasswordRequired => 'Password is required.';

  @override
  String get authDisplayNameRequired => 'Display name is required.';

  @override
  String get authErrorInvalidCredentials =>
      'Incorrect email or password. Check your details and try again.';

  @override
  String get authErrorEmailTaken =>
      'An account with this email already exists.';

  @override
  String get authErrorValidation => 'Some information is invalid.';

  @override
  String get authErrorGeneric => 'Something went wrong. Please try again.';

  @override
  String get accountsAddButton => 'Add account';

  @override
  String get accountsTotalBalanceLabel => 'Total balance';

  @override
  String accountsActiveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count active accounts',
      one: '1 active account',
      zero: 'No active accounts',
    );
    return '$_temp0';
  }

  @override
  String get accountsEmptyTitle => 'Add your first account';

  @override
  String get accountsEmptyBody =>
      'Track your balances and activity in one place.';

  @override
  String get accountsRetry => 'Retry';

  @override
  String get accountEdit => 'Edit';

  @override
  String get accountArchive => 'Archive';

  @override
  String get accountFormCancel => 'Cancel';

  @override
  String get accountArchiveConfirmTitle => 'Archive this account?';

  @override
  String get accountArchiveConfirmBody =>
      'You\'ll still be able to view its history, but it will no longer appear in your accounts list.';

  @override
  String get accountFormCreateTitle => 'New account';

  @override
  String get accountFormEditTitle => 'Edit account';

  @override
  String get accountNameLabel => 'Name';

  @override
  String get accountNameRequired => 'Name is required.';

  @override
  String get accountTypeLabel => 'Type';

  @override
  String get accountTypeChecking => 'Checking';

  @override
  String get accountTypeSavings => 'Savings';

  @override
  String get accountTypeCredit => 'Credit card';

  @override
  String get accountTypeCash => 'Cash';

  @override
  String get accountTypeOther => 'Other';

  @override
  String get accountInstitutionLabel => 'Institution';

  @override
  String get accountInstitutionRequired => 'Institution is required.';

  @override
  String get accountOpeningBalanceLabel => 'Opening balance';

  @override
  String get accountOpeningBalanceRequired => 'Opening balance is required.';

  @override
  String get accountOpeningBalanceInvalid => 'Enter a valid amount.';

  @override
  String get accountCurrencyLabel => 'Currency';

  @override
  String get accountFormSubmitCreate => 'Create account';

  @override
  String get accountFormSubmitEdit => 'Save';

  @override
  String get accountErrorNotFound => 'Account not found.';

  @override
  String get accountErrorValidation => 'Some information is invalid.';

  @override
  String get accountErrorGeneric => 'Something went wrong. Please try again.';
}
