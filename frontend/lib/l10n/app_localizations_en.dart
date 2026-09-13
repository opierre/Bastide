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
      'OFX and QFX statements — processed on this computer';

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
  String get importDropZoneTitle => 'Drop an OFX or QFX file';

  @override
  String get importDropZoneHint =>
      'or click to browse — the statement names its own account';

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
  String get importChooseAccount => 'Choose an account';

  @override
  String get importUnreadableAccount =>
      'This file names no account — choose the destination.';

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
  String get importErrorAccountNotFound => 'Account not found.';

  @override
  String get importErrorBatchNotFound => 'Import not found.';

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
  String get transactionsDateRangeTitle => 'Date range';

  @override
  String get transactionsDateRangeFromLabel => 'From';

  @override
  String get transactionsDateRangeToLabel => 'To';

  @override
  String get transactionsDateRangeHelp =>
      'Leave both dates empty to see every date.';

  @override
  String get transactionsDateRangePickFrom => 'Pick the start date';

  @override
  String get transactionsDateRangePickTo => 'Pick the end date';

  @override
  String get transactionsDateRangeInvalid => 'Invalid date.';

  @override
  String get transactionsDateRangeIncomplete =>
      'Fill in both dates, or neither.';

  @override
  String get transactionsDateRangeOrder =>
      'The end date comes before the start date.';

  @override
  String get transactionsDateRangeCancel => 'Cancel';

  @override
  String get transactionsDateRangeApply => 'Apply';

  @override
  String transactionsPager(int from, int to, int total) {
    return '$from–$to of $total';
  }

  @override
  String transactionRowMemoAndAccount(String memo, String account) {
    return '$memo · $account';
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
  String get transactionErrorCategoryInvalid =>
      'That category is no longer available.';

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
  String get categorySystemIncomePension => 'Pension';

  @override
  String get categorySystemIncomeDividends => 'Dividends';

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
  String get dashboardCategoryBreakdownTitle => 'Spending by category';

  @override
  String dashboardCategoryBreakdownSubtitle(String month, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count categories',
      one: '1 category',
    );
    return '$month · $_temp0';
  }

  @override
  String get dashboardDonutCenterCaption => 'spent';

  @override
  String get dashboardSavingsTrendTitle => 'Savings over time';

  @override
  String dashboardSavingsTrendSubtitle(int count) {
    return 'Total saved · $count months';
  }

  @override
  String dashboardSavingsTrendDelta(String amount, String month) {
    return '$amount in $month';
  }

  @override
  String get dashboardIncomeVsExpenseTitle => 'Income vs expenses';

  @override
  String dashboardIncomeVsExpenseSubtitle(int count) {
    return 'Last $count months';
  }

  @override
  String get dashboardLegendIncome => 'Income';

  @override
  String get dashboardLegendExpense => 'Expenses';

  @override
  String get dashboardRecentActivityTitle => 'Recent activity';

  @override
  String get dashboardViewAllTransactions => 'View all transactions';

  @override
  String get dashboardRecentActivityEmpty =>
      'Your transactions will show up here.';

  @override
  String get dashboardEmptyTitle =>
      'Import a statement to see your money come to life';

  @override
  String get dashboardEmptyBody =>
      'Everything stays on this computer — nothing is sent online.';

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

  @override
  String get categoriesAddButton => 'New category';

  @override
  String get categoriesEmptyTitle => 'No categories yet';

  @override
  String get categoriesEmptyBody =>
      'Categories sort your spending. Create one to get started.';

  @override
  String get categoriesRetry => 'Try again';

  @override
  String get categoryBadgeSystem => 'System';

  @override
  String get categoryBadgeCustom => 'Custom';

  @override
  String get categorySystemLockedTooltip =>
      'System category: it cannot be edited or deleted.';

  @override
  String get categoryActionsTooltip => 'Actions';

  @override
  String get categoryEdit => 'Edit';

  @override
  String get categoryDelete => 'Delete';

  @override
  String get categoryAddSubcategory => 'Subcategory';

  @override
  String categoryRuleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count automatic rules',
      one: '1 automatic rule',
      zero: 'No rules',
    );
    return '$_temp0';
  }

  @override
  String get categoryDeleteConfirmTitle => 'Delete this category?';

  @override
  String categoryDeleteConfirmBody(String name) {
    return '“$name” and its subcategories will be deleted. The transactions in them become uncategorized again.';
  }

  @override
  String get categoryFormCreateTitle => 'New category';

  @override
  String get categoryFormEditTitle => 'Edit category';

  @override
  String get categoryFormNameLabel => 'Name';

  @override
  String get categoryFormNameHint => 'Project savings';

  @override
  String get categoryFormNameRequired => 'Give this category a name.';

  @override
  String get categoryFormKindLabel => 'Kind';

  @override
  String get categoryFormKindHelper =>
      'An expense leaves your accounts, income arrives in them, a transfer moves between them.';

  @override
  String get categoryFormParentLabel => 'Parent category';

  @override
  String get categoryFormParentNone => 'None (top-level category)';

  @override
  String get categoryFormIconLabel => 'Icon';

  @override
  String get categoryFormColorLabel => 'Color';

  @override
  String get categoryFormColorHelper =>
      'The color follows the category everywhere: charts, legends and labels.';

  @override
  String get categoryFormCancel => 'Cancel';

  @override
  String get categoryFormSave => 'Save';

  @override
  String get categoryKindExpense => 'Expense';

  @override
  String get categoryKindIncome => 'Income';

  @override
  String get categoryKindTransfer => 'Transfer';

  @override
  String get categoryIconHousing => 'Housing';

  @override
  String get categoryIconFood => 'Food';

  @override
  String get categoryIconTransport => 'Transport';

  @override
  String get categoryIconLeisure => 'Leisure';

  @override
  String get categoryIconSubscriptions => 'Subscriptions';

  @override
  String get categoryIconHealth => 'Health';

  @override
  String get categoryIconIncome => 'Income';

  @override
  String get categoryIconSavings => 'Savings';

  @override
  String get categoryIconOther => 'Other';

  @override
  String get categoryErrorNotEditable =>
      'This category belongs to the system: it cannot be edited or deleted.';

  @override
  String get categoryErrorValidation =>
      'That information isn\'t valid. Check the name and the kind.';

  @override
  String get categoryErrorGeneric => 'Something went wrong. Please try again.';

  @override
  String get categoriesTabCategories => 'Categories';

  @override
  String get categoriesTabRules => 'Rules';

  @override
  String get rulesAddButton => 'New rule';

  @override
  String get rulesPriorityNote =>
      'Evaluated in priority order — a rule never replaces a category you chose yourself.';

  @override
  String get rulesApplyButton => 'Run the rules';

  @override
  String get rulesApplyRunning => 'Running…';

  @override
  String rulesApplyToastTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions recategorized',
      one: '$count transaction recategorized',
      zero: 'No transactions recategorized',
    );
    return '$_temp0';
  }

  @override
  String get rulesApplyToastBody =>
      'The categories you chose yourself were left untouched.';

  @override
  String get rulesApplyFailed => 'The rule run failed';

  @override
  String get rulesReorderFailed => 'The new order could not be saved';

  @override
  String get rulesToggleFailed => 'The rule could not be changed';

  @override
  String get rulesFilterClear => 'Show all rules';

  @override
  String get rulesFilterEmpty => 'No rule targets this category.';

  @override
  String get rulesRetry => 'Try again';

  @override
  String get rulesEmptyTitle => 'Automate your sorting';

  @override
  String get rulesEmptyBody =>
      'A rule recognizes a label — “CARREFOUR” — and applies its category to every matching transaction, today and on every import after.';

  @override
  String get ruleToggleSemantics => 'Enable rule';

  @override
  String get ruleTargetMissing => 'Category missing';

  @override
  String get ruleFieldDescription => 'Label';

  @override
  String get ruleFieldMerchant => 'Merchant';

  @override
  String get ruleFieldAmount => 'Amount';

  @override
  String get ruleConditionContains => 'contains';

  @override
  String get ruleConditionEquals => 'equals';

  @override
  String get ruleConditionRegex => 'regex';

  @override
  String get ruleConditionRange => 'range';

  @override
  String get ruleFormCreateTitle => 'New rule';

  @override
  String get ruleFormEditTitle => 'Edit rule';

  @override
  String get ruleFormFieldLabel => 'Field';

  @override
  String get ruleFormConditionLabel => 'Condition';

  @override
  String get ruleFormPriorityLabel => 'Priority';

  @override
  String get ruleFormPriorityInvalid => 'Enter a priority of at least 1.';

  @override
  String get ruleFormPatternLabel => 'Pattern';

  @override
  String get ruleFormPatternRequired => 'Enter what the rule should recognize.';

  @override
  String get rulePatternHelperText =>
      'Case-insensitive search in the chosen field.';

  @override
  String get rulePatternHelperRegex =>
      'Regular expression, case-sensitive. Tested live below.';

  @override
  String get rulePatternHelperRange =>
      'Amount range in cents, “min:max”. Leave one side empty for an open bound; expenses are negative.';

  @override
  String get rulePatternHintText => 'CARREFOUR';

  @override
  String get rulePatternHintRegex => '^CB .*CARREFOUR';

  @override
  String get rulePatternHintRange => '-10000:-5000';

  @override
  String get ruleFormCategoryLabel => 'Category assigned';

  @override
  String get ruleFormCategoryNone => 'Choose a category';

  @override
  String get ruleFormCategoryRequired =>
      'Choose the category this rule assigns.';

  @override
  String get ruleFormEnabledLabel => 'Rule active';

  @override
  String get ruleFormCancel => 'Cancel';

  @override
  String get ruleFormSave => 'Save';

  @override
  String get ruleFormDelete => 'Delete';

  @override
  String get rulePreviewLoading => 'Looking for matching transactions…';

  @override
  String rulePreviewCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Matches $count existing transactions.',
      one: 'Matches $count existing transaction.',
      zero: 'Matches no existing transaction.',
    );
    return '$_temp0';
  }

  @override
  String rulePreviewCountWithSample(int count, String sample, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Matches $count existing transactions — including “$sample” of $date.',
      one: 'Matches $count existing transaction — “$sample” of $date.',
    );
    return '$_temp0';
  }

  @override
  String get ruleErrorPatternInvalid =>
      'That pattern isn\'t a valid regular expression.';

  @override
  String get ruleErrorNotFound => 'That rule no longer exists.';

  @override
  String get ruleErrorCategoryNotFound =>
      'The target category no longer exists.';

  @override
  String get ruleErrorValidation =>
      'That information isn\'t valid. Check the pattern and the priority.';

  @override
  String get ruleErrorGeneric => 'Something went wrong. Please try again.';

  @override
  String get rulePackMenuTooltip => 'Import / export rules';

  @override
  String get rulePackImportFile => 'Import a file…';

  @override
  String rulePackImportBuiltin(String name) {
    return 'Import “$name”';
  }

  @override
  String get rulePackExportAction => 'Export my rules…';

  @override
  String get rulePackCancel => 'Cancel';

  @override
  String get rulePackClose => 'Close';

  @override
  String get rulePackRefusedTitle => 'This file wasn\'t accepted';

  @override
  String get rulePackRefusedMalformed =>
      'This file isn\'t a FinStride rule pack. Expected a JSON file with a name, a format version and a list of rules.';

  @override
  String rulePackRefusedVersion(int version) {
    return 'This pack uses a format version this build of FinStride doesn\'t read. It reads version $version. A pack we only half understood would silently drop rules, so it is refused whole.';
  }

  @override
  String get rulePackRefusedRegex =>
      'This pack contains a “regex” rule. Regular expressions aren\'t accepted in a shared pack: an expression from someone else\'s file can lock up your machine. Use “contains”, “equals” or “range”.';

  @override
  String rulePackWouldMatch(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'This pack would categorize $count of your uncategorized transactions.',
      one:
          'This pack would categorize $count of your uncategorized transactions.',
      zero:
          'This pack would categorize none of your uncategorized transactions.',
    );
    return '$_temp0';
  }

  @override
  String get rulePackRuleCount => 'Rules in the pack';

  @override
  String get rulePackNewCount => 'New rules';

  @override
  String get rulePackDuplicateCount => 'Duplicates skipped';

  @override
  String get rulePackUnresolvedCount => 'Categories not found';

  @override
  String rulePackUnresolvedDetail(String keys) {
    return 'These rules will be skipped: $keys';
  }

  @override
  String get rulePackSamplesLabel => 'Example transactions affected';

  @override
  String get rulePackApplyNowLabel =>
      'Apply the rules to my existing transactions after importing';

  @override
  String get rulePackImportConfirm => 'Import';

  @override
  String rulePackImportedTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rules imported',
      one: '$count rule imported',
      zero: 'No rules imported',
    );
    return '$_temp0';
  }

  @override
  String rulePackImportedBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions recategorized.',
      one: '$count transaction recategorized.',
      zero: 'No transaction changed category.',
    );
    return '$_temp0';
  }

  @override
  String get rulePackImportFailed => 'The import failed';

  @override
  String get rulePackExportTitle => 'Export my rules';

  @override
  String get rulePackExportPrivacyNotice =>
      'Read it before saving: a pattern can hold personal details — your landlord\'s name, “VIR SALAIRE DUPONT”.';

  @override
  String rulePackExportContents(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'File contents — $count rules',
      one: 'File contents — $count rule',
      zero: 'File contents — no rules',
    );
    return '$_temp0';
  }

  @override
  String rulePackOmittedLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rules can\'t be exported',
      one: '$count rule can\'t be exported',
    );
    return '$_temp0';
  }

  @override
  String rulePackOmittedRegex(String pattern) {
    return '“$pattern” — regex rules cannot appear in a pack.';
  }

  @override
  String rulePackOmittedUserCategory(String pattern) {
    return '“$pattern” — targets a custom category, which has no shareable identifier.';
  }

  @override
  String get rulePackExportSave => 'Save';

  @override
  String get rulePackExportedTitle => 'Pack saved';

  @override
  String get rulePackExportFailed => 'The export failed';

  @override
  String rulePackStartWith(String name, int count) {
    return 'Start with “$name” ($count rules)';
  }

  @override
  String get rulePackStartWithHelper =>
      'You\'ll see what the pack would do before importing it.';

  @override
  String reviewQueueAiSubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Local AI proposes a category for $count of them — confirm or correct, nothing is filed without you.',
      one:
          'Local AI proposes a category for one of them — confirm or correct, nothing is filed without you.',
      zero:
          'Local AI hasn\'t proposed a category for any of these — confirm or correct, nothing is filed without you.',
    );
    return '$_temp0';
  }

  @override
  String reviewQueueProgress(int resolved, int total, double percent) {
    final intl.NumberFormat percentNumberFormat =
        intl.NumberFormat.percentPattern(localeName);
    final String percentString = percentNumberFormat.format(percent);

    return '$resolved/$total · $percentString';
  }

  @override
  String get reviewAiInvitation =>
      'Turn on local AI to automatically categorize the transactions your rules didn\'t recognize.';

  @override
  String get reviewAiInvitationLink => 'Settings';

  @override
  String reviewConfidence(double confidence) {
    final intl.NumberFormat confidenceNumberFormat =
        intl.NumberFormat.percentPattern(localeName);
    final String confidenceString = confidenceNumberFormat.format(confidence);

    return 'Confidence $confidenceString';
  }

  @override
  String get reviewConfirm => 'Confirm';

  @override
  String get reviewCorrect => 'Correct';

  @override
  String get reviewNoProposal => '— no proposal';

  @override
  String get reviewChooseCategory => 'Choose a category';

  @override
  String alwaysRuleSubtitle(String label) {
    return 'A rule files these transactions without AI, on every import — pre-filled from “$label”.';
  }

  @override
  String get alwaysRuleCategoryLabel => 'Target category';

  @override
  String get alwaysRuleApplyExisting => 'Apply to existing transactions';

  @override
  String get alwaysRuleSubmit => 'Create the rule';

  @override
  String get alwaysRuleCreatedTitle => 'Rule created';

  @override
  String alwaysRuleCreatedBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions recategorized.',
      one: '$count transaction recategorized.',
      zero: 'No other transaction changed category.',
    );
    return '$_temp0';
  }

  @override
  String get alwaysRuleSuggestionFailed =>
      'Couldn\'t pre-fill the rule. Enter the pattern yourself.';

  @override
  String get reviewQueueRunAction => 'Categorize with AI';

  @override
  String runBannerRunning(int processed, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: 'Categorizing — $processed of $total transactions',
      one: 'Categorizing — $processed of $total transaction',
    );
    return '$_temp0';
  }

  @override
  String runBannerRunningDetail(int assigned, int deferred) {
    String _temp0 = intl.Intl.pluralLogic(
      assigned,
      locale: localeName,
      other: '$assigned filed · $deferred to review · the panel stays usable',
      one: '$assigned filed · $deferred to review · the panel stays usable',
    );
    return '$_temp0';
  }

  @override
  String get runBannerCancel => 'Cancel';

  @override
  String runBannerPartial(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Categorization finished — $count transactions couldn\'t be analysed.',
      one:
          'Categorization finished — $count transaction couldn\'t be analysed.',
    );
    return '$_temp0';
  }

  @override
  String get runBannerPartialAction => 'View';

  @override
  String get runBannerFailed => 'Categorization couldn\'t run.';

  @override
  String get runBannerDismiss => 'Dismiss';

  @override
  String get runStartFailed => 'Categorization can\'t be started right now.';

  @override
  String get settingsAiTitle => 'Local AI';

  @override
  String get settingsAiSubtitle => 'Enable AI categorization';

  @override
  String get settingsAiToggleLabel => 'AI categorization';

  @override
  String get settingsAiPrivacy =>
      'Your transaction descriptions are sent to a model running on this computer. Nothing leaves your machine.';

  @override
  String get settingsAiBaseUrlLabel => 'Engine address';

  @override
  String get settingsAiBaseUrlHelp =>
      'Local addresses only — 127.0.0.1 or localhost.';

  @override
  String get settingsAiBaseUrlRejected =>
      'Address refused: the engine must run on this computer (127.0.0.1 or localhost). A remote address would send your transaction descriptions off your machine.';

  @override
  String get settingsAiModelLabel => 'Model';

  @override
  String get settingsAiModelHelp =>
      'List provided by the engine — manual entry allowed.';

  @override
  String get settingsAiModelUnavailable => 'No model — engine unreachable.';

  @override
  String get settingsAiModelChoose => 'Choose a model';

  @override
  String settingsAiThresholdLabel(double threshold) {
    final intl.NumberFormat thresholdNumberFormat =
        intl.NumberFormat.percentPattern(localeName);
    final String thresholdString = thresholdNumberFormat.format(threshold);

    return 'Confidence threshold — $thresholdString';
  }

  @override
  String get settingsAiThresholdHelp =>
      'Below this threshold, a transaction is offered to you for review rather than categorized automatically.';

  @override
  String settingsAiStatusConnected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Connected — $count models available',
      one: 'Connected — 1 model available',
      zero: 'Connected — no model available',
    );
    return '$_temp0';
  }

  @override
  String get settingsAiStatusUnreachable =>
      'No engine detected at this address.';

  @override
  String get settingsAiStatusDisabled => 'AI categorization is off.';

  @override
  String get settingsAiLearnMore => 'Learn more';

  @override
  String get settingsAiTest => 'Test connection';

  @override
  String get settingsAiTesting => 'Testing…';

  @override
  String get settingsAiLoadFailed =>
      'Your settings couldn\'t be loaded right now.';

  @override
  String get settingsAiRetry => 'Try again';

  @override
  String get settingsBackupTitle => 'Backup & restore';

  @override
  String get settingsBackupSubtitle =>
      'Export all your data to a file you can import again.';

  @override
  String get settingsBackupExportLabel => 'Export all data';

  @override
  String get settingsBackupExportCaption =>
      '.finstride file — accounts, transactions, categories, rules, goals, loans, properties, settings.';

  @override
  String get settingsBackupExportPreparing => 'Preparing the archive…';

  @override
  String get settingsBackupExport => 'Export';

  @override
  String settingsBackupLast(String when) {
    return 'Last backup: $when';
  }

  @override
  String get settingsBackupNone => 'No backup yet.';

  @override
  String settingsBackupDateTime(String date, String time) {
    return '$date at $time';
  }

  @override
  String get settingsBackupPrivacy =>
      'The file isn\'t encrypted. Keep it somewhere safe — it holds your entire financial history.';

  @override
  String get settingsBackupRestoreTitle => 'Restore a backup';

  @override
  String get settingsBackupRestoreSubtitle => 'Replaces all current data.';

  @override
  String get settingsBackupRestoreButton => 'Import a file…';

  @override
  String get settingsBackupRestoreFailedLead => 'Restore not possible.';

  @override
  String get settingsBackupErrorTooNew =>
      'This file comes from a newer version of FinStride. Update the app to restore it.';

  @override
  String get settingsBackupErrorInvalid =>
      'This file isn\'t a valid FinStride backup, or it\'s damaged.';

  @override
  String get settingsBackupErrorCurrency =>
      'This backup uses a different currency from your account.';

  @override
  String get settingsBackupErrorRunActive =>
      'A categorization run is in progress. Wait for it to finish, then try again.';

  @override
  String get settingsBackupErrorConflict =>
      'This backup belongs to another account on this computer.';

  @override
  String get settingsBackupErrorUnknown =>
      'The restore failed. Your data hasn\'t been changed.';

  @override
  String settingsBackupExported(
    int transactionCount,
    String transactions,
    int accountCount,
    String accounts,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      transactionCount,
      locale: localeName,
      other: '$transactions transactions',
      one: '$transactions transaction',
    );
    String _temp1 = intl.Intl.pluralLogic(
      accountCount,
      locale: localeName,
      other: '$accounts accounts',
      one: '$accounts account',
    );
    return 'Backup saved — $_temp0, $_temp1.';
  }

  @override
  String get settingsBackupExportFailed => 'The export failed. Try again.';

  @override
  String get settingsBackupConfirmTitle => 'Restore this backup?';

  @override
  String get settingsBackupConfirmFile => 'Selected file:';

  @override
  String get settingsBackupConfirmExportedAt => 'Exported on';

  @override
  String get settingsBackupConfirmVersion => 'App version';

  @override
  String get settingsBackupConfirmAccounts => 'Accounts';

  @override
  String get settingsBackupConfirmTransactions => 'Transactions';

  @override
  String get settingsBackupConfirmCategories => 'Categories';

  @override
  String get settingsBackupConfirmRules => 'Rules';

  @override
  String get settingsBackupConfirmSubscriptions => 'Subscriptions';

  @override
  String get settingsBackupConfirmGoals => 'Goals';

  @override
  String get settingsBackupConfirmMortgages => 'Loans';

  @override
  String get settingsBackupConfirmProperties => 'Properties';

  @override
  String get settingsBackupConfirmSimulations => 'Simulations';

  @override
  String get settingsBackupConfirmWarning =>
      'All your current data will be replaced. Export it first if needed.';

  @override
  String get settingsBackupCancel => 'Cancel';

  @override
  String get settingsBackupReplace => 'Replace my data';

  @override
  String get settingsBackupRestored => 'Backup restored';

  @override
  String get navSubscriptions => 'Recurring';

  @override
  String get navSubscriptionsSubtitle =>
      'Your recurring charges, detected automatically';

  @override
  String get subscriptionsDetect => 'Detect';

  @override
  String get subscriptionsDetectRunning => 'Detecting…';

  @override
  String get subscriptionsAdd => 'New recurring payment';

  @override
  String subscriptionsDetectResult(int created) {
    String _temp0 = intl.Intl.pluralLogic(
      created,
      locale: localeName,
      other: '$created new recurring payments detected',
      one: '1 new recurring payment detected',
      zero: 'No new recurring payments detected',
    );
    return '$_temp0';
  }

  @override
  String subscriptionsDetectResultDetail(int updated) {
    String _temp0 = intl.Intl.pluralLogic(
      updated,
      locale: localeName,
      other: '$updated existing series refreshed',
      one: '1 existing series refreshed',
      zero: 'No existing series refreshed',
    );
    return '$_temp0';
  }

  @override
  String get subscriptionsDetectFailed => 'Detection could not run.';

  @override
  String get subscriptionsBurdenLabel => 'Monthly burden';

  @override
  String get subscriptionsBurdenCaption =>
      'Quarterly and yearly charges brought back to a monthly figure.';

  @override
  String subscriptionsBurdenExcluded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ended payments excluded.',
      one: '1 ended payment excluded.',
    );
    return '$_temp0';
  }

  @override
  String get subscriptionsActiveLabel => 'Active payments';

  @override
  String subscriptionsCadenceWeeklyCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count weekly',
      one: '1 weekly',
    );
    return '$_temp0';
  }

  @override
  String subscriptionsCadenceMonthlyCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count monthly',
      one: '1 monthly',
    );
    return '$_temp0';
  }

  @override
  String subscriptionsCadenceQuarterlyCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count quarterly',
      one: '1 quarterly',
    );
    return '$_temp0';
  }

  @override
  String subscriptionsCadenceYearlyCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count yearly',
      one: '1 yearly',
    );
    return '$_temp0';
  }

  @override
  String subscriptionsCadenceIrregularCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count irregular',
      one: '1 irregular',
    );
    return '$_temp0';
  }

  @override
  String subscriptionsCancelledCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ended',
      one: '1 ended',
    );
    return '$_temp0';
  }

  @override
  String get subscriptionsNextLabel => 'Next charge';

  @override
  String subscriptionsNextValue(String label, String when) {
    return '$label — $when';
  }

  @override
  String subscriptionsNextCaption(String amount, String date) {
    return '$amount · $date';
  }

  @override
  String get subscriptionsNextToday => 'today';

  @override
  String get subscriptionsNextTomorrow => 'tomorrow';

  @override
  String subscriptionsNextInDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'in $days days',
      one: 'in 1 day',
    );
    return '$_temp0';
  }

  @override
  String get subscriptionsNextNone => 'No upcoming charge';

  @override
  String get subscriptionsColumnName => 'Name';

  @override
  String get subscriptionsColumnCategory => 'Category';

  @override
  String get subscriptionsColumnCadence => 'Frequency';

  @override
  String get subscriptionsColumnAmount => 'Amount';

  @override
  String get subscriptionsColumnNext => 'Next';

  @override
  String get subscriptionsColumnStatus => 'Status';

  @override
  String get subscriptionsValueNone => '—';

  @override
  String get cadenceWeekly => 'Weekly';

  @override
  String get cadenceMonthly => 'Monthly';

  @override
  String get cadenceQuarterly => 'Quarterly';

  @override
  String get cadenceYearly => 'Yearly';

  @override
  String get cadenceIrregular => 'Irregular';

  @override
  String subscriptionSignalIncrease(String from, String to) {
    return 'Price increase · $from → $to';
  }

  @override
  String subscriptionSignalMissed(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Missed charge · $days days late',
      one: 'Missed charge · 1 day late',
    );
    return '$_temp0';
  }

  @override
  String subscriptionSignalCancelled(String date) {
    return 'Ended · last charge $date';
  }

  @override
  String subscriptionNextExpected(String date) {
    return 'expected $date';
  }

  @override
  String get subscriptionActionsTooltip => 'Payment actions';

  @override
  String get subscriptionActionConfirm => 'Confirm';

  @override
  String get subscriptionActionDismiss => 'Ignore';

  @override
  String get subscriptionActionCancel => 'Mark as ended';

  @override
  String get subscriptionActionEdit => 'Edit';

  @override
  String get subscriptionErrorInvalidTransition =>
      'That status change isn\'t available for this payment.';

  @override
  String get subscriptionErrorExists =>
      'This account already tracks a recurring payment under that name.';

  @override
  String get subscriptionErrorNotFound =>
      'This recurring payment no longer exists.';

  @override
  String get subscriptionErrorAccountNotFound =>
      'That account no longer exists.';

  @override
  String get subscriptionErrorCategoryInvalid =>
      'That category is no longer available.';

  @override
  String get subscriptionErrorValidation => 'Check the details you entered.';

  @override
  String get subscriptionErrorGeneric => 'Something went wrong. Try again.';

  @override
  String get subscriptionsLoadFailed =>
      'We couldn\'t load your recurring payments right now.';

  @override
  String get subscriptionsRetry => 'Try again';

  @override
  String get subscriptionsEmptyTitle => 'No recurring payments detected yet';

  @override
  String get subscriptionsEmptyBody =>
      'FinStride spots a recurring payment once a charge has repeated three times. Importing more history speeds detection up.';

  @override
  String get subscriptionsEmptyCta => 'Go to imports';

  @override
  String get subscriptionDetailBack => 'Back to recurring payments';

  @override
  String subscriptionDetailDetectedSince(String account, String month) {
    return '$account · detected since $month';
  }

  @override
  String subscriptionDetailTrackedSince(String account, String month) {
    return '$account · tracked since $month';
  }

  @override
  String get subscriptionDetailCadence => 'Frequency';

  @override
  String get subscriptionDetailExpectedAmount => 'Expected amount';

  @override
  String get subscriptionDetailNextCharge => 'Next charge';

  @override
  String subscriptionDetailIncrease(
    String from,
    String to,
    String date,
    String annual,
  ) {
    return 'Price increase: $from → $to on $date — that\'s $annual a year.';
  }

  @override
  String get subscriptionDetailHistoryTitle => 'Charge history';

  @override
  String subscriptionDetailHistorySubtitle(String account) {
    return 'The transactions this series is deduced from · $account';
  }

  @override
  String get subscriptionDetailHistoryEmpty =>
      'No charges linked to this payment yet.';

  @override
  String subscriptionDetailChange(String from, String to) {
    return '$from → $to';
  }

  @override
  String get subscriptionDetailFootnote =>
      'FinStride deduces the series from these charges — check them before confirming a change.';

  @override
  String get subscriptionDetailLoadFailed =>
      'We couldn\'t load this recurring payment right now.';

  @override
  String get subscriptionFormCreateTitle => 'New recurring payment';

  @override
  String get subscriptionFormEditTitle => 'Edit recurring payment';

  @override
  String get subscriptionFormIntro =>
      'Track a recurring charge detection hasn\'t spotted yet.';

  @override
  String get subscriptionFormNameLabel => 'Name';

  @override
  String get subscriptionFormNameRequired => 'Give this payment a name.';

  @override
  String get subscriptionFormAccountLabel => 'Account';

  @override
  String get subscriptionFormAmountLabel => 'Amount';

  @override
  String get subscriptionFormAmountInvalid =>
      'Enter an amount greater than zero.';

  @override
  String get subscriptionFormCadenceLabel => 'Frequency';

  @override
  String get subscriptionFormCadenceHelp =>
      'Weekly · Monthly · Quarterly · Yearly · Irregular';

  @override
  String get subscriptionFormCategoryLabel => 'Category';

  @override
  String get subscriptionFormCategoryNone => 'None';

  @override
  String get subscriptionFormNoAccounts =>
      'Create an account first to track a recurring payment in it.';

  @override
  String get subscriptionFormCancel => 'Cancel';

  @override
  String get subscriptionFormSubmit => 'Create payment';

  @override
  String get subscriptionFormSave => 'Save';

  @override
  String get navGoals => 'Goals';

  @override
  String get navGoalsSubtitle => 'Set money aside, virtually, for what matters';

  @override
  String get goalsAdd => 'New goal';

  @override
  String get goalsReassurance =>
      'On-paper allocation: your accounts are not modified.';

  @override
  String goalsOverAllocated(String allocated, String savings) {
    return 'You\'ve allocated $allocated while your savings accounts total $savings.';
  }

  @override
  String get goalsDismissBanner => 'Hide this warning';

  @override
  String goalsShowArchived(int count) {
    return 'Show archived goals ($count)';
  }

  @override
  String goalsHideArchived(int count) {
    return 'Hide archived goals ($count)';
  }

  @override
  String get goalsEmptyTitle => 'Give a name to what matters';

  @override
  String get goalsEmptyBody =>
      'A goal is a virtual envelope: you set money aside at your own pace, without touching your accounts.';

  @override
  String get goalsLoadFailed => 'We couldn\'t load your goals right now.';

  @override
  String get goalsRetry => 'Try again';

  @override
  String get goalPillNoDeadline => 'No deadline';

  @override
  String get goalPillReached => 'Goal reached';

  @override
  String goalPillReachedOn(String month) {
    return 'Goal reached · $month';
  }

  @override
  String get goalDetailBack => 'Back to goals';

  @override
  String goalDetailTargetDate(String month) {
    return 'Target $month';
  }

  @override
  String get goalDetailArchive => 'Archive';

  @override
  String get goalDetailRestore => 'Restore';

  @override
  String get goalDetailNewAllocation => 'New allocation';

  @override
  String get goalDetailMissing => 'This goal is no longer available.';

  @override
  String get goalDetailFootnote =>
      'No transaction is created: these lines exist only on the goal\'s paper.';

  @override
  String get goalDetailHistoryFailed =>
      'We couldn\'t load the allocation history.';

  @override
  String get goalHistoryTitle => 'Allocation history';

  @override
  String get goalHistorySubtitle =>
      'One list, signed amounts — a withdrawal is a negative line.';

  @override
  String get goalHistoryDate => 'Date';

  @override
  String get goalHistoryAmount => 'Amount';

  @override
  String get goalHistoryNote => 'Note';

  @override
  String get goalHistoryDelete => 'Delete this allocation';

  @override
  String get goalHistoryEmpty => 'No allocations yet.';

  @override
  String get goalFormCreateTitle => 'New goal';

  @override
  String get goalFormEditTitle => 'Edit goal';

  @override
  String get goalFormIntro =>
      'A virtual envelope: you set money aside on paper, without touching your accounts.';

  @override
  String get goalFormNameLabel => 'Name';

  @override
  String get goalFormNameRequired => 'Give this goal a name.';

  @override
  String get goalFormTargetLabel => 'Target amount';

  @override
  String get goalFormTargetInvalid => 'Enter an amount greater than zero.';

  @override
  String get goalFormDateLabel => 'Target date';

  @override
  String get goalFormDateHelp => 'Optional';

  @override
  String get goalFormDateInvalid => 'Invalid date.';

  @override
  String get goalFormIconLabel => 'Icon';

  @override
  String get goalFormColorLabel => 'Color';

  @override
  String get goalFormCancel => 'Cancel';

  @override
  String get goalFormSubmit => 'Create goal';

  @override
  String get goalFormSave => 'Save';

  @override
  String get allocationModalTitle => 'New allocation';

  @override
  String get allocationAmountLabel => 'Amount';

  @override
  String get allocationAmountHelp =>
      'A negative amount takes money back out of the goal.';

  @override
  String get allocationAmountInvalid => 'Enter an amount other than zero.';

  @override
  String get allocationDateLabel => 'Date';

  @override
  String get allocationDateInvalid => 'Invalid date.';

  @override
  String get allocationNoteLabel => 'Note (optional)';

  @override
  String get allocationNoteHint => 'e.g. Monthly transfer';

  @override
  String get allocationCancel => 'Cancel';

  @override
  String get allocationSubmit => 'Add';

  @override
  String get goalErrorNotFound => 'This goal no longer exists.';

  @override
  String get goalErrorAllocationNotFound => 'This allocation no longer exists.';

  @override
  String get goalErrorValidation => 'Check the details you entered.';

  @override
  String get goalErrorGeneric => 'Something went wrong. Try again.';

  @override
  String get dashboardGoalsTitle => 'Goals';

  @override
  String get dashboardGoalsViewAll => 'View all';

  @override
  String dashboardGoalsProgress(String saved, String target) {
    return '$saved / $target';
  }

  @override
  String get dashboardGoalsReached => 'Reached';

  @override
  String get goalFormDatePick => 'Pick a target date';

  @override
  String get allocationDatePick => 'Pick a date';

  @override
  String get settingsResetTitle => 'Danger zone';

  @override
  String get settingsResetBadge => 'IRREVERSIBLE';

  @override
  String get settingsResetSubtitle =>
      'Resetting the database deletes this profile\'s transactions, accounts, rules, custom categories, goals, subscriptions, loans, properties and simulations. Exported backups aren\'t touched.';

  @override
  String get settingsResetButton => 'Reset…';

  @override
  String get settingsResetConfirmTitle => 'Reset the database?';

  @override
  String settingsResetConfirmLead(String name) {
    return 'Everything in $name\'s profile will be permanently deleted:';
  }

  @override
  String get settingsResetConfirmCategories => 'Custom categories';

  @override
  String get settingsResetConfirmNote =>
      'System categories, your preferences and the AI settings are kept. Backup files you\'ve already exported stay intact.';

  @override
  String get settingsResetConfirmWarning =>
      'This can\'t be undone. Export a backup before you continue.';

  @override
  String get settingsResetConfirmWord => 'DELETE';

  @override
  String settingsResetConfirmLabel(String word) {
    return 'Type $word to confirm';
  }

  @override
  String get settingsResetConfirmSubmit => 'Delete everything';

  @override
  String get settingsResetDone =>
      'Database reset. The system categories have been restored.';

  @override
  String get settingsResetFailedLead => 'Reset not possible.';

  @override
  String get settingsResetErrorUnknown =>
      'The reset failed. Your data hasn\'t been changed.';

  @override
  String get navSectionWealth => 'Wealth';

  @override
  String get navMortgages => 'Loans';

  @override
  String get navMortgagesSubtitle => 'Your loans, their cost and your capacity';

  @override
  String get navSimulator => 'Simulator';

  @override
  String get navSimulatorSubtitle => 'What a new loan would change';

  @override
  String get navNetworth => 'Net worth';

  @override
  String get navNetworthSubtitle => 'What you own, what you owe';

  @override
  String get mortgagesAdd => 'New loan';

  @override
  String get mortgagesLoadFailed => 'Couldn\'t load your loans.';

  @override
  String get mortgagesRetry => 'Retry';

  @override
  String get mortgagesEmptyTitle => 'No loans recorded';

  @override
  String get mortgagesEmptyBody =>
      'Add your loans to follow their real cost, their trajectory and your capacity — without ever connecting FinStride to a bank.';

  @override
  String get mortgagesChargeLabel => 'Monthly charge';

  @override
  String mortgagesChargeCaption(int count, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count instalments on $date',
      one: '1 instalment on $date',
    );
    return '$_temp0 · insurance included';
  }

  @override
  String get mortgagesChargeCaptionNoNext => 'insurance included';

  @override
  String get mortgagesOutstandingLabel => 'Outstanding principal';

  @override
  String mortgagesOutstandingCaption(String principal, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count loans',
      one: '1 loan',
    );
    return 'of $principal borrowed · $_temp0';
  }

  @override
  String mortgagesRepaidLine(String amount, String percent) {
    return '$amount repaid · $percent';
  }

  @override
  String get mortgagesRatioLabel => 'Debt ratio';

  @override
  String mortgagesRatioReference(String percent) {
    return 'HCSF reference $percent';
  }

  @override
  String get mortgagesRatioOverLimit => 'Above the reference';

  @override
  String mortgagesRatioCaptionDeclared(String charge, String income) {
    return 'Charge $charge against a declared income of $income';
  }

  @override
  String mortgagesRatioCaptionLedger(String charge, String income) {
    return 'Charge $charge against a median observed income of $income (12 months of the ledger). The household may receive income outside the app: a declared income replaces this reading.';
  }

  @override
  String get mortgagesRatioUnknown =>
      'No known income: the ledger holds no regular income and none is declared. Without an income there is no ratio to compute.';

  @override
  String get mortgagesRatioDeclareLink => 'Declare an income →';

  @override
  String get mortgagesRatioDeclareButton => 'Declare an income';

  @override
  String get mortgagesRatioCaveat =>
      'An informative reading: this reference binds no lender.';

  @override
  String get mortgagesIncomeTitle => 'Declare an income';

  @override
  String get mortgagesIncomeBody =>
      'The household\'s net monthly income the debt ratio is read against. It replaces the ledger\'s median income.';

  @override
  String get mortgagesIncomeLabel => 'Monthly income';

  @override
  String get mortgagesIncomeInvalid => 'Enter an amount above zero.';

  @override
  String get mortgagesIncomeSubmit => 'Save';

  @override
  String get mortgagesIncomeFailed => 'The income couldn\'t be saved.';

  @override
  String get mortgageKindMortgage => 'Home loan';

  @override
  String get mortgageKindWorks => 'Home improvement loan';

  @override
  String get mortgageKindConsumer => 'Consumer loan';

  @override
  String get mortgageKindAuto => 'Car loan';

  @override
  String get mortgageRepaymentConstant => 'Constant payment';

  @override
  String get mortgageRepaymentInterestOnly => 'Interest-only';

  @override
  String mortgageCardSubline(String kind, String lender, int months) {
    return '$kind · $lender · $months months';
  }

  @override
  String get mortgageCardPerMonth => '/ month';

  @override
  String get mortgageCardOutstandingLabel => 'Outstanding principal';

  @override
  String mortgageCardOutstandingOf(String principal) {
    return 'of $principal';
  }

  @override
  String get mortgageCardRepaid => 'repaid';

  @override
  String mortgageCardRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count instalments left',
      one: '1 instalment left',
      zero: 'no instalments left',
    );
    return '$_temp0';
  }

  @override
  String get mortgageRateLabel => 'Nominal rate';

  @override
  String get mortgageInsuranceLabel => 'Insurance';

  @override
  String get mortgageNextLabel => 'Next instalment';

  @override
  String mortgageInsurancePerMonth(String amount) {
    return '$amount / month';
  }

  @override
  String get mortgagesChartTitle => 'Outstanding principal trajectory';

  @override
  String mortgagesChartSubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'All $count loans, instalment by instalment, to the last repayment',
      two: 'Both loans, instalment by instalment, to the last repayment',
      one: 'The loan, instalment by instalment, to the last repayment',
    );
    return '$_temp0';
  }

  @override
  String get mortgagesChartLegendTotal => 'Total outstanding principal';

  @override
  String get mortgagesChartLegendToday => 'today';

  @override
  String mortgagesChartToday(String month, String amount) {
    return '$month · $amount';
  }

  @override
  String mortgagesChartLoanEnd(String kind, String month) {
    return 'end of $kind · $month';
  }

  @override
  String get mortgageDetailBack => 'Back to loans';

  @override
  String get mortgageDetailLoadFailed => 'Couldn\'t load this loan.';

  @override
  String mortgageDetailSubline(
    String kind,
    String lender,
    String principal,
    int months,
    String date,
  ) {
    return '$kind · $lender · $principal over $months months · first instalment on $date';
  }

  @override
  String mortgageDetailSublineFees(
    String kind,
    String lender,
    String principal,
    int months,
    String date,
    String fees,
  ) {
    return '$kind · $lender · $principal over $months months · first instalment on $date · upfront fees $fees';
  }

  @override
  String get mortgageDetailInstalmentLabel => 'Total instalment';

  @override
  String mortgageDetailInstalmentCaption(String payment, String insurance) {
    return '$payment + $insurance insurance';
  }

  @override
  String get mortgageDetailInstalmentNoInsurance => 'no insurance';

  @override
  String mortgageDetailOutstandingCaption(String percent, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count instalments',
      one: '1 instalment',
    );
    return '$percent repaid · $_temp0';
  }

  @override
  String get mortgageDetailEdit => 'Edit';

  @override
  String get mortgageCostRateCaption => 'fixed for the whole term';

  @override
  String get mortgageCostTaegLabel => 'APR';

  @override
  String get mortgageCostIndicative => 'Indicative';

  @override
  String get mortgageCostTaegDisclaimer =>
      'Indicative: a real APR includes fees FinStride never sees.';

  @override
  String get mortgageCostTaegCaption => 'rate, insurance and fees included';

  @override
  String get mortgageCostInterestLabel => 'Total interest';

  @override
  String mortgageCostInterestCaption(String amount) {
    return 'of which $amount still to pay';
  }

  @override
  String get mortgageCostTotalLabel => 'Total cost of credit';

  @override
  String mortgageCostTotalCaption(String insurance, String fees) {
    return 'interest + insurance $insurance + fees $fees';
  }

  @override
  String get mortgageFormCreateTitle => 'New loan';

  @override
  String get mortgageFormEditTitle => 'Edit loan';

  @override
  String get mortgageFormSubtitle =>
      'The instalment is computed from the principal, the rate and the term.';

  @override
  String get mortgageFormLabel => 'Label';

  @override
  String get mortgageFormLabelRequired => 'Give this loan a name.';

  @override
  String get mortgageFormLender => 'Lender';

  @override
  String get mortgageFormLenderRequired => 'Enter the lender.';

  @override
  String get mortgageFormKind => 'Type';

  @override
  String get mortgageFormRepayment => 'Repayment';

  @override
  String get mortgageFormPrincipal => 'Amount borrowed';

  @override
  String get mortgageFormAmountInvalid => 'Enter an amount above zero.';

  @override
  String get mortgageFormRate => 'Nominal rate';

  @override
  String get mortgageFormRateInvalid => 'Enter a rate, for example 3.45.';

  @override
  String get mortgageFormTerm => 'Term';

  @override
  String get mortgageFormTermUnit => 'months';

  @override
  String get mortgageFormTermInvalid => 'Enter a term in months.';

  @override
  String get mortgageFormFirstPayment => 'First instalment';

  @override
  String get mortgageFormDateInvalid => 'Enter a valid date.';

  @override
  String get mortgageFormCalendar => 'Pick a date';

  @override
  String get mortgageFormInsurance => 'Insurance / month';

  @override
  String get mortgageFormAmountOptionalInvalid =>
      'Enter a valid amount or leave it empty.';

  @override
  String get mortgageFormFees => 'Upfront fees';

  @override
  String get mortgageFormProperty => 'Financed property';

  @override
  String get mortgageFormPropertyNone => 'None';

  @override
  String get mortgageFormPlateLabel => 'Computed instalment';

  @override
  String mortgageFormPlateDetail(String instalment, String interest) {
    return 'total instalment $instalment — total interest $interest';
  }

  @override
  String get mortgageFormPlatePending =>
      'Fill in the principal, the rate and the term.';

  @override
  String get mortgageFormPlateInterestOnly =>
      'An interest-only loan\'s instalment shows once the loan is saved.';

  @override
  String get mortgageFormCancel => 'Cancel';

  @override
  String get mortgageFormSubmit => 'Add loan';

  @override
  String get mortgageFormSave => 'Save';

  @override
  String get mortgageFormDelete => 'Delete loan';

  @override
  String get mortgageDeleteTitle => 'Delete this loan?';

  @override
  String get mortgageDeleteBody =>
      'It will leave the liabilities in Net worth and, if it is linked to a property, the IFI base.';

  @override
  String get mortgageDeleteConfirm => 'Delete';

  @override
  String get mortgageErrorNonAmortizing =>
      'This loan never repays: the instalment doesn\'t cover the first month\'s interest. Change the rate, the amount borrowed or the term.';

  @override
  String get mortgageErrorFeesExceed =>
      'Upfront fees must stay below the amount borrowed.';

  @override
  String get mortgageErrorPropertyInvalid => 'This property no longer exists.';

  @override
  String get mortgageErrorNotFound => 'This loan no longer exists.';

  @override
  String get mortgageErrorValidation => 'Some values are invalid.';

  @override
  String get mortgageErrorGeneric => 'Something went wrong. Try again.';

  @override
  String get mortgageScheduleTitle => 'Amortisation schedule';

  @override
  String mortgageScheduleSubtitle(int position, int total, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count instalments',
      one: '1 instalment',
    );
    return 'Year $position of $total · $_temp0 · insurance is counted separately';
  }

  @override
  String mortgageScheduleSubtitleLoading(int position, int total) {
    return 'Year $position of $total';
  }

  @override
  String get mortgageScheduleDue => 'Due date';

  @override
  String get mortgageScheduleInterest => 'Interest';

  @override
  String get mortgageSchedulePrincipal => 'Principal';

  @override
  String get mortgageScheduleInsurance => 'Insurance';

  @override
  String get mortgageScheduleTotalPaid => 'Total paid';

  @override
  String get mortgageScheduleOutstanding => 'Outstanding';

  @override
  String mortgageScheduleFootTotal(String year) {
    return '$year total';
  }

  @override
  String mortgageScheduleFootOutstanding(String date, String amount) {
    return 'at $date: $amount';
  }

  @override
  String get mortgageScheduleYearPrevious => 'Previous year';

  @override
  String get mortgageScheduleYearNext => 'Next year';

  @override
  String get mortgageScheduleLoadFailed =>
      'Couldn\'t load the amortisation schedule.';

  @override
  String get simulatorLoadFailed => 'Couldn\'t load the simulator.';

  @override
  String get simulatorRetry => 'Try again';

  @override
  String get simulatorFormTitle => 'New loan';

  @override
  String get simulatorFormSubtitle => 'The result updates as you type';

  @override
  String get simulatorPrice => 'Property price';

  @override
  String get simulatorDownPayment => 'Down payment';

  @override
  String get simulatorFees => 'Fees';

  @override
  String get simulatorPrincipal => 'Amount borrowed';

  @override
  String get simulatorDerivedPill => 'Derived';

  @override
  String get simulatorRate => 'Nominal rate';

  @override
  String get simulatorRateInvalid => 'Enter a rate, for example 3.25.';

  @override
  String get simulatorInsurance => 'Insurance / month';

  @override
  String get simulatorTerm => 'Term';

  @override
  String simulatorTermValue(int months, num years) {
    final intl.NumberFormat yearsNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String yearsString = yearsNumberFormat.format(years);

    String _temp0 = intl.Intl.pluralLogic(
      years,
      locale: localeName,
      other: '$yearsString years',
      one: '1 year',
    );
    return '$months months · $_temp0';
  }

  @override
  String simulatorYears(num years) {
    final intl.NumberFormat yearsNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String yearsString = yearsNumberFormat.format(years);

    String _temp0 = intl.Intl.pluralLogic(
      years,
      locale: localeName,
      other: '$yearsString years',
      one: '1 year',
    );
    return '$_temp0';
  }

  @override
  String simulatorMonths(int months) {
    return '$months months';
  }

  @override
  String get simulatorIncludeExisting => 'Include my current loans';

  @override
  String simulatorIncludeExistingAdds(String amount) {
    return 'Adds $amount / month to the reading';
  }

  @override
  String get simulatorIncludeExistingNone => 'No current loan to add';

  @override
  String get simulatorInstalmentLabel => 'Monthly instalment';

  @override
  String simulatorInstalmentCaption(
    String payment,
    String insurance,
    int count,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count instalments',
      one: '1 instalment',
    );
    return '$payment payment + $insurance insurance · $_temp0';
  }

  @override
  String get simulatorInstalmentEmpty =>
      'Enter a price and a rate to see the instalment and its insurance share.';

  @override
  String get simulatorCostLabel => 'Total cost';

  @override
  String simulatorCostCaption(
    String interest,
    String insurance,
    String fees,
    String share,
  ) {
    return 'interest $interest + insurance $insurance + fees $fees · $share of the price';
  }

  @override
  String simulatorCostCaptionNoPrice(
    String interest,
    String insurance,
    String fees,
  ) {
    return 'interest $interest + insurance $insurance + fees $fees';
  }

  @override
  String get simulatorCostEmpty =>
      'Enter a price and a rate to see the total cost and its share of the price.';

  @override
  String get simulatorTaegLabel => 'APR';

  @override
  String get simulatorIndicativePill => 'Indicative';

  @override
  String get simulatorTaegCaption => 'rate, insurance and fees included';

  @override
  String get simulatorHcsfTitle => 'HCSF reading';

  @override
  String get simulatorHcsfOver => 'Above the reference';

  @override
  String get simulatorHcsfCaveat => 'Informative — binds no lender';

  @override
  String simulatorReference(String value) {
    return 'reference $value';
  }

  @override
  String get simulatorRatioLabel => 'Debt ratio';

  @override
  String simulatorRatioCaption(
    String instalment,
    String source,
    String income,
  ) {
    String _temp0 = intl.Intl.selectLogic(source, {
      'declared': 'declared',
      'other': 'median observed',
    });
    return '$instalment against a $_temp0 income of $income';
  }

  @override
  String simulatorRatioCaptionWithExisting(
    String instalment,
    String existing,
    String source,
    String income,
  ) {
    String _temp0 = intl.Intl.selectLogic(source, {
      'declared': 'declared',
      'other': 'median observed',
    });
    return '$instalment + current loans $existing against a $_temp0 income of $income';
  }

  @override
  String get simulatorRatioEmpty =>
      'Enter a price and a rate to read the debt ratio.';

  @override
  String get simulatorRatioUnknown =>
      'No known income: the ledger has no regular income and none is declared. Without an income, neither a ratio nor a capacity can be read.';

  @override
  String get simulatorDeclareIncome => 'Declare an income';

  @override
  String get simulatorTermAtReference => 'at the reference, not beyond';

  @override
  String get simulatorTermUnderReference => 'under the reference';

  @override
  String get simulatorTermOverReference => 'beyond the reference';

  @override
  String get simulatorCapacityLabel => 'Borrowing capacity at the reference';

  @override
  String simulatorCapacityCaption(String available, String limit) {
    return '$available of instalment available under $limit, on these terms';
  }

  @override
  String simulatorCapacityCaptionExisting(String available) {
    return 'only $available of instalment is left under the reference once your current loans are counted — that is what keeps the capacity so low, not the property';
  }

  @override
  String get simulatorCapacityEmpty =>
      'Enter a price and a rate to read the borrowing capacity.';

  @override
  String get simulatorChartTitle => 'Yearly projection';

  @override
  String get simulatorChartSubtitle =>
      'Principal repaid and interest paid, year by year';

  @override
  String get simulatorChartCapital => 'Principal';

  @override
  String get simulatorChartInterest => 'Interest';

  @override
  String get simulatorChartEmpty =>
      'Enter a price and a rate: the yearly split between principal and interest shows here.';

  @override
  String get simulatorComputeFailed =>
      'The calculation didn\'t go through. Try again in a moment.';

  @override
  String get simulatorErrorNonAmortizing =>
      'At this rate the instalment doesn\'t repay the principal: lower the rate or lengthen the term.';

  @override
  String get simulatorErrorFeesExceed =>
      'Fees must stay below the amount borrowed.';

  @override
  String get simulatorErrorValidation => 'Some values aren\'t accepted.';

  @override
  String get simulatorErrorGeneric => 'Something went wrong. Try again.';

  @override
  String get simulatorIncomeTitle => 'Declare an income';

  @override
  String get simulatorIncomeBody =>
      'The declared monthly income is the basis of the debt ratio and the borrowing capacity.';

  @override
  String get simulatorIncomeLabel => 'Net monthly income';

  @override
  String get simulatorIncomeInvalid => 'Enter an amount above zero.';

  @override
  String get simulatorIncomeSubmit => 'Declare';

  @override
  String get simulatorIncomeFailed => 'Couldn\'t save this income. Try again.';

  @override
  String get simulatorCancel => 'Cancel';
}
