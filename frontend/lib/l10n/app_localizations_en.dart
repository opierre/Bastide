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
  String get settingsSectionProfile => 'Profile';

  @override
  String get settingsSectionPreferences => 'Preferences';

  @override
  String get settingsSectionData => 'Data';

  @override
  String get settingsSectionAbout => 'About';

  @override
  String get settingsLanguageTitle => 'Language';

  @override
  String get settingsLanguageNote =>
      'Applies immediately across the whole interface.';

  @override
  String get settingsCurrencyTitle => 'Currency';

  @override
  String get settingsCurrencyNote =>
      'Chosen when you registered and applied to all your accounts. It cannot be changed in this version.';

  @override
  String get settingsFormatsTitle => 'Format preview';

  @override
  String get settingsFormatsDates => 'Dates';

  @override
  String get settingsFormatsAmounts => 'Amounts';

  @override
  String get settingsAboutVersion => 'Version';

  @override
  String get settingsAboutPrivacy =>
      'All your data stays on this computer. FinStride connects to no bank and sends nothing over the internet.';

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
  String get accountsSearchHint => 'Search…';

  @override
  String get accountsSearchEmpty => 'No account matches your search.';

  @override
  String accountsBalancesAsOf(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Balances as of $dateString';
  }

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
  String get accountFormPrefilledNote => 'Pre-filled from your statement.';

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
  String get accountTypeDeferredCard => 'Deferred debit card';

  @override
  String get accountTypeCash => 'Cash';

  @override
  String get accountTypeOther => 'Other';

  @override
  String get accountInstitutionLabel => 'Institution';

  @override
  String get accountInstitutionRequired => 'Institution is required.';

  @override
  String get accountInstitutionFromStatementNote =>
      'Taken from the institution your statement declares.';

  @override
  String get accountOpeningBalanceLabel => 'Opening balance';

  @override
  String get accountCurrentBalanceLabel => 'Current balance';

  @override
  String accountBalanceAsOfLabel(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Balance as of $dateString';
  }

  @override
  String get accountBalanceStatementNote =>
      'Adjusted automatically from the balance your statement declares, on the first import.';

  @override
  String get accountBalanceFromStatementNote =>
      'Taken from the balance your statement declares.';

  @override
  String get accountOpeningBalanceEditNote =>
      'Correcting this shifts the account\'s balance and any saved history by the same amount — it never touches a transaction.';

  @override
  String get accountOpeningBalanceRequired => 'Balance is required.';

  @override
  String get accountOpeningBalanceInvalid => 'Enter a valid amount.';

  @override
  String get accountFormSubmitCreate => 'Create account';

  @override
  String get accountFormSubmitEdit => 'Save';

  @override
  String get accountErrorNotFound => 'Account not found.';

  @override
  String get accountErrorOfxIdTaken =>
      'Another account already uses this bank account id.';

  @override
  String get accountErrorValidation => 'Some information is invalid.';

  @override
  String get accountErrorGeneric => 'Something went wrong. Please try again.';

  @override
  String get importNewTitle => 'New import';

  @override
  String get importAccountLabel => 'Destination account';

  @override
  String get importAccountsUnavailable =>
      'Couldn\'t load your accounts. Try again in a moment.';

  @override
  String get importDropZoneTitle => 'Drop an OFX, QFX or CSV file';

  @override
  String get importDropZoneHint =>
      'or click to browse — a CSV opens the mapping wizard';

  @override
  String importFileSize(String size) {
    return '$size kB';
  }

  @override
  String get importRemoveFile => 'Remove file';

  @override
  String get importSubmit => 'Import';

  @override
  String get importSubmitting => 'Importing…';

  @override
  String get importOpenWizard => 'Set up and import';

  @override
  String importTemplateReuse(String bank) {
    return 'CSV format saved for $bank — it will be reused for this file.';
  }

  @override
  String get importReconfigureTemplate => 'Reconfigure';

  @override
  String importDetectedAccount(String account) {
    return 'Account recognized in the file: $account.';
  }

  @override
  String importDetectedAccountAmbiguous(String account) {
    return 'This statement is from $account, but several accounts match it — choose the destination.';
  }

  @override
  String importDetectedAccountUnknown(String account) {
    return 'No account matches this statement\'s account $account.';
  }

  @override
  String get importCreateDetectedAccount => 'Create this account';

  @override
  String get importResultTitle => 'Last import';

  @override
  String importResultNewLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'new transactions',
      one: 'new transaction',
      zero: 'no new transactions',
    );
    return '$_temp0';
  }

  @override
  String importResultDuplicateLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'duplicates skipped',
      one: 'duplicate skipped',
      zero: 'no duplicates',
    );
    return '$_temp0';
  }

  @override
  String importResultTarget(String file, String account) {
    return '$file → $account';
  }

  @override
  String importResultBalanceMismatchBody(String amount, DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'The statement declares a balance $amount from your ledger as of $dateString. Check for a missed import, or correct the account\'s opening balance if this keeps happening.';
  }

  @override
  String importPeriodRange(DateTime start, DateTime end) {
    final intl.DateFormat startDateFormat = intl.DateFormat.yMd(localeName);
    final String startString = startDateFormat.format(start);
    final intl.DateFormat endDateFormat = intl.DateFormat.yMd(localeName);
    final String endString = endDateFormat.format(end);

    return '$startString – $endString';
  }

  @override
  String get importFailedNote =>
      'The file couldn\'t be read — nothing was changed.';

  @override
  String importDuplicatesNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions already present, skipped',
      one: '1 transaction already present, skipped',
    );
    return '$_temp0';
  }

  @override
  String importBalanceMismatchNote(String amount, DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Off by $amount from the bank\'s balance as of $dateString.';
  }

  @override
  String get importStatusSuccess => 'Succeeded';

  @override
  String get importStatusPartial => 'Partial';

  @override
  String get importStatusFailed => 'Failed';

  @override
  String get importHistoryTitle => 'Import history';

  @override
  String get importHistoryEmptyTitle => 'No imports yet';

  @override
  String get importHistoryEmptyBody =>
      'Drop a statement above and your transactions will appear here.';

  @override
  String get importHistoryFileHeader => 'File';

  @override
  String get importHistoryFormatHeader => 'Format';

  @override
  String get importHistoryImportedHeader => 'Imported on';

  @override
  String get importHistoryPeriodHeader => 'Period covered';

  @override
  String get importHistoryNewHeader => 'New';

  @override
  String get importHistoryDuplicatesHeader => 'Duplicates';

  @override
  String get importHistoryStatusHeader => 'Status';

  @override
  String get importRetry => 'Try again';

  @override
  String get csvWizardTitle => 'CSV wizard';

  @override
  String get csvWizardStepFormat => 'Format';

  @override
  String get csvWizardStepColumns => 'Columns & preview';

  @override
  String get csvWizardCancel => 'Cancel';

  @override
  String get csvWizardNext => 'Continue';

  @override
  String get csvWizardConfirm => 'Confirm and import';

  @override
  String get csvWizardConfirming => 'Importing…';

  @override
  String get csvWizardBankLabel => 'Bank';

  @override
  String get csvWizardBankHelper =>
      'This format is saved under this name and reused for every import from this bank.';

  @override
  String get csvWizardDelimiterLabel => 'Delimiter';

  @override
  String get csvDelimiterSemicolon => 'Semicolon ( ; )';

  @override
  String get csvDelimiterComma => 'Comma ( , )';

  @override
  String get csvDelimiterTab => 'Tab';

  @override
  String get csvDelimiterPipe => 'Pipe ( | )';

  @override
  String get csvWizardEncodingLabel => 'Encoding';

  @override
  String get csvWizardDateFormatLabel => 'Date format';

  @override
  String get csvWizardDecimalLabel => 'Decimal separator';

  @override
  String get csvDecimalComma => 'Comma ( , )';

  @override
  String get csvDecimalPeriod => 'Period ( . )';

  @override
  String get csvWizardAmountsLabel => 'Amounts';

  @override
  String get csvAmountStrategySigned => 'Signed';

  @override
  String get csvAmountStrategyDebitCredit => 'Debit / Credit';

  @override
  String get csvWizardHeaderOffsetLabel => 'Lines to skip';

  @override
  String get csvWizardHeaderOffsetHelper => 'Before the header row.';

  @override
  String get csvWizardColumnsHint =>
      'Give the file\'s column name (or its number, starting at 0) for each piece of information.';

  @override
  String get csvWizardColumnHint => 'Column name or number';

  @override
  String get csvWizardColumnOptional => 'optional';

  @override
  String get csvColumnBookedDate => 'Booked date';

  @override
  String get csvColumnValueDate => 'Value date';

  @override
  String get csvColumnDescription => 'Description';

  @override
  String get csvColumnAmount => 'Amount';

  @override
  String get csvColumnDebit => 'Debit';

  @override
  String get csvColumnCredit => 'Credit';

  @override
  String get csvWizardPreviewTitle => 'Preview';

  @override
  String get csvWizardPreviewPending =>
      'Fill in the required columns to see a preview.';

  @override
  String get csvWizardPreviewEmpty => 'No readable rows with these settings.';

  @override
  String get csvPreviewDateHeader => 'Date';

  @override
  String get csvPreviewDescriptionHeader => 'Description';

  @override
  String get csvPreviewAmountHeader => 'Amount';

  @override
  String get importErrorAccountNotFound => 'Account not found.';

  @override
  String get importErrorBatchNotFound => 'Import not found.';

  @override
  String get importErrorTemplateNotFound =>
      'CSV format not found — run the wizard again.';

  @override
  String get importErrorTemplateInvalid =>
      'These settings don\'t match the file — adjust the columns above.';

  @override
  String get importErrorGeneric => 'Something went wrong. Please try again.';

  @override
  String get transactionsSearchHint => 'Search a description or a merchant…';

  @override
  String get transactionsSearchEmpty => 'No transaction matches your search.';

  @override
  String get transactionsRetry => 'Retry';

  @override
  String get transactionsEmptyTitle => 'No transactions yet';

  @override
  String get transactionsEmptyBody =>
      'Import a statement to see your transactions appear here.';

  @override
  String get transactionsGoToImports => 'Go to imports';

  @override
  String get transactionsNeedsReviewLabel => 'Needs review';

  @override
  String get transactionsFilterAllAccounts => 'All accounts';

  @override
  String get transactionsFilterAllCategories => 'All categories';

  @override
  String get transactionsFilterAllDates => 'All dates';

  @override
  String transactionsPager(int from, int to, int total) {
    return '$from–$to of $total';
  }

  @override
  String get reviewQueueEmpty => 'No transactions to review.';

  @override
  String reviewQueueCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions to review',
      one: '1 transaction to review',
      zero: 'No transactions to review',
    );
    return '$_temp0';
  }

  @override
  String get reviewQueueEncouragement => 'You\'re almost there — keep going!';

  @override
  String get reviewAlwaysCategorize => 'Always categorize like this';

  @override
  String get categoryPickerSearchHint => 'Change category…';

  @override
  String get categoryPickerLoadError => 'Couldn\'t load categories.';

  @override
  String get categoryPickerEmpty => 'No category matches.';

  @override
  String get categoryUncategorized => 'Uncategorized';

  @override
  String get transactionErrorNotFound => 'Transaction not found.';

  @override
  String get transactionErrorValidation => 'Some information is invalid.';

  @override
  String get transactionErrorGeneric =>
      'Something went wrong. Please try again.';

  @override
  String get categorySystemHousing => 'Housing';

  @override
  String get categorySystemHousingRent => 'Rent';

  @override
  String get categorySystemHousingMortgage => 'Mortgage';

  @override
  String get categorySystemHousingUtilities => 'Utilities';

  @override
  String get categorySystemHousingHomeInsurance => 'Home insurance';

  @override
  String get categorySystemFood => 'Food';

  @override
  String get categorySystemFoodGroceries => 'Groceries';

  @override
  String get categorySystemFoodRestaurants => 'Restaurants';

  @override
  String get categorySystemFoodCoffee => 'Coffee';

  @override
  String get categorySystemTransport => 'Transport';

  @override
  String get categorySystemTransportFuel => 'Fuel';

  @override
  String get categorySystemTransportPublicTransit => 'Public transit';

  @override
  String get categorySystemTransportParking => 'Parking';

  @override
  String get categorySystemTransportCarMaintenance => 'Car maintenance';

  @override
  String get categorySystemHealth => 'Health';

  @override
  String get categorySystemHealthDoctor => 'Doctor';

  @override
  String get categorySystemHealthPharmacy => 'Pharmacy';

  @override
  String get categorySystemHealthInsurance => 'Health insurance';

  @override
  String get categorySystemLeisure => 'Leisure';

  @override
  String get categorySystemLeisureOutings => 'Outings';

  @override
  String get categorySystemLeisureTravel => 'Travel';

  @override
  String get categorySystemSubscriptions => 'Subscriptions';

  @override
  String get categorySystemShopping => 'Shopping';

  @override
  String get categorySystemShoppingClothing => 'Clothing';

  @override
  String get categorySystemShoppingElectronics => 'Electronics';

  @override
  String get categorySystemShoppingHome => 'Home';

  @override
  String get categorySystemFinance => 'Finances';

  @override
  String get categorySystemFinanceBankFees => 'Bank fees';

  @override
  String get categorySystemFinanceTaxes => 'Taxes';

  @override
  String get categorySystemFinanceSavings => 'Savings';

  @override
  String get categorySystemFinanceInterest => 'Interest';

  @override
  String get categorySystemIncome => 'Income';

  @override
  String get categorySystemIncomeSalary => 'Salary';

  @override
  String get categorySystemIncomeRefunds => 'Refunds';

  @override
  String get categorySystemIncomeOther => 'Other income';

  @override
  String get categorySystemOther => 'Other';

  @override
  String get categorySystemOtherUncategorized => 'Uncategorized';

  @override
  String get dashboardStatIncome => 'Income (month)';

  @override
  String get dashboardStatExpense => 'Expenses (month)';

  @override
  String get dashboardStatNet => 'Net';

  @override
  String get dashboardStatSavingsRate => 'Savings rate';

  @override
  String dashboardStatVsPreviousMonth(DateTime month) {
    final intl.DateFormat monthDateFormat = intl.DateFormat.MMMM(localeName);
    final String monthString = monthDateFormat.format(month);

    return 'vs $monthString';
  }

  @override
  String get dashboardStatNetCaption => 'income − expenses';

  @override
  String dashboardSavingsDeltaPoints(String delta) {
    return '$delta pt';
  }

  @override
  String dashboardSavingsGoalReached(String goal) {
    return 'Goal: $goal · reached';
  }

  @override
  String dashboardSavingsGoalPending(String goal) {
    return 'Goal: $goal · in progress';
  }

  @override
  String get dashboardCategoryBreakdownTitle => 'Expenses by category';

  @override
  String get dashboardEmptyTitle =>
      'Import a statement to see your money come to life';

  @override
  String get dashboardEmptyBody =>
      'Your income, expenses, and savings rate will show up here as soon as you import your first statement.';

  @override
  String get dashboardGoToImports => 'Go to imports';

  @override
  String get dashboardRetry => 'Retry';

  @override
  String get dashboardErrorInvalidMonth => 'The requested month isn\'t valid.';

  @override
  String get dashboardErrorGeneric => 'Something went wrong. Please try again.';

  @override
  String get dashboardChooseMonth => 'Choose a month';

  @override
  String get dashboardPreviousYear => 'Previous year';

  @override
  String get dashboardNextYear => 'Next year';
}
