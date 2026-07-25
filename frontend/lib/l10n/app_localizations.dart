import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
  ];

  /// The application title, shown in the OS window title and task switcher.
  ///
  /// In fr, this message translates to:
  /// **'FinStride'**
  String get appTitle;

  /// Left nav label for the dashboard screen.
  ///
  /// In fr, this message translates to:
  /// **'Tableau de bord'**
  String get navDashboard;

  /// Left nav label for the accounts screen.
  ///
  /// In fr, this message translates to:
  /// **'Comptes'**
  String get navAccounts;

  /// Left nav label for the transactions screen.
  ///
  /// In fr, this message translates to:
  /// **'Transactions'**
  String get navTransactions;

  /// Left nav label for the imports screen.
  ///
  /// In fr, this message translates to:
  /// **'Imports'**
  String get navImports;

  /// Left nav label for the categories screen.
  ///
  /// In fr, this message translates to:
  /// **'Catégories'**
  String get navCategories;

  /// Left nav label for the settings screen.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres'**
  String get navSettings;

  /// Default status text shown in the bottom bar.
  ///
  /// In fr, this message translates to:
  /// **'Prêt'**
  String get statusBarReady;

  /// Heading on the login screen.
  ///
  /// In fr, this message translates to:
  /// **'Se connecter'**
  String get authLoginTitle;

  /// Heading on the registration screen.
  ///
  /// In fr, this message translates to:
  /// **'Créer un compte'**
  String get authRegisterTitle;

  /// Label for the email field on login/register forms.
  ///
  /// In fr, this message translates to:
  /// **'E-mail'**
  String get authEmailLabel;

  /// Label for the password field on login/register forms.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe'**
  String get authPasswordLabel;

  /// Label for the display name field on the register form.
  ///
  /// In fr, this message translates to:
  /// **'Nom affiché'**
  String get authDisplayNameLabel;

  /// Label for the language selector on the register form.
  ///
  /// In fr, this message translates to:
  /// **'Langue'**
  String get authLocaleLabel;

  /// Option label for French, shown in its own language regardless of app locale.
  ///
  /// In fr, this message translates to:
  /// **'Français'**
  String get authLocaleFrench;

  /// Option label for English, shown in its own language regardless of app locale.
  ///
  /// In fr, this message translates to:
  /// **'English'**
  String get authLocaleEnglish;

  /// Label for the base-currency selector on the register form.
  ///
  /// In fr, this message translates to:
  /// **'Devise'**
  String get authCurrencyLabel;

  /// Submit button label on the login form.
  ///
  /// In fr, this message translates to:
  /// **'Se connecter'**
  String get authLoginSubmit;

  /// Submit button label on the register form.
  ///
  /// In fr, this message translates to:
  /// **'Créer mon compte'**
  String get authRegisterSubmit;

  /// Link on the login screen navigating to registration.
  ///
  /// In fr, this message translates to:
  /// **'Pas encore de compte ? Créer un compte'**
  String get authGoToRegister;

  /// Link on the register screen navigating to login.
  ///
  /// In fr, this message translates to:
  /// **'Déjà un compte ? Se connecter'**
  String get authGoToLogin;

  /// Validation message when the email field is left empty.
  ///
  /// In fr, this message translates to:
  /// **'L\'e-mail est requis.'**
  String get authEmailRequired;

  /// Validation message when the password field is left empty.
  ///
  /// In fr, this message translates to:
  /// **'Le mot de passe est requis.'**
  String get authPasswordRequired;

  /// Validation message when the display name field is left empty.
  ///
  /// In fr, this message translates to:
  /// **'Le nom est requis.'**
  String get authDisplayNameRequired;

  /// Localized message for the backend's INVALID_CREDENTIALS error code.
  ///
  /// In fr, this message translates to:
  /// **'E-mail ou mot de passe incorrect.'**
  String get authErrorInvalidCredentials;

  /// Localized message for the backend's EMAIL_TAKEN error code.
  ///
  /// In fr, this message translates to:
  /// **'Un compte existe déjà avec cet e-mail.'**
  String get authErrorEmailTaken;

  /// Localized message for the backend's VALIDATION_ERROR error code.
  ///
  /// In fr, this message translates to:
  /// **'Certaines informations sont invalides.'**
  String get authErrorValidation;

  /// Fallback localized message for unrecognized or network errors.
  ///
  /// In fr, this message translates to:
  /// **'Une erreur est survenue. Veuillez réessayer.'**
  String get authErrorGeneric;

  /// Button label to open the create-account form.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un compte'**
  String get accountsAddButton;

  /// Heading shown when the user has no accounts yet.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez votre premier compte'**
  String get accountsEmptyTitle;

  /// Encouraging subtext under the empty-state heading on the accounts screen.
  ///
  /// In fr, this message translates to:
  /// **'Suivez vos soldes et vos mouvements en un seul endroit.'**
  String get accountsEmptyBody;

  /// Retry button label shown when the accounts list fails to load.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get accountsRetry;

  /// Menu item to edit an account.
  ///
  /// In fr, this message translates to:
  /// **'Modifier'**
  String get accountEdit;

  /// Menu item and confirm-dialog action to archive an account.
  ///
  /// In fr, this message translates to:
  /// **'Archiver'**
  String get accountArchive;

  /// Cancel action on the account form and archive confirmation dialogs.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get accountFormCancel;

  /// Title of the archive confirmation dialog.
  ///
  /// In fr, this message translates to:
  /// **'Archiver ce compte ?'**
  String get accountArchiveConfirmTitle;

  /// Body text of the archive confirmation dialog.
  ///
  /// In fr, this message translates to:
  /// **'Vous pourrez toujours consulter son historique, mais il n\'apparaîtra plus dans votre liste de comptes.'**
  String get accountArchiveConfirmBody;

  /// Title of the account form dialog when creating an account.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau compte'**
  String get accountFormCreateTitle;

  /// Title of the account form dialog when editing an account.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le compte'**
  String get accountFormEditTitle;

  /// Label for the account name field on the account form.
  ///
  /// In fr, this message translates to:
  /// **'Nom'**
  String get accountNameLabel;

  /// Validation message when the account name field is left empty.
  ///
  /// In fr, this message translates to:
  /// **'Le nom est requis.'**
  String get accountNameRequired;

  /// Label for the account type selector on the account form.
  ///
  /// In fr, this message translates to:
  /// **'Type'**
  String get accountTypeLabel;

  /// Account type option: checking.
  ///
  /// In fr, this message translates to:
  /// **'Compte courant'**
  String get accountTypeChecking;

  /// Account type option: savings.
  ///
  /// In fr, this message translates to:
  /// **'Épargne'**
  String get accountTypeSavings;

  /// Account type option: credit.
  ///
  /// In fr, this message translates to:
  /// **'Carte de crédit'**
  String get accountTypeCredit;

  /// Account type option: cash.
  ///
  /// In fr, this message translates to:
  /// **'Espèces'**
  String get accountTypeCash;

  /// Account type option: other.
  ///
  /// In fr, this message translates to:
  /// **'Autre'**
  String get accountTypeOther;

  /// Label for the institution field on the account form.
  ///
  /// In fr, this message translates to:
  /// **'Établissement'**
  String get accountInstitutionLabel;

  /// Validation message when the institution field is left empty.
  ///
  /// In fr, this message translates to:
  /// **'L\'établissement est requis.'**
  String get accountInstitutionRequired;

  /// Label for the opening balance field on the account form.
  ///
  /// In fr, this message translates to:
  /// **'Solde initial'**
  String get accountOpeningBalanceLabel;

  /// Validation message when the opening balance field is left empty.
  ///
  /// In fr, this message translates to:
  /// **'Le solde initial est requis.'**
  String get accountOpeningBalanceRequired;

  /// Validation message when the opening balance can't be parsed as a number.
  ///
  /// In fr, this message translates to:
  /// **'Entrez un montant valide.'**
  String get accountOpeningBalanceInvalid;

  /// Label for the read-only currency field on the account form.
  ///
  /// In fr, this message translates to:
  /// **'Devise'**
  String get accountCurrencyLabel;

  /// Submit button label on the account form when creating an account.
  ///
  /// In fr, this message translates to:
  /// **'Créer le compte'**
  String get accountFormSubmitCreate;

  /// Submit button label on the account form when editing an account.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get accountFormSubmitEdit;

  /// Localized message for the backend's ACCOUNT_NOT_FOUND error code.
  ///
  /// In fr, this message translates to:
  /// **'Compte introuvable.'**
  String get accountErrorNotFound;

  /// Localized message for the backend's VALIDATION_ERROR error code.
  ///
  /// In fr, this message translates to:
  /// **'Certaines informations sont invalides.'**
  String get accountErrorValidation;

  /// Fallback localized message for unrecognized or network errors on the accounts screen.
  ///
  /// In fr, this message translates to:
  /// **'Une erreur est survenue. Veuillez réessayer.'**
  String get accountErrorGeneric;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
