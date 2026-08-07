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

  /// Note at the top of the account form when its fields were pre-filled from an imported statement rather than typed. Says nothing about editability: which fields can be changed varies with what the statement declares, and each field's own helper carries that.
  ///
  /// In fr, this message translates to:
  /// **'Champs pré-remplis depuis votre relevé.'**
  String get accountFormPrefilledNote;

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

  /// Account type option: the holding account a deferred-debit card posts to, settled against the current account once a month.
  ///
  /// In fr, this message translates to:
  /// **'Carte à débit différé'**
  String get accountTypeDeferredCard;

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

  /// Helper under the read-only institution field when the account is being created from a statement that names its bank.
  ///
  /// In fr, this message translates to:
  /// **'Repris de l\'établissement déclaré par votre relevé.'**
  String get accountInstitutionFromStatementNote;

  /// Label for the opening balance field on the account form, when editing an account: the figure the account started from.
  ///
  /// In fr, this message translates to:
  /// **'Solde initial'**
  String get accountOpeningBalanceLabel;

  /// Label for the same balance field when creating an account: with no history behind it yet, what the user enters is the balance the account holds today.
  ///
  /// In fr, this message translates to:
  /// **'Solde actuel'**
  String get accountCurrentBalanceLabel;

  /// Helper under the balance field when the account is being created from a statement: the import derives the real figure from the statement's declared balance, so an approximate entry here is harmless.
  ///
  /// In fr, this message translates to:
  /// **'Ajusté automatiquement d\'après le solde déclaré par votre relevé lors du premier import.'**
  String get accountBalanceStatementNote;

  /// Helper under the read-only balance field when the account is being created from a statement that declares its closing balance: the figure is the statement's, not something to type.
  ///
  /// In fr, this message translates to:
  /// **'Repris du solde déclaré par votre relevé.'**
  String get accountBalanceFromStatementNote;

  /// Helper under the balance field when editing an existing account: explains that a manual correction shifts the cached balance and every saved snapshot by the same delta rather than rewriting the ledger.
  ///
  /// In fr, this message translates to:
  /// **'Corriger cette valeur décale le solde du compte et son historique enregistré du même montant — aucune transaction n\'est modifiée.'**
  String get accountOpeningBalanceEditNote;

  /// Validation message when the balance field is left empty, whether creating an account or correcting it while editing.
  ///
  /// In fr, this message translates to:
  /// **'Le solde est requis.'**
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

  /// Localized message for the backend's ACCOUNT_OFX_ID_TAKEN error code, raised when the bank account id read from a statement is already bound to another account.
  ///
  /// In fr, this message translates to:
  /// **'Un autre compte utilise déjà cet identifiant bancaire.'**
  String get accountErrorOfxIdTaken;

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

  /// Title of the card where a file is staged and imported, on the imports panel.
  ///
  /// In fr, this message translates to:
  /// **'Nouvel import'**
  String get importNewTitle;

  /// Label for the account selector on the imports panel.
  ///
  /// In fr, this message translates to:
  /// **'Compte de destination'**
  String get importAccountLabel;

  /// Shown in place of the account selector when the accounts list failed to load.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger vos comptes. Réessayez dans un instant.'**
  String get importAccountsUnavailable;

  /// Headline inside the imports drop zone.
  ///
  /// In fr, this message translates to:
  /// **'Déposez un fichier OFX, QFX ou CSV'**
  String get importDropZoneTitle;

  /// Sub-line inside the imports drop zone, stating that a CSV opens the mapping wizard.
  ///
  /// In fr, this message translates to:
  /// **'ou cliquez pour parcourir — un CSV ouvre l\'assistant de correspondance'**
  String get importDropZoneHint;

  /// Size of the staged file, shown under its name. The number is already formatted for the locale.
  ///
  /// In fr, this message translates to:
  /// **'{size} ko'**
  String importFileSize(String size);

  /// Tooltip on the control that unstages the selected file.
  ///
  /// In fr, this message translates to:
  /// **'Retirer le fichier'**
  String get importRemoveFile;

  /// Primary action that imports the staged file.
  ///
  /// In fr, this message translates to:
  /// **'Importer'**
  String get importSubmit;

  /// Label replacing the import button text while the upload is in flight.
  ///
  /// In fr, this message translates to:
  /// **'Import en cours…'**
  String get importSubmitting;

  /// Primary action shown for a CSV with no saved mapping — it opens the wizard rather than importing straight away.
  ///
  /// In fr, this message translates to:
  /// **'Configurer et importer'**
  String get importOpenWizard;

  /// Banner telling the user a saved CSV template will be reused instead of the wizard.
  ///
  /// In fr, this message translates to:
  /// **'Format CSV mémorisé pour {bank} — il sera réutilisé pour ce fichier.'**
  String importTemplateReuse(String bank);

  /// Action that re-opens the CSV wizard even though a saved template exists.
  ///
  /// In fr, this message translates to:
  /// **'Reconfigurer'**
  String get importReconfigureTemplate;

  /// Banner confirming the statement's account block matched an existing account, which has been selected as the destination.
  ///
  /// In fr, this message translates to:
  /// **'Compte reconnu dans le fichier : {account}.'**
  String importDetectedAccount(String account);

  /// Banner shown when the statement's bank matches several accounts and nothing in the file separates them; the user picks the destination.
  ///
  /// In fr, this message translates to:
  /// **'Ce relevé vient de {account}, mais plusieurs comptes y correspondent — choisissez la destination.'**
  String importDetectedAccountAmbiguous(String account);

  /// Banner shown when the account declared by the statement matches none of the user's accounts.
  ///
  /// In fr, this message translates to:
  /// **'Aucun compte ne correspond au compte {account} de ce relevé.'**
  String importDetectedAccountUnknown(String account);

  /// Action opening the account form pre-filled with the account read from the statement.
  ///
  /// In fr, this message translates to:
  /// **'Créer ce compte'**
  String get importCreateDetectedAccount;

  /// Title of the card summarising the import that just ran.
  ///
  /// In fr, this message translates to:
  /// **'Dernier import'**
  String get importResultTitle;

  /// Caption under the count of newly inserted transactions on the import result card.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{aucune nouvelle opération} =1{nouvelle opération} other{nouvelles opérations}}'**
  String importResultNewLabel(int count);

  /// Caption under the count of skipped duplicate transactions on the import result card.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{aucun doublon} =1{doublon ignoré} other{doublons ignorés}}'**
  String importResultDuplicateLabel(int count);

  /// Line on the result card naming the imported file and the account it landed in.
  ///
  /// In fr, this message translates to:
  /// **'{file} → {account}'**
  String importResultTarget(String file, String account);

  /// Warning banner on the result card when the statement's declared balance disagrees with what the ledger implies. `amount` is pre-formatted with a sign (see formatAmount).
  ///
  /// In fr, this message translates to:
  /// **'Le relevé indique un solde à {amount} de votre suivi au {date}. Vérifiez un import manquant, ou corrigez le solde d\'ouverture du compte si l\'écart persiste.'**
  String importResultBalanceMismatchBody(String amount, DateTime date);

  /// The coverage window of an import batch, derived from the file's contents.
  ///
  /// In fr, this message translates to:
  /// **'{start} – {end}'**
  String importPeriodRange(DateTime start, DateTime end);

  /// Calm explanation shown on a failed import, stating that nothing was written.
  ///
  /// In fr, this message translates to:
  /// **'Le fichier n\'a pas pu être lu — rien n\'a été modifié.'**
  String get importFailedNote;

  /// Note under a history row's filename when the run skipped duplicates.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 opération déjà présente, ignorée} other{{count} opérations déjà présentes, ignorées}}'**
  String importDuplicatesNote(int count);

  /// Note under a history row's filename when the statement's declared balance disagrees with what the ledger implies — only ever set from an account's second import onward. `amount` is pre-formatted with a sign (see formatAmount).
  ///
  /// In fr, this message translates to:
  /// **'Écart de {amount} avec le solde de la banque au {date}.'**
  String importBalanceMismatchNote(String amount, DateTime date);

  /// Status pill for an import that completed.
  ///
  /// In fr, this message translates to:
  /// **'Réussi'**
  String get importStatusSuccess;

  /// Status pill for an import where only some rows landed.
  ///
  /// In fr, this message translates to:
  /// **'Partiel'**
  String get importStatusPartial;

  /// Status pill for an import that could not be parsed at all.
  ///
  /// In fr, this message translates to:
  /// **'Échec'**
  String get importStatusFailed;

  /// Title of the card listing every past import.
  ///
  /// In fr, this message translates to:
  /// **'Historique des imports'**
  String get importHistoryTitle;

  /// Heading shown when the import history is empty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun import pour l\'instant'**
  String get importHistoryEmptyTitle;

  /// Encouraging subtext under the empty import-history heading.
  ///
  /// In fr, this message translates to:
  /// **'Déposez un relevé ci-dessus : vos opérations apparaîtront ici.'**
  String get importHistoryEmptyBody;

  /// Import history column header for the file name.
  ///
  /// In fr, this message translates to:
  /// **'Fichier'**
  String get importHistoryFileHeader;

  /// Import history column header for the source format badge.
  ///
  /// In fr, this message translates to:
  /// **'Format'**
  String get importHistoryFormatHeader;

  /// Import history column header for the date the file was imported.
  ///
  /// In fr, this message translates to:
  /// **'Importé le'**
  String get importHistoryImportedHeader;

  /// Import history column header for the coverage window.
  ///
  /// In fr, this message translates to:
  /// **'Période couverte'**
  String get importHistoryPeriodHeader;

  /// Import history column header for the count of newly inserted transactions.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelles'**
  String get importHistoryNewHeader;

  /// Import history column header for the count of skipped duplicates.
  ///
  /// In fr, this message translates to:
  /// **'Doublons'**
  String get importHistoryDuplicatesHeader;

  /// Import history column header for the outcome pill.
  ///
  /// In fr, this message translates to:
  /// **'Statut'**
  String get importHistoryStatusHeader;

  /// Retry button label shown when the import history fails to load.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get importRetry;

  /// Title of the one-time CSV column-mapping wizard modal.
  ///
  /// In fr, this message translates to:
  /// **'Assistant CSV'**
  String get csvWizardTitle;

  /// Label of the wizard's first step, where the file's format is described.
  ///
  /// In fr, this message translates to:
  /// **'Format'**
  String get csvWizardStepFormat;

  /// Label of the wizard's second step, where columns are mapped and previewed.
  ///
  /// In fr, this message translates to:
  /// **'Colonnes & aperçu'**
  String get csvWizardStepColumns;

  /// Cancel action in the CSV wizard footer.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get csvWizardCancel;

  /// Action moving from the wizard's format step to its columns step.
  ///
  /// In fr, this message translates to:
  /// **'Continuer'**
  String get csvWizardNext;

  /// Action that saves the mapping and imports the file.
  ///
  /// In fr, this message translates to:
  /// **'Valider et importer'**
  String get csvWizardConfirm;

  /// Label replacing the wizard's confirm button text while saving and importing.
  ///
  /// In fr, this message translates to:
  /// **'Import en cours…'**
  String get csvWizardConfirming;

  /// Label for the bank name the CSV mapping is remembered under.
  ///
  /// In fr, this message translates to:
  /// **'Banque'**
  String get csvWizardBankLabel;

  /// Helper under the bank name field, stating that the mapping is saved for reuse.
  ///
  /// In fr, this message translates to:
  /// **'Ce format sera mémorisé sous ce nom et réutilisé à chaque import de cette banque.'**
  String get csvWizardBankHelper;

  /// Label for the CSV column separator selector.
  ///
  /// In fr, this message translates to:
  /// **'Délimiteur'**
  String get csvWizardDelimiterLabel;

  /// Delimiter option: semicolon, the common French bank export separator.
  ///
  /// In fr, this message translates to:
  /// **'Point-virgule ( ; )'**
  String get csvDelimiterSemicolon;

  /// Delimiter option: comma.
  ///
  /// In fr, this message translates to:
  /// **'Virgule ( , )'**
  String get csvDelimiterComma;

  /// Delimiter option: tab character.
  ///
  /// In fr, this message translates to:
  /// **'Tabulation'**
  String get csvDelimiterTab;

  /// Delimiter option: pipe character.
  ///
  /// In fr, this message translates to:
  /// **'Barre verticale ( | )'**
  String get csvDelimiterPipe;

  /// Label for the CSV character encoding selector.
  ///
  /// In fr, this message translates to:
  /// **'Encodage'**
  String get csvWizardEncodingLabel;

  /// Label for the CSV date format selector.
  ///
  /// In fr, this message translates to:
  /// **'Format de date'**
  String get csvWizardDateFormatLabel;

  /// Label for the decimal separator control.
  ///
  /// In fr, this message translates to:
  /// **'Séparateur décimal'**
  String get csvWizardDecimalLabel;

  /// Decimal separator option: comma.
  ///
  /// In fr, this message translates to:
  /// **'Virgule ( , )'**
  String get csvDecimalComma;

  /// Decimal separator option: period.
  ///
  /// In fr, this message translates to:
  /// **'Point ( . )'**
  String get csvDecimalPeriod;

  /// Label for the control choosing how the file encodes amount direction.
  ///
  /// In fr, this message translates to:
  /// **'Montants'**
  String get csvWizardAmountsLabel;

  /// Amount strategy option: a single signed amount column.
  ///
  /// In fr, this message translates to:
  /// **'Signé'**
  String get csvAmountStrategySigned;

  /// Amount strategy option: separate debit and credit columns.
  ///
  /// In fr, this message translates to:
  /// **'Débit / Crédit'**
  String get csvAmountStrategyDebitCredit;

  /// Label for the count of lines to skip before the header row.
  ///
  /// In fr, this message translates to:
  /// **'Lignes à ignorer'**
  String get csvWizardHeaderOffsetLabel;

  /// Helper clarifying that the skipped lines precede the header row.
  ///
  /// In fr, this message translates to:
  /// **'Avant la ligne d\'en-tête.'**
  String get csvWizardHeaderOffsetHelper;

  /// Instruction above the column mapping rows in the CSV wizard.
  ///
  /// In fr, this message translates to:
  /// **'Indiquez le nom de la colonne du fichier (ou son numéro, à partir de 0) pour chaque information.'**
  String get csvWizardColumnsHint;

  /// Placeholder inside a column mapping input.
  ///
  /// In fr, this message translates to:
  /// **'Nom ou numéro de colonne'**
  String get csvWizardColumnHint;

  /// Marker beside a canonical field that does not have to be mapped.
  ///
  /// In fr, this message translates to:
  /// **'facultatif'**
  String get csvWizardColumnOptional;

  /// Canonical field name: the date the transaction was booked.
  ///
  /// In fr, this message translates to:
  /// **'Date d\'opération'**
  String get csvColumnBookedDate;

  /// Canonical field name: the value date.
  ///
  /// In fr, this message translates to:
  /// **'Date de valeur'**
  String get csvColumnValueDate;

  /// Canonical field name: the raw description from the bank.
  ///
  /// In fr, this message translates to:
  /// **'Libellé'**
  String get csvColumnDescription;

  /// Canonical field name: the signed amount.
  ///
  /// In fr, this message translates to:
  /// **'Montant'**
  String get csvColumnAmount;

  /// Canonical field name: the debit column, used by the debit/credit layout.
  ///
  /// In fr, this message translates to:
  /// **'Débit'**
  String get csvColumnDebit;

  /// Canonical field name: the credit column, used by the debit/credit layout.
  ///
  /// In fr, this message translates to:
  /// **'Crédit'**
  String get csvColumnCredit;

  /// Section label above the live preview of parsed sample rows.
  ///
  /// In fr, this message translates to:
  /// **'Aperçu'**
  String get csvWizardPreviewTitle;

  /// Placeholder shown before the mapping is complete enough to preview.
  ///
  /// In fr, this message translates to:
  /// **'Renseignez les colonnes obligatoires pour voir un aperçu.'**
  String get csvWizardPreviewPending;

  /// Shown when the preview parsed the file but found no rows.
  ///
  /// In fr, this message translates to:
  /// **'Aucune ligne lisible avec ce paramétrage.'**
  String get csvWizardPreviewEmpty;

  /// Preview table column header for the booked date.
  ///
  /// In fr, this message translates to:
  /// **'Date'**
  String get csvPreviewDateHeader;

  /// Preview table column header for the raw description.
  ///
  /// In fr, this message translates to:
  /// **'Libellé'**
  String get csvPreviewDescriptionHeader;

  /// Preview table column header for the parsed amount.
  ///
  /// In fr, this message translates to:
  /// **'Montant'**
  String get csvPreviewAmountHeader;

  /// Localized message for the backend's ACCOUNT_NOT_FOUND error code on the imports panel.
  ///
  /// In fr, this message translates to:
  /// **'Compte introuvable.'**
  String get importErrorAccountNotFound;

  /// Localized message for the backend's IMPORT_BATCH_NOT_FOUND error code.
  ///
  /// In fr, this message translates to:
  /// **'Import introuvable.'**
  String get importErrorBatchNotFound;

  /// Localized message for the backend's CSV_TEMPLATE_NOT_FOUND error code.
  ///
  /// In fr, this message translates to:
  /// **'Format CSV introuvable — relancez l\'assistant.'**
  String get importErrorTemplateNotFound;

  /// Localized message for the backend's CSV_TEMPLATE_INVALID and VALIDATION_ERROR codes.
  ///
  /// In fr, this message translates to:
  /// **'Ce paramétrage ne correspond pas au fichier — ajustez les colonnes ci-dessus.'**
  String get importErrorTemplateInvalid;

  /// Fallback localized message for unrecognized or network errors on the imports panel.
  ///
  /// In fr, this message translates to:
  /// **'Une erreur est survenue. Veuillez réessayer.'**
  String get importErrorGeneric;

  /// Placeholder in the transactions search pill in the top bar.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher une description ou un marchand…'**
  String get transactionsSearchHint;

  /// Shown in place of the transaction list when the filters/search match nothing.
  ///
  /// In fr, this message translates to:
  /// **'Aucune transaction ne correspond à votre recherche.'**
  String get transactionsSearchEmpty;

  /// Retry button label shown when the transaction list fails to load.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get transactionsRetry;

  /// Heading shown when the user has no transactions at all yet.
  ///
  /// In fr, this message translates to:
  /// **'Aucune transaction pour l\'instant'**
  String get transactionsEmptyTitle;

  /// Encouraging subtext under the empty-state heading on the transactions screen.
  ///
  /// In fr, this message translates to:
  /// **'Importez un relevé pour voir vos opérations apparaître ici.'**
  String get transactionsEmptyBody;

  /// CTA on the transactions empty state, navigating to the imports panel.
  ///
  /// In fr, this message translates to:
  /// **'Aller aux imports'**
  String get transactionsGoToImports;

  /// Label beside the filter bar's needs-review toggle.
  ///
  /// In fr, this message translates to:
  /// **'À vérifier'**
  String get transactionsNeedsReviewLabel;

  /// Default option in the account filter pill, meaning no account filter is applied.
  ///
  /// In fr, this message translates to:
  /// **'Tous les comptes'**
  String get transactionsFilterAllAccounts;

  /// Default option in the category filter pill, meaning no category filter is applied.
  ///
  /// In fr, this message translates to:
  /// **'Toutes les catégories'**
  String get transactionsFilterAllCategories;

  /// Default label on the date range filter pill when no range is chosen.
  ///
  /// In fr, this message translates to:
  /// **'Toutes les dates'**
  String get transactionsFilterAllDates;

  /// Pager label under the transaction list, showing the current page's row range and the total count.
  ///
  /// In fr, this message translates to:
  /// **'{from}–{to} sur {total}'**
  String transactionsPager(int from, int to, int total);

  /// Shown in place of the review queue list when it is empty.
  ///
  /// In fr, this message translates to:
  /// **'Aucune transaction à vérifier.'**
  String get reviewQueueEmpty;

  /// Headline on the review queue's progress card, counting the transactions still needing review.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucune transaction à vérifier} =1{1 transaction à vérifier} other{{count} transactions à vérifier}}'**
  String reviewQueueCount(int count);

  /// Encouraging subtext under the review queue's progress headline — framed as progress, not a backlog.
  ///
  /// In fr, this message translates to:
  /// **'Vous y êtes presque, continuez !'**
  String get reviewQueueEncouragement;

  /// Affordance on a review queue row that, alongside picking a category, creates a matching categorization rule.
  ///
  /// In fr, this message translates to:
  /// **'Toujours catégoriser ainsi'**
  String get reviewAlwaysCategorize;

  /// Placeholder in the category picker popover's search field.
  ///
  /// In fr, this message translates to:
  /// **'Changer de catégorie…'**
  String get categoryPickerSearchHint;

  /// Shown inside the category picker popover when the category list fails to load.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger les catégories.'**
  String get categoryPickerLoadError;

  /// Shown inside the category picker popover when the search filters out every category.
  ///
  /// In fr, this message translates to:
  /// **'Aucune catégorie ne correspond.'**
  String get categoryPickerEmpty;

  /// Label on the dashed category chip for a transaction with no category yet.
  ///
  /// In fr, this message translates to:
  /// **'Non catégorisé'**
  String get categoryUncategorized;

  /// Localized message for the backend's TRANSACTION_NOT_FOUND error code.
  ///
  /// In fr, this message translates to:
  /// **'Transaction introuvable.'**
  String get transactionErrorNotFound;

  /// Localized message for the backend's VALIDATION_ERROR error code on the transactions panel.
  ///
  /// In fr, this message translates to:
  /// **'Certaines informations sont invalides.'**
  String get transactionErrorValidation;

  /// Fallback localized message for unrecognized or network errors on the transactions panel.
  ///
  /// In fr, this message translates to:
  /// **'Une erreur est survenue. Veuillez réessayer.'**
  String get transactionErrorGeneric;

  /// Display name for the system category with i18n key category.housing.
  ///
  /// In fr, this message translates to:
  /// **'Logement'**
  String get categorySystemHousing;

  /// Display name for the system category with i18n key category.housing.rent.
  ///
  /// In fr, this message translates to:
  /// **'Loyer'**
  String get categorySystemHousingRent;

  /// Display name for the system category with i18n key category.housing.mortgage.
  ///
  /// In fr, this message translates to:
  /// **'Prêt immobilier'**
  String get categorySystemHousingMortgage;

  /// Display name for the system category with i18n key category.housing.utilities.
  ///
  /// In fr, this message translates to:
  /// **'Charges'**
  String get categorySystemHousingUtilities;

  /// Display name for the system category with i18n key category.housing.home_insurance.
  ///
  /// In fr, this message translates to:
  /// **'Assurance habitation'**
  String get categorySystemHousingHomeInsurance;

  /// Display name for the system category with i18n key category.food.
  ///
  /// In fr, this message translates to:
  /// **'Alimentation'**
  String get categorySystemFood;

  /// Display name for the system category with i18n key category.food.groceries.
  ///
  /// In fr, this message translates to:
  /// **'Courses'**
  String get categorySystemFoodGroceries;

  /// Display name for the system category with i18n key category.food.restaurants.
  ///
  /// In fr, this message translates to:
  /// **'Restaurants'**
  String get categorySystemFoodRestaurants;

  /// Display name for the system category with i18n key category.food.coffee.
  ///
  /// In fr, this message translates to:
  /// **'Café'**
  String get categorySystemFoodCoffee;

  /// Display name for the system category with i18n key category.transport.
  ///
  /// In fr, this message translates to:
  /// **'Transport'**
  String get categorySystemTransport;

  /// Display name for the system category with i18n key category.transport.fuel.
  ///
  /// In fr, this message translates to:
  /// **'Carburant'**
  String get categorySystemTransportFuel;

  /// Display name for the system category with i18n key category.transport.public_transit.
  ///
  /// In fr, this message translates to:
  /// **'Transports en commun'**
  String get categorySystemTransportPublicTransit;

  /// Display name for the system category with i18n key category.transport.parking.
  ///
  /// In fr, this message translates to:
  /// **'Stationnement'**
  String get categorySystemTransportParking;

  /// Display name for the system category with i18n key category.transport.car_maintenance.
  ///
  /// In fr, this message translates to:
  /// **'Entretien auto'**
  String get categorySystemTransportCarMaintenance;

  /// Display name for the system category with i18n key category.health.
  ///
  /// In fr, this message translates to:
  /// **'Santé'**
  String get categorySystemHealth;

  /// Display name for the system category with i18n key category.health.doctor.
  ///
  /// In fr, this message translates to:
  /// **'Médecin'**
  String get categorySystemHealthDoctor;

  /// Display name for the system category with i18n key category.health.pharmacy.
  ///
  /// In fr, this message translates to:
  /// **'Pharmacie'**
  String get categorySystemHealthPharmacy;

  /// Display name for the system category with i18n key category.health.insurance.
  ///
  /// In fr, this message translates to:
  /// **'Mutuelle'**
  String get categorySystemHealthInsurance;

  /// Display name for the system category with i18n key category.leisure.
  ///
  /// In fr, this message translates to:
  /// **'Loisirs'**
  String get categorySystemLeisure;

  /// Display name for the system category with i18n key category.leisure.outings.
  ///
  /// In fr, this message translates to:
  /// **'Sorties'**
  String get categorySystemLeisureOutings;

  /// Display name for the system category with i18n key category.leisure.travel.
  ///
  /// In fr, this message translates to:
  /// **'Voyages'**
  String get categorySystemLeisureTravel;

  /// Display name for the system category with i18n key category.subscriptions — a top-level category (not a child of Loisirs), pinned to its own design-system hue.
  ///
  /// In fr, this message translates to:
  /// **'Abonnements'**
  String get categorySystemSubscriptions;

  /// Display name for the system category with i18n key category.shopping.
  ///
  /// In fr, this message translates to:
  /// **'Achats'**
  String get categorySystemShopping;

  /// Display name for the system category with i18n key category.shopping.clothing.
  ///
  /// In fr, this message translates to:
  /// **'Vêtements'**
  String get categorySystemShoppingClothing;

  /// Display name for the system category with i18n key category.shopping.electronics.
  ///
  /// In fr, this message translates to:
  /// **'Électronique'**
  String get categorySystemShoppingElectronics;

  /// Display name for the system category with i18n key category.shopping.home.
  ///
  /// In fr, this message translates to:
  /// **'Maison'**
  String get categorySystemShoppingHome;

  /// Display name for the system category with i18n key category.finance.
  ///
  /// In fr, this message translates to:
  /// **'Finances'**
  String get categorySystemFinance;

  /// Display name for the system category with i18n key category.finance.bank_fees.
  ///
  /// In fr, this message translates to:
  /// **'Frais bancaires'**
  String get categorySystemFinanceBankFees;

  /// Display name for the system category with i18n key category.finance.taxes.
  ///
  /// In fr, this message translates to:
  /// **'Impôts'**
  String get categorySystemFinanceTaxes;

  /// Display name for the system category with i18n key category.finance.savings.
  ///
  /// In fr, this message translates to:
  /// **'Épargne'**
  String get categorySystemFinanceSavings;

  /// Display name for the system category with i18n key category.finance.interest.
  ///
  /// In fr, this message translates to:
  /// **'Intérêts'**
  String get categorySystemFinanceInterest;

  /// Display name for the system category with i18n key category.income.
  ///
  /// In fr, this message translates to:
  /// **'Revenus'**
  String get categorySystemIncome;

  /// Display name for the system category with i18n key category.income.salary.
  ///
  /// In fr, this message translates to:
  /// **'Salaire'**
  String get categorySystemIncomeSalary;

  /// Display name for the system category with i18n key category.income.refunds.
  ///
  /// In fr, this message translates to:
  /// **'Remboursements'**
  String get categorySystemIncomeRefunds;

  /// Display name for the system category with i18n key category.income.other.
  ///
  /// In fr, this message translates to:
  /// **'Autres revenus'**
  String get categorySystemIncomeOther;

  /// Display name for the system category with i18n key category.other.
  ///
  /// In fr, this message translates to:
  /// **'Divers'**
  String get categorySystemOther;

  /// Display name for the system category with i18n key category.other.uncategorized.
  ///
  /// In fr, this message translates to:
  /// **'Non catégorisé'**
  String get categorySystemOtherUncategorized;

  /// Label on the income stat card.
  ///
  /// In fr, this message translates to:
  /// **'Revenus'**
  String get dashboardStatIncome;

  /// Label on the expense stat card.
  ///
  /// In fr, this message translates to:
  /// **'Dépenses'**
  String get dashboardStatExpense;

  /// Label on the net (income minus expense) stat card.
  ///
  /// In fr, this message translates to:
  /// **'Net'**
  String get dashboardStatNet;

  /// Label on the savings rate hero card.
  ///
  /// In fr, this message translates to:
  /// **'Taux d\'épargne'**
  String get dashboardStatSavingsRate;

  /// Title of the by-category expense breakdown chart card.
  ///
  /// In fr, this message translates to:
  /// **'Dépenses par catégorie'**
  String get dashboardCategoryBreakdownTitle;

  /// Encouraging heading shown when the user has no transactions yet for any month.
  ///
  /// In fr, this message translates to:
  /// **'Importez un relevé pour donner vie à votre argent'**
  String get dashboardEmptyTitle;

  /// Encouraging subtext under the dashboard empty-state heading.
  ///
  /// In fr, this message translates to:
  /// **'Vos revenus, vos dépenses et votre taux d\'épargne apparaîtront ici dès votre premier import.'**
  String get dashboardEmptyBody;

  /// CTA on the dashboard empty state, navigating to the imports panel.
  ///
  /// In fr, this message translates to:
  /// **'Aller aux imports'**
  String get dashboardGoToImports;

  /// Retry button label shown when the dashboard summary fails to load.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get dashboardRetry;

  /// Localized message for the backend's DASHBOARD_MONTH_INVALID error code.
  ///
  /// In fr, this message translates to:
  /// **'Le mois demandé n\'est pas valide.'**
  String get dashboardErrorInvalidMonth;

  /// Fallback localized message for unrecognized or network errors on the dashboard.
  ///
  /// In fr, this message translates to:
  /// **'Une erreur est survenue. Veuillez réessayer.'**
  String get dashboardErrorGeneric;
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
