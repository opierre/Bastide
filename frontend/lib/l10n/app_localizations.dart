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

  /// Left nav section heading grouping the dashboard, accounts and transactions destinations. Rendered uppercase.
  ///
  /// In fr, this message translates to:
  /// **'Vue d\'ensemble'**
  String get navSectionOverview;

  /// Left nav section heading grouping the imports and categories destinations. Rendered uppercase.
  ///
  /// In fr, this message translates to:
  /// **'Gestion'**
  String get navSectionManage;

  /// One-line descriptor shown under the panel title in the top bar, on the dashboard.
  ///
  /// In fr, this message translates to:
  /// **'Votre mois en un coup d\'œil'**
  String get navDashboardSubtitle;

  /// One-line descriptor shown under the panel title in the top bar, on the accounts screen.
  ///
  /// In fr, this message translates to:
  /// **'Tous vos comptes, une seule devise'**
  String get navAccountsSubtitle;

  /// One-line descriptor shown under the panel title in the top bar, on the transactions screen.
  ///
  /// In fr, this message translates to:
  /// **'Toutes vos opérations, en un seul fil'**
  String get navTransactionsSubtitle;

  /// One-line descriptor shown under the panel title in the top bar, on the imports screen.
  ///
  /// In fr, this message translates to:
  /// **'Relevés OFX, QFX et CSV — traités sur cet ordinateur'**
  String get navImportsSubtitle;

  /// One-line descriptor shown under the panel title in the top bar, on the categories screen.
  ///
  /// In fr, this message translates to:
  /// **'Organisez vos dépenses, automatisez avec des règles'**
  String get navCategoriesSubtitle;

  /// One-line descriptor shown under the panel title in the top bar, on the settings screen.
  ///
  /// In fr, this message translates to:
  /// **'Profil, préférences et vos données locales'**
  String get navSettingsSubtitle;

  /// Reassurance badge pinned at the foot of the sidebar, beside a lock glyph.
  ///
  /// In fr, this message translates to:
  /// **'Données 100 % locales'**
  String get sidebarPrivacyBadge;

  /// Tooltip on the control that collapses the sidebar to an icon-only rail.
  ///
  /// In fr, this message translates to:
  /// **'Réduire le menu'**
  String get sidebarCollapse;

  /// Tooltip on the control that expands the collapsed sidebar back to full width.
  ///
  /// In fr, this message translates to:
  /// **'Déployer le menu'**
  String get sidebarExpand;

  /// Item in the top-bar user menu that ends the session.
  ///
  /// In fr, this message translates to:
  /// **'Se déconnecter'**
  String get userMenuLogout;

  /// Placeholder heading on panels whose feature isn't built yet.
  ///
  /// In fr, this message translates to:
  /// **'Bientôt disponible'**
  String get comingSoonTitle;

  /// Settings section nav item for the user's profile.
  ///
  /// In fr, this message translates to:
  /// **'Profil'**
  String get settingsSectionProfile;

  /// Settings section nav item for language, currency and formats.
  ///
  /// In fr, this message translates to:
  /// **'Préférences'**
  String get settingsSectionPreferences;

  /// Settings section nav item for the local database, export and danger zone.
  ///
  /// In fr, this message translates to:
  /// **'Données'**
  String get settingsSectionData;

  /// Settings section nav item for the version and privacy statement.
  ///
  /// In fr, this message translates to:
  /// **'À propos'**
  String get settingsSectionAbout;

  /// Title of the language card in settings preferences.
  ///
  /// In fr, this message translates to:
  /// **'Langue'**
  String get settingsLanguageTitle;

  /// Note under the language segmented control.
  ///
  /// In fr, this message translates to:
  /// **'S\'applique immédiatement à toute l\'interface.'**
  String get settingsLanguageNote;

  /// Title of the currency card in settings preferences.
  ///
  /// In fr, this message translates to:
  /// **'Devise'**
  String get settingsCurrencyTitle;

  /// Note under the read-only currency field in settings, stating that it is permanent.
  ///
  /// In fr, this message translates to:
  /// **'Choisie à l\'inscription et appliquée à tous vos comptes. Elle ne peut pas être modifiée dans cette version.'**
  String get settingsCurrencyNote;

  /// Title of the card previewing how dates and amounts render in the active locale.
  ///
  /// In fr, this message translates to:
  /// **'Aperçu des formats'**
  String get settingsFormatsTitle;

  /// Label on the date format preview plate.
  ///
  /// In fr, this message translates to:
  /// **'Dates'**
  String get settingsFormatsDates;

  /// Label on the amount format preview plate.
  ///
  /// In fr, this message translates to:
  /// **'Montants'**
  String get settingsFormatsAmounts;

  /// Label beside the application version number in the About section.
  ///
  /// In fr, this message translates to:
  /// **'Version'**
  String get settingsAboutVersion;

  /// Local-privacy statement in the About section.
  ///
  /// In fr, this message translates to:
  /// **'Toutes vos données restent sur cet ordinateur. FinStride ne se connecte à aucune banque et n\'envoie rien sur Internet.'**
  String get settingsAboutPrivacy;

  /// Encouraging placeholder body on panels whose feature isn't built yet.
  ///
  /// In fr, this message translates to:
  /// **'Cet écran arrive dans une prochaine étape. En attendant, ajoutez vos comptes pour préparer le terrain.'**
  String get comingSoonBody;

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

  /// Reassuring subheading under the brand lockup on the login and register screens.
  ///
  /// In fr, this message translates to:
  /// **'Votre argent, en clair.'**
  String get authTagline;

  /// Reassurance line shown under the tagline on the signed-out screens, beside a lock glyph.
  ///
  /// In fr, this message translates to:
  /// **'Local et privé — vos données ne quittent jamais cet ordinateur.'**
  String get authPrivacyLine;

  /// Label replacing the sign-in button text while the request is in flight.
  ///
  /// In fr, this message translates to:
  /// **'Connexion…'**
  String get authLoginSubmitting;

  /// Accessible label for the control that reveals the typed password.
  ///
  /// In fr, this message translates to:
  /// **'Afficher le mot de passe'**
  String get authPasswordShow;

  /// Accessible label for the control that hides the typed password again.
  ///
  /// In fr, this message translates to:
  /// **'Masquer le mot de passe'**
  String get authPasswordHide;

  /// Label for the email field on login/register forms.
  ///
  /// In fr, this message translates to:
  /// **'Adresse e-mail'**
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

  /// Verdict beside the password strength meter at its lowest levels.
  ///
  /// In fr, this message translates to:
  /// **'Trop faible'**
  String get authPasswordStrengthWeak;

  /// Verdict beside the password strength meter at its middle level.
  ///
  /// In fr, this message translates to:
  /// **'Moyen'**
  String get authPasswordStrengthFair;

  /// Verdict beside the password strength meter once it is acceptable.
  ///
  /// In fr, this message translates to:
  /// **'Robuste'**
  String get authPasswordStrengthStrong;

  /// Guidance shown under a password that is still too weak to submit.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez quelques caractères, un chiffre et une majuscule.'**
  String get authPasswordStrengthHint;

  /// Microcopy under the language and currency row at registration, stating which choice is permanent.
  ///
  /// In fr, this message translates to:
  /// **'Vous pourrez changer la langue plus tard ; la devise s\'applique à tous vos comptes et ne pourra plus être modifiée dans cette version.'**
  String get authPreferencesNote;

  /// Validation helper shown when the chosen email already has an account.
  ///
  /// In fr, this message translates to:
  /// **'Cet e-mail est déjà utilisé — connectez-vous plutôt.'**
  String get authEmailTaken;

  /// Validation helper shown when the typed email is not a valid address.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez une adresse e-mail valide.'**
  String get authEmailInvalid;

  /// Display name for the EUR currency, shown beside its code and symbol.
  ///
  /// In fr, this message translates to:
  /// **'Euro'**
  String get currencyNameEUR;

  /// Display name for the USD currency, shown beside its code and symbol.
  ///
  /// In fr, this message translates to:
  /// **'Dollar américain'**
  String get currencyNameUSD;

  /// Display name for the GBP currency, shown beside its code and symbol.
  ///
  /// In fr, this message translates to:
  /// **'Livre sterling'**
  String get currencyNameGBP;

  /// Display name for the CHF currency, shown beside its code and symbol.
  ///
  /// In fr, this message translates to:
  /// **'Franc suisse'**
  String get currencyNameCHF;

  /// Display name for the CAD currency, shown beside its code and symbol.
  ///
  /// In fr, this message translates to:
  /// **'Dollar canadien'**
  String get currencyNameCAD;

  /// Display name for the JPY currency, shown beside its code and symbol.
  ///
  /// In fr, this message translates to:
  /// **'Yen japonais'**
  String get currencyNameJPY;

  /// Display name for the AUD currency, shown beside its code and symbol.
  ///
  /// In fr, this message translates to:
  /// **'Dollar australien'**
  String get currencyNameAUD;

  /// Display name for the CNY currency, shown beside its code and symbol.
  ///
  /// In fr, this message translates to:
  /// **'Yuan chinois'**
  String get currencyNameCNY;

  /// Display name for the INR currency, shown beside its code and symbol.
  ///
  /// In fr, this message translates to:
  /// **'Roupie indienne'**
  String get currencyNameINR;

  /// Display name for the BRL currency, shown beside its code and symbol.
  ///
  /// In fr, this message translates to:
  /// **'Réal brésilien'**
  String get currencyNameBRL;

  /// Display name for the MXN currency, shown beside its code and symbol.
  ///
  /// In fr, this message translates to:
  /// **'Peso mexicain'**
  String get currencyNameMXN;

  /// Display name for the SEK currency, shown beside its code and symbol.
  ///
  /// In fr, this message translates to:
  /// **'Couronne suédoise'**
  String get currencyNameSEK;

  /// Display name for the NOK currency, shown beside its code and symbol.
  ///
  /// In fr, this message translates to:
  /// **'Couronne norvégienne'**
  String get currencyNameNOK;

  /// Display name for the DKK currency, shown beside its code and symbol.
  ///
  /// In fr, this message translates to:
  /// **'Couronne danoise'**
  String get currencyNameDKK;

  /// Display name for the PLN currency, shown beside its code and symbol.
  ///
  /// In fr, this message translates to:
  /// **'Zloty polonais'**
  String get currencyNamePLN;

  /// Display name for the CZK currency, shown beside its code and symbol.
  ///
  /// In fr, this message translates to:
  /// **'Couronne tchèque'**
  String get currencyNameCZK;

  /// Display name for the HUF currency, shown beside its code and symbol.
  ///
  /// In fr, this message translates to:
  /// **'Forint hongrois'**
  String get currencyNameHUF;

  /// Display name for the RON currency, shown beside its code and symbol.
  ///
  /// In fr, this message translates to:
  /// **'Leu roumain'**
  String get currencyNameRON;

  /// Display name for the ZAR currency, shown beside its code and symbol.
  ///
  /// In fr, this message translates to:
  /// **'Rand sud-africain'**
  String get currencyNameZAR;

  /// Display name for the AED currency, shown beside its code and symbol.
  ///
  /// In fr, this message translates to:
  /// **'Dirham des Émirats'**
  String get currencyNameAED;

  /// Display name for the SGD currency, shown beside its code and symbol.
  ///
  /// In fr, this message translates to:
  /// **'Dollar de Singapour'**
  String get currencyNameSGD;

  /// Display name for the HKD currency, shown beside its code and symbol.
  ///
  /// In fr, this message translates to:
  /// **'Dollar de Hong Kong'**
  String get currencyNameHKD;

  /// Display name for the NZD currency, shown beside its code and symbol.
  ///
  /// In fr, this message translates to:
  /// **'Dollar néo-zélandais'**
  String get currencyNameNZD;

  /// Display name for the TRY currency, shown beside its code and symbol.
  ///
  /// In fr, this message translates to:
  /// **'Livre turque'**
  String get currencyNameTRY;

  /// Display name for the ILS currency, shown beside its code and symbol.
  ///
  /// In fr, this message translates to:
  /// **'Shekel israélien'**
  String get currencyNameILS;

  /// Display name for the KRW currency, shown beside its code and symbol.
  ///
  /// In fr, this message translates to:
  /// **'Won sud-coréen'**
  String get currencyNameKRW;

  /// Display name for the THB currency, shown beside its code and symbol.
  ///
  /// In fr, this message translates to:
  /// **'Baht thaïlandais'**
  String get currencyNameTHB;

  /// Display name for the MAD currency, shown beside its code and symbol.
  ///
  /// In fr, this message translates to:
  /// **'Dirham marocain'**
  String get currencyNameMAD;

  /// Display name for the XOF currency, shown beside its code and symbol.
  ///
  /// In fr, this message translates to:
  /// **'Franc CFA (BCEAO)'**
  String get currencyNameXOF;

  /// Display name for the XAF currency, shown beside its code and symbol.
  ///
  /// In fr, this message translates to:
  /// **'Franc CFA (BEAC)'**
  String get currencyNameXAF;

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
  /// **'E-mail ou mot de passe incorrect. Vérifiez vos identifiants et réessayez.'**
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

  /// Placeholder in the accounts search pill in the top bar.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher…'**
  String get accountsSearchHint;

  /// Shown in place of the account grid when the search filters everything out.
  ///
  /// In fr, this message translates to:
  /// **'Aucun compte ne correspond à votre recherche.'**
  String get accountsSearchEmpty;

  /// Timestamp under the summary meta saying when the balances were last recalculated.
  ///
  /// In fr, this message translates to:
  /// **'Soldes au {date}'**
  String accountsBalancesAsOf(DateTime date);

  /// Confirmation shown beside the institution monogram once the typed name is one we have a pinned color for.
  ///
  /// In fr, this message translates to:
  /// **'Logo reconnu'**
  String get accountLogoRecognized;

  /// Note under the read-only currency field in the account form.
  ///
  /// In fr, this message translates to:
  /// **'La devise est celle de votre profil et s\'applique à tous les comptes.'**
  String get accountCurrencyNote;

  /// Label on the summary card above the accounts list, over the sum of all account balances.
  ///
  /// In fr, this message translates to:
  /// **'Solde total'**
  String get accountsTotalBalanceLabel;

  /// Caption under the total balance, counting the accounts included in the sum.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucun compte actif} =1{1 compte actif} other{{count} comptes actifs}}'**
  String accountsActiveCount(int count);

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
  /// **'Courant'**
  String get accountTypeChecking;

  /// Account type option: savings.
  ///
  /// In fr, this message translates to:
  /// **'Épargne'**
  String get accountTypeSavings;

  /// Account type option: credit.
  ///
  /// In fr, this message translates to:
  /// **'Crédit'**
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
