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
  String get navDashboardSubtitle => 'Your financial picture at a glance';

  @override
  String get navAccountsSubtitle => 'Your accounts and their balances';

  @override
  String get navTransactionsSubtitle => 'Every movement, categorized';

  @override
  String get navImportsSubtitle => 'Bring in your OFX and CSV statements';

  @override
  String get navCategoriesSubtitle => 'Organize where your money goes';

  @override
  String get navSettingsSubtitle => 'Preferences and account';

  @override
  String get userMenuLogout => 'Log out';

  @override
  String get statusBarReady => 'Ready';

  @override
  String get statusBarLocalData => 'Local data';

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
  String get authTagline =>
      'Your finances, on your machine. Nothing leaves it.';

  @override
  String get authEmailLabel => 'Email';

  @override
  String get authPasswordLabel => 'Password';

  @override
  String get authDisplayNameLabel => 'Display name';

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
  String get authErrorInvalidCredentials => 'Incorrect email or password.';

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
