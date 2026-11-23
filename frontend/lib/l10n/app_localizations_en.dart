// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Bastide';

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
  String get windowControls => 'Window';

  @override
  String get windowMinimize => 'Minimize';

  @override
  String get windowMaximize => 'Maximize';

  @override
  String get windowRestore => 'Restore';

  @override
  String get windowClose => 'Close';

  @override
  String get sidebarPrivacyBadge => 'Local data';

  @override
  String sidebarReviewCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions to review',
      one: '1 transaction to review',
    );
    return '$_temp0';
  }

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
  String get settingsGroupDisplay => 'Display';

  @override
  String get settingsGroupMoney => 'Money';

  @override
  String get settingsFormatsNote =>
      'Dates and amounts follow the chosen language.';

  @override
  String settingsFormatsDatePair(String long, String short) {
    return '$long · $short';
  }

  @override
  String settingsCurrencyValue(String code, String name, String symbol) {
    return '$code, $name ($symbol)';
  }

  @override
  String get settingsSavingsGoalTitle => 'Savings-rate goal';

  @override
  String get settingsSavingsGoalNote => 'The mark shown on the dashboard.';

  @override
  String get settingsIncomeTitle => 'Declared income';

  @override
  String get settingsIncomeNote =>
      'Used for the debt ratio in the Loans and Simulator panels. Without it, Bastide uses the median income it observed.';

  @override
  String get settingsIncomePerMonth => 'per month';

  @override
  String get settingsIncomeInvalid =>
      'Enter a positive amount, or leave it empty.';

  @override
  String get settingsIncomeSaveFailed =>
      'The income couldn’t be saved. Nothing was changed. Try again.';

  @override
  String get settingsGroupSecurity => 'Security';

  @override
  String get settingsGroupSession => 'Session';

  @override
  String get settingsEmailTitle => 'Email address';

  @override
  String get settingsEmailNote =>
      'Used only to sign in. Bastide sends no messages.';

  @override
  String get settingsProfileNameNote =>
      'You can sign in with this name or with your email.';

  @override
  String get settingsLogoutTitle => 'Log out';

  @override
  String get settingsLogoutNote =>
      'Your data stays on this computer, protected by your password.';

  @override
  String get settingsAiEngineTitle => 'Engine';

  @override
  String get settingsAiConnected => 'Connected';

  @override
  String settingsAiModelCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count models available',
      one: '1 model available',
      zero: 'no model available',
    );
    return '· $_temp0';
  }

  @override
  String get settingsAiThresholdTitle => 'Confidence threshold';

  @override
  String settingsBackupRestoreRefused(String reason) {
    return 'Restore not possible. $reason';
  }

  @override
  String get settingsResetRowTitle => 'Reset the database';

  @override
  String settingsResetRefused(String reason) {
    return 'Reset not possible. $reason';
  }

  @override
  String settingsAboutVersionLine(String version, String os) {
    return 'Version $version · $os';
  }

  @override
  String settingsAboutOs(String os) {
    String _temp0 = intl.Intl.selectLogic(os, {
      'windows': 'Windows',
      'macos': 'macOS',
      'linux': 'Linux',
      'other': '$os',
    });
    return '$_temp0';
  }

  @override
  String get settingsUpdatesLatest => 'You are on the latest version.';

  @override
  String get settingsUpdatesCheckNow => 'Check now';

  @override
  String get settingsAboutPrivacyTitle => 'Privacy';

  @override
  String get settingsAboutPrivacyNote => 'What Bastide does with your data.';

  @override
  String get settingsAboutDataTitle => 'Data location';

  @override
  String get settingsAboutDataNote =>
      'The file that holds your entire history.';

  @override
  String get settingsAboutDataOpen => 'Open folder';

  @override
  String get settingsAboutLicenseTitle => 'License';

  @override
  String get settingsAboutLicenseNote =>
      'Bastide is free software. Its name and logo are not covered by the license.';

  @override
  String get settingsAboutLicenseName =>
      'GNU Affero General Public License v3.0';

  @override
  String get settingsAboutSourceCode => 'Source code';

  @override
  String get settingsAboutInstallGuide => 'Installation guide';

  @override
  String get settingsAboutCreditsNote =>
      'The third-party components shipped with the app.';

  @override
  String get settingsAboutCreditsIconsLabel => 'Icons';

  @override
  String get settingsAboutCreditsFontLabel => 'Typeface';

  @override
  String get settingsAboutCreditsFont => 'Geist, SIL OFL license';

  @override
  String get settingsAboutAllLicenses => 'All licenses';

  @override
  String get settingsThemeTitle => 'Theme';

  @override
  String get settingsThemeNote => 'Dark, light, or your system’s.';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeSaveFailed =>
      'The theme could not be saved. Nothing was changed. Try again.';

  @override
  String get settingsTextSizeTitle => 'Text size';

  @override
  String get settingsTextSizeNote => 'Makes all the app’s text larger.';

  @override
  String get settingsTextSizeNormal => 'Normal';

  @override
  String get settingsTextSizeLarge => 'Large';

  @override
  String get settingsTextSizeXLarge => 'Extra large';

  @override
  String get settingsTextSizeSaveFailed =>
      'The text size could not be saved. Nothing was changed. Try again.';

  @override
  String get settingsLanguageTitle => 'Language';

  @override
  String get settingsLanguageNote =>
      'Applies immediately across the whole interface.';

  @override
  String get settingsSidebarTitle => 'Sidebar';

  @override
  String get settingsSidebarNote => 'Collapsed, it keeps only the icons.';

  @override
  String get settingsSidebarExpanded => 'Expanded';

  @override
  String get settingsSidebarCollapsed => 'Collapsed';

  @override
  String get settingsCurrencyTitle => 'Currency';

  @override
  String get settingsCurrencyNote =>
      'Chosen when you registered and applied to all your accounts. It cannot be changed in this version.';

  @override
  String get settingsFormatsTitle => 'Formats';

  @override
  String get settingsFormatsDates => 'Date';

  @override
  String get settingsFormatsAmounts => 'Amount';

  @override
  String get settingsAboutVersionUnavailable => 'Unavailable';

  @override
  String get settingsAboutCreditsTitle => 'Credits';

  @override
  String get settingsAboutCreditsIcons => 'Lucide, ISC license';

  @override
  String get settingsUpdatesTitle => 'Updates';

  @override
  String get settingsUpdatesSubtitle => 'Tell me about a new version';

  @override
  String get settingsUpdatesToggleLabel => 'Check for updates';

  @override
  String get settingsUpdatesNote =>
      'At most once a day, Bastide asks GitHub for the number of the latest release. Nothing else is sent, and nothing is installed without you.';

  @override
  String get settingsUpdatesChecking => 'Checking…';

  @override
  String settingsUpdatesAvailable(String version) {
    return 'Bastide $version is available';
  }

  @override
  String get settingsUpdatesDownload => 'Download';

  @override
  String get settingsUpdatesOffline => 'GitHub could not be reached.';

  @override
  String get settingsUpdatesUnavailable => 'Update status unavailable.';

  @override
  String get settingsUpdatesToastLatest => 'Bastide is up to date';

  @override
  String settingsUpdatesToastAvailable(String version) {
    return 'New version available: Bastide $version';
  }

  @override
  String get settingsUpdatesToastFailed => 'The check failed';

  @override
  String get settingsUpdatesToastOffline =>
      'GitHub could not be reached. Try again later.';

  @override
  String get settingsUpdatesToastError =>
      'Bastide could not start the check. Try again.';

  @override
  String get settingsAboutPrivacy =>
      'All your data stays on this computer. Bastide connects to no bank and sends nothing over the internet, apart from the update check if you turn it on.';

  @override
  String get comingSoonBody =>
      'This screen arrives in a later step. In the meantime, add your accounts to get set up.';

  @override
  String get authPrivacyLine => 'Your data stays on this computer.';

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
  String authPasswordMinimum(int minimum) {
    return '$minimum characters minimum.';
  }

  @override
  String authPasswordLengthOk(int count, int minimum) {
    return '$count characters. The minimum is $minimum.';
  }

  @override
  String authPasswordTooShort(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count more characters.',
      one: '1 more character.',
    );
    return '$_temp0';
  }

  @override
  String get authConfirmPasswordLabel => 'Confirm password';

  @override
  String get authPasswordMismatch => 'The passwords do not match.';

  @override
  String get authDisplayNameLabel => 'Username';

  @override
  String get authPreferencesNote =>
      'You can change the language in Settings. The currency is permanent and applies to all your accounts.';

  @override
  String get authEmailTaken => 'This email already has an account. Sign in.';

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
  String authCurrencyOption(String code, String name) {
    return '$code, $name';
  }

  @override
  String authCurrencyName(String code) {
    String _temp0 = intl.Intl.selectLogic(code, {
      'EUR': 'euro',
      'USD': 'US dollar',
      'GBP': 'pound sterling',
      'CHF': 'Swiss franc',
      'CAD': 'Canadian dollar',
      'JPY': 'Japanese yen',
      'AUD': 'Australian dollar',
      'CNY': 'Chinese yuan',
      'INR': 'Indian rupee',
      'BRL': 'Brazilian real',
      'MXN': 'Mexican peso',
      'SEK': 'Swedish krona',
      'NOK': 'Norwegian krone',
      'DKK': 'Danish krone',
      'PLN': 'Polish zloty',
      'CZK': 'Czech koruna',
      'HUF': 'Hungarian forint',
      'RON': 'Romanian leu',
      'ZAR': 'South African rand',
      'AED': 'UAE dirham',
      'SGD': 'Singapore dollar',
      'HKD': 'Hong Kong dollar',
      'NZD': 'New Zealand dollar',
      'TRY': 'Turkish lira',
      'ILS': 'Israeli shekel',
      'KRW': 'South Korean won',
      'THB': 'Thai baht',
      'MAD': 'Moroccan dirham',
      'XOF': 'West African CFA franc',
      'XAF': 'Central African CFA franc',
      'other': '$code',
    });
    return '$_temp0';
  }

  @override
  String get authLoginSubmit => 'Log in';

  @override
  String get authRegisterSubmit => 'Create account';

  @override
  String get authRegisterSubmitting => 'Creating…';

  @override
  String get authGoToRegister => 'Create an account';

  @override
  String get authGoToLogin => 'Already have an account?';

  @override
  String get authGoToLoginLink => 'Log in';

  @override
  String get authPasswordRequired => 'Password is required.';

  @override
  String get authErrorInvalidCredentials =>
      'Wrong email, username or password.';

  @override
  String get authErrorEmailTaken =>
      'An account with this email already exists.';

  @override
  String get authErrorValidation => 'Some information is invalid.';

  @override
  String authErrorPasswordTooShort(int minimum) {
    return 'The password must be at least $minimum characters long.';
  }

  @override
  String get authErrorGeneric => 'Something went wrong. Please try again.';

  @override
  String get accountsAddButton => 'Add account';

  @override
  String get accountsTotalBalanceLabel => 'Total balance';

  @override
  String get accountsEmptyTitle => 'Add your first account';

  @override
  String get accountsEmptyBody =>
      'Create an account, or import a statement: Bastide creates the account it describes.';

  @override
  String get accountsRetry => 'Retry';

  @override
  String get accountsGroupByType => 'By type';

  @override
  String get accountsGroupByInstitution => 'By institution';

  @override
  String get accountsGroupChecking => 'Current accounts';

  @override
  String get accountsGroupSavings => 'Savings';

  @override
  String get accountsGroupDeferredCards => 'Deferred debit cards';

  @override
  String get accountsGroupCredits => 'Credit';

  @override
  String get accountsGroupOther => 'Other';

  @override
  String get accountsNoInstitution => 'No institution';

  @override
  String accountsGroupShare(double share) {
    final intl.NumberFormat shareNumberFormat =
        intl.NumberFormat.decimalPatternDigits(
          locale: localeName,
          decimalDigits: 1,
        );
    final String shareString = shareNumberFormat.format(share);

    return '$shareString% of total';
  }

  @override
  String accountsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count accounts',
      one: '1 account',
    );
    return '$_temp0';
  }

  @override
  String accountsSummaryCaption(String accounts, String ago) {
    return '$accounts · balances recalculated $ago';
  }

  @override
  String accountsAgoMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes min ago',
      one: '1 min ago',
      zero: 'just now',
    );
    return '$_temp0';
  }

  @override
  String accountsAgoHours(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours h ago',
      one: '1 h ago',
    );
    return '$_temp0';
  }

  @override
  String get accountsColumnAccount => 'Account';

  @override
  String get accountsColumnInstitution => 'Institution';

  @override
  String get accountsColumnLastImport => 'Last import';

  @override
  String accountsColumnMonthChange(String month) {
    return 'Change in $month';
  }

  @override
  String get accountsColumnBalance => 'Balance';

  @override
  String get accountsNoImport => '—';

  @override
  String accountsCardCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cards',
      one: '1 card',
    );
    return '$_temp0';
  }

  @override
  String get accountsGoToImports => 'Go to imports';

  @override
  String get accountCurrencyLabel => 'Currency';

  @override
  String accountCurrencyValue(String currency) {
    String _temp0 = intl.Intl.selectLogic(currency, {
      'EUR': 'EUR, euro',
      'USD': 'USD, US dollar',
      'GBP': 'GBP, pound sterling',
      'CHF': 'CHF, Swiss franc',
      'other': '$currency',
    });
    return '$_temp0';
  }

  @override
  String get accountCurrencyHelper => 'The currency is your profile’s.';

  @override
  String get accountEdit => 'Edit';

  @override
  String get accountArchive => 'Archive';

  @override
  String get accountSettlementRule => 'Settlement rule';

  @override
  String cardSettlementNoAccount(String card) {
    return '$card: choose the account the card is paid from, so its purchases count only once.';
  }

  @override
  String get cardSettlementChooseAccount => 'Choose the account';

  @override
  String cardSettlementNoRule(String card) {
    return '$card’s monthly debit counts as spending on top of the card’s purchases: create its settlement rule.';
  }

  @override
  String get cardSettlementCreateRule => 'Create the rule';

  @override
  String cardSettlementUnsettled(
    int count,
    String card,
    String amount,
    DateTime date,
  ) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMd(localeName);
    final String dateString = dateDateFormat.format(date);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count purchases on $card ($amount) have waited for their debit since $dateString: the card’s rule may no longer match the bank’s wording.',
      one:
          'One purchase on $card ($amount) has waited for its debit since $dateString: the card’s rule may no longer match the bank’s wording.',
    );
    return '$_temp0';
  }

  @override
  String get cardSettlementCheckRule => 'Check the rule';

  @override
  String get settlementRuleTitle => 'Card settlement rule';

  @override
  String settlementRuleBody(String card) {
    return 'Each month, the bank charges the total of $card to the account that pays it. That debit is a transfer, not spending: the card’s purchases are already counted one by one.';
  }

  @override
  String get settlementRulePatternLabel => 'The debit’s label contains';

  @override
  String get settlementRulePatternHelper =>
      'Proposed from the labels that recur each month on the account paying the card.';

  @override
  String get settlementRulePatternRequired =>
      'Enter the text that names the debit.';

  @override
  String get settlementRuleFromLabel => 'Applies from';

  @override
  String get settlementRuleFromHelper =>
      'Earlier debits stay spending: the purchases they paid aren’t in the app. Proposed from the card’s imported history.';

  @override
  String get settlementRuleFromInvalid => 'Invalid date.';

  @override
  String ruleAppliesFrom(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'from $dateString';
  }

  @override
  String get settlementRuleSave => 'Save rule';

  @override
  String get settlementRuleLater => 'Later';

  @override
  String settlementRuleSaved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Rule saved: $count debits filed as transfers.',
      one: 'Rule saved: 1 debit filed as a transfer.',
      zero: 'Rule saved.',
    );
    return '$_temp0';
  }

  @override
  String get settlementRuleLoadFailed => 'Couldn’t load the card’s rule.';

  @override
  String get settlementRuleSaveFailed => 'Couldn’t save the rule. Try again.';

  @override
  String get accountArchiveConfirmTitle => 'Archive this account?';

  @override
  String get accountArchiveConfirmBody =>
      'You’ll still be able to view its history, but it will no longer appear in your accounts list.';

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
  String get accountCardDebitLabel => 'Card debit';

  @override
  String get accountCardDebitDeferred => 'Deferred debit';

  @override
  String get accountCardDebitCredit => 'Credit';

  @override
  String get accountSettlementLabel => 'Paid from';

  @override
  String get accountSettlementHelper =>
      'The account charged the card’s total each month: that debit is a transfer between the two, not spending.';

  @override
  String get accountSettlementPlaceholder => 'Choose an account';

  @override
  String get accountSettlementRequired => 'Choose the account it is paid from.';

  @override
  String get accountErrorSettlementRequired =>
      'A deferred-debit card must name the account it is paid from.';

  @override
  String get accountErrorSettlementInvalid =>
      'This account cannot pay the card.';

  @override
  String get accountCardDebitHelper =>
      'A deferred-debit card is charged to your current account in one sum each month.';

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
      'Correcting this shifts the account’s balance and any saved history by the same amount. It never touches a transaction.';

  @override
  String get accountOpeningBalanceRequired => 'Balance is required.';

  @override
  String get accountOpeningBalanceInvalid => 'Enter a valid amount.';

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
  String get importAccountsUnavailable =>
      'Couldn’t load your accounts. Try again in a moment.';

  @override
  String get importDropZoneTitle => 'Drop an OFX or QFX statement';

  @override
  String get importDropZoneHint =>
      'The statement names its own account. Nothing is imported until you confirm.';

  @override
  String importFileSize(String size) {
    return '$size kB';
  }

  @override
  String get importRemoveFile => 'Remove';

  @override
  String get importSubmit => 'Import';

  @override
  String get importSubmitting => 'Importing…';

  @override
  String get importAll => 'Import all';

  @override
  String importDetectedAccountAmbiguous(String account) {
    return 'This statement is from $account, but several accounts match it. Choose the destination.';
  }

  @override
  String importDetectedAccountUnknown(String account) {
    return 'Unknown account: $account';
  }

  @override
  String get importCreateDetectedAccount => 'Create this account';

  @override
  String get importCardAccountName => 'Card';

  @override
  String get importChooseAccount => 'Choose an account';

  @override
  String get importUnreadableAccount =>
      'This file names no account. Choose the destination.';

  @override
  String importPeriodRange(String start, String end) {
    return '$start – $end';
  }

  @override
  String get importFailedNote => 'Unreadable file. Nothing was changed.';

  @override
  String importDuplicatesNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions already present were skipped.',
      one: '1 transaction already present was skipped.',
    );
    return '$_temp0';
  }

  @override
  String importBalanceMismatchNote(String amount, DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Off by $amount from the bank’s balance as of $dateString.';
  }

  @override
  String get importStatusSuccess => 'Succeeded';

  @override
  String get importStatusPartial => 'Partial';

  @override
  String get importStatusFailed => 'Failed';

  @override
  String get importHistoryTitle => 'History';

  @override
  String get importHistoryEmptyTitle => 'No imports';

  @override
  String get importHistoryEmptyBody =>
      'Drop a statement above and your transactions will appear here.';

  @override
  String get importHistoryFileHeader => 'File';

  @override
  String get importHistoryImportedHeader => 'Imported on';

  @override
  String get importHistoryPeriodHeader => 'Period covered';

  @override
  String get importHistoryNewHeader => 'New';

  @override
  String get importHistoryDuplicatesHeader => 'Duplicates';

  @override
  String get importRetry => 'Try again';

  @override
  String get importErrorAccountNotFound => 'Account not found.';

  @override
  String get importErrorBatchNotFound => 'Import not found.';

  @override
  String get importErrorStatementRequired =>
      'This file holds several accounts and none was named.';

  @override
  String get importErrorStatementNotFound => 'That account isn’t in the file.';

  @override
  String get importDuplicateDestination =>
      'Two statements go to the same account. Choose a different destination.';

  @override
  String get importErrorGeneric => 'Something went wrong. Please try again.';

  @override
  String get importBrowse => 'Browse';

  @override
  String get importDetectionRecognised => 'Account recognized';

  @override
  String get importDetectionAmbiguous => 'Several accounts match';

  @override
  String get importDetectionNoAccount => 'No account named';

  @override
  String get importUnsupportedFormat => 'Format not supported.';

  @override
  String importToastSummary(int newCount, int duplicateCount) {
    final intl.NumberFormat newCountNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String newCountString = newCountNumberFormat.format(newCount);
    final intl.NumberFormat duplicateCountNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String duplicateCountString = duplicateCountNumberFormat.format(
      duplicateCount,
    );

    String _temp0 = intl.Intl.pluralLogic(
      newCount,
      locale: localeName,
      other: '$newCountString new transactions',
      one: '1 new transaction',
      zero: 'No new transactions',
    );
    String _temp1 = intl.Intl.pluralLogic(
      duplicateCount,
      locale: localeName,
      other: '$duplicateCountString duplicates skipped',
      one: '1 duplicate skipped',
      zero: 'no duplicates',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get importHistoryAccountHeader => 'Account';

  @override
  String get importHistoryResultHeader => 'Result';

  @override
  String get importBalanceMismatchStatus => 'Balance gap';

  @override
  String get importHistoryNoValue => '—';

  @override
  String get transactionsSearchHint => 'Search';

  @override
  String get searchShortcutHint => 'Ctrl K';

  @override
  String get transactionsRetry => 'Retry';

  @override
  String get transactionsEmptyTitle => 'No transactions';

  @override
  String get transactionsEmptyBody =>
      'Import a statement to see your operations here.';

  @override
  String get transactionsGoToImports => 'Go to imports';

  @override
  String get transactionsNeedsReviewLabel => 'To review';

  @override
  String get transactionsFilterAllAccounts => 'All accounts';

  @override
  String get transactionsFilterAllCategories => 'All categories';

  @override
  String get transactionsFilterAllDates => 'All dates';

  @override
  String transactionsFilterImport(String fileName) {
    return 'Import: $fileName';
  }

  @override
  String get transactionsFilterImportRemove => 'Remove the import filter';

  @override
  String transactionsFilterOperation(String name) {
    return 'Operation: $name';
  }

  @override
  String get transactionsFilterOperationRemove => 'Remove the operation filter';

  @override
  String get transactionsDateRangeTitle => 'Date range';

  @override
  String get transactionsDateRangeFromLabel => 'From';

  @override
  String get transactionsDateRangeToLabel => 'To';

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
  String get transactionsDateRangeApply => 'Apply';

  @override
  String transactionsPager(int from, int to, int total) {
    return '$from – $to of $total';
  }

  @override
  String get transactionsTabAll => 'All';

  @override
  String transactionsPeriodRange(String from, String to) {
    return '$from – $to';
  }

  @override
  String transactionsCountNet(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count operations · net',
      one: '1 operation · net',
    );
    return '$_temp0';
  }

  @override
  String get transactionsColumnOperation => 'Operation';

  @override
  String get transactionsColumnCategory => 'Category';

  @override
  String get transactionsColumnAmount => 'Amount';

  @override
  String get transactionsPagerPrevious => 'Previous page';

  @override
  String get transactionsPagerNext => 'Next page';

  @override
  String get transactionsNoResult => 'No operation for these filters.';

  @override
  String get transactionsClearFilters => 'Clear the filters';

  @override
  String get transactionInspectorEmpty =>
      'Select an operation to see its details.';

  @override
  String get transactionInspectorDate => 'Date';

  @override
  String get transactionInspectorAccount => 'Account';

  @override
  String get transactionInspectorCategory => 'Category';

  @override
  String get transactionInspectorClassifiedBy => 'Filed by';

  @override
  String get transactionInspectorImport => 'Import';

  @override
  String transactionClassifiedByRule(String pattern) {
    return 'rule “$pattern”';
  }

  @override
  String transactionClassifiedByModel(double confidence) {
    final intl.NumberFormat confidenceNumberFormat =
        intl.NumberFormat.percentPattern(localeName);
    final String confidenceString = confidenceNumberFormat.format(confidence);

    return 'local AI, confidence $confidenceString';
  }

  @override
  String get transactionClassifiedByUser => 'you';

  @override
  String get transactionClassifiedByNone => 'not filed';

  @override
  String get transactionInspectorLoadError =>
      'These details could not be loaded. Nothing was changed.';

  @override
  String get transactionRecurringTitle => 'Recurring payment';

  @override
  String transactionRecurringNext(String cadence, String date) {
    return '$cadence · next on $date';
  }

  @override
  String get transactionRecurringView => 'View the series';

  @override
  String get transactionSameMerchant => 'Same merchant';

  @override
  String get transactionSameMerchantNone => 'No earlier operation.';

  @override
  String get transactionCreateRule => 'Create a rule';

  @override
  String get transactionEditRule => 'Edit the rule';

  @override
  String reviewProgressCount(int done, int total) {
    return '$done of $total';
  }

  @override
  String get reviewProgressCaption => 'filed';

  @override
  String reviewAiNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Local AI proposes a category for $count operations. Nothing is filed without your consent.',
      one:
          'Local AI proposes a category for 1 operation. Nothing is filed without your consent.',
      zero:
          'Local AI proposed no category. Nothing is filed without your consent.',
    );
    return '$_temp0';
  }

  @override
  String get reviewColumnLabel => 'Statement label';

  @override
  String get reviewColumnDate => 'Date';

  @override
  String get reviewColumnProposal => 'Proposal';

  @override
  String get reviewEmptyTitle => 'Nothing to review';

  @override
  String get reviewEmptyBody => 'All your operations have a category.';

  @override
  String get alwaysRuleLead =>
      'A rule files these operations at every import, without AI.';

  @override
  String alwaysRuleCreatedToast(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Rule created · $count operations recategorized',
      one: 'Rule created · 1 operation recategorized',
      zero: 'Rule created',
    );
    return '$_temp0';
  }

  @override
  String get reviewAlwaysCategorize => 'Always categorize like this';

  @override
  String get categoryPickerSearchHint => 'Change category';

  @override
  String get categoryPickerLoadError => 'Couldn’t load categories.';

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
  String get categorySystemHousingCondoFees => 'Condo fees';

  @override
  String get categorySystemHousingMaintenance => 'Repairs and maintenance';

  @override
  String get categorySystemHousingHomeServices => 'Home services';

  @override
  String get categorySystemFood => 'Food';

  @override
  String get categorySystemFoodGroceries => 'Groceries';

  @override
  String get categorySystemFoodRestaurants => 'Restaurants';

  @override
  String get categorySystemFoodCoffee => 'Coffee';

  @override
  String get categorySystemFoodTakeaway => 'Takeaway and delivery';

  @override
  String get categorySystemFoodCanteen => 'Canteen';

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
  String get categorySystemTransportCarInsurance => 'Car insurance';

  @override
  String get categorySystemTransportTolls => 'Tolls';

  @override
  String get categorySystemTransportTaxi => 'Taxi and ride-hailing';

  @override
  String get categorySystemTransportRental => 'Vehicle rental';

  @override
  String get categorySystemHealth => 'Health';

  @override
  String get categorySystemHealthDoctor => 'Doctor';

  @override
  String get categorySystemHealthPharmacy => 'Pharmacy';

  @override
  String get categorySystemHealthInsurance => 'Health insurance';

  @override
  String get categorySystemHealthDentist => 'Dentist';

  @override
  String get categorySystemHealthOptician => 'Optician';

  @override
  String get categorySystemLeisure => 'Leisure';

  @override
  String get categorySystemLeisureOutings => 'Outings';

  @override
  String get categorySystemLeisureTravel => 'Travel';

  @override
  String get categorySystemLeisureAccommodation => 'Accommodation';

  @override
  String get categorySystemLeisureSports => 'Sports';

  @override
  String get categorySystemLeisureCulture => 'Culture';

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
  String get categorySystemShoppingPersonalCare => 'Personal care';

  @override
  String get categorySystemShoppingGifts => 'Gifts';

  @override
  String get categorySystemFinance => 'Finances';

  @override
  String get categorySystemFinanceBankFees => 'Bank fees';

  @override
  String get categorySystemFinanceTaxes => 'Taxes';

  @override
  String get categorySystemFinanceSavings => 'Savings';

  @override
  String get categorySystemFinanceCardSettlement => 'Deferred card settlement';

  @override
  String get categorySystemFinanceInterest => 'Interest';

  @override
  String get categorySystemFinanceInvestments => 'Investments';

  @override
  String get categorySystemFinanceLoans => 'Loan repayment';

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
  String get categorySystemIncomeBenefits => 'Benefits';

  @override
  String get categorySystemIncomeRental => 'Rental income';

  @override
  String get categorySystemIncomeSales => 'Sales';

  @override
  String get categorySystemIncomeOther => 'Other income';

  @override
  String get categorySystemOther => 'Other';

  @override
  String get categorySystemOtherUncategorized => 'Uncategorized';

  @override
  String get categorySystemOtherCash => 'Cash withdrawals';

  @override
  String get categorySystemOtherDonations => 'Donations';

  @override
  String get categorySystemChildren => 'Children';

  @override
  String get categorySystemChildrenChildcare => 'Childcare';

  @override
  String get categorySystemChildrenSchool => 'Schooling';

  @override
  String get categorySystemChildrenActivities => 'Kids’ activities';

  @override
  String get categorySystemPets => 'Pets';

  @override
  String get categorySystemPetsFood => 'Pet food';

  @override
  String get categorySystemPetsVet => 'Vet';

  @override
  String get dashboardStatIncome => 'Income';

  @override
  String get dashboardStatExpense => 'Expenses';

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
  String get dashboardSavingsGoalReached => 'Goal reached';

  @override
  String dashboardSavingsGoalPending(String goal) {
    return 'Goal $goal in progress';
  }

  @override
  String dashboardSavingsDeltaSince(String delta, DateTime month) {
    final intl.DateFormat monthDateFormat = intl.DateFormat.MMMM(localeName);
    final String monthString = monthDateFormat.format(month);

    return '$delta pt since $monthString';
  }

  @override
  String dashboardSavingsGoalMark(String goal) {
    return 'goal $goal';
  }

  @override
  String get dashboardNoValue => '—';

  @override
  String get dashboardCategoryBreakdownTitle => 'Spending by category';

  @override
  String get dashboardCategoryOthers => 'Other';

  @override
  String get dashboardCategoryNoSpending => 'No spending this month.';

  @override
  String get dashboardSavingsTrendTitle => 'Monthly savings';

  @override
  String get dashboardSavingsTrendAverage => 'on average over 12 months';

  @override
  String get dashboardRecentActivityTitle => 'Recent activity';

  @override
  String get dashboardViewAllTransactions => 'All transactions';

  @override
  String get dashboardEmptyTitle => 'No data for this month';

  @override
  String get dashboardEmptyBody =>
      'Import an OFX or QFX statement to see your income, your spending and your savings rate.';

  @override
  String get dashboardGoToImports => 'Go to imports';

  @override
  String get dashboardRetry => 'Retry';

  @override
  String get dashboardErrorInvalidMonth => 'The requested month isn’t valid.';

  @override
  String get dashboardErrorGeneric =>
      'The dashboard could not be loaded. Nothing was changed.';

  @override
  String get dashboardChooseMonth => 'Choose a month';

  @override
  String get dashboardPreviousMonth => 'Previous month';

  @override
  String get dashboardNextMonth => 'Next month';

  @override
  String get dashboardPreviousYear => 'Previous year';

  @override
  String get dashboardNextYear => 'Next year';

  @override
  String get categoriesAddButton => 'New category';

  @override
  String get categoriesEmptyTitle => 'No categories';

  @override
  String get categoriesEmptyBody =>
      'Categories sort your spending. Create one to get started.';

  @override
  String get categoriesRetry => 'Try again';

  @override
  String get categoriesPanelTitle => 'Categories and rules';

  @override
  String get categoriesTreeTitle => 'Categories';

  @override
  String get categoriesAllRules => 'All rules';

  @override
  String get categoriesSystemNote =>
      'The categories that come with Bastide cannot be deleted.';

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
      other: '$count rules',
      one: '1 rule',
      zero: 'no rule',
    );
    return '$_temp0';
  }

  @override
  String categoryDeleteConfirmTitle(String name) {
    return 'Delete the category “$name”?';
  }

  @override
  String get categoryDeleteConfirmLead =>
      'Its subcategories will be deleted too. The transactions in them become uncategorized again.';

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
  String categoryColorName(String slot) {
    String _temp0 = intl.Intl.selectLogic(slot, {
      'cat1': 'Blue',
      'cat2': 'Orange',
      'cat3': 'Green',
      'cat4': 'Amber',
      'cat5': 'Pink',
      'cat6': 'Violet',
      'other': 'Gray',
    });
    return '$_temp0';
  }

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
  String get categoryIconKey => 'Key';

  @override
  String get categoryIconEnergy => 'Energy';

  @override
  String get categoryIconRepairs => 'Repairs';

  @override
  String get categoryIconFurniture => 'Furniture';

  @override
  String get categoryIconGroceries => 'Groceries';

  @override
  String get categoryIconRestaurant => 'Restaurant';

  @override
  String get categoryIconCoffee => 'Coffee';

  @override
  String get categoryIconPublicTransport => 'Public transport';

  @override
  String get categoryIconFuel => 'Fuel';

  @override
  String get categoryIconTravel => 'Travel';

  @override
  String get categoryIconOutings => 'Outings';

  @override
  String get categoryIconGames => 'Games';

  @override
  String get categoryIconReading => 'Reading';

  @override
  String get categoryIconSport => 'Sport';

  @override
  String get categoryIconPhone => 'Phone';

  @override
  String get categoryIconInternet => 'Internet';

  @override
  String get categoryIconPharmacy => 'Pharmacy';

  @override
  String get categoryIconCard => 'Bank card';

  @override
  String get categoryIconBank => 'Bank';

  @override
  String get categoryIconInvestments => 'Investments';

  @override
  String get categoryIconBills => 'Bills';

  @override
  String get categoryIconSalary => 'Salary';

  @override
  String get categoryIconGifts => 'Gifts';

  @override
  String get categoryIconClothing => 'Clothing';

  @override
  String get categoryIconShopping => 'Shopping';

  @override
  String get categoryIconEducation => 'Education';

  @override
  String get categoryIconChildren => 'Children';

  @override
  String get categoryIconPets => 'Pets';

  @override
  String get categoryIconDonations => 'Donations';

  @override
  String get categoryErrorNotEditable =>
      'This category belongs to the system: it cannot be edited or deleted.';

  @override
  String get categoryErrorValidation =>
      'That information isn’t valid. Check the name and the kind.';

  @override
  String get categoryErrorGeneric => 'Something went wrong. Please try again.';

  @override
  String get rulesAddButton => 'New rule';

  @override
  String get rulesPriorityNote =>
      'Applied in this order. A category you chose by hand is never replaced.';

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
      'The categories you chose by hand were not changed.';

  @override
  String get rulesApplyFailed => 'The rule run failed';

  @override
  String get rulesReorderFailed => 'The new order could not be saved';

  @override
  String get rulesToggleFailed => 'The rule could not be changed';

  @override
  String get rulesFilterClear => 'Show all rules';

  @override
  String get rulesFilterEmpty => 'No rule for this category.';

  @override
  String get rulesRetry => 'Try again';

  @override
  String get rulesPaneTitle => 'Rules';

  @override
  String get rulesColumnOrder => 'Order';

  @override
  String get rulesColumnField => 'Field';

  @override
  String get rulesColumnCondition => 'Condition';

  @override
  String get rulesColumnPattern => 'Pattern';

  @override
  String get rulesColumnCategory => 'Category';

  @override
  String get rulesColumnMatches => 'Matches';

  @override
  String get rulesColumnActive => 'Active';

  @override
  String get rulesEmptyTitle => 'No rules';

  @override
  String get rulesEmptyBody =>
      'A rule recognizes a label, “CARREFOUR” for example, and gives its category to every matching transaction, today and on every import after.';

  @override
  String get ruleToggleSemantics => 'Enable rule';

  @override
  String get ruleTargetMissing => 'Category missing';

  @override
  String get ruleFieldDescription => 'Description';

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
  String get ruleFormCategoryLabel => 'Target category';

  @override
  String get ruleFormCategoryNone => 'Choose a category';

  @override
  String get ruleFormCategoryRequired =>
      'Choose the category this rule assigns.';

  @override
  String get ruleFormEnabledLabel => 'Active';

  @override
  String get ruleFormLogoLabel => 'Logo';

  @override
  String get ruleFormLogoHelper =>
      'Shown instead of the monogram on the transactions and subscriptions this rule matches.';

  @override
  String get ruleFormLogoChoose => 'Choose a picture';

  @override
  String get ruleFormLogoReplace => 'Replace…';

  @override
  String get ruleFormLogoRemove => 'Remove';

  @override
  String get ruleFormLogoSaveFirst => 'Save the rule to add a logo to it.';

  @override
  String get modalCancel => 'Cancel';

  @override
  String get modalClose => 'Close';

  @override
  String get modalRetry => 'Retry';

  @override
  String get modalDiscardTitle => 'Discard your changes?';

  @override
  String modalDiscardLead(String form) {
    return 'What you entered in “$form” will be lost.';
  }

  @override
  String get modalDiscardContinue => 'Keep editing';

  @override
  String get modalDiscardConfirm => 'Discard';

  @override
  String get modalCropWindow => 'Framing';

  @override
  String get modalCropZoom => 'Zoom';

  @override
  String modalCropZoomValue(String value) {
    return '$value ×';
  }

  @override
  String get logoZoomOpen => 'Show the logo larger';

  @override
  String get logoZoomLabel => 'Enlarged logo';

  @override
  String get ruleLogoInvalid => 'This file isn’t a PNG, JPEG or WebP picture.';

  @override
  String get ruleLogoError => 'The logo couldn’t be saved. Try again.';

  @override
  String get ruleLogoCropTitle => 'Crop the logo';

  @override
  String get ruleLogoCropLead => 'Drag the image to frame the logo.';

  @override
  String get ruleLogoCropSave => 'Use this logo';

  @override
  String ruleLogoTooLarge(int megabytes) {
    return 'This picture is too large: choose a file under $megabytes MB.';
  }

  @override
  String get ruleFormLogoFromUrl => 'From an address…';

  @override
  String get ruleLogoUrlTitle => 'Logo from an address';

  @override
  String get ruleLogoUrlLead =>
      'Paste a picture’s address. Bastide downloads it from this computer, then you crop it.';

  @override
  String get ruleLogoUrlLabel => 'Picture address';

  @override
  String get ruleLogoUrlHint => 'https://…';

  @override
  String get ruleLogoUrlFetch => 'Download';

  @override
  String get ruleLogoUrlInvalidAddress =>
      'Enter an address starting with http:// or https://.';

  @override
  String get ruleLogoUrlUnreachable =>
      'The picture couldn’t be downloaded. Check the address and your connection.';

  @override
  String ruleLogoUrlTooLarge(int megabytes) {
    return 'This picture is over $megabytes MB.';
  }

  @override
  String get ruleLogoUrlNotAPicture =>
      'This address doesn’t lead to a picture.';

  @override
  String get ruleFormSave => 'Save';

  @override
  String get ruleFormDelete => 'Delete';

  @override
  String ruleDeleteConfirmTitle(String pattern) {
    return 'Delete the rule “$pattern”?';
  }

  @override
  String get ruleDeleteConfirmLead =>
      'The transactions it already classed keep their category.';

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
          'Matches $count existing transactions, including “$sample” of $date.',
      one: 'Matches $count existing transaction: “$sample” of $date.',
    );
    return '$_temp0';
  }

  @override
  String get ruleErrorPatternInvalid =>
      'That pattern isn’t a valid regular expression.';

  @override
  String get ruleErrorNotFound => 'That rule no longer exists.';

  @override
  String get ruleErrorCategoryNotFound =>
      'The target category no longer exists.';

  @override
  String get ruleErrorValidation =>
      'That information isn’t valid. Check the pattern and the priority.';

  @override
  String get ruleErrorGeneric => 'Something went wrong. Please try again.';

  @override
  String get rulePackImportFile => 'Import a rule pack';

  @override
  String rulePackImportBuiltin(String name) {
    return 'Import “$name”';
  }

  @override
  String get rulePackExportAction => 'Export my rules';

  @override
  String get rulePackRefusedTitle => 'This file wasn’t accepted';

  @override
  String get rulePackRefusedMalformed =>
      'This file isn’t a Bastide rule pack. Expected a JSON file with a name, a format version and a list of rules.';

  @override
  String rulePackRefusedVersion(int version) {
    return 'This pack uses a format version this build of Bastide doesn’t read. It reads version $version. A pack we only half understood would silently drop rules, so it is refused whole.';
  }

  @override
  String get rulePackRefusedRegex =>
      'Nothing was imported. This pack contains a “regex” rule, which Bastide doesn’t accept from a shared file: written by someone else, it could slow the app down badly. The “contains”, “equals” and “range” conditions are accepted.';

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
      'Read it before saving. A pattern can hold personal details, such as your landlord’s name: “VIR LOYER DUPONT”.';

  @override
  String rulePackExportContents(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'File contents: $count rules',
      one: 'File contents: $count rule',
      zero: 'File contents: no rules',
    );
    return '$_temp0';
  }

  @override
  String rulePackOmittedLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rules can’t be exported',
      one: '$count rule can’t be exported',
    );
    return '$_temp0';
  }

  @override
  String rulePackOmittedRegex(String pattern) {
    return '“$pattern”: regex rules cannot appear in a pack.';
  }

  @override
  String rulePackOmittedUserCategory(String pattern) {
    return '“$pattern”: targets a custom category, which has no shareable identifier.';
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
      'You’ll see what the pack would do before importing it.';

  @override
  String get rulePackRulesLabel => 'Rules in the pack';

  @override
  String get rulePackLogoCount => 'Logos to add';

  @override
  String rulePackLogoDownload(int count) {
    return 'Download the logos ($count)';
  }

  @override
  String get rulePackLogoDownloadHelper =>
      'These logos come from Wikimedia Commons and are downloaded only if you tick the box.';

  @override
  String rulePackLogoFailuresTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count logos couldn’t be added',
      one: 'One logo couldn’t be added',
    );
    return '$_temp0';
  }

  @override
  String get rulePackLogoFailuresNotice =>
      'The rules were imported: only these logos were left out.';

  @override
  String rulePackLogoFailureInvalidImage(String pattern) {
    return '“$pattern”: the file isn’t a PNG, JPEG or WebP picture.';
  }

  @override
  String rulePackLogoFailureTooLarge(String pattern) {
    return '“$pattern”: the picture is over the size limit.';
  }

  @override
  String rulePackLogoFailureDownloadFailed(String pattern) {
    return '“$pattern”: the download failed.';
  }

  @override
  String get rulePackExportIncludeLogos => 'Include the logos';

  @override
  String rulePackExportLogoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count logos included.',
      one: '$count logo included.',
      zero: 'No rule has a logo to include.',
    );
    return '$_temp0';
  }

  @override
  String get rulePackExportLogosTooLarge =>
      'The logos were left out: the pack would be too large to import. All the rules are exported, without their logos.';

  @override
  String rulePackExportLogoElided(int kilobytes) {
    return '‹ $kilobytes KB picture ›';
  }

  @override
  String get reviewAiInvitation =>
      'Turn on local AI to file the operations your rules did not recognise.';

  @override
  String get reviewAiInvitationLink => 'Settings';

  @override
  String reviewConfidence(double confidence) {
    final intl.NumberFormat confidenceNumberFormat =
        intl.NumberFormat.percentPattern(localeName);
    final String confidenceString = confidenceNumberFormat.format(confidence);

    return 'confidence $confidenceString';
  }

  @override
  String get reviewConfirm => 'Confirm';

  @override
  String get reviewCorrect => 'Correct';

  @override
  String get reviewNoProposal => 'No proposal';

  @override
  String get reviewChooseCategory => 'Choose a category';

  @override
  String get alwaysRuleCategoryLabel => 'Target category';

  @override
  String get alwaysRuleApplyExisting => 'Apply to existing operations';

  @override
  String get alwaysRuleSubmit => 'Create the rule';

  @override
  String get alwaysRuleSuggestionFailed =>
      'Couldn’t pre-fill the rule. Enter the pattern yourself.';

  @override
  String get reviewQueueRunAction => 'Categorize with AI';

  @override
  String runBannerRunning(int processed, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: 'Categorizing: $processed of $total operations',
      one: 'Categorizing: $processed of $total operation',
    );
    return '$_temp0';
  }

  @override
  String runBannerRunningDetail(int assigned, int deferred) {
    String _temp0 = intl.Intl.pluralLogic(
      assigned,
      locale: localeName,
      other: '$assigned filed · $deferred to review',
      one: '$assigned filed · $deferred to review',
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
      other: 'Categorization finished. $count operations couldn’t be analysed.',
      one: 'Categorization finished. $count operation couldn’t be analysed.',
    );
    return '$_temp0';
  }

  @override
  String get runBannerPartialAction => 'View';

  @override
  String get runBannerFailed => 'Categorization couldn’t run.';

  @override
  String get runBannerDismiss => 'Dismiss';

  @override
  String get runStartFailed => 'Categorization can’t be started right now.';

  @override
  String get settingsAiTitle => 'Local AI';

  @override
  String get settingsAiToggleLabel => 'AI categorization';

  @override
  String get settingsAiPrivacy =>
      'Your transactions’ labels are sent to a model that runs on this computer. Nothing leaves your machine.';

  @override
  String get settingsAiBaseUrlLabel => 'Engine address';

  @override
  String get settingsAiBaseUrlHelp =>
      'Local addresses only: 127.0.0.1 or localhost.';

  @override
  String get settingsAiBaseUrlRejected =>
      'Address refused: the engine must run on this computer (127.0.0.1 or localhost). A remote address would send your transaction descriptions off your machine.';

  @override
  String get settingsAiModelLabel => 'Model';

  @override
  String get settingsAiModelUnavailable =>
      'Engine unreachable: no model to offer.';

  @override
  String get settingsAiModelChoose => 'Choose a model';

  @override
  String get settingsAiThresholdHelp =>
      'Below it, the transaction is offered to you for review instead of being filed.';

  @override
  String get settingsAiStatusUnreachable =>
      'No engine detected at this address.';

  @override
  String get settingsAiLearnMore => 'Learn more';

  @override
  String get settingsAiTest => 'Test';

  @override
  String get settingsAiTesting => 'Testing…';

  @override
  String get settingsAiLoadFailed =>
      'Your settings couldn’t be loaded right now.';

  @override
  String get settingsAiRetry => 'Try again';

  @override
  String get settingsBackupTitle => 'Backup';

  @override
  String get settingsBackupExportLabel => 'Export all data';

  @override
  String get settingsBackupExportCaption =>
      'A .bastide file, unencrypted, with your entire history. Keep it somewhere safe.';

  @override
  String get settingsBackupExportPreparing => 'Preparing the archive…';

  @override
  String get settingsBackupExport => 'Export';

  @override
  String settingsBackupLast(String when) {
    return 'Last backup on $when';
  }

  @override
  String get settingsBackupNone => 'No backup.';

  @override
  String settingsBackupDateTime(String date, String time) {
    return '$date at $time';
  }

  @override
  String get settingsBackupRestoreTitle => 'Restore a backup';

  @override
  String get settingsBackupRestoreSubtitle =>
      'Replaces all current data, after confirmation.';

  @override
  String get settingsBackupRestoreButton => 'Import a file';

  @override
  String get settingsBackupErrorTooNew =>
      'This file comes from a newer version of Bastide. Update the app to restore it.';

  @override
  String get settingsBackupErrorInvalid =>
      'This file isn’t a valid Bastide backup, or it’s damaged.';

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
      'The restore failed. Your data hasn’t been changed.';

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
    return 'Backup saved · $_temp0, $_temp1.';
  }

  @override
  String get settingsBackupExportFailed => 'The export failed. Try again.';

  @override
  String get settingsBackupConfirmTitle => 'Restore this backup?';

  @override
  String settingsBackupConfirmLead(String date) {
    return 'The data exported on $date replaces all your current data.';
  }

  @override
  String get settingsBackupConfirmBackupColumn => 'Backup';

  @override
  String get settingsBackupConfirmCurrentColumn => 'Current';

  @override
  String get settingsBackupConfirmLastImport => 'Latest import';

  @override
  String settingsBackupConfirmOlder(String date) {
    return 'This backup predates your latest import on $date.';
  }

  @override
  String get settingsBackupConfirmCurrentError =>
      'Your current data could not be read.';

  @override
  String get settingsBackupExportFirst => 'Export first';

  @override
  String get settingsBackupSaved => 'Backup saved';

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
  String get settingsBackupReplace => 'Replace my data';

  @override
  String get settingsBackupRestored => 'Backup restored';

  @override
  String get navSubscriptions => 'Subscriptions';

  @override
  String get subscriptionsDetect => 'Detect';

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
  String get subscriptionsBurdenLabel => 'Monthly cost';

  @override
  String get subscriptionsBurdenCaption =>
      'Quarterly and yearly brought back to a month';

  @override
  String get subscriptionsActiveLabel => 'Active';

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
  String get subscriptionsNextLabel => 'Next charge';

  @override
  String subscriptionsNextValue(String label, String when) {
    return '$label, $when';
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
      other: 'in $days days',
      one: 'in 1 day',
    );
    return '$_temp0';
  }

  @override
  String get subscriptionsWatchLabel => 'Worth a look';

  @override
  String subscriptionsWatchIncreases(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count price rises',
      one: '1 price rise',
    );
    return '$_temp0';
  }

  @override
  String subscriptionsWatchMissed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count missed charges',
      one: '1 missed charge',
    );
    return '$_temp0';
  }

  @override
  String get subscriptionsColumnName => 'Subscription';

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
  String get subscriptionsSortByName => 'Sort by name';

  @override
  String get subscriptionsSortByAmount => 'Sort by amount';

  @override
  String get subscriptionsSortByNext => 'Sort by next charge';

  @override
  String get subscriptionsSortedAscending =>
      'Sorted ascending. Click to reverse.';

  @override
  String get subscriptionsSortedDescending =>
      'Sorted descending. Click to reverse.';

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
    return 'Price rise: $from → $to';
  }

  @override
  String subscriptionSignalMissed(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Missed charge for $days days',
      one: 'Missed charge for 1 day',
    );
    return '$_temp0';
  }

  @override
  String subscriptionSignalCancelled(String date) {
    return 'Cancelled, last charge on $date';
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
  String get subscriptionActionCancel => 'Mark as cancelled';

  @override
  String get subscriptionActionEdit => 'Edit';

  @override
  String get subscriptionActionArchive => 'Archive';

  @override
  String get subscriptionActionUnarchive => 'Unarchive';

  @override
  String get subscriptionArchiveFailed =>
      'Couldn’t change whether this payment is archived.';

  @override
  String subscriptionsShowArchived(int count) {
    return 'Show archived payments ($count)';
  }

  @override
  String subscriptionsHideArchived(int count) {
    return 'Hide archived payments ($count)';
  }

  @override
  String get subscriptionsArchivedSection => 'Archived';

  @override
  String get subscriptionErrorInvalidTransition =>
      'That status change isn’t available for this payment.';

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
  String get subscriptionErrorMergeInvalid =>
      'These two subscriptions can’t be merged.';

  @override
  String subscriptionsMergeSuggestion(String source, String target) {
    return '“$source” and “$target” look like the same subscription, renamed by the bank.';
  }

  @override
  String get subscriptionsMergeAction => 'Merge';

  @override
  String get subscriptionsMergeKeepApart => 'They’re different';

  @override
  String get subscriptionsMergeDone => 'Subscriptions merged';

  @override
  String subscriptionsMergeDoneDetail(String target) {
    return 'Future charges under either label will go to “$target”.';
  }

  @override
  String subscriptionsMergeSuggestionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count merge suggestions',
      one: '1 merge suggestion',
    );
    return '$_temp0';
  }

  @override
  String get subscriptionsMergeSuggestionsHide => 'Hide suggestions';

  @override
  String get subscriptionsMergeSuggestionsShow => 'Show suggestions';

  @override
  String get subscriptionsLoadFailed =>
      'Subscriptions couldn’t be loaded. Nothing was changed.';

  @override
  String get subscriptionsRetry => 'Try again';

  @override
  String get subscriptionsEmptyTitle => 'No recurring payments detected';

  @override
  String get subscriptionsEmptyBody =>
      'Bastide spots a recurring payment once a charge has repeated three times. Importing more history speeds detection up.';

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
    return 'Price rise: $from → $to on $date, that’s $annual a year.';
  }

  @override
  String get subscriptionDetailHistoryTitle => 'Charge history';

  @override
  String subscriptionDetailHistorySubtitle(String account) {
    return '$account';
  }

  @override
  String subscriptionDetailChange(String from, String to) {
    return '$from → $to';
  }

  @override
  String get subscriptionDetailFootnote =>
      'The series is deduced from these charges. Check them before confirming a change.';

  @override
  String get subscriptionDetailLoadFailed =>
      'This recurring payment couldn’t be loaded. Nothing was changed.';

  @override
  String get subscriptionDetailMoreActions => 'More actions';

  @override
  String get subscriptionFormEditTitle => 'Edit recurring payment';

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
  String get subscriptionFormCategoryLabel => 'Category';

  @override
  String get subscriptionFormCategoryNone => 'None';

  @override
  String get subscriptionFormSave => 'Save';

  @override
  String get navGoals => 'Goals';

  @override
  String get goalsAdd => 'New goal';

  @override
  String goalsSummaryReserved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count goals',
      one: '1 goal',
    );
    return 'Reserved across $_temp0';
  }

  @override
  String get goalsSummarySavings => 'Available savings';

  @override
  String get goalsNoValue => '—';

  @override
  String get goalsColumnGoal => 'Goal';

  @override
  String get goalsColumnDeadline => 'Deadline';

  @override
  String get goalsColumnProgress => 'Progress';

  @override
  String get goalsColumnReserved => 'Reserved';

  @override
  String goalsTargetSuffix(String target) {
    return '/ $target';
  }

  @override
  String get goalNoDeadline => 'No deadline';

  @override
  String goalReachedIn(String month) {
    return 'Reached in $month';
  }

  @override
  String goalsArchivedLink(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count archived goals',
      one: '1 archived goal',
    );
    return '$_temp0';
  }

  @override
  String get goalsNote =>
      'A goal reserves an amount on paper. Your accounts are not changed. Images stay on this computer.';

  @override
  String goalOfTarget(String target) {
    return 'of $target';
  }

  @override
  String goalDeadlineRemaining(String deadline, String remaining) {
    return '$deadline · $remaining left';
  }

  @override
  String get goalArchive => 'Archive';

  @override
  String get goalUnarchive => 'Unarchive';

  @override
  String get goalEdit => 'Edit';

  @override
  String get goalDelete => 'Delete';

  @override
  String get goalAllocationsTitle => 'Allocations';

  @override
  String get goalAllocate => 'Allocate';

  @override
  String get goalAllocationsEmpty => 'No allocations.';

  @override
  String get goalAllocationsFailed =>
      'The allocations couldn’t be loaded. Nothing was changed.';

  @override
  String get goalAllocationDelete => 'Delete allocation';

  @override
  String goalAllocationDeleteTitle(String date) {
    return 'Delete the allocation of $date?';
  }

  @override
  String goalAllocationDeleteDate(int day, String month, String year) {
    return '$month $day, $year';
  }

  @override
  String goalAllocationDeleteLeadDown(String goal, String amount) {
    return 'The amount set aside for “$goal” goes down by $amount. Your accounts are not changed.';
  }

  @override
  String goalAllocationDeleteLeadUp(String goal, String amount) {
    return 'The amount set aside for “$goal” goes back up by $amount. Your accounts are not changed.';
  }

  @override
  String get goalAllocationDeleteSubmit => 'Delete';

  @override
  String get goalImageChange => 'Change';

  @override
  String get goalImageReplace => 'Choose another image';

  @override
  String get goalImageRemove => 'Remove image';

  @override
  String get goalImageAdd => 'Add an image';

  @override
  String get goalImageCropTitle => 'Crop the image';

  @override
  String get goalImageCropLead => 'Drag the image to frame the banner.';

  @override
  String get goalImageCropSave => 'Use this image';

  @override
  String goalImageTooLarge(int megabytes) {
    return 'This picture is too large: choose a file under $megabytes MB.';
  }

  @override
  String get goalImageInvalid => 'This file isn’t a PNG, JPEG or WebP picture.';

  @override
  String get goalImageError => 'The image couldn’t be saved. Try again.';

  @override
  String goalImageAlt(String name) {
    return 'Image of the goal $name';
  }

  @override
  String get goalFormImageLabel => 'Image (optional)';

  @override
  String get goalFormImagePick => 'Choose an image';

  @override
  String get goalFormImageRemove => 'Remove';

  @override
  String goalsOverAllocated(String delta) {
    return 'You have reserved $delta more than the total of your savings accounts.';
  }

  @override
  String get goalsDismissBanner => 'Hide this warning';

  @override
  String get goalsEmptyTitle => 'No goals';

  @override
  String get goalsEmptyBody =>
      'A goal sets an amount aside on paper. Your accounts are not changed.';

  @override
  String get goalsLoadFailed =>
      'Your goals couldn’t be loaded. Nothing was changed.';

  @override
  String get goalsRetry => 'Try again';

  @override
  String get goalFormCreateTitle => 'New goal';

  @override
  String get goalFormEditTitle => 'Edit goal';

  @override
  String get goalFormNameLabel => 'Name';

  @override
  String get goalFormNameRequired => 'Give this goal a name.';

  @override
  String get goalFormTargetLabel => 'Target amount';

  @override
  String get goalFormTargetInvalid => 'Enter an amount greater than zero.';

  @override
  String get goalFormDateLabel => 'Deadline (optional)';

  @override
  String get goalFormDateHint => 'MM/YYYY';

  @override
  String get goalFormDatePick => 'Pick a month';

  @override
  String get goalFormDateInvalid => 'Enter a month as MM/YYYY.';

  @override
  String get goalFormCancel => 'Cancel';

  @override
  String get goalFormSave => 'Save';

  @override
  String goalDeleteTitle(String name) {
    return 'Delete the goal “$name”?';
  }

  @override
  String get goalDeleteLead =>
      'Its allocations and image will be deleted. To keep its history, archive it instead. Your accounts are not changed.';

  @override
  String get goalDeleteSubmit => 'Delete';

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
  String get dashboardGoalsViewAll => 'All goals';

  @override
  String dashboardGoalsTarget(String target) {
    return '/ $target';
  }

  @override
  String get allocationDatePick => 'Pick a date';

  @override
  String get settingsResetTitle => 'Reset';

  @override
  String get settingsResetSubtitle =>
      'Deletes this profile’s transactions, accounts, rules, custom categories, goals, subscriptions, loans, properties, investments and simulations. Exported backups are not touched.';

  @override
  String get settingsResetButton => 'Reset…';

  @override
  String get settingsResetConfirmTitle => 'Reset the database?';

  @override
  String settingsResetConfirmLead(String name) {
    return 'Everything in $name’s profile will be permanently deleted:';
  }

  @override
  String get settingsResetConfirmCategories => 'Custom categories';

  @override
  String get settingsResetConfirmNote =>
      'The built-in categories, your preferences and the AI settings are kept.';

  @override
  String get settingsResetConfirmWord => 'delete';

  @override
  String settingsResetConfirmLabel(String word) {
    return 'Type “$word” to confirm';
  }

  @override
  String get settingsResetConfirmHelper => 'Upper or lower case, either works.';

  @override
  String get settingsResetConfirmSubmit => 'Delete everything';

  @override
  String get settingsResetDone => 'Database reset.';

  @override
  String get settingsResetErrorUnknown =>
      'The reset failed. Your data hasn’t been changed.';

  @override
  String get navSectionWealth => 'Wealth';

  @override
  String get navMortgages => 'Loans';

  @override
  String get navPlacements => 'Investments';

  @override
  String get navSimulator => 'Simulator';

  @override
  String get navNetworth => 'Net worth';

  @override
  String get placementsEmptyTitle => 'No investments';

  @override
  String get placementsEmptyMessage =>
      'Follow a PEA, a life insurance policy or another investment from the values on your statements.';

  @override
  String get mortgagesAdd => 'New loan';

  @override
  String get mortgagesLoadFailed => 'Couldn’t load your loans.';

  @override
  String get mortgagesRetry => 'Retry';

  @override
  String get mortgagesEmptyTitle => 'No loans recorded';

  @override
  String get mortgagesEmptyBody =>
      'Add a loan to follow its cost, its schedule and your debt ratio.';

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
    return '$_temp0, insurance included';
  }

  @override
  String get mortgagesChargeCaptionNoNext => 'Insurance included';

  @override
  String get mortgagesOutstandingLabel => 'Outstanding principal';

  @override
  String mortgagesOutstandingCaption(String principal, String percent) {
    return 'of $principal · $percent repaid';
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
    return '$charge against a declared income of $income.';
  }

  @override
  String mortgagesRatioCaptionLedger(String charge, String income) {
    return '$charge against a median observed income of $income (12 months). A declared income replaces this reading.';
  }

  @override
  String get mortgagesRatioUnknown =>
      'No known income. Without an income there is no ratio to compute.';

  @override
  String get mortgagesRatioDeclareLink => 'Declare an income';

  @override
  String get mortgagesRatioCaveat =>
      'An indicative reading that binds no lender.';

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
  String get mortgageRateLabel => 'Nominal rate';

  @override
  String get mortgageInsuranceLabel => 'Insurance';

  @override
  String get mortgageNextLabel => 'Next instalment';

  @override
  String get mortgagesChartTitle =>
      'Outstanding principal until the last repayment';

  @override
  String mortgagesChartToday(String month, String amount) {
    return '$month · $amount';
  }

  @override
  String mortgagesChartLoanEnd(String kind) {
    return 'end of the $kind';
  }

  @override
  String get mortgageDetailLoadFailed => 'Couldn’t load this loan.';

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
  String get mortgageCostTaegLabel => 'Indicative APR';

  @override
  String get mortgageCostTaegCaption => 'rate, insurance and fees';

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
  String get mortgageFormInsurance => 'Insurance per month';

  @override
  String get mortgageFormAmountOptionalInvalid =>
      'Enter a valid amount or leave it empty.';

  @override
  String get mortgageFormFees => 'Upfront fees';

  @override
  String get mortgageFormProperty => 'Financed property (optional)';

  @override
  String get mortgageFormPropertyNone => 'None';

  @override
  String get mortgageFormPlateLabel => 'Computed instalment';

  @override
  String mortgageFormPlateDetail(String instalment, String interest) {
    return 'total instalment $instalment · total interest $interest';
  }

  @override
  String get mortgageFormPlatePending =>
      'Fill in the principal, the rate and the term.';

  @override
  String get mortgageFormPlateInterestOnly =>
      'An interest-only loan’s instalment shows once the loan is saved.';

  @override
  String get mortgageFormCancel => 'Cancel';

  @override
  String get mortgageFormSave => 'Save';

  @override
  String get mortgageFormDelete => 'Delete';

  @override
  String mortgageDeleteTitle(String label) {
    return 'Delete the loan “$label”?';
  }

  @override
  String get mortgageDeleteBody =>
      'It will no longer be deducted from your net worth in Net worth, and its amortisation schedule disappears. Your accounts are not changed.';

  @override
  String get mortgageDeleteConfirm => 'Delete';

  @override
  String get mortgageErrorNonAmortizing =>
      'This loan never repays: the instalment doesn’t cover the first month’s interest. Change the rate, the amount borrowed or the term.';

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
      'Couldn’t load the amortisation schedule.';

  @override
  String get mortgagesTableLoan => 'Loan';

  @override
  String get mortgagesTableLender => 'Lender';

  @override
  String get mortgagesTableRate => 'Rate';

  @override
  String get mortgagesTableInsurance => 'Insurance';

  @override
  String get mortgagesTableRepaid => 'Repaid';

  @override
  String get mortgagesTableEnd => 'End';

  @override
  String get mortgagesTableInstalment => 'Instalment';

  @override
  String mortgagesTableLenderTerm(String lender, int months) {
    return '$lender · $months months';
  }

  @override
  String mortgagesTableRepaidCaption(String percent, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count instalments left',
      one: '1 instalment left',
      zero: 'no instalments left',
    );
    return '$percent · $_temp0';
  }

  @override
  String mortgageDetailFacts(
    String kind,
    String lender,
    String principal,
    int months,
  ) {
    return '$kind · $lender · $principal over $months months';
  }

  @override
  String mortgageDetailFirstPayment(String date) {
    return 'First instalment on $date';
  }

  @override
  String mortgageDetailFirstPaymentFees(String date, String fees) {
    return 'First instalment on $date · upfront fees $fees';
  }

  @override
  String get mortgageScheduleYearSelect => 'Year';

  @override
  String get simulatorLoadFailed => 'Couldn’t load the simulator.';

  @override
  String get simulatorRetry => 'Try again';

  @override
  String get simulatorNoValue => '—';

  @override
  String get simulatorFormTitle => 'New loan';

  @override
  String get simulatorPrice => 'Property price';

  @override
  String get simulatorDownPayment => 'Down payment';

  @override
  String get simulatorFees => 'Fees';

  @override
  String get simulatorPrincipal => 'Amount borrowed';

  @override
  String get simulatorPrincipalDerivedHelper =>
      'calculated: price − down payment + fees';

  @override
  String get simulatorRate => 'Nominal rate';

  @override
  String get simulatorRateInvalid => 'Enter a rate, for example 3.25.';

  @override
  String get simulatorInsurance => 'Insurance per month';

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
      other: '$yearsString years',
      one: '1 year',
    );
    return '$_temp0 · $months months';
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
      other: '$yearsString years',
      one: '1 year',
    );
    return '$_temp0';
  }

  @override
  String simulatorMonths(int months) {
    return '$months months';
  }

  @override
  String get simulatorIncludeExisting => 'Include my current loans';

  @override
  String simulatorIncludeExistingAdds(String amount) {
    return 'Adds $amount per month to the reading';
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
      'Enter a price and a rate to see the instalment.';

  @override
  String get simulatorCostLabel => 'Total cost';

  @override
  String simulatorCostCaption(String interest, String insurance, String fees) {
    return 'interest $interest · insurance $insurance · fees $fees';
  }

  @override
  String get simulatorTaegLabel => 'Indicative APR';

  @override
  String get simulatorTaegCaption => 'rate, insurance and fees';

  @override
  String get simulatorHcsfTitle => 'HCSF reading';

  @override
  String get simulatorHcsfOver => 'Above the reference';

  @override
  String get simulatorHcsfCaveat =>
      'An indicative reading that binds no lender.';

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
    String total,
    String instalment,
    String existing,
    String source,
    String income,
  ) {
    String _temp0 = intl.Intl.selectLogic(source, {
      'declared': 'declared',
      'other': 'median observed',
    });
    return '$total ($instalment + current loans $existing) against a $_temp0 income of $income';
  }

  @override
  String get simulatorRatioEmpty =>
      'Enter a price and a rate to read the debt ratio.';

  @override
  String get simulatorRatioUnknown =>
      'No known income. Without an income, neither a ratio nor a capacity can be read.';

  @override
  String get simulatorDeclareIncome => 'Declare an income';

  @override
  String get simulatorTermAtReference => 'At the reference, not beyond';

  @override
  String get simulatorTermUnderReference => 'Under the reference';

  @override
  String get simulatorTermOverReference => 'Beyond the reference';

  @override
  String get simulatorCapacityLabel => 'Borrowing capacity at the reference';

  @override
  String simulatorCapacityCaption(String available, String limit) {
    return '$available of instalment available under $limit, on these terms';
  }

  @override
  String simulatorCapacityCaptionExisting(String available, String limit) {
    return 'Your current loans leave $available of instalment under $limit. That is what limits the capacity, not the property.';
  }

  @override
  String get simulatorCapacityEmpty =>
      'Enter a price and a rate to read the borrowing capacity.';

  @override
  String get simulatorChartTitle => 'Yearly projection';

  @override
  String get simulatorChartCapital => 'Principal';

  @override
  String get simulatorChartInterest => 'Interest';

  @override
  String simulatorChartTooltipCapital(String amount) {
    return 'Principal: $amount';
  }

  @override
  String simulatorChartTooltipInterest(String amount) {
    return 'Interest: $amount';
  }

  @override
  String get simulatorChartEmpty =>
      'Enter a price and a rate: the split by year shows here.';

  @override
  String get simulatorComputeFailed =>
      'The calculation didn’t go through. Try again in a moment.';

  @override
  String get simulatorErrorNonAmortizing =>
      'At this rate the instalment doesn’t repay the principal: lower the rate or lengthen the term.';

  @override
  String get simulatorErrorFeesExceed =>
      'Fees must stay below the amount borrowed.';

  @override
  String get simulatorErrorValidation => 'Some values aren’t accepted.';

  @override
  String get simulatorErrorGeneric => 'Something went wrong. Try again.';

  @override
  String get simulatorCancel => 'Cancel';

  @override
  String get simulatorSaveScenario => 'Save scenario';

  @override
  String get simulatorSaveName => 'Name';

  @override
  String simulatorSaveNamePrefill(String price) {
    return ', $price';
  }

  @override
  String get simulatorSaveNameRequired => 'Give the scenario a name.';

  @override
  String get simulatorSaveSubmit => 'Save';

  @override
  String simulatorPriceThousands(String amount) {
    return '€${amount}k';
  }

  @override
  String get simulatorErrorLimitReached =>
      'You’ve reached the maximum number of saved scenarios. Delete one to add another.';

  @override
  String get simulatorErrorNotFound => 'This scenario no longer exists.';

  @override
  String get simulatorScenariosTitle => 'Saved scenarios';

  @override
  String simulatorCompareButton(int count, int max) {
    return 'Compare ($count/$max)';
  }

  @override
  String simulatorCompareCapNamed(String name) {
    return 'Three scenarios at most. Uncheck one to add $name.';
  }

  @override
  String get simulatorCompareCap =>
      'Three scenarios at most. Uncheck one to add another.';

  @override
  String get simulatorLiveName => 'Current simulation';

  @override
  String get simulatorLiveMarker => 'current';

  @override
  String simulatorScenarioSub(String rate, String term) {
    return '$rate · $term';
  }

  @override
  String simulatorScenarioSubLive(String rate, String term) {
    return 'current · $rate · $term';
  }

  @override
  String get simulatorScenarioActions => 'Scenario actions';

  @override
  String get simulatorScenarioRename => 'Rename';

  @override
  String get simulatorRenameTitle => 'Rename scenario';

  @override
  String get simulatorScenarioDelete => 'Delete';

  @override
  String simulatorScenarioSelect(String name) {
    return 'Select $name for comparison';
  }

  @override
  String get simulatorScenariosEmpty => 'No saved scenario.';

  @override
  String simulatorCompareTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Comparing $count scenarios',
      one: 'Comparing 1 scenario',
    );
    return '$_temp0';
  }

  @override
  String get simulatorCompareClose => 'Close comparison';

  @override
  String get simulatorCompareFailed => 'Couldn’t compute the comparison.';

  @override
  String get simulatorCompareTotalInterest => 'Total interest';

  @override
  String get simulatorCompareTotalInsurance => 'Total insurance';

  @override
  String get simulatorCompareCostShare => 'Cost / price';

  @override
  String get simulatorCompareTaeg => 'Indicative APR';

  @override
  String get simulatorCompareWithExisting => 'With current loans';

  @override
  String simulatorCompareFoot(String source, String income, String limit) {
    String _temp0 = intl.Intl.selectLogic(source, {
      'declared': 'declared',
      'other': 'median observed',
    });
    return 'Debt ratio against a $_temp0 income of $income · HCSF reference $limit. An indicative reading that binds no lender.';
  }

  @override
  String simulatorCompareFootUnknown(String limit) {
    return 'No known income, so no debt ratio · HCSF reference $limit. An indicative reading that binds no lender.';
  }

  @override
  String get propertyKindPrimaryResidence => 'Primary residence';

  @override
  String get propertyKindRental => 'Rental';

  @override
  String get propertyKindSecondary => 'Second home';

  @override
  String get propertyKindOther => 'Other property';

  @override
  String get propertyFormCreateTitle => 'New property';

  @override
  String get propertyFormEditTitle => 'Edit property';

  @override
  String get propertyFormLabel => 'Label';

  @override
  String get propertyFormLabelRequired => 'Give this property a name.';

  @override
  String get propertyFormAddress => 'Address (optional)';

  @override
  String get propertyFormKind => 'Type';

  @override
  String get propertyFormValue => 'Declared value';

  @override
  String get propertyFormValuedOn => 'Valuation date';

  @override
  String get propertyFormOwnership => 'Share owned';

  @override
  String propertyFormOwnershipShare(String amount) {
    return 'share: $amount';
  }

  @override
  String get propertyFormOwnershipInvalid =>
      'Enter a share between 0.01 and 100%.';

  @override
  String get propertyFormAcquisitionPrice => 'Purchase price';

  @override
  String get propertyFormAcquiredOn => 'Purchase date';

  @override
  String get propertyFormAmountInvalid => 'Enter an amount above zero.';

  @override
  String get propertyFormAmountOptionalInvalid =>
      'Unreadable amount. Leave it empty if unknown.';

  @override
  String get propertyFormDateInvalid => 'Invalid date (M/D/YYYY).';

  @override
  String get propertyFormCalendar => 'Pick a date';

  @override
  String get propertyFormSave => 'Save';

  @override
  String get propertyRevalueTitle => 'New valuation';

  @override
  String propertyRevalueSubtitle(String label, String value, String date) {
    return '$label: $value as valued on $date. The new valuation replaces it.';
  }

  @override
  String get propertyErrorValuationInFuture =>
      'A valuation date can’t be in the future.';

  @override
  String get propertyErrorNotFound => 'This property no longer exists.';

  @override
  String get propertyErrorValidation =>
      'Some values were refused. Check the form.';

  @override
  String get propertyErrorGeneric => 'Couldn’t save the property. Try again.';

  @override
  String get propertyMenuTooltip => 'Actions';

  @override
  String get propertyMenuEdit => 'Edit';

  @override
  String get propertyMenuRevalue => 'New valuation';

  @override
  String get propertyMenuArchive => 'Archive';

  @override
  String get propertyMenuUnarchive => 'Unarchive';

  @override
  String get propertiesDismiss => 'Dismiss';

  @override
  String get networthAddProperty => 'New property';

  @override
  String get networthNetWorthLabel => 'Net worth';

  @override
  String get networthEquationMinus => '−';

  @override
  String get networthEquationEquals => '=';

  @override
  String networthAssetsPartAccounts(String amount) {
    return 'Accounts $amount';
  }

  @override
  String networthAssetsPartProperties(String amount) {
    return 'Properties $amount';
  }

  @override
  String networthCompositionPartNote(String label, String held, String full) {
    return 'A property counts for the held share: $label, $held of $full.';
  }

  @override
  String get networthNotesTitle => 'Good to know';

  @override
  String get networthNoPropertyNote =>
      'No property declared: the assets count only your accounts and investments.';

  @override
  String get propertiesTitle => 'Properties';

  @override
  String get propertiesColumnProperty => 'Property';

  @override
  String get propertiesColumnKind => 'Type';

  @override
  String get propertiesColumnShare => 'Share';

  @override
  String get propertiesColumnHeldValue => 'Held value';

  @override
  String propertiesArchivedLink(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count archived properties',
      one: '1 archived property',
    );
    return '$_temp0';
  }

  @override
  String networthDeltaCaption(String delta, String month) {
    return '$delta since $month';
  }

  @override
  String get networthAssetsLabel => 'Assets';

  @override
  String get networthLiabilitiesLabel => 'Liabilities';

  @override
  String networthLiabilitiesCaption(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count loans, outstanding principal',
      one: '1 loan, outstanding principal',
      zero: 'No loan',
    );
    return '$_temp0';
  }

  @override
  String get networthCompositionTitle => 'Asset composition';

  @override
  String get networthCompositionChecking => 'Current accounts';

  @override
  String get networthCompositionSavings => 'Savings';

  @override
  String get networthCompositionCredit => 'Credit accounts';

  @override
  String get networthCompositionDeferredCard => 'Deferred-debit cards';

  @override
  String get networthCompositionCash => 'Cash';

  @override
  String get networthCompositionOtherAccounts => 'Other accounts';

  @override
  String networthCompositionHeldShare(String label) {
    return '$label, held share';
  }

  @override
  String get networthExclusionGoalsBody =>
      'Goals set aside money already in an account. They are not counted a second time.';

  @override
  String get networthExclusionSubscriptionsBody =>
      'A subscription is a future expense, not a debt owed today.';

  @override
  String get networthEmptyTitle => 'No accounts, properties or loans';

  @override
  String get networthEmptyBody =>
      'Import an account or declare a property. Net worth adds up what you own and subtracts your loans.';

  @override
  String get networthEmptyImport => 'Go to imports';

  @override
  String get networthLoadFailed => 'Couldn’t load your net worth.';

  @override
  String get networthRetry => 'Retry';

  @override
  String get networthSeriesTitle => 'Net worth';

  @override
  String networthSeriesRange(String from, String to) {
    return '$from – $to';
  }

  @override
  String get networthSeriesEmpty =>
      'No history: the series starts with the first closed month of an imported account, or with the first total you declare.';

  @override
  String networthSeriesCaveat(String date) {
    return 'Properties are held at their declared value (oldest estimate: $date) and count only from their acquisition date, loans only from their payout. Months without data are absent.';
  }

  @override
  String get networthRangeYear => '12 months';

  @override
  String get networthRangeThreeYears => '3 years';

  @override
  String get networthRangeAll => 'All';

  @override
  String get networthLegendLedger => 'Imported accounts';

  @override
  String get networthLegendDeclared => 'Declared totals';

  @override
  String get networthDeclaredOpen => 'Declared history';

  @override
  String get networthDeclaredTitle => 'Declared history';

  @override
  String get networthDeclaredSubtitle =>
      'The total of all your accounts at a month end, for the time before your imports. A month your imports cover keeps the imported figure.';

  @override
  String get networthDeclaredMonth => 'Month';

  @override
  String get networthDeclaredMonthHint => 'MM/YYYY';

  @override
  String get networthDeclaredMonthInvalid => 'Enter a month as MM/YYYY.';

  @override
  String get networthDeclaredMonthNotClosed =>
      'Only a month that has ended can be declared.';

  @override
  String get networthDeclaredAmount => 'Accounts total';

  @override
  String get networthDeclaredAmountInvalid => 'Enter an amount.';

  @override
  String get networthDeclaredSave => 'Save';

  @override
  String get networthDeclaredEmpty => 'No declared total.';

  @override
  String get networthDeclaredSuperseded => 'Covered by your imports';

  @override
  String get networthDeclaredEdit => 'Edit';

  @override
  String get networthDeclaredDelete => 'Delete';

  @override
  String get networthDeclaredLoadFailed =>
      'Couldn’t load the declared history.';

  @override
  String get networthDeclaredErrorNotFound => 'This total no longer exists.';

  @override
  String get networthDeclaredErrorGeneric => 'Saving failed. Try again.';

  @override
  String get authForgotPasswordLink => 'Forgot password';

  @override
  String get authRecoveryCodeLabel => 'Recovery code';

  @override
  String get authRecoveryCodeRequired => 'The recovery code is required.';

  @override
  String get authNewPasswordLabel => 'New password';

  @override
  String get authResetSubmit => 'Reset password';

  @override
  String get authResetSubmitting => 'Resetting…';

  @override
  String get authResetNote =>
      'You were given this code when you created your account. Without it the password can’t be reset: your data never leaves this computer.';

  @override
  String get authBackToLogin => 'Back to sign in';

  @override
  String get authErrorInvalidRecoveryCode =>
      'Incorrect username, email or recovery code. Check the code and try again.';

  @override
  String get authRecoveryCodeCopy => 'Copy';

  @override
  String get authRecoveryCodeCopied => 'Copied';

  @override
  String get authRecoveryCodeKeep =>
      'Write this code down and keep it somewhere safe: it will not be shown again.';

  @override
  String get authRecoveryCodeAcknowledge => 'I have written this code down';

  @override
  String get settingsRecoveryTitle => 'Recovery code';

  @override
  String get settingsRecoverySubtitle =>
      'Lets you reset your password if you forget it. Generating a new one invalidates the previous code.';

  @override
  String get settingsRecoveryButton => 'Generate a new code';

  @override
  String get settingsRecoveryModalTitle => 'New recovery code';

  @override
  String get settingsRecoveryModalLead =>
      'Confirm your password to generate a new code. The previous one will stop working.';

  @override
  String get settingsRecoveryModalGenerated =>
      'Write this code down and keep it safe: it won’t be shown again.';

  @override
  String get settingsRecoveryModalGenerate => 'Generate';

  @override
  String get settingsRecoveryModalSaveFile => 'Save to a file';

  @override
  String get settingsRecoveryModalSaved => 'Saved';

  @override
  String get settingsRecoveryModalSaveFailed =>
      'The file could not be saved. Try again.';

  @override
  String get settingsRecoveryFileName => 'bastide-recovery-code.txt';

  @override
  String get settingsRecoveryModalDone => 'Done';

  @override
  String get settingsRecoveryWrongPassword => 'Incorrect password.';

  @override
  String get settingsPasswordTitle => 'Password';

  @override
  String settingsPasswordSubtitle(int minimum) {
    return 'At least $minimum characters. It protects access to your data on this computer.';
  }

  @override
  String get settingsPasswordButton => 'Change password';

  @override
  String get settingsPasswordModalTitle => 'Change password';

  @override
  String get settingsPasswordModalLead => 'Your recovery code stays valid.';

  @override
  String get settingsPasswordCurrentLabel => 'Current password';

  @override
  String get settingsPasswordModalSave => 'Change password';

  @override
  String get settingsPasswordWrongPassword => 'Incorrect password.';

  @override
  String get settingsPasswordChanged => 'Password changed.';

  @override
  String get authIdentifierLabel => 'Email or username';

  @override
  String get authIdentifierRequired => 'Email or username is required.';

  @override
  String get authDisplayNameHelper =>
      'Also used to sign in. 3 to 32 characters: letters, digits, spaces, ’.’, ’_’ or ’-’.';

  @override
  String get authDisplayNameInvalid =>
      '3 to 32 characters: unaccented letters, digits, spaces, ’.’, ’_’ or ’-’.';

  @override
  String get authDisplayNameTaken => 'This username is already taken.';

  @override
  String get settingsProfileNameTitle => 'Username';

  @override
  String get settingsProfileNameButton => 'Change';

  @override
  String get settingsAvatarTitle => 'Avatar';

  @override
  String get settingsAvatarSubtitle =>
      'A monogram, a colour plate or a picture. The picture stays on this computer.';

  @override
  String get settingsAvatarMonogram => 'Monogram';

  @override
  String settingsAvatarPreset(String slot) {
    String _temp0 = intl.Intl.selectLogic(slot, {
      'cat1': 'Blue plate',
      'cat2': 'Orange plate',
      'cat3': 'Green plate',
      'cat4': 'Amber plate',
      'cat5': 'Pink plate',
      'cat6': 'Violet plate',
      'other': 'Plate',
    });
    return '$_temp0';
  }

  @override
  String get settingsAvatarError => 'The avatar couldn’t be saved. Try again.';

  @override
  String get settingsAvatarChoosePicture => 'Choose a picture';

  @override
  String get settingsAvatarRemovePicture => 'Remove picture';

  @override
  String settingsAvatarPictureTooLarge(int megabytes) {
    return 'This picture is too large: choose a file under $megabytes MB.';
  }

  @override
  String get settingsAvatarPictureInvalid =>
      'This file isn’t a PNG, JPEG or WebP picture.';

  @override
  String get settingsAvatarPictureError =>
      'The picture couldn’t be saved. Try again.';

  @override
  String get settingsAvatarCropTitle => 'Crop the picture';

  @override
  String get settingsAvatarCropLead => 'Drag the image to frame your avatar.';

  @override
  String get settingsAvatarCropCancel => 'Cancel';

  @override
  String get settingsAvatarCropSave => 'Use this picture';

  @override
  String get settingsProfileNameModalTitle => 'Change username';

  @override
  String get settingsProfileNameModalLead =>
      'The new name replaces the old one for signing in.';

  @override
  String get settingsProfileNameModalSave => 'Save';

  @override
  String get settingsEmailButton => 'Change';

  @override
  String get settingsEmailModalTitle => 'Change email address';

  @override
  String get settingsEmailModalLead =>
      'The new address replaces the old one for signing in.';

  @override
  String get settingsEmailNewLabel => 'New email address';

  @override
  String get settingsEmailModalSave => 'Save';

  @override
  String get settingsEmailTaken => 'This email address is already in use.';

  @override
  String get startupPrivacy => 'Your data stays on this computer.';

  @override
  String get startupEngineStarting => 'Starting the local engine…';

  @override
  String get startupRetry => 'Try again';

  @override
  String get startupRelaunch => 'Restart';

  @override
  String get startupOpenLogs => 'Open logs folder';

  @override
  String get startupDidNotStartTitle => 'Bastide couldn’t start';

  @override
  String get startupDidNotStartMessage =>
      'The app’s local engine didn’t start. Try again; if it happens again, the logs say why.';

  @override
  String get startupNotFoundMessage =>
      'Some of the app’s files are missing. Reinstall Bastide: your data is kept separately and won’t be touched.';

  @override
  String get startupUnreachableMessage =>
      'No local engine is answering. Start it, then try again.';

  @override
  String get startupCrashedTitle => 'Bastide stopped unexpectedly';

  @override
  String get startupCrashedMessage =>
      'The local engine stopped. Your data is saved as you go; try again to restart it.';

  @override
  String get startupSchemaTooNewTitle => 'This data comes from a newer version';

  @override
  String get startupSchemaTooNewMessage =>
      'Your data was saved by a newer version of Bastide. Install that version again to open it; nothing has been changed.';

  @override
  String get startupVersionMismatchTitle => 'Mismatched versions';

  @override
  String startupVersionMismatchMessage(String app, String backend) {
    return 'The app ($app) and its local engine ($backend) come from different versions. Reinstall Bastide to bring them back in line; your data isn’t touched.';
  }

  @override
  String startupVersionMismatchDebugMessage(String app, String backend) {
    return 'The local engine ($backend) doesn’t match the app ($app): it was probably left running from an earlier session. Restart it, or continue anyway.';
  }

  @override
  String get startupContinueAnyway => 'Continue anyway';

  @override
  String settingsAiOllamaFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count models installed',
      one: '1 model installed',
      zero: 'no model installed',
    );
    return 'Ollama found on this computer · $_temp0';
  }

  @override
  String get settingsAiOllamaUse => 'Use Ollama';

  @override
  String get accountDetailMoreActions => 'More actions';

  @override
  String get accountDetailCycleLabel => 'Current cycle';

  @override
  String accountDetailBalanceOn(String date) {
    return 'Balance on $date';
  }

  @override
  String accountDetailMonthInflow(String month) {
    return 'Money in, $month';
  }

  @override
  String accountDetailMonthOutflow(String month) {
    return 'Money out, $month';
  }

  @override
  String get accountDetailNet => 'Net';

  @override
  String get accountDetailPreviousCycle => 'Previous cycle';

  @override
  String get accountDetailDebitDateLabel => 'Debited on';

  @override
  String accountDetailIdentity(String institution, String type) {
    return '$institution · $type';
  }

  @override
  String get accountDetailMetaSeparator => ' · ';

  @override
  String accountDetailHistorySince(String date) {
    return 'Tracked since $date';
  }

  @override
  String get accountDetailNoHistory => 'No transactions';

  @override
  String accountDetailLastImport(String date) {
    return 'last import on $date';
  }

  @override
  String accountDetailMaskedNumber(String digits) {
    return '•••• $digits';
  }

  @override
  String transactionRowCardLabel(String card, String digits) {
    return '$card · •••• $digits';
  }

  @override
  String get accountDetailBalanceChartTitle => 'Month-end balance';

  @override
  String get accountDetailCyclesChartTitle => 'Spending per cycle';

  @override
  String get accountDetailRangeSixMonths => '6 months';

  @override
  String get accountDetailRangeTwelveMonths => '12 months';

  @override
  String get accountDetailRangeAll => 'All';

  @override
  String get accountDetailChartEmpty =>
      'The chart will appear after the second month of history.';

  @override
  String get accountDetailImportCta => 'Import a statement';

  @override
  String accountDetailTooltipDelta(String amount) {
    return '$amount vs previous month';
  }

  @override
  String get accountDetailTooltipFirstMonth => 'First tracked month';

  @override
  String accountDetailCycleSettledOn(String date) {
    return 'Settled on $date';
  }

  @override
  String get accountDetailCycleOpen => 'In progress';

  @override
  String accountDetailRisingStreak(int count) {
    return 'Your balance has been rising for $count months.';
  }

  @override
  String accountDetailCycleAverage(int count) {
    return 'Average over $count cycles';
  }

  @override
  String get accountDetailNoStats => '—';

  @override
  String get accountDetailLinkedTitle => 'Linked cards';

  @override
  String get accountDetailDeferredDebit => 'Deferred debit';

  @override
  String accountDetailDebitOn(String date) {
    return 'Debited on $date';
  }

  @override
  String get accountDetailNoDebitScheduled => 'No debit scheduled';

  @override
  String get accountDetailRuleMissing => 'Settlement rule to set up';

  @override
  String accountDetailOpenAccount(String name) {
    return 'Open $name';
  }

  @override
  String get accountDetailSettleTitle => 'Settlement account';

  @override
  String get accountDetailNoPayingAccount => 'No settlement account';

  @override
  String accountDetailRuleSummary(String pattern, String date) {
    return 'Label: $pattern · applied since $date';
  }

  @override
  String accountDetailRuleSummaryUndated(String pattern) {
    return 'Label: $pattern';
  }

  @override
  String get accountDetailEditRule => 'Edit the rule';

  @override
  String get accountDetailSetUpRule => 'Set up the rule';

  @override
  String get accountDetailLinkCard => 'Link a card';

  @override
  String get linkCardTitle => 'Link a card';

  @override
  String linkCardBody(String account) {
    return 'Choose the deferred debit card whose monthly statement is drawn from $account.';
  }

  @override
  String get linkCardLabel => 'Card';

  @override
  String get linkCardPlaceholder => 'Choose a card';

  @override
  String get linkCardCancel => 'Cancel';

  @override
  String get linkCardConfirm => 'Link';

  @override
  String get linkCardFailed => 'Couldn’t link the card. Try again.';

  @override
  String linkCardLinked(String card) {
    return '$card is now linked to this account';
  }

  @override
  String get accountDetailRecentTitle => 'Transactions';

  @override
  String get accountDetailColumnOperation => 'Transaction';

  @override
  String get accountDetailColumnCategory => 'Category';

  @override
  String get accountDetailColumnDate => 'Date';

  @override
  String get accountDetailColumnAmount => 'Amount';

  @override
  String get accountDetailSeeAll => 'Open in Transactions';

  @override
  String get accountDetailNoTransactions => 'No transactions';

  @override
  String get markRecurringAction => 'Mark as recurring';

  @override
  String get markRecurringOpenSeriesAction =>
      'Already recurring: view the series';

  @override
  String get recurringSeriesGoneTitle =>
      'This recurring payment no longer exists';

  @override
  String get recurringSeriesGoneMessage =>
      'It was deleted in the meantime: the transaction is no longer marked as recurring.';

  @override
  String get markRecurringTitle => 'Mark as recurring';

  @override
  String get markRecurringIntro =>
      'These are the transactions Bastide would group together. Untick any that don’t belong.';

  @override
  String get markRecurringConfidenceHigh => 'High confidence';

  @override
  String get markRecurringConfidenceMedium => 'Medium confidence';

  @override
  String get markRecurringConfidenceLow => 'Low confidence';

  @override
  String markRecurringReasonOccurrences(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions found',
      one: '1 transaction found',
    );
    return '$_temp0';
  }

  @override
  String get markRecurringReasonCadenceWeekly => 'Weekly rhythm recognised';

  @override
  String get markRecurringReasonCadenceMonthly => 'Monthly rhythm recognised';

  @override
  String get markRecurringReasonCadenceQuarterly =>
      'Quarterly rhythm recognised';

  @override
  String get markRecurringReasonCadenceYearly => 'Yearly rhythm recognised';

  @override
  String get markRecurringReasonAmountStable => 'Steady amount';

  @override
  String get markRecurringReasonAmountChanged => 'The amount changed recently';

  @override
  String get markRecurringReasonAmountOutsideTolerance =>
      'One amount differs from the others';

  @override
  String get markRecurringReasonGapOutsideTolerance =>
      'One gap breaks the rhythm';

  @override
  String get markRecurringReasonTooFewOccurrences => 'Fewer than three charges';

  @override
  String get markRecurringReasonNoRhythm => 'No regular rhythm';

  @override
  String get markRecurringCadenceLabel => 'Proposed cadence';

  @override
  String get markRecurringAmountLabel => 'Expected amount';

  @override
  String markRecurringTickedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions ticked',
      one: '1 transaction ticked',
      zero: 'No transaction ticked',
    );
    return '$_temp0';
  }

  @override
  String markRecurringTickedRange(int count, String from, String to) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions ticked',
      one: '1 transaction ticked',
    );
    return '$_temp0 · from $from to $to';
  }

  @override
  String get markRecurringNoneTicked =>
      'Tick at least one transaction to save the series.';

  @override
  String get markRecurringSave => 'Save series';

  @override
  String get markRecurringLoadError =>
      'The preview could not be prepared. Nothing was changed.';

  @override
  String get subscriptionErrorPreviewInflow =>
      'Only an expense can be marked as recurring.';

  @override
  String get subscriptionErrorTransactionsInvalid =>
      'Some transactions cannot be linked to this series.';

  @override
  String get subscriptionErrorTransactionLinked =>
      'Some transactions already belong to a series.';

  @override
  String markRecurringExistingIntro(String label) {
    return 'This expense matches “$label”, which you already track. Tick the transactions to add to it.';
  }

  @override
  String markRecurringViewSeries(String label) {
    return 'View the “$label” series';
  }

  @override
  String get markRecurringAddToSeries => 'Add to this series';

  @override
  String get markRecurringPickSeries => 'Add to an existing series…';

  @override
  String get seriesPickerIntro =>
      'Choose the series this transaction belongs to. Bastide will remember its label for the next ones.';

  @override
  String get seriesPickerSearchHint => 'Search a series';

  @override
  String get seriesPickerEmpty => 'You don’t track any series.';

  @override
  String seriesPickerNoMatch(String query) {
    return 'No series matches “$query”.';
  }

  @override
  String get seriesPickerLoadError => 'Your series could not be loaded.';

  @override
  String get seriesPickerBack => 'Back to the preview';

  @override
  String seriesPickerRowDetail(String account, String cadence, String amount) {
    return '$account · $cadence · $amount';
  }

  @override
  String get seriesPickerConfirm => 'Confirm';

  @override
  String seriesPickerAdded(String label) {
    return 'Transaction added to “$label”';
  }

  @override
  String get seriesPickerAddFailed => 'The transaction could not be added';

  @override
  String get chargePickerAction => 'Add a transaction';

  @override
  String chargePickerTitle(String label) {
    return 'Add to “$label”';
  }

  @override
  String get chargePickerIntro =>
      'Transactions that belong to no series, closest first.';

  @override
  String get chargePickerSearchHint => 'Search a label';

  @override
  String get chargePickerEmpty =>
      'Nothing to add: every expense already belongs to a series.';

  @override
  String chargePickerNoMatch(String query) {
    return 'No transaction matches “$query”.';
  }

  @override
  String get chargePickerLoadError => 'The transactions could not be loaded.';

  @override
  String get chargePickerLoadMore => 'Show more';

  @override
  String chargePickerSave(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Add $count transactions',
      one: 'Add 1 transaction',
      zero: 'Add',
    );
    return '$_temp0';
  }

  @override
  String rulePackLogoProgress(int done, int total) {
    return 'Downloading logos… $done / $total';
  }

  @override
  String get rulePackLogoProgressNotice =>
      'The rules are imported: only their logos are left.';

  @override
  String get rulePackImportRunFailed =>
      'The import could not finish. Check your rules before trying again.';

  @override
  String get ruleErrorPackNotFound => 'This rule pack could not be found.';

  @override
  String get ruleErrorPackImportInProgress =>
      'Another rule import is already running. Wait for it to finish.';

  @override
  String get ruleErrorPackImportRunNotFound =>
      'This import can no longer be followed. Check your rules.';

  @override
  String get placementsAdd => 'New investment';

  @override
  String get placementsSummaryValue => 'Declared value';

  @override
  String placementsSummaryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count investments',
      one: '1 investment',
    );
    return '$_temp0';
  }

  @override
  String placementsSummaryCaption(int count, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count investments',
      one: '1 investment',
    );
    return '$_temp0 · last value entered on $date';
  }

  @override
  String get placementsSummaryNetPayments => 'Net payments';

  @override
  String get placementsSummaryNetPaymentsCaption => 'paid in − withdrawn';

  @override
  String get placementsSummaryGain => 'Unrealised gain';

  @override
  String placementsSummaryGainShare(String percent) {
    return '$percent of net payments';
  }

  @override
  String get placementsColumnPlacement => 'Investment';

  @override
  String get placementsColumnNetPayments => 'Net payments';

  @override
  String get placementsColumnValue => 'Declared value';

  @override
  String get placementsColumnGain => 'Gain';

  @override
  String get placementsColumnValuedOn => 'Value as of';

  @override
  String placementsRowSubtitle(
    String envelope,
    String institution,
    String month,
  ) {
    return '$envelope · $institution · opened $month';
  }

  @override
  String placementsStaleBanner(String name) {
    return 'The value of $name is more than four months old.';
  }

  @override
  String get placementsStaleAction => 'Update the value';

  @override
  String placementsStaleMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count others',
      one: '1 other',
    );
    return 'and $_temp0';
  }

  @override
  String get placementsNote =>
      'Bastide connects to no broker and downloads no price. The value is the one you copy from your statement. The gain is calculated, never stored.';

  @override
  String get placementsNoValue => '—';

  @override
  String get placementsDismissBanner => 'Dismiss';

  @override
  String get placementsLoadFailed =>
      'Couldn’t load your investments. Nothing was changed.';

  @override
  String get placementsRetry => 'Retry';

  @override
  String placementOpenedOn(String institution, String date) {
    return '$institution · opened on $date';
  }

  @override
  String placementClosedOn(String institution, String date) {
    return '$institution · closed on $date';
  }

  @override
  String get placementMenuTooltip => 'Investment actions';

  @override
  String get placementMenuEdit => 'Edit';

  @override
  String get placementMenuClose => 'Close';

  @override
  String get placementMenuReopen => 'Reopen';

  @override
  String get placementMenuDelete => 'Delete';

  @override
  String placementValueAt(String date) {
    return 'as of $date';
  }

  @override
  String get placementEnterValue => 'Enter a value';

  @override
  String get placementAddMovement => 'Payment or withdrawal';

  @override
  String get placementLegendValue => 'Declared value';

  @override
  String get placementLegendNetPayments => 'Net payments';

  @override
  String get placementNoValueNote => 'Enter a value to see the gain.';

  @override
  String placementChartValue(String amount) {
    return 'Value $amount';
  }

  @override
  String placementChartNetPayments(String amount) {
    return 'Net payments $amount';
  }

  @override
  String placementChartLabel(String name) {
    return 'Declared value and net payments of $name';
  }

  @override
  String get placementCeilingLabel => 'Payment ceiling';

  @override
  String placementCeilingOf(String ceiling) {
    return 'of $ceiling';
  }

  @override
  String get placementCeilingReached => 'Payment ceiling reached.';

  @override
  String get placementAgeLabel => 'Age';

  @override
  String placementAgeYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count years',
      one: '1 year',
    );
    return '$_temp0';
  }

  @override
  String placementAgeMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count months',
      one: '1 month',
    );
    return '$_temp0';
  }

  @override
  String placementAgeBoth(String years, String months) {
    return '$years $months';
  }

  @override
  String placementMilestoneMark(int years, String month) {
    return '$years-year mark · $month';
  }

  @override
  String get placementMilestonePea =>
      'Before 5 years, a withdrawal normally closes the plan. Indicative reading, not tax advice.';

  @override
  String get placementMilestoneLifeInsurance =>
      'After 8 years, withdrawals are taxed more lightly. Indicative reading, not tax advice.';

  @override
  String get placementMovementsTitle => 'Movements';

  @override
  String placementMovementsLinked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count matched with your transactions',
      one: '1 matched with your transactions',
    );
    return '$_temp0';
  }

  @override
  String get placementMovementsEmpty => 'No movement.';

  @override
  String get placementMovementsFailed => 'Couldn’t load the history.';

  @override
  String get placementEntryPayment => 'Payment';

  @override
  String get placementEntryWithdrawal => 'Withdrawal';

  @override
  String get placementEntryValuation => 'Value entered';

  @override
  String placementEntryWithNote(String label, String note) {
    return '$label · $note';
  }

  @override
  String get placementEnvelopePea => 'PEA';

  @override
  String get placementEnvelopePeaPme => 'PEA-PME';

  @override
  String get placementEnvelopeLifeInsurance => 'Life insurance';

  @override
  String get placementEnvelopePer => 'PER';

  @override
  String get placementEnvelopePee => 'PEE';

  @override
  String get placementEnvelopeSecuritiesAccount => 'Securities account';

  @override
  String get placementEnvelopeOther => 'Other';

  @override
  String get placementFormCreateTitle => 'New investment';

  @override
  String get placementFormEditTitle => 'Edit the investment';

  @override
  String get placementFormName => 'Name';

  @override
  String get placementFormNameRequired => 'Enter a name.';

  @override
  String get placementFormEnvelope => 'Envelope';

  @override
  String get placementFormInstitution => 'Institution';

  @override
  String get placementFormInstitutionRequired => 'Enter the institution.';

  @override
  String get placementFormOpenedOn => 'Opening date';

  @override
  String get placementFormCurrentValue => 'Current value (optional)';

  @override
  String get placementFormInitialPayments => 'Payments already made (optional)';

  @override
  String get placementFormInitialPaymentsHelp =>
      'Counted as one payment at opening.';

  @override
  String get placementFormDateInvalid =>
      'Enter today’s date or an earlier one.';

  @override
  String get placementFormAmountInvalid => 'Enter a positive amount.';

  @override
  String get placementFormDatePick => 'Pick a date';

  @override
  String get placementFormSave => 'Save';

  @override
  String get placementFormDelete => 'Delete';

  @override
  String get placementValuationEditTitle => 'Edit the value';

  @override
  String get placementValuationValue => 'Value';

  @override
  String get placementValuationHelp =>
      'Copy the total value shown on your statement.';

  @override
  String get placementValuationValueInvalid => 'Enter a value.';

  @override
  String get placementFieldDate => 'Date';

  @override
  String get placementFieldNote => 'Note (optional)';

  @override
  String get placementValuationNoteHint => 'e.g. Quarterly statement';

  @override
  String get placementMovementNoteHint => 'e.g. Monthly payment';

  @override
  String get placementMovementEditTitle => 'Edit the movement';

  @override
  String get placementMovementAmount => 'Amount';

  @override
  String get placementMovementAmountHelp =>
      'A negative amount is a withdrawal.';

  @override
  String get placementMovementAmountInvalid =>
      'Enter an amount other than zero.';

  @override
  String get placementMovementLink => 'Linked transaction (optional)';

  @override
  String get placementMovementLinkHelp =>
      'Recent transfers of the same amount.';

  @override
  String get placementMovementLinkNone => 'None';

  @override
  String placementMovementLinkDetail(String date, String amount) {
    return '$date · $amount';
  }

  @override
  String get placementCloseTitle => 'Close this investment?';

  @override
  String get placementCloseLead =>
      'It leaves your net worth from the closing date and stays in the list, dimmed. Its history is kept.';

  @override
  String get placementCloseDate => 'Closing date';

  @override
  String get placementCloseAmount => 'Final amount received';

  @override
  String get placementCloseAmountInvalid =>
      'Enter an amount, zero if nothing was received.';

  @override
  String get placementCloseSubmit => 'Close';

  @override
  String placementDeleteTitle(String name) {
    return 'Delete the investment “$name”?';
  }

  @override
  String get placementDeleteLead =>
      'Its entered values and payments will be deleted. Your accounts are not changed.';

  @override
  String get placementDeleteSubmit => 'Delete';

  @override
  String get placementErrorNotFound =>
      'This investment no longer exists. Nothing was changed.';

  @override
  String get placementErrorMovementNotFound =>
      'This movement no longer exists. Nothing was changed.';

  @override
  String get placementErrorValuationNotFound =>
      'This value no longer exists. Nothing was changed.';

  @override
  String get placementErrorDateInFuture =>
      'The date is in the future. Nothing was changed.';

  @override
  String get placementErrorDateBeforeOpening =>
      'The date is before the investment was opened. Nothing was changed.';

  @override
  String get placementErrorDateAfterClosing =>
      'The date is after the investment was closed. Nothing was changed.';

  @override
  String get placementErrorAlreadyClosed =>
      'This investment is already closed. Nothing was changed.';

  @override
  String get placementErrorNotClosed =>
      'This investment is not closed. Nothing was changed.';

  @override
  String get placementErrorValuationExists =>
      'A value is already entered on that date. Edit it from the movements.';

  @override
  String get placementErrorLinkNotFound =>
      'This transaction no longer exists. Nothing was changed.';

  @override
  String get placementErrorAlreadyLinked =>
      'This transaction is already linked to another movement. Nothing was changed.';

  @override
  String get placementErrorValidation =>
      'A field is not valid. Nothing was changed.';

  @override
  String get placementErrorGeneric =>
      'The operation failed. Nothing was changed. Try again.';

  @override
  String networthAssetsPartInvestments(String amount) {
    return 'Investments $amount';
  }

  @override
  String get networthCompositionInvestments => 'Investments';

  @override
  String get networthNoteInvestments =>
      'Investments count at their last entered value. Between two entries, the curve stays flat.';
}
