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
  /// **'Relevés OFX et QFX — traités sur cet ordinateur'**
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

  /// Timestamp under the summary meta saying when the balances were last recalculated.
  ///
  /// In fr, this message translates to:
  /// **'Soldes au {date}'**
  String accountsBalancesAsOf(DateTime date);

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

  /// Label for the balance field when creating an account from a statement that dates its declared balance (OFX DTASOF): names the day the figure belongs to rather than calling it the current balance.
  ///
  /// In fr, this message translates to:
  /// **'Solde au {date}'**
  String accountBalanceAsOfLabel(DateTime date);

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

  /// Label for the account picker shown only when a statement could not name its own destination.
  ///
  /// In fr, this message translates to:
  /// **'Compte de destination'**
  String get importAccountLabel;

  /// Shown when the accounts list failed to load, so the statement cannot be matched against anything.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger vos comptes. Réessayez dans un instant.'**
  String get importAccountsUnavailable;

  /// Headline inside the imports drop zone.
  ///
  /// In fr, this message translates to:
  /// **'Déposez un fichier OFX ou QFX'**
  String get importDropZoneTitle;

  /// Sub-line inside the imports drop zone, stating that the file itself names the destination account.
  ///
  /// In fr, this message translates to:
  /// **'ou cliquez pour parcourir — le relevé indique lui-même son compte'**
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

  /// Placeholder option in the account picker shown when a statement could not name its own destination — the unanswered state.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez un compte'**
  String get importChooseAccount;

  /// Warning shown when the staged file declares no account block at all, so the user has to pick the destination from every account.
  ///
  /// In fr, this message translates to:
  /// **'Ce fichier n\'indique aucun compte — choisissez la destination.'**
  String get importUnreadableAccount;

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

  /// Title of the transactions date range filter modal.
  ///
  /// In fr, this message translates to:
  /// **'Période'**
  String get transactionsDateRangeTitle;

  /// Label of the range's start date field.
  ///
  /// In fr, this message translates to:
  /// **'Du'**
  String get transactionsDateRangeFromLabel;

  /// Label of the range's end date field.
  ///
  /// In fr, this message translates to:
  /// **'Au'**
  String get transactionsDateRangeToLabel;

  /// Helper under the range fields explaining how to lift the date filter.
  ///
  /// In fr, this message translates to:
  /// **'Laissez les deux dates vides pour voir toutes les dates.'**
  String get transactionsDateRangeHelp;

  /// Tooltip on the calendar button of the range's start date field.
  ///
  /// In fr, this message translates to:
  /// **'Choisir la date de début'**
  String get transactionsDateRangePickFrom;

  /// Tooltip on the calendar button of the range's end date field.
  ///
  /// In fr, this message translates to:
  /// **'Choisir la date de fin'**
  String get transactionsDateRangePickTo;

  /// Validation message when a range date cannot be read in the current locale.
  ///
  /// In fr, this message translates to:
  /// **'Date invalide.'**
  String get transactionsDateRangeInvalid;

  /// Validation message when only one of the two range dates is filled in.
  ///
  /// In fr, this message translates to:
  /// **'Renseignez les deux dates, ou aucune.'**
  String get transactionsDateRangeIncomplete;

  /// Validation message when the range's end date is before its start date.
  ///
  /// In fr, this message translates to:
  /// **'La date de fin précède la date de début.'**
  String get transactionsDateRangeOrder;

  /// Cancel button of the date range modal.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get transactionsDateRangeCancel;

  /// Confirm button of the date range modal, applying the chosen range.
  ///
  /// In fr, this message translates to:
  /// **'Appliquer'**
  String get transactionsDateRangeApply;

  /// Pager label under the transaction list, showing the current page's row range and the total count.
  ///
  /// In fr, this message translates to:
  /// **'{from}–{to} sur {total}'**
  String transactionsPager(int from, int to, int total);

  /// Secondary line of a transaction row when the bank shipped a memo: the memo first, then the account it belongs to.
  ///
  /// In fr, this message translates to:
  /// **'{memo} · {account}'**
  String transactionRowMemoAndAccount(String memo, String account);

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

  /// Localized message for the backend's CATEGORY_INVALID error code, returned when a transaction is patched with a category the user cannot assign — usually one deleted in another window.
  ///
  /// In fr, this message translates to:
  /// **'Cette catégorie n\'est plus disponible.'**
  String get transactionErrorCategoryInvalid;

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

  /// Display name for the system category with i18n key category.income.pension.
  ///
  /// In fr, this message translates to:
  /// **'Retraite'**
  String get categorySystemIncomePension;

  /// Display name for the system category with i18n key category.income.dividends.
  ///
  /// In fr, this message translates to:
  /// **'Dividendes'**
  String get categorySystemIncomeDividends;

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
  /// **'Revenus (mois)'**
  String get dashboardStatIncome;

  /// Label on the expense stat card.
  ///
  /// In fr, this message translates to:
  /// **'Dépenses (mois)'**
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

  /// Caption beside the income and expense trend pills, naming the month compared against. French renders the month lowercase (« vs avril »), English capitalized ("vs April").
  ///
  /// In fr, this message translates to:
  /// **'vs {month}'**
  String dashboardStatVsPreviousMonth(DateTime month);

  /// Caption beside the net card's trend pill, restating how net is derived. The minus is U+2212, matching the money rule.
  ///
  /// In fr, this message translates to:
  /// **'revenus − dépenses'**
  String get dashboardStatNetCaption;

  /// The savings-rate trend pill. A change in a rate is measured in percentage *points*, not percent, so the unit differs from the other three cards.
  ///
  /// In fr, this message translates to:
  /// **'{delta} pt'**
  String dashboardSavingsDeltaPoints(String delta);

  /// Caption on the savings rate card when the rate meets or beats the goal.
  ///
  /// In fr, this message translates to:
  /// **'Objectif : {goal} · atteint'**
  String dashboardSavingsGoalReached(String goal);

  /// Caption on the savings rate card when the rate is still below the goal. Phrased as progress rather than shortfall — the panel leads with encouragement.
  ///
  /// In fr, this message translates to:
  /// **'Objectif : {goal} · en cours'**
  String dashboardSavingsGoalPending(String goal);

  /// Title of the by-category expense breakdown chart card.
  ///
  /// In fr, this message translates to:
  /// **'Dépenses par catégorie'**
  String get dashboardCategoryBreakdownTitle;

  /// Subtitle under the breakdown chart's title: the month it covers and how many categories it splits into.
  ///
  /// In fr, this message translates to:
  /// **'{month} · {count, plural, =1{1 catégorie} other{{count} catégories}}'**
  String dashboardCategoryBreakdownSubtitle(String month, int count);

  /// Caption under the total in the middle of the category donut.
  ///
  /// In fr, this message translates to:
  /// **'dépensés'**
  String get dashboardDonutCenterCaption;

  /// Title of the cumulative savings area chart.
  ///
  /// In fr, this message translates to:
  /// **'Évolution de l\'épargne'**
  String get dashboardSavingsTrendTitle;

  /// Subtitle of the cumulative savings chart, naming the window it covers.
  ///
  /// In fr, this message translates to:
  /// **'Épargne cumulée · {count} mois'**
  String dashboardSavingsTrendSubtitle(int count);

  /// The savings chart's header delta — how much the latest month added, e.g. « +635,65 € en mai ».
  ///
  /// In fr, this message translates to:
  /// **'{amount} en {month}'**
  String dashboardSavingsTrendDelta(String amount, String month);

  /// Title of the stacked income-vs-expense bar chart.
  ///
  /// In fr, this message translates to:
  /// **'Revenus vs dépenses'**
  String get dashboardIncomeVsExpenseTitle;

  /// Subtitle of the income-vs-expense chart, naming the window it covers.
  ///
  /// In fr, this message translates to:
  /// **'{count} derniers mois'**
  String dashboardIncomeVsExpenseSubtitle(int count);

  /// Green dot legend in the income-vs-expense chart header.
  ///
  /// In fr, this message translates to:
  /// **'Revenus'**
  String get dashboardLegendIncome;

  /// Red dot legend in the income-vs-expense chart header.
  ///
  /// In fr, this message translates to:
  /// **'Dépenses'**
  String get dashboardLegendExpense;

  /// Title of the recent-transactions card.
  ///
  /// In fr, this message translates to:
  /// **'Activité récente'**
  String get dashboardRecentActivityTitle;

  /// Iris link under the recent-activity list, navigating to the transactions panel.
  ///
  /// In fr, this message translates to:
  /// **'Voir toutes les transactions'**
  String get dashboardViewAllTransactions;

  /// Shown in the recent-activity card when the user has no transactions yet.
  ///
  /// In fr, this message translates to:
  /// **'Vos transactions apparaîtront ici.'**
  String get dashboardRecentActivityEmpty;

  /// Encouraging heading shown when the user has no transactions yet for any month.
  ///
  /// In fr, this message translates to:
  /// **'Importez un relevé pour donner vie à votre argent'**
  String get dashboardEmptyTitle;

  /// Reassurance under the dashboard empty-state heading. Leads with privacy rather than with what the panel will contain: the user has just been asked to hand over a bank statement, and that is the doubt worth answering first.
  ///
  /// In fr, this message translates to:
  /// **'Tout reste sur cet ordinateur — rien n\'est envoyé en ligne.'**
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

  /// Tooltip on the top bar's month label, which opens a month-and-year picker.
  ///
  /// In fr, this message translates to:
  /// **'Choisir un mois'**
  String get dashboardChooseMonth;

  /// Tooltip on the picker's back-a-year step button.
  ///
  /// In fr, this message translates to:
  /// **'Année précédente'**
  String get dashboardPreviousYear;

  /// Tooltip on the picker's forward-a-year step button.
  ///
  /// In fr, this message translates to:
  /// **'Année suivante'**
  String get dashboardNextYear;

  /// Top-bar primary button on the categories panel, opening the create-category modal.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle catégorie'**
  String get categoriesAddButton;

  /// Heading of the categories empty state.
  ///
  /// In fr, this message translates to:
  /// **'Aucune catégorie pour l\'instant'**
  String get categoriesEmptyTitle;

  /// Reassuring line under the categories empty-state heading.
  ///
  /// In fr, this message translates to:
  /// **'Les catégories classent vos dépenses. Créez-en une pour commencer.'**
  String get categoriesEmptyBody;

  /// Retry button shown when the category catalog fails to load.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get categoriesRetry;

  /// Neutral badge on a seeded, read-only category card.
  ///
  /// In fr, this message translates to:
  /// **'Système'**
  String get categoryBadgeSystem;

  /// Iris-tinted badge on a category the user created.
  ///
  /// In fr, this message translates to:
  /// **'Personnalisée'**
  String get categoryBadgeCustom;

  /// Tooltip on the lock glyph of a system category card. States the refusal the API also enforces.
  ///
  /// In fr, this message translates to:
  /// **'Catégorie du système : elle ne peut pas être modifiée ni supprimée.'**
  String get categorySystemLockedTooltip;

  /// Tooltip on the ⋯ menu of a user category card.
  ///
  /// In fr, this message translates to:
  /// **'Actions'**
  String get categoryActionsTooltip;

  /// ⋯ menu entry opening the edit modal (name, icon, color) of a user category.
  ///
  /// In fr, this message translates to:
  /// **'Modifier'**
  String get categoryEdit;

  /// ⋯ menu entry and edit-modal action deleting a user category, and label of the delete confirmation button.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get categoryDelete;

  /// Dashed ghost chip at the end of a category card's subcategories, drawn after a plus glyph. Opens the create modal with this category preset as the parent.
  ///
  /// In fr, this message translates to:
  /// **'Sous-catégorie'**
  String get categoryAddSubcategory;

  /// Footer of a category card: how many rules target this category or its subcategories, disabled ones included. The zero case is drawn in amber.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucune règle} one{1 règle automatique} other{{count} règles automatiques}}'**
  String categoryRuleCount(int count);

  /// Title of the delete-category confirmation dialog.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer cette catégorie ?'**
  String get categoryDeleteConfirmTitle;

  /// Body of the delete-category confirmation. Names what else goes with it, since the deletion cascades.
  ///
  /// In fr, this message translates to:
  /// **'« {name} » et ses sous-catégories seront supprimées. Les transactions concernées redeviendront non catégorisées.'**
  String categoryDeleteConfirmBody(String name);

  /// Title of the create-category modal.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle catégorie'**
  String get categoryFormCreateTitle;

  /// Title of the edit-category modal.
  ///
  /// In fr, this message translates to:
  /// **'Modifier la catégorie'**
  String get categoryFormEditTitle;

  /// Label of the category name field.
  ///
  /// In fr, this message translates to:
  /// **'Nom'**
  String get categoryFormNameLabel;

  /// Placeholder example in the category name field.
  ///
  /// In fr, this message translates to:
  /// **'Épargne projet'**
  String get categoryFormNameHint;

  /// Validation message when the category name is left empty.
  ///
  /// In fr, this message translates to:
  /// **'Donnez un nom à cette catégorie.'**
  String get categoryFormNameRequired;

  /// Label of the category kind select.
  ///
  /// In fr, this message translates to:
  /// **'Type'**
  String get categoryFormKindLabel;

  /// Helper under the category kind select, explaining the three kinds in the user's own terms.
  ///
  /// In fr, this message translates to:
  /// **'Une dépense sort de vos comptes, un revenu y entre, un transfert circule entre eux.'**
  String get categoryFormKindHelper;

  /// Label of the parent-category select.
  ///
  /// In fr, this message translates to:
  /// **'Catégorie parente'**
  String get categoryFormParentLabel;

  /// Option in the parent select for a top-level category.
  ///
  /// In fr, this message translates to:
  /// **'Aucune (catégorie principale)'**
  String get categoryFormParentNone;

  /// Label of the category icon select.
  ///
  /// In fr, this message translates to:
  /// **'Icône'**
  String get categoryFormIconLabel;

  /// Label of the category colour picker.
  ///
  /// In fr, this message translates to:
  /// **'Couleur'**
  String get categoryFormColorLabel;

  /// Helper under the colour picker, explaining that the hue is reused across the app.
  ///
  /// In fr, this message translates to:
  /// **'La couleur suit la catégorie partout : graphiques, légendes et étiquettes.'**
  String get categoryFormColorHelper;

  /// Cancel button in the category modal and the delete confirmation.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get categoryFormCancel;

  /// Submit button of the category modal.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get categoryFormSave;

  /// Category kind: money leaving the user's accounts.
  ///
  /// In fr, this message translates to:
  /// **'Dépense'**
  String get categoryKindExpense;

  /// Category kind: money arriving in the user's accounts.
  ///
  /// In fr, this message translates to:
  /// **'Revenu'**
  String get categoryKindIncome;

  /// Category kind: money moving between the user's own accounts.
  ///
  /// In fr, this message translates to:
  /// **'Transfert'**
  String get categoryKindTransfer;

  /// Icon choice in the category form: house glyph.
  ///
  /// In fr, this message translates to:
  /// **'Logement'**
  String get categoryIconHousing;

  /// Icon choice in the category form: bowl glyph.
  ///
  /// In fr, this message translates to:
  /// **'Alimentation'**
  String get categoryIconFood;

  /// Icon choice in the category form: car glyph.
  ///
  /// In fr, this message translates to:
  /// **'Transport'**
  String get categoryIconTransport;

  /// Icon choice in the category form: star glyph.
  ///
  /// In fr, this message translates to:
  /// **'Loisirs'**
  String get categoryIconLeisure;

  /// Icon choice in the category form: refresh glyph.
  ///
  /// In fr, this message translates to:
  /// **'Abonnements'**
  String get categoryIconSubscriptions;

  /// Icon choice in the category form: cross glyph.
  ///
  /// In fr, this message translates to:
  /// **'Santé'**
  String get categoryIconHealth;

  /// Icon choice in the category form: up-arrow glyph.
  ///
  /// In fr, this message translates to:
  /// **'Revenus'**
  String get categoryIconIncome;

  /// Icon choice in the category form: coin glyph.
  ///
  /// In fr, this message translates to:
  /// **'Épargne'**
  String get categoryIconSavings;

  /// Icon choice in the category form: the neutral fallback glyph.
  ///
  /// In fr, this message translates to:
  /// **'Autre'**
  String get categoryIconOther;

  /// Localized message for the backend's CATEGORY_NOT_FOUND code, which is also what a forced edit of a system category returns.
  ///
  /// In fr, this message translates to:
  /// **'Cette catégorie appartient au système : elle ne peut pas être modifiée ni supprimée.'**
  String get categoryErrorNotEditable;

  /// Localized message for a VALIDATION_ERROR on a category write.
  ///
  /// In fr, this message translates to:
  /// **'Ces informations ne sont pas valides. Vérifiez le nom et le type.'**
  String get categoryErrorValidation;

  /// Fallback message for unrecognized or network errors on the categories panel.
  ///
  /// In fr, this message translates to:
  /// **'Une erreur est survenue. Veuillez réessayer.'**
  String get categoryErrorGeneric;

  /// Left segment of the panel's view switch.
  ///
  /// In fr, this message translates to:
  /// **'Catégories'**
  String get categoriesTabCategories;

  /// Right segment of the panel's view switch.
  ///
  /// In fr, this message translates to:
  /// **'Règles'**
  String get categoriesTabRules;

  /// Top-bar primary button while the rules view is showing.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle règle'**
  String get rulesAddButton;

  /// Note beside the view switch on the rules view, stating both how rules are ordered and what they will never overwrite.
  ///
  /// In fr, this message translates to:
  /// **'Évaluées dans l\'ordre de priorité — une règle ne remplace jamais une catégorie choisie manuellement.'**
  String get rulesPriorityNote;

  /// Secondary action re-running the rules over existing transactions.
  ///
  /// In fr, this message translates to:
  /// **'Exécuter les règles'**
  String get rulesApplyButton;

  /// Label of the run action while the run is in flight.
  ///
  /// In fr, this message translates to:
  /// **'Exécution…'**
  String get rulesApplyRunning;

  /// First line of the toast after a rule run: how many transactions changed category.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucune transaction recatégorisée} one{{count} transaction recatégorisée} other{{count} transactions recatégorisées}}'**
  String rulesApplyToastTitle(int count);

  /// Second line of the rule-run toast. Answers the question the count alone raises.
  ///
  /// In fr, this message translates to:
  /// **'Vos catégories choisies manuellement n\'ont pas été modifiées.'**
  String get rulesApplyToastBody;

  /// Toast headline when the rule run itself failed.
  ///
  /// In fr, this message translates to:
  /// **'L\'exécution des règles a échoué'**
  String get rulesApplyFailed;

  /// Toast headline when persisting a drag-reorder failed and the previous order was restored.
  ///
  /// In fr, this message translates to:
  /// **'L\'ordre n\'a pas pu être enregistré'**
  String get rulesReorderFailed;

  /// Toast headline when enabling or disabling a rule failed and the switch was put back.
  ///
  /// In fr, this message translates to:
  /// **'La règle n\'a pas pu être modifiée'**
  String get rulesToggleFailed;

  /// Tooltip on the ✕ beside the category filter chip in the rules view, opened from a category card's footer.
  ///
  /// In fr, this message translates to:
  /// **'Afficher toutes les règles'**
  String get rulesFilterClear;

  /// Shown inside the rules card when the category filter leaves no rule.
  ///
  /// In fr, this message translates to:
  /// **'Aucune règle ne cible cette catégorie.'**
  String get rulesFilterEmpty;

  /// Retry button shown when the rules list fails to load.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get rulesRetry;

  /// Heading of the rules empty state.
  ///
  /// In fr, this message translates to:
  /// **'Automatisez votre classement'**
  String get rulesEmptyTitle;

  /// Body of the rules empty state, explaining what a rule does before asking the user to write one.
  ///
  /// In fr, this message translates to:
  /// **'Une règle reconnaît un libellé — « CARREFOUR » — et attribue sa catégorie à chaque transaction correspondante, aujourd\'hui et aux prochains imports.'**
  String get rulesEmptyBody;

  /// Accessible label of the enable switch on a rule row.
  ///
  /// In fr, this message translates to:
  /// **'Activer la règle'**
  String get ruleToggleSemantics;

  /// Chip shown when a rule points at a category that no longer exists.
  ///
  /// In fr, this message translates to:
  /// **'Catégorie introuvable'**
  String get ruleTargetMissing;

  /// Rule match field: the cleaned transaction description.
  ///
  /// In fr, this message translates to:
  /// **'Libellé'**
  String get ruleFieldDescription;

  /// Rule match field: the extracted merchant name.
  ///
  /// In fr, this message translates to:
  /// **'Commerçant'**
  String get ruleFieldMerchant;

  /// Rule match field: the transaction amount.
  ///
  /// In fr, this message translates to:
  /// **'Montant'**
  String get ruleFieldAmount;

  /// Rule condition badge: substring match.
  ///
  /// In fr, this message translates to:
  /// **'contient'**
  String get ruleConditionContains;

  /// Rule condition badge: exact match.
  ///
  /// In fr, this message translates to:
  /// **'égal à'**
  String get ruleConditionEquals;

  /// Rule condition badge: regular expression match.
  ///
  /// In fr, this message translates to:
  /// **'regex'**
  String get ruleConditionRegex;

  /// Rule condition badge: amount range match.
  ///
  /// In fr, this message translates to:
  /// **'plage'**
  String get ruleConditionRange;

  /// Title of the rule editor when creating.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle règle'**
  String get ruleFormCreateTitle;

  /// Title of the rule editor when editing.
  ///
  /// In fr, this message translates to:
  /// **'Modifier la règle'**
  String get ruleFormEditTitle;

  /// Label of the rule editor's match-field select.
  ///
  /// In fr, this message translates to:
  /// **'Champ'**
  String get ruleFormFieldLabel;

  /// Label of the rule editor's condition select.
  ///
  /// In fr, this message translates to:
  /// **'Condition'**
  String get ruleFormConditionLabel;

  /// Label of the rule editor's priority field. Lower runs first.
  ///
  /// In fr, this message translates to:
  /// **'Priorité'**
  String get ruleFormPriorityLabel;

  /// Validation message for a missing or non-positive priority.
  ///
  /// In fr, this message translates to:
  /// **'Indiquez une priorité d\'au moins 1.'**
  String get ruleFormPriorityInvalid;

  /// Label of the rule editor's pattern field.
  ///
  /// In fr, this message translates to:
  /// **'Motif'**
  String get ruleFormPatternLabel;

  /// Validation message when the pattern is left empty.
  ///
  /// In fr, this message translates to:
  /// **'Indiquez ce que la règle doit reconnaître.'**
  String get ruleFormPatternRequired;

  /// Helper under the pattern field for the contains and equals conditions.
  ///
  /// In fr, this message translates to:
  /// **'Recherche insensible à la casse dans le champ choisi.'**
  String get rulePatternHelperText;

  /// Helper under the pattern field for the regex condition.
  ///
  /// In fr, this message translates to:
  /// **'Expression régulière, sensible à la casse. Testée en direct ci-dessous.'**
  String get rulePatternHelperRegex;

  /// Helper under the pattern field for the range condition. Names the unit and the sign, both of which the user cannot guess.
  ///
  /// In fr, this message translates to:
  /// **'Plage de montants en centimes, « min:max ». Laissez un côté vide pour une borne ouverte ; les dépenses sont négatives.'**
  String get rulePatternHelperRange;

  /// Placeholder example in the pattern field for a text condition.
  ///
  /// In fr, this message translates to:
  /// **'CARREFOUR'**
  String get rulePatternHintText;

  /// Placeholder example in the pattern field for a regex condition.
  ///
  /// In fr, this message translates to:
  /// **'^CB .*CARREFOUR'**
  String get rulePatternHintRegex;

  /// Placeholder example in the pattern field for a range condition.
  ///
  /// In fr, this message translates to:
  /// **'-10000:-5000'**
  String get rulePatternHintRange;

  /// Label of the rule editor's target-category select.
  ///
  /// In fr, this message translates to:
  /// **'Catégorie attribuée'**
  String get ruleFormCategoryLabel;

  /// Empty option of the target-category select.
  ///
  /// In fr, this message translates to:
  /// **'Choisir une catégorie'**
  String get ruleFormCategoryNone;

  /// Error shown when saving a rule with no target category.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez la catégorie que cette règle attribue.'**
  String get ruleFormCategoryRequired;

  /// Label beside the rule editor's enable switch.
  ///
  /// In fr, this message translates to:
  /// **'Règle active'**
  String get ruleFormEnabledLabel;

  /// Cancel button of the rule editor.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get ruleFormCancel;

  /// Submit button of the rule editor.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get ruleFormSave;

  /// Delete action in the rule editor's footer, shown only when editing.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get ruleFormDelete;

  /// Info banner shown while the match preview is in flight.
  ///
  /// In fr, this message translates to:
  /// **'Recherche des transactions correspondantes…'**
  String get rulePreviewLoading;

  /// Match-preview banner when the backend returned no example to quote.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Ne correspond à aucune transaction existante.} one{Correspond à {count} transaction existante.} other{Correspond à {count} transactions existantes.}}'**
  String rulePreviewCount(int count);

  /// Match-preview banner naming one of the matched transactions, so the user can tell whether the rule caught what they meant.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{Correspond à {count} transaction existante — « {sample} » du {date}.} other{Correspond à {count} transactions existantes — dont « {sample} » du {date}.}}'**
  String rulePreviewCountWithSample(int count, String sample, String date);

  /// Localized message for RULE_PATTERN_INVALID. Rendered on the pattern field, never as a match count of zero.
  ///
  /// In fr, this message translates to:
  /// **'Ce motif n\'est pas une expression régulière valide.'**
  String get ruleErrorPatternInvalid;

  /// Localized message for the backend's RULE_NOT_FOUND code.
  ///
  /// In fr, this message translates to:
  /// **'Cette règle n\'existe plus.'**
  String get ruleErrorNotFound;

  /// Localized message when a rule targets a category the backend can no longer resolve.
  ///
  /// In fr, this message translates to:
  /// **'La catégorie visée n\'existe plus.'**
  String get ruleErrorCategoryNotFound;

  /// Localized message for a VALIDATION_ERROR on a rule write.
  ///
  /// In fr, this message translates to:
  /// **'Ces informations ne sont pas valides. Vérifiez le motif et la priorité.'**
  String get ruleErrorValidation;

  /// Fallback message for unrecognized or network errors on the rules view.
  ///
  /// In fr, this message translates to:
  /// **'Une erreur est survenue. Veuillez réessayer.'**
  String get ruleErrorGeneric;

  /// Tooltip on the rules view's pack menu.
  ///
  /// In fr, this message translates to:
  /// **'Importer / Exporter des règles'**
  String get rulePackMenuTooltip;

  /// Pack menu entry opening the file picker.
  ///
  /// In fr, this message translates to:
  /// **'Importer un fichier…'**
  String get rulePackImportFile;

  /// Pack menu entry importing one of the packs bundled with the app.
  ///
  /// In fr, this message translates to:
  /// **'Importer « {name} »'**
  String rulePackImportBuiltin(String name);

  /// Pack menu entry opening the export review sheet.
  ///
  /// In fr, this message translates to:
  /// **'Exporter mes règles…'**
  String get rulePackExportAction;

  /// Cancel button on the pack import and export sheets.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get rulePackCancel;

  /// Button closing the refused-pack explanation.
  ///
  /// In fr, this message translates to:
  /// **'Fermer'**
  String get rulePackClose;

  /// Title of the dialog explaining why a pack was refused.
  ///
  /// In fr, this message translates to:
  /// **'Ce fichier n\'a pas été accepté'**
  String get rulePackRefusedTitle;

  /// Refusal reason: the file isn't a pack-shaped JSON document.
  ///
  /// In fr, this message translates to:
  /// **'Ce fichier n\'est pas un pack de règles FinStride. Attendu : un fichier JSON avec un nom, une version de format et une liste de règles.'**
  String get rulePackRefusedMalformed;

  /// Refusal reason: unsupported format_version. Says why the pack is refused outright rather than read best-effort.
  ///
  /// In fr, this message translates to:
  /// **'Ce pack utilise une version de format que cette version de FinStride ne lit pas. Elle lit la version {version}. Un pack partiellement compris perdrait silencieusement des règles, il est donc refusé en entier.'**
  String rulePackRefusedVersion(int version);

  /// Refusal reason: the pack contains a regex rule. Names the risk, and the three types that are accepted.
  ///
  /// In fr, this message translates to:
  /// **'Ce pack contient une règle « regex ». Les expressions régulières ne sont pas acceptées dans un pack partagé : une expression venue d\'un fichier tiers peut bloquer votre machine. Utilisez « contient », « égal à » ou « plage ».'**
  String get rulePackRefusedRegex;

  /// Headline of the import confirmation. The figure the backend reports covers the user's currently-uncategorized transactions.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Ce pack ne catégoriserait aucune de vos transactions non catégorisées.} one{Ce pack catégoriserait {count} de vos transactions non catégorisées.} other{Ce pack catégoriserait {count} de vos transactions non catégorisées.}}'**
  String rulePackWouldMatch(int count);

  /// Report line: how many rules the pack holds.
  ///
  /// In fr, this message translates to:
  /// **'Règles dans le pack'**
  String get rulePackRuleCount;

  /// Report line: how many would actually be created.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelles règles'**
  String get rulePackNewCount;

  /// Report line: how many are already among the user's rules.
  ///
  /// In fr, this message translates to:
  /// **'Doublons ignorés'**
  String get rulePackDuplicateCount;

  /// Report line: how many rules point at a category this install doesn't have.
  ///
  /// In fr, this message translates to:
  /// **'Catégories introuvables'**
  String get rulePackUnresolvedCount;

  /// Detail under the unresolved count, naming the category keys that could not be resolved.
  ///
  /// In fr, this message translates to:
  /// **'Ces règles seront ignorées : {keys}'**
  String rulePackUnresolvedDetail(String keys);

  /// Section label above the sample transactions in the import report.
  ///
  /// In fr, this message translates to:
  /// **'Exemples de transactions concernées'**
  String get rulePackSamplesLabel;

  /// Label beside the apply-now switch on the import sheet.
  ///
  /// In fr, this message translates to:
  /// **'Appliquer les règles à mes transactions existantes après l\'import'**
  String get rulePackApplyNowLabel;

  /// Confirm button on the import sheet.
  ///
  /// In fr, this message translates to:
  /// **'Importer'**
  String get rulePackImportConfirm;

  /// First line of the toast after a pack import.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucune règle importée} one{{count} règle importée} other{{count} règles importées}}'**
  String rulePackImportedTitle(int count);

  /// Second line of the import toast when the rules were applied straight away.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucune transaction n\'a changé de catégorie.} one{{count} transaction recatégorisée.} other{{count} transactions recatégorisées.}}'**
  String rulePackImportedBody(int count);

  /// Toast headline when a pack import failed.
  ///
  /// In fr, this message translates to:
  /// **'L\'import a échoué'**
  String get rulePackImportFailed;

  /// Title of the export review sheet.
  ///
  /// In fr, this message translates to:
  /// **'Exporter mes règles'**
  String get rulePackExportTitle;

  /// Warning at the top of the export sheet. Names a concrete example, because the abstract warning is the one nobody reads.
  ///
  /// In fr, this message translates to:
  /// **'Relisez avant d\'enregistrer : un motif peut contenir des informations personnelles — le nom de votre propriétaire, « VIR SALAIRE DUPONT ».'**
  String get rulePackExportPrivacyNotice;

  /// Section label above the verbatim pack contents in the export sheet.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Contenu du fichier — aucune règle} one{Contenu du fichier — {count} règle} other{Contenu du fichier — {count} règles}}'**
  String rulePackExportContents(int count);

  /// Section label above the rules an export could not carry.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{{count} règle non exportable} other{{count} règles non exportables}}'**
  String rulePackOmittedLabel(int count);

  /// Explains one omitted rule: it uses a regex, which no importer accepts.
  ///
  /// In fr, this message translates to:
  /// **'« {pattern} » — les règles regex ne peuvent pas figurer dans un pack.'**
  String rulePackOmittedRegex(String pattern);

  /// Explains one omitted rule: it targets a user-defined category, which has no portable key.
  ///
  /// In fr, this message translates to:
  /// **'« {pattern} » — vise une catégorie personnalisée, qui n\'a pas d\'identifiant partageable.'**
  String rulePackOmittedUserCategory(String pattern);

  /// Save button on the export sheet.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get rulePackExportSave;

  /// First line of the toast after an export is written to disk.
  ///
  /// In fr, this message translates to:
  /// **'Pack enregistré'**
  String get rulePackExportedTitle;

  /// Toast headline when preparing or writing an export failed.
  ///
  /// In fr, this message translates to:
  /// **'L\'export a échoué'**
  String get rulePackExportFailed;

  /// CTA on the rules empty state offering the bundled pack, named and sized.
  ///
  /// In fr, this message translates to:
  /// **'Commencer avec « {name} » ({count} règles)'**
  String rulePackStartWith(String name, int count);

  /// Reassurance under the bundled-pack CTA: the preview step always comes first.
  ///
  /// In fr, this message translates to:
  /// **'Vous verrez ce que le pack ferait avant de l\'importer.'**
  String get rulePackStartWithHelper;

  /// Subtext on the review queue's header card when local AI is active, counting the rows it proposed a category for.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucune de ces transactions n\'a reçu de proposition de l\'IA locale — confirmez ou corrigez, rien n\'est classé sans vous.} one{L\'IA locale propose une catégorie pour l\'une d\'entre elles — confirmez ou corrigez, rien n\'est classé sans vous.} other{L\'IA locale propose une catégorie pour {count} d\'entre elles — confirmez ou corrigez, rien n\'est classé sans vous.}}'**
  String reviewQueueAiSubtitle(int count);

  /// Resolved-progress label on the review queue's header card: rows already dealt with, out of the queue's size this session.
  ///
  /// In fr, this message translates to:
  /// **'{resolved}/{total} · {percent}'**
  String reviewQueueProgress(int resolved, int total, double percent);

  /// Calm invitation at the foot of the review queue's header card when AI is off or the runtime is unreachable. The only place in the app that mentions it.
  ///
  /// In fr, this message translates to:
  /// **'Activez l\'IA locale pour classer automatiquement les transactions que vos règles n\'ont pas reconnues.'**
  String get reviewAiInvitation;

  /// Link at the end of the AI invitation, opening the settings panel.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres'**
  String get reviewAiInvitationLink;

  /// Caption beside a proposal's confidence gauge. Always a percentage, never the raw [0,1] value the API returns.
  ///
  /// In fr, this message translates to:
  /// **'Confiance {confidence}'**
  String reviewConfidence(double confidence);

  /// Row action accepting the model's proposed category as-is.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer'**
  String get reviewConfirm;

  /// Row action opening the category picker to replace the model's proposal.
  ///
  /// In fr, this message translates to:
  /// **'Corriger'**
  String get reviewCorrect;

  /// Italic note on a review row the model made no proposal for.
  ///
  /// In fr, this message translates to:
  /// **'— aucune proposition'**
  String get reviewNoProposal;

  /// Link on a review row with no proposal, opening the category picker.
  ///
  /// In fr, this message translates to:
  /// **'Choisir une catégorie'**
  String get reviewChooseCategory;

  /// Subtext under the always-categorize modal's title, naming the transaction the rule was derived from.
  ///
  /// In fr, this message translates to:
  /// **'Une règle classe ces transactions sans IA, à chaque import — pré-remplie depuis « {label} ».'**
  String alwaysRuleSubtitle(String label);

  /// Label of the always-categorize modal's target-category select.
  ///
  /// In fr, this message translates to:
  /// **'Catégorie cible'**
  String get alwaysRuleCategoryLabel;

  /// Checkbox in the always-categorize modal: re-run the new rule over transactions already imported.
  ///
  /// In fr, this message translates to:
  /// **'Appliquer aux transactions existantes'**
  String get alwaysRuleApplyExisting;

  /// Confirm button of the always-categorize modal.
  ///
  /// In fr, this message translates to:
  /// **'Créer la règle'**
  String get alwaysRuleSubmit;

  /// Success toast headline after a rule was created from a correction.
  ///
  /// In fr, this message translates to:
  /// **'Règle créée'**
  String get alwaysRuleCreatedTitle;

  /// Success toast subtext after a rule was created from a correction, counting the other rows it moved.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucune autre transaction n\'a changé de catégorie.} one{{count} transaction recatégorisée.} other{{count} transactions recatégorisées.}}'**
  String alwaysRuleCreatedBody(int count);

  /// Shown in the always-categorize modal when the server-side pre-fill could not be fetched — the form stays usable.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de pré-remplir la règle. Renseignez le motif vous-même.'**
  String get alwaysRuleSuggestionFailed;

  /// Action on the review queue's header card that starts a local-AI categorization run over the pending rows.
  ///
  /// In fr, this message translates to:
  /// **'Catégoriser avec l\'IA'**
  String get reviewQueueRunAction;

  /// Headline of the banner that replaces the review queue's header card while a run is classifying.
  ///
  /// In fr, this message translates to:
  /// **'{total, plural, one{Catégorisation en cours — {processed} sur {total} transaction} other{Catégorisation en cours — {processed} sur {total} transactions}}'**
  String runBannerRunning(int processed, int total);

  /// Sub-line under the running banner: what the run has settled, what it has left for the user, and the reassurance that nothing is blocked.
  ///
  /// In fr, this message translates to:
  /// **'{assigned, plural, one{{assigned} classée · {deferred} à vérifier · le panneau reste utilisable} other{{assigned} classées · {deferred} à vérifier · le panneau reste utilisable}}'**
  String runBannerRunningDetail(int assigned, int deferred);

  /// Cancels the categorization run in flight. The executor stops after the batch it is on.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get runBannerCancel;

  /// Dismissible amber banner after a run that ended `partial`. A report, not an error wall.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{Catégorisation terminée — {count} transaction n\'a pas pu être analysée.} other{Catégorisation terminée — {count} transactions n\'ont pas pu être analysées.}}'**
  String runBannerPartial(int count);

  /// Link on the partial-run banner, showing the transactions the run could not analyse.
  ///
  /// In fr, this message translates to:
  /// **'Voir'**
  String get runBannerPartialAction;

  /// Banner after a run that ended `failed` — reported plainly; the queue stays fully usable.
  ///
  /// In fr, this message translates to:
  /// **'La catégorisation n\'a pas pu s\'exécuter.'**
  String get runBannerFailed;

  /// Accessible label of the × that dismisses a finished-run banner.
  ///
  /// In fr, this message translates to:
  /// **'Fermer'**
  String get runBannerDismiss;

  /// Shown when starting or cancelling a run failed. The queue is unaffected.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de lancer la catégorisation pour le moment.'**
  String get runStartFailed;

  /// Title of the local-AI card in the settings Données tab.
  ///
  /// In fr, this message translates to:
  /// **'IA locale'**
  String get settingsAiTitle;

  /// Sub-line under the card title, naming what the toggle beside it does.
  ///
  /// In fr, this message translates to:
  /// **'Activer la catégorisation par IA'**
  String get settingsAiSubtitle;

  /// Accessible label of the card's opt-in toggle.
  ///
  /// In fr, this message translates to:
  /// **'Catégorisation par IA'**
  String get settingsAiToggleLabel;

  /// The card's privacy callout — its centerpiece. Visible whenever the card is, whether or not AI is enabled.
  ///
  /// In fr, this message translates to:
  /// **'Les descriptions de vos transactions sont envoyées à un modèle qui s\'exécute sur cet ordinateur. Rien ne quitte votre machine.'**
  String get settingsAiPrivacy;

  /// Label of the inference base URL field.
  ///
  /// In fr, this message translates to:
  /// **'Adresse du moteur'**
  String get settingsAiBaseUrlLabel;

  /// Helper under the engine address field, stating the loopback-only rule.
  ///
  /// In fr, this message translates to:
  /// **'Adresse locale uniquement — 127.0.0.1 ou localhost.'**
  String get settingsAiBaseUrlHelp;

  /// Inline validation shown on the address field when the backend refuses a non-loopback URL (422). States why it was refused, not only that it was.
  ///
  /// In fr, this message translates to:
  /// **'Adresse refusée : le moteur doit s\'exécuter sur cet ordinateur (127.0.0.1 ou localhost). Une adresse distante enverrait les descriptions de vos transactions hors de votre machine.'**
  String get settingsAiBaseUrlRejected;

  /// Label of the model tag field.
  ///
  /// In fr, this message translates to:
  /// **'Modèle'**
  String get settingsAiModelLabel;

  /// Helper under the model field: the list comes from the engine, but any tag can be typed.
  ///
  /// In fr, this message translates to:
  /// **'Liste fournie par le moteur — saisie manuelle possible.'**
  String get settingsAiModelHelp;

  /// Helper under the model field when no engine answered, where the field degrades to a dashed read-only dash.
  ///
  /// In fr, this message translates to:
  /// **'Aucun modèle — moteur injoignable.'**
  String get settingsAiModelUnavailable;

  /// Accessible label of the control opening the list of models the engine reported.
  ///
  /// In fr, this message translates to:
  /// **'Choisir un modèle'**
  String get settingsAiModelChoose;

  /// Label above the threshold slider, carrying its live percentage. Only this label is a percentage — the stored value is the [0,1] real the API defines.
  ///
  /// In fr, this message translates to:
  /// **'Seuil de confiance — {threshold}'**
  String settingsAiThresholdLabel(double threshold);

  /// Helper under the threshold slider, stating what the threshold decides.
  ///
  /// In fr, this message translates to:
  /// **'En dessous de ce seuil, la transaction vous est proposée pour vérification plutôt que classée automatiquement.'**
  String get settingsAiThresholdHelp;

  /// Status row when the runtime answered, with the number of models it reported.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Connecté — aucun modèle disponible} =1{Connecté — 1 modèle disponible} other{Connecté — {count} modèles disponibles}}'**
  String settingsAiStatusConnected(int count);

  /// Status row when nothing answered at the configured address.
  ///
  /// In fr, this message translates to:
  /// **'Aucun moteur détecté à cette adresse.'**
  String get settingsAiStatusUnreachable;

  /// Status row while the user has not opted in. The connection test stays available so an engine can be checked before opting in.
  ///
  /// In fr, this message translates to:
  /// **'Catégorisation par IA désactivée.'**
  String get settingsAiStatusDisabled;

  /// Link beside the no-engine status, opening the local runtime's download page in the browser.
  ///
  /// In fr, this message translates to:
  /// **'En savoir plus'**
  String get settingsAiLearnMore;

  /// Button that probes the configured runtime.
  ///
  /// In fr, this message translates to:
  /// **'Tester la connexion'**
  String get settingsAiTest;

  /// Label the connection-test button takes while its probe is in flight.
  ///
  /// In fr, this message translates to:
  /// **'Test en cours…'**
  String get settingsAiTesting;

  /// Shown in place of the local-AI card when reading the settings failed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger vos paramètres pour le moment.'**
  String get settingsAiLoadFailed;

  /// Retry action on the local-AI card's error state.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get settingsAiRetry;

  /// Title of the backup card in Settings › Données.
  ///
  /// In fr, this message translates to:
  /// **'Sauvegarde et restauration'**
  String get settingsBackupTitle;

  /// Line under the backup card's title.
  ///
  /// In fr, this message translates to:
  /// **'Exportez toutes vos données dans un fichier que vous pourrez réimporter.'**
  String get settingsBackupSubtitle;

  /// Label of the export row on the backup card.
  ///
  /// In fr, this message translates to:
  /// **'Exporter toutes les données'**
  String get settingsBackupExportLabel;

  /// Caption under the export row's label: what the file contains.
  ///
  /// In fr, this message translates to:
  /// **'Fichier .finstride — comptes, transactions, catégories, règles, objectifs, crédits, biens, paramètres.'**
  String get settingsBackupExportCaption;

  /// Replaces the export caption while the archive is being built.
  ///
  /// In fr, this message translates to:
  /// **'Préparation de l\'archive…'**
  String get settingsBackupExportPreparing;

  /// Primary button that exports a full backup.
  ///
  /// In fr, this message translates to:
  /// **'Exporter'**
  String get settingsBackupExport;

  /// Line under the export row with the time of the latest backup.
  ///
  /// In fr, this message translates to:
  /// **'Dernière sauvegarde : {when}'**
  String settingsBackupLast(String when);

  /// Shown under the export row when the user has never exported a backup.
  ///
  /// In fr, this message translates to:
  /// **'Aucune sauvegarde pour l\'instant.'**
  String get settingsBackupNone;

  /// A backup timestamp: a locale-formatted date then time.
  ///
  /// In fr, this message translates to:
  /// **'{date} à {time}'**
  String settingsBackupDateTime(String date, String time);

  /// Lock callout on the backup card warning that the archive is unencrypted.
  ///
  /// In fr, this message translates to:
  /// **'Le fichier n\'est pas chiffré. Conservez-le en lieu sûr — il contient tout votre historique financier.'**
  String get settingsBackupPrivacy;

  /// Label of the restore row on the backup card.
  ///
  /// In fr, this message translates to:
  /// **'Restaurer une sauvegarde'**
  String get settingsBackupRestoreTitle;

  /// Line under the restore row's label.
  ///
  /// In fr, this message translates to:
  /// **'Remplace toutes les données actuelles.'**
  String get settingsBackupRestoreSubtitle;

  /// Secondary button that opens the file picker to restore a backup.
  ///
  /// In fr, this message translates to:
  /// **'Importer un fichier…'**
  String get settingsBackupRestoreButton;

  /// Bold lead of the error banner shown when a chosen backup cannot be restored.
  ///
  /// In fr, this message translates to:
  /// **'Restauration impossible.'**
  String get settingsBackupRestoreFailedLead;

  /// Restore refused: the archive was written by a newer app version (BACKUP_TOO_NEW).
  ///
  /// In fr, this message translates to:
  /// **'Ce fichier provient d\'une version plus récente de FinStride. Mettez l\'application à jour pour le restaurer.'**
  String get settingsBackupErrorTooNew;

  /// Restore refused: not a FinStride archive or corrupted (BACKUP_INVALID).
  ///
  /// In fr, this message translates to:
  /// **'Ce fichier n\'est pas une sauvegarde FinStride valide, ou il est endommagé.'**
  String get settingsBackupErrorInvalid;

  /// Restore refused: the archive's currency differs from the user's (BACKUP_CURRENCY_MISMATCH).
  ///
  /// In fr, this message translates to:
  /// **'Cette sauvegarde utilise une autre devise que votre compte.'**
  String get settingsBackupErrorCurrency;

  /// Restore refused while a categorization run is in flight (BACKUP_RUN_ACTIVE).
  ///
  /// In fr, this message translates to:
  /// **'Une catégorisation est en cours. Attendez qu\'elle se termine, puis réessayez.'**
  String get settingsBackupErrorRunActive;

  /// Restore refused: its rows belong to another account still in this database (BACKUP_CONFLICT).
  ///
  /// In fr, this message translates to:
  /// **'Cette sauvegarde appartient à un autre compte présent sur cet ordinateur.'**
  String get settingsBackupErrorConflict;

  /// Restore failed for any other reason; nothing was changed.
  ///
  /// In fr, this message translates to:
  /// **'La restauration a échoué. Vos données n\'ont pas été modifiées.'**
  String get settingsBackupErrorUnknown;

  /// Toast after a backup was written. The String placeholders are the locale-formatted counts.
  ///
  /// In fr, this message translates to:
  /// **'Sauvegarde enregistrée — {transactionCount, plural, one{{transactions} transaction} other{{transactions} transactions}}, {accountCount, plural, one{{accounts} compte} other{{accounts} comptes}}.'**
  String settingsBackupExported(
    int transactionCount,
    String transactions,
    int accountCount,
    String accounts,
  );

  /// Error toast when building or writing the backup failed.
  ///
  /// In fr, this message translates to:
  /// **'L\'export a échoué. Réessayez.'**
  String get settingsBackupExportFailed;

  /// Title of the restore confirmation modal.
  ///
  /// In fr, this message translates to:
  /// **'Restaurer cette sauvegarde ?'**
  String get settingsBackupConfirmTitle;

  /// Subtitle lead of the restore modal, followed by the file name.
  ///
  /// In fr, this message translates to:
  /// **'Fichier sélectionné :'**
  String get settingsBackupConfirmFile;

  /// Summary row: when the backup was exported.
  ///
  /// In fr, this message translates to:
  /// **'Exporté le'**
  String get settingsBackupConfirmExportedAt;

  /// Summary row: the app version that wrote the backup.
  ///
  /// In fr, this message translates to:
  /// **'Version de l\'application'**
  String get settingsBackupConfirmVersion;

  /// Summary row: number of accounts in the backup.
  ///
  /// In fr, this message translates to:
  /// **'Comptes'**
  String get settingsBackupConfirmAccounts;

  /// Summary row: number of transactions in the backup.
  ///
  /// In fr, this message translates to:
  /// **'Transactions'**
  String get settingsBackupConfirmTransactions;

  /// Summary row: number of user categories in the backup.
  ///
  /// In fr, this message translates to:
  /// **'Catégories'**
  String get settingsBackupConfirmCategories;

  /// Summary row: number of categorization rules in the backup.
  ///
  /// In fr, this message translates to:
  /// **'Règles'**
  String get settingsBackupConfirmRules;

  /// Summary row: number of recurring series in the backup.
  ///
  /// In fr, this message translates to:
  /// **'Abonnements'**
  String get settingsBackupConfirmSubscriptions;

  /// Summary row: number of savings goals in the backup.
  ///
  /// In fr, this message translates to:
  /// **'Objectifs'**
  String get settingsBackupConfirmGoals;

  /// Summary row: number of declared loans (the Crédits panel).
  ///
  /// In fr, this message translates to:
  /// **'Crédits'**
  String get settingsBackupConfirmMortgages;

  /// Summary row: number of declared real-estate properties.
  ///
  /// In fr, this message translates to:
  /// **'Biens'**
  String get settingsBackupConfirmProperties;

  /// Summary row: number of saved loan simulator scenarios.
  ///
  /// In fr, this message translates to:
  /// **'Simulations'**
  String get settingsBackupConfirmSimulations;

  /// Warning callout in the restore modal.
  ///
  /// In fr, this message translates to:
  /// **'Toutes vos données actuelles seront remplacées. Exportez-les d\'abord si besoin.'**
  String get settingsBackupConfirmWarning;

  /// Dismisses the restore modal without changing anything.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get settingsBackupCancel;

  /// Destructive confirm button of the restore modal.
  ///
  /// In fr, this message translates to:
  /// **'Remplacer mes données'**
  String get settingsBackupReplace;

  /// Toast after a restore completed.
  ///
  /// In fr, this message translates to:
  /// **'Sauvegarde restaurée'**
  String get settingsBackupRestored;

  /// Sidebar entry for the recurring payments panel, third in the Gestion group.
  ///
  /// In fr, this message translates to:
  /// **'Récurrents'**
  String get navSubscriptions;

  /// Top-bar descriptor under the recurring payments panel title.
  ///
  /// In fr, this message translates to:
  /// **'Vos paiements récurrents, détectés automatiquement'**
  String get navSubscriptionsSubtitle;

  /// Secondary top-bar button re-running detection over the imported ledger.
  ///
  /// In fr, this message translates to:
  /// **'Détecter'**
  String get subscriptionsDetect;

  /// Label the detect button takes while a pass is in flight.
  ///
  /// In fr, this message translates to:
  /// **'Détection…'**
  String get subscriptionsDetectRunning;

  /// Primary top-bar button opening the manual-creation modal.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau paiement récurrent'**
  String get subscriptionsAdd;

  /// Toast headline after a detection pass, counting what it created.
  ///
  /// In fr, this message translates to:
  /// **'{created, plural, =0{Aucun nouveau paiement récurrent détecté} =1{1 nouveau paiement récurrent détecté} other{{created} nouveaux paiements récurrents détectés}}'**
  String subscriptionsDetectResult(int created);

  /// Second toast line after a detection pass, counting what it refreshed.
  ///
  /// In fr, this message translates to:
  /// **'{updated, plural, =0{Aucune série existante mise à jour} =1{1 série existante mise à jour} other{{updated} séries existantes mises à jour}}'**
  String subscriptionsDetectResultDetail(int updated);

  /// Toast headline when the detection call itself failed.
  ///
  /// In fr, this message translates to:
  /// **'La détection n\'a pas pu s\'exécuter.'**
  String get subscriptionsDetectFailed;

  /// Label of the iris-tinted hero card carrying the monthly burden.
  ///
  /// In fr, this message translates to:
  /// **'Charge mensuelle'**
  String get subscriptionsBurdenLabel;

  /// Caption under the monthly burden, naming the normalisation it applies.
  ///
  /// In fr, this message translates to:
  /// **'Charges trimestrielles et annuelles ramenées au mois.'**
  String get subscriptionsBurdenCaption;

  /// Appended to the burden caption so the figure names its own exclusion rather than disagreeing silently with the count beside it.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 paiement terminé exclu.} other{{count} paiements terminés exclus.}}'**
  String subscriptionsBurdenExcluded(int count);

  /// Label of the card counting the recurring payments still running.
  ///
  /// In fr, this message translates to:
  /// **'Paiements actifs'**
  String get subscriptionsActiveLabel;

  /// Weekly share of the active count, in the cadence breakdown caption.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 hebdomadaire} other{{count} hebdomadaires}}'**
  String subscriptionsCadenceWeeklyCount(int count);

  /// Monthly share of the active count, in the cadence breakdown caption.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 mensuel} other{{count} mensuels}}'**
  String subscriptionsCadenceMonthlyCount(int count);

  /// Quarterly share of the active count, in the cadence breakdown caption.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 trimestriel} other{{count} trimestriels}}'**
  String subscriptionsCadenceQuarterlyCount(int count);

  /// Yearly share of the active count, in the cadence breakdown caption.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 annuel} other{{count} annuels}}'**
  String subscriptionsCadenceYearlyCount(int count);

  /// Irregular share of the active count — user-declared series only.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 irrégulier} other{{count} irréguliers}}'**
  String subscriptionsCadenceIrregularCount(int count);

  /// Tail of the cadence breakdown caption, naming the cancelled rows the active count leaves out.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 terminé} other{{count} terminés}}'**
  String subscriptionsCancelledCount(int count);

  /// Label of the card naming the soonest charge ahead.
  ///
  /// In fr, this message translates to:
  /// **'Prochain prélèvement'**
  String get subscriptionsNextLabel;

  /// Value line of the next-charge card: the payment and how far off it is.
  ///
  /// In fr, this message translates to:
  /// **'{label} — {when}'**
  String subscriptionsNextValue(String label, String when);

  /// Caption of the next-charge card: the amount and the exact date.
  ///
  /// In fr, this message translates to:
  /// **'{amount} · {date}'**
  String subscriptionsNextCaption(String amount, String date);

  /// Relative phrasing for a charge due today.
  ///
  /// In fr, this message translates to:
  /// **'aujourd\'hui'**
  String get subscriptionsNextToday;

  /// Relative phrasing for a charge due tomorrow.
  ///
  /// In fr, this message translates to:
  /// **'demain'**
  String get subscriptionsNextTomorrow;

  /// Relative phrasing for a charge further ahead.
  ///
  /// In fr, this message translates to:
  /// **'{days, plural, =1{dans 1 jour} other{dans {days} jours}}'**
  String subscriptionsNextInDays(int days);

  /// Value of the next-charge card when no running series expects one.
  ///
  /// In fr, this message translates to:
  /// **'Aucun prélèvement à venir'**
  String get subscriptionsNextNone;

  /// Table header over the payment name column.
  ///
  /// In fr, this message translates to:
  /// **'Libellé'**
  String get subscriptionsColumnName;

  /// Table header over the category chip column.
  ///
  /// In fr, this message translates to:
  /// **'Catégorie'**
  String get subscriptionsColumnCategory;

  /// Table header over the cadence column.
  ///
  /// In fr, this message translates to:
  /// **'Cadence'**
  String get subscriptionsColumnCadence;

  /// Table header over the expected-amount column.
  ///
  /// In fr, this message translates to:
  /// **'Montant'**
  String get subscriptionsColumnAmount;

  /// Table header over the next-charge date column.
  ///
  /// In fr, this message translates to:
  /// **'Prochain'**
  String get subscriptionsColumnNext;

  /// Table header over the status-pill column, which is empty for a healthy row.
  ///
  /// In fr, this message translates to:
  /// **'Statut'**
  String get subscriptionsColumnStatus;

  /// Placeholder in a cell with nothing to state — a cancelled row's next charge.
  ///
  /// In fr, this message translates to:
  /// **'—'**
  String get subscriptionsValueNone;

  /// Cadence name: every week.
  ///
  /// In fr, this message translates to:
  /// **'Hebdomadaire'**
  String get cadenceWeekly;

  /// Cadence name: every month.
  ///
  /// In fr, this message translates to:
  /// **'Mensuel'**
  String get cadenceMonthly;

  /// Cadence name: every quarter.
  ///
  /// In fr, this message translates to:
  /// **'Trimestriel'**
  String get cadenceQuarterly;

  /// Cadence name: every year.
  ///
  /// In fr, this message translates to:
  /// **'Annuel'**
  String get cadenceYearly;

  /// Cadence name for a user-declared series with no rhythm. Detection never produces it.
  ///
  /// In fr, this message translates to:
  /// **'Irrégulier'**
  String get cadenceIrregular;

  /// Amber status pill on a row whose charge recently grew.
  ///
  /// In fr, this message translates to:
  /// **'Augmentation · {from} → {to}'**
  String subscriptionSignalIncrease(String from, String to);

  /// Amber status pill on a row whose charge has not landed past its tolerance.
  ///
  /// In fr, this message translates to:
  /// **'{days, plural, =1{Prélèvement manquant · 1 jour de retard} other{Prélèvement manquant · {days} jours de retard}}'**
  String subscriptionSignalMissed(int days);

  /// Gray status pill on a recurring payment the user ended. It stays listed, dimmed.
  ///
  /// In fr, this message translates to:
  /// **'Terminé · dernier prélèvement {date}'**
  String subscriptionSignalCancelled(String date);

  /// Replaces the next-charge date on a row with a missed charge, in amber: the date is what was expected, not what is coming.
  ///
  /// In fr, this message translates to:
  /// **'attendu le {date}'**
  String subscriptionNextExpected(String date);

  /// Tooltip of the row's kebab button.
  ///
  /// In fr, this message translates to:
  /// **'Actions du paiement'**
  String get subscriptionActionsTooltip;

  /// Kebab action accepting a detected series — status becomes confirmed.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer'**
  String get subscriptionActionConfirm;

  /// Kebab action dismissing a series. Final: detection never revives a dismissed one.
  ///
  /// In fr, this message translates to:
  /// **'Ignorer'**
  String get subscriptionActionDismiss;

  /// Kebab action recording that the recurring payment has ended.
  ///
  /// In fr, this message translates to:
  /// **'Marquer comme terminé'**
  String get subscriptionActionCancel;

  /// Kebab action opening the series in the edit form.
  ///
  /// In fr, this message translates to:
  /// **'Modifier'**
  String get subscriptionActionEdit;

  /// Localized RECURRING_INVALID_TRANSITION.
  ///
  /// In fr, this message translates to:
  /// **'Ce changement de statut n\'est pas possible pour ce paiement.'**
  String get subscriptionErrorInvalidTransition;

  /// Localized RECURRING_SERIES_EXISTS.
  ///
  /// In fr, this message translates to:
  /// **'Ce compte suit déjà un paiement récurrent sous ce nom.'**
  String get subscriptionErrorExists;

  /// Localized RECURRING_SERIES_NOT_FOUND.
  ///
  /// In fr, this message translates to:
  /// **'Ce paiement récurrent n\'existe plus.'**
  String get subscriptionErrorNotFound;

  /// Localized ACCOUNT_NOT_FOUND, reachable from the creation form's account select.
  ///
  /// In fr, this message translates to:
  /// **'Ce compte n\'existe plus.'**
  String get subscriptionErrorAccountNotFound;

  /// Localized CATEGORY_INVALID on the recurring payment form, returned when the chosen category is not one the user may assign.
  ///
  /// In fr, this message translates to:
  /// **'Cette catégorie n\'est plus disponible.'**
  String get subscriptionErrorCategoryInvalid;

  /// Localized VALIDATION_ERROR on the recurring payment form.
  ///
  /// In fr, this message translates to:
  /// **'Vérifiez les informations saisies.'**
  String get subscriptionErrorValidation;

  /// Fallback for an error code this panel has no specific message for.
  ///
  /// In fr, this message translates to:
  /// **'Une erreur est survenue. Réessayez.'**
  String get subscriptionErrorGeneric;

  /// Error state replacing the panel when the list or summary failed to load.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger vos paiements récurrents pour le moment.'**
  String get subscriptionsLoadFailed;

  /// Retry action on the recurring payments error state.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get subscriptionsRetry;

  /// Empty-state title on the recurring payments panel.
  ///
  /// In fr, this message translates to:
  /// **'Aucun paiement récurrent détecté pour l\'instant'**
  String get subscriptionsEmptyTitle;

  /// Empty-state body, stating the three-repeat rule so the absence reads as a threshold rather than a failure.
  ///
  /// In fr, this message translates to:
  /// **'FinStride repère un paiement récurrent lorsqu\'un prélèvement s\'est répété trois fois. Importer davantage d\'historique accélère la détection.'**
  String get subscriptionsEmptyBody;

  /// Empty-state CTA. It goes to imports rather than to manual creation because more history is the actual remedy.
  ///
  /// In fr, this message translates to:
  /// **'Aller aux imports'**
  String get subscriptionsEmptyCta;

  /// Iris back link at the top of the series detail.
  ///
  /// In fr, this message translates to:
  /// **'Retour aux récurrents'**
  String get subscriptionDetailBack;

  /// Sub-line of the detail header for a detected series.
  ///
  /// In fr, this message translates to:
  /// **'{account} · détecté depuis {month}'**
  String subscriptionDetailDetectedSince(String account, String month);

  /// Sub-line of the detail header for a user-declared series, which was never detected.
  ///
  /// In fr, this message translates to:
  /// **'{account} · suivi depuis {month}'**
  String subscriptionDetailTrackedSince(String account, String month);

  /// Label of the cadence stat in the detail header.
  ///
  /// In fr, this message translates to:
  /// **'Cadence'**
  String get subscriptionDetailCadence;

  /// Label of the expected-amount stat in the detail header.
  ///
  /// In fr, this message translates to:
  /// **'Montant attendu'**
  String get subscriptionDetailExpectedAmount;

  /// Label of the next-charge stat in the detail header.
  ///
  /// In fr, this message translates to:
  /// **'Prochain prélèvement'**
  String get subscriptionDetailNextCharge;

  /// Amber banner on the detail. The annualised figure is stated rather than left as a multiplication for the reader.
  ///
  /// In fr, this message translates to:
  /// **'Augmentation : {from} → {to} le {date} — soit {annual} par an.'**
  String subscriptionDetailIncrease(
    String from,
    String to,
    String date,
    String annual,
  );

  /// Title of the occurrence-history card on the detail.
  ///
  /// In fr, this message translates to:
  /// **'Historique des prélèvements'**
  String get subscriptionDetailHistoryTitle;

  /// Sub-line of the history card, naming the evidence and the account it comes from.
  ///
  /// In fr, this message translates to:
  /// **'Les transactions dont cette série est déduite · {account}'**
  String subscriptionDetailHistorySubtitle(String account);

  /// History card with no rows — the ordinary state of a series the user has just declared.
  ///
  /// In fr, this message translates to:
  /// **'Aucun prélèvement rattaché à ce paiement pour l\'instant.'**
  String get subscriptionDetailHistoryEmpty;

  /// Amber pill marking the occurrence where the price stepped up.
  ///
  /// In fr, this message translates to:
  /// **'{from} → {to}'**
  String subscriptionDetailChange(String from, String to);

  /// Foot note under the history: the user is being asked to trust a deduction, so the evidence is part of the screen.
  ///
  /// In fr, this message translates to:
  /// **'FinStride déduit la série de ces occurrences — vérifiez-les avant de confirmer un changement.'**
  String get subscriptionDetailFootnote;

  /// Error state replacing the detail when it failed to load.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger ce paiement récurrent pour le moment.'**
  String get subscriptionDetailLoadFailed;

  /// Title of the manual-creation modal.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau paiement récurrent'**
  String get subscriptionFormCreateTitle;

  /// Title of the modal when editing an existing series.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le paiement récurrent'**
  String get subscriptionFormEditTitle;

  /// Sub-line under the creation modal's title.
  ///
  /// In fr, this message translates to:
  /// **'Suivez un paiement récurrent que la détection n\'a pas encore repéré.'**
  String get subscriptionFormIntro;

  /// Label of the payment name field.
  ///
  /// In fr, this message translates to:
  /// **'Nom'**
  String get subscriptionFormNameLabel;

  /// Validation message when the name field is empty.
  ///
  /// In fr, this message translates to:
  /// **'Donnez un nom à ce paiement.'**
  String get subscriptionFormNameRequired;

  /// Label of the account select in the recurring payment form.
  ///
  /// In fr, this message translates to:
  /// **'Compte'**
  String get subscriptionFormAccountLabel;

  /// Label of the amount field. The user types the charge as a positive figure; it is stored signed.
  ///
  /// In fr, this message translates to:
  /// **'Montant'**
  String get subscriptionFormAmountLabel;

  /// Validation message when the amount is missing, unparseable, or not positive.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez un montant supérieur à zéro.'**
  String get subscriptionFormAmountInvalid;

  /// Label of the cadence select in the recurring payment form.
  ///
  /// In fr, this message translates to:
  /// **'Cadence'**
  String get subscriptionFormCadenceLabel;

  /// Helper under the cadence select, listing what it offers. Irregular is offered here and nowhere else — detection never concludes it.
  ///
  /// In fr, this message translates to:
  /// **'Hebdomadaire · Mensuel · Trimestriel · Annuel · Irrégulier'**
  String get subscriptionFormCadenceHelp;

  /// Label of the category select in the recurring payment form.
  ///
  /// In fr, this message translates to:
  /// **'Catégorie'**
  String get subscriptionFormCategoryLabel;

  /// The no-category option in the recurring payment form's category select.
  ///
  /// In fr, this message translates to:
  /// **'Aucune'**
  String get subscriptionFormCategoryNone;

  /// Shown in place of the account select when the user has no accounts yet.
  ///
  /// In fr, this message translates to:
  /// **'Créez d\'abord un compte pour y suivre un paiement récurrent.'**
  String get subscriptionFormNoAccounts;

  /// Cancel action in the recurring payment modal footer.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get subscriptionFormCancel;

  /// Confirm action when creating a recurring payment.
  ///
  /// In fr, this message translates to:
  /// **'Créer le paiement récurrent'**
  String get subscriptionFormSubmit;

  /// Confirm action when editing a recurring payment.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get subscriptionFormSave;

  /// Sidebar label of the goals panel, last of the Gestion group.
  ///
  /// In fr, this message translates to:
  /// **'Objectifs'**
  String get navGoals;

  /// Top-bar descriptor of the goals panel.
  ///
  /// In fr, this message translates to:
  /// **'Mettez de côté, virtuellement, pour ce qui compte'**
  String get navGoalsSubtitle;

  /// Primary top-bar action opening the goal form.
  ///
  /// In fr, this message translates to:
  /// **'Nouvel objectif'**
  String get goalsAdd;

  /// Lock line stating that allocating changes no account. Shown on the grid and on the detail.
  ///
  /// In fr, this message translates to:
  /// **'Répartition sur le papier : vos comptes ne sont pas modifiés.'**
  String get goalsReassurance;

  /// The over-allocation banner. Informative and dismissible, never blocking (`PROJECT.md` §13).
  ///
  /// In fr, this message translates to:
  /// **'Vous avez réparti {allocated} alors que vos comptes d\'épargne totalisent {savings}.'**
  String goalsOverAllocated(String allocated, String savings);

  /// Tooltip on the over-allocation banner's dismiss control.
  ///
  /// In fr, this message translates to:
  /// **'Masquer cet avertissement'**
  String get goalsDismissBanner;

  /// Link below the grid that reveals archived goals in place; the count is the real number.
  ///
  /// In fr, this message translates to:
  /// **'Afficher les objectifs archivés ({count})'**
  String goalsShowArchived(int count);

  /// The same link once the archived goals are showing.
  ///
  /// In fr, this message translates to:
  /// **'Masquer les objectifs archivés ({count})'**
  String goalsHideArchived(int count);

  /// Empty-state title of the goals panel.
  ///
  /// In fr, this message translates to:
  /// **'Donnez un nom à ce qui compte'**
  String get goalsEmptyTitle;

  /// Empty-state body explaining what a virtual envelope is.
  ///
  /// In fr, this message translates to:
  /// **'Un objectif est une enveloppe virtuelle : vous y mettez de côté à votre rythme, sans toucher à vos comptes.'**
  String get goalsEmptyBody;

  /// Error state when the goals list fails to load.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger vos objectifs pour le moment.'**
  String get goalsLoadFailed;

  /// Retry action on the goals error states.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get goalsRetry;

  /// Card pill for a goal with no target date.
  ///
  /// In fr, this message translates to:
  /// **'Sans échéance'**
  String get goalPillNoDeadline;

  /// Card pill for a reached goal with no target date.
  ///
  /// In fr, this message translates to:
  /// **'Objectif atteint'**
  String get goalPillReached;

  /// The reached pill when the goal carried a target date.
  ///
  /// In fr, this message translates to:
  /// **'Objectif atteint · {month}'**
  String goalPillReachedOn(String month);

  /// Iris back link from the goal detail to the grid.
  ///
  /// In fr, this message translates to:
  /// **'Retour aux objectifs'**
  String get goalDetailBack;

  /// Sub-line of the detail header when the goal has a target date. No account is named here.
  ///
  /// In fr, this message translates to:
  /// **'Échéance {month}'**
  String goalDetailTargetDate(String month);

  /// Secondary action archiving a goal from its detail header.
  ///
  /// In fr, this message translates to:
  /// **'Archiver'**
  String get goalDetailArchive;

  /// The same button on an archived goal, which restores it.
  ///
  /// In fr, this message translates to:
  /// **'Restaurer'**
  String get goalDetailRestore;

  /// Primary action opening the allocation modal.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle allocation'**
  String get goalDetailNewAllocation;

  /// Shown when the open goal no longer exists.
  ///
  /// In fr, this message translates to:
  /// **'Cet objectif n\'est plus disponible.'**
  String get goalDetailMissing;

  /// Foot note under the allocation history: no transaction is created.
  ///
  /// In fr, this message translates to:
  /// **'Aucune transaction n\'est créée : ces lignes n\'existent que sur le papier de l\'objectif.'**
  String get goalDetailFootnote;

  /// Error state when the allocation history fails to load.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger l\'historique des allocations.'**
  String get goalDetailHistoryFailed;

  /// Title of the allocation history card.
  ///
  /// In fr, this message translates to:
  /// **'Historique des allocations'**
  String get goalHistoryTitle;

  /// Sub-line stating that the ledger is one signed list.
  ///
  /// In fr, this message translates to:
  /// **'Une seule liste, montants signés — un retrait est une ligne négative.'**
  String get goalHistorySubtitle;

  /// Date column of the allocation history.
  ///
  /// In fr, this message translates to:
  /// **'Date'**
  String get goalHistoryDate;

  /// Amount column of the allocation history.
  ///
  /// In fr, this message translates to:
  /// **'Montant'**
  String get goalHistoryAmount;

  /// Note column of the allocation history.
  ///
  /// In fr, this message translates to:
  /// **'Note'**
  String get goalHistoryNote;

  /// Tooltip on the control removing one allocation line.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer cette allocation'**
  String get goalHistoryDelete;

  /// Shown when a goal has no allocations yet.
  ///
  /// In fr, this message translates to:
  /// **'Aucune allocation pour l\'instant.'**
  String get goalHistoryEmpty;

  /// Title of the goal modal when creating.
  ///
  /// In fr, this message translates to:
  /// **'Nouvel objectif'**
  String get goalFormCreateTitle;

  /// Title of the goal modal when editing.
  ///
  /// In fr, this message translates to:
  /// **'Modifier l\'objectif'**
  String get goalFormEditTitle;

  /// Sub-line under the goal modal's title.
  ///
  /// In fr, this message translates to:
  /// **'Une enveloppe virtuelle : vous y mettez de côté sur le papier, sans toucher à vos comptes.'**
  String get goalFormIntro;

  /// Label of the goal name field.
  ///
  /// In fr, this message translates to:
  /// **'Nom'**
  String get goalFormNameLabel;

  /// Validation message when the goal name is empty.
  ///
  /// In fr, this message translates to:
  /// **'Donnez un nom à cet objectif.'**
  String get goalFormNameRequired;

  /// Label of the target amount field.
  ///
  /// In fr, this message translates to:
  /// **'Montant cible'**
  String get goalFormTargetLabel;

  /// Validation message when the target is missing, unparseable, or not positive.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez un montant supérieur à zéro.'**
  String get goalFormTargetInvalid;

  /// Label of the optional target date field.
  ///
  /// In fr, this message translates to:
  /// **'Date cible'**
  String get goalFormDateLabel;

  /// Helper marking the target date as optional.
  ///
  /// In fr, this message translates to:
  /// **'Facultative'**
  String get goalFormDateHelp;

  /// Validation message when the target date cannot be read in the current locale.
  ///
  /// In fr, this message translates to:
  /// **'Date invalide.'**
  String get goalFormDateInvalid;

  /// Label of the goal icon picker.
  ///
  /// In fr, this message translates to:
  /// **'Icône'**
  String get goalFormIconLabel;

  /// Label of the goal color picker.
  ///
  /// In fr, this message translates to:
  /// **'Couleur'**
  String get goalFormColorLabel;

  /// Cancel action in the goal modal footer.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get goalFormCancel;

  /// Confirm action when creating a goal.
  ///
  /// In fr, this message translates to:
  /// **'Créer l\'objectif'**
  String get goalFormSubmit;

  /// Confirm action when editing a goal.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get goalFormSave;

  /// Title of the allocation modal.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle allocation'**
  String get allocationModalTitle;

  /// Label of the signed amount field — the only amount control in the modal.
  ///
  /// In fr, this message translates to:
  /// **'Montant'**
  String get allocationAmountLabel;

  /// Helper stating that a negative amount is a withdrawal. There are no deposit/withdraw modes.
  ///
  /// In fr, this message translates to:
  /// **'Un montant négatif retire de l\'objectif.'**
  String get allocationAmountHelp;

  /// Validation message when the allocation amount is missing, unparseable, or zero.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez un montant différent de zéro.'**
  String get allocationAmountInvalid;

  /// Label of the allocation date field.
  ///
  /// In fr, this message translates to:
  /// **'Date'**
  String get allocationDateLabel;

  /// Validation message when the allocation date cannot be read in the current locale.
  ///
  /// In fr, this message translates to:
  /// **'Date invalide.'**
  String get allocationDateInvalid;

  /// Label of the optional allocation note field.
  ///
  /// In fr, this message translates to:
  /// **'Note (optionnelle)'**
  String get allocationNoteLabel;

  /// Placeholder example in the allocation note field.
  ///
  /// In fr, this message translates to:
  /// **'Ex. Virement mensuel'**
  String get allocationNoteHint;

  /// Cancel action in the allocation modal footer.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get allocationCancel;

  /// Confirm action appending the allocation.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter'**
  String get allocationSubmit;

  /// Message for the backend's GOAL_NOT_FOUND code.
  ///
  /// In fr, this message translates to:
  /// **'Cet objectif n\'existe plus.'**
  String get goalErrorNotFound;

  /// Message for the backend's GOAL_ALLOCATION_NOT_FOUND code.
  ///
  /// In fr, this message translates to:
  /// **'Cette allocation n\'existe plus.'**
  String get goalErrorAllocationNotFound;

  /// Message for a rejected goal or allocation payload.
  ///
  /// In fr, this message translates to:
  /// **'Vérifiez les informations saisies.'**
  String get goalErrorValidation;

  /// Fallback message for any other goals failure.
  ///
  /// In fr, this message translates to:
  /// **'Une erreur est survenue. Réessayez.'**
  String get goalErrorGeneric;

  /// Title of the dashboard's Objectifs card.
  ///
  /// In fr, this message translates to:
  /// **'Objectifs'**
  String get dashboardGoalsTitle;

  /// Iris link from the dashboard goals card to the goals panel.
  ///
  /// In fr, this message translates to:
  /// **'Voir tout'**
  String get dashboardGoalsViewAll;

  /// Compact saved/target pair on a dashboard goal row.
  ///
  /// In fr, this message translates to:
  /// **'{saved} / {target}'**
  String dashboardGoalsProgress(String saved, String target);

  /// Badge replacing the amounts on a reached goal's dashboard row.
  ///
  /// In fr, this message translates to:
  /// **'Atteint'**
  String get dashboardGoalsReached;

  /// Tooltip on the calendar button of the goal form's target date field.
  ///
  /// In fr, this message translates to:
  /// **'Choisir une date cible'**
  String get goalFormDatePick;

  /// Tooltip on the calendar button of the allocation modal's date field.
  ///
  /// In fr, this message translates to:
  /// **'Choisir une date'**
  String get allocationDatePick;

  /// Title of the danger zone card in Settings › Données.
  ///
  /// In fr, this message translates to:
  /// **'Zone de danger'**
  String get settingsResetTitle;

  /// Pill beside the danger zone title, stating the stake in a word.
  ///
  /// In fr, this message translates to:
  /// **'IRRÉVERSIBLE'**
  String get settingsResetBadge;

  /// What a database reset deletes, and what it leaves alone.
  ///
  /// In fr, this message translates to:
  /// **'Réinitialiser la base de données supprime transactions, comptes, règles, catégories personnalisées, objectifs, abonnements, crédits, biens et simulations de ce profil. Les sauvegardes exportées ne sont pas touchées.'**
  String get settingsResetSubtitle;

  /// Outline danger button opening the reset confirmation.
  ///
  /// In fr, this message translates to:
  /// **'Réinitialiser…'**
  String get settingsResetButton;

  /// Title of the reset confirmation modal.
  ///
  /// In fr, this message translates to:
  /// **'Réinitialiser la base de données ?'**
  String get settingsResetConfirmTitle;

  /// Lead sentence of the reset confirmation; the name is set in bold.
  ///
  /// In fr, this message translates to:
  /// **'Tout le contenu du profil {name} sera supprimé définitivement :'**
  String settingsResetConfirmLead(String name);

  /// Counts row for the user's own categories — the system catalog is kept.
  ///
  /// In fr, this message translates to:
  /// **'Catégories personnalisées'**
  String get settingsResetConfirmCategories;

  /// Note under the reset counts listing what survives the reset.
  ///
  /// In fr, this message translates to:
  /// **'Les catégories système, vos préférences et le réglage IA sont conservés. Les fichiers de sauvegarde déjà exportés restent intacts.'**
  String get settingsResetConfirmNote;

  /// Red callout in the reset confirmation modal.
  ///
  /// In fr, this message translates to:
  /// **'Cette action est irréversible. Exportez une sauvegarde avant de continuer.'**
  String get settingsResetConfirmWarning;

  /// The word that must be typed exactly to enable the reset. Uppercase.
  ///
  /// In fr, this message translates to:
  /// **'SUPPRIMER'**
  String get settingsResetConfirmWord;

  /// Label of the typed-confirmation field.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez {word} pour confirmer'**
  String settingsResetConfirmLabel(String word);

  /// Destructive confirm action of the reset modal.
  ///
  /// In fr, this message translates to:
  /// **'Tout supprimer'**
  String get settingsResetConfirmSubmit;

  /// Toast shown once the reset has completed.
  ///
  /// In fr, this message translates to:
  /// **'Base de données réinitialisée. Les catégories système ont été restaurées.'**
  String get settingsResetDone;

  /// Bold red lead of the refusal banner in the danger zone card.
  ///
  /// In fr, this message translates to:
  /// **'Réinitialisation impossible.'**
  String get settingsResetFailedLead;

  /// Fallback message for any other reset failure.
  ///
  /// In fr, this message translates to:
  /// **'La réinitialisation a échoué. Vos données n\'ont pas été modifiées.'**
  String get settingsResetErrorUnknown;

  /// Left nav section heading grouping the loans, simulator and net-worth destinations (Phase 3). Rendered uppercase.
  ///
  /// In fr, this message translates to:
  /// **'Patrimoine'**
  String get navSectionWealth;

  /// Left nav label for the loans screen.
  ///
  /// In fr, this message translates to:
  /// **'Crédits'**
  String get navMortgages;

  /// Top-bar descriptor under the loans panel title.
  ///
  /// In fr, this message translates to:
  /// **'Vos emprunts, leur coût et votre capacité'**
  String get navMortgagesSubtitle;

  /// Left nav label for the new-loan simulator screen.
  ///
  /// In fr, this message translates to:
  /// **'Simulateur'**
  String get navSimulator;

  /// Top-bar descriptor under the simulator panel title.
  ///
  /// In fr, this message translates to:
  /// **'Ce qu\'un nouveau crédit changerait'**
  String get navSimulatorSubtitle;

  /// Left nav label for the net-worth screen. The EN label is 'Net worth', not 'Overview': the Overview group already owns that word.
  ///
  /// In fr, this message translates to:
  /// **'Synthèse'**
  String get navNetworth;

  /// Top-bar descriptor under the net-worth panel title.
  ///
  /// In fr, this message translates to:
  /// **'Ce que vous possédez, ce que vous devez'**
  String get navNetworthSubtitle;

  /// Top-bar primary CTA of the loans panel.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau crédit'**
  String get mortgagesAdd;

  /// Error state when the loans list cannot be loaded.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger vos crédits.'**
  String get mortgagesLoadFailed;

  /// Retry button on the loans error states.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get mortgagesRetry;

  /// Empty state title of the loans panel.
  ///
  /// In fr, this message translates to:
  /// **'Aucun crédit enregistré'**
  String get mortgagesEmptyTitle;

  /// Empty state reassurance line of the loans panel.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez vos emprunts pour suivre leur coût réel, leur trajectoire et votre capacité — sans jamais relier FinStride à une banque.'**
  String get mortgagesEmptyBody;

  /// Label of the monthly charge summary card. Rendered uppercase.
  ///
  /// In fr, this message translates to:
  /// **'Charge mensuelle'**
  String get mortgagesChargeLabel;

  /// Caption of the monthly charge card: how many instalments fall on the next due date.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 échéance le {date}} other{{count} échéances le {date}}} · assurance comprise'**
  String mortgagesChargeCaption(int count, String date);

  /// Caption of the monthly charge card when no instalment remains.
  ///
  /// In fr, this message translates to:
  /// **'assurance comprise'**
  String get mortgagesChargeCaptionNoNext;

  /// Label of the outstanding principal summary card. Rendered uppercase.
  ///
  /// In fr, this message translates to:
  /// **'Capital restant dû'**
  String get mortgagesOutstandingLabel;

  /// Caption of the outstanding principal card: the amount borrowed and the loan count.
  ///
  /// In fr, this message translates to:
  /// **'sur {principal} empruntés · {count, plural, =1{1 crédit} other{{count} crédits}}'**
  String mortgagesOutstandingCaption(String principal, int count);

  /// Foot line of the outstanding principal card.
  ///
  /// In fr, this message translates to:
  /// **'{amount} remboursés · {percent}'**
  String mortgagesRepaidLine(String amount, String percent);

  /// Label of the debt ratio card. Rendered uppercase.
  ///
  /// In fr, this message translates to:
  /// **'Taux d\'endettement'**
  String get mortgagesRatioLabel;

  /// The HCSF reference beside the ratio value.
  ///
  /// In fr, this message translates to:
  /// **'repère HCSF {percent}'**
  String mortgagesRatioReference(String percent);

  /// Amber status pill when the ratio is above the HCSF reference. Information, never a refusal.
  ///
  /// In fr, this message translates to:
  /// **'Au-dessus du repère'**
  String get mortgagesRatioOverLimit;

  /// Ratio caption when the income was declared by the user.
  ///
  /// In fr, this message translates to:
  /// **'Charge {charge} sur un revenu déclaré de {income}'**
  String mortgagesRatioCaptionDeclared(String charge, String income);

  /// Ratio caption when the income is the ledger's median of the last 12 complete months. Must say median, never average.
  ///
  /// In fr, this message translates to:
  /// **'Charge {charge} sur un revenu médian constaté de {income} (12 mois du grand livre). Le ménage perçoit peut-être des revenus hors application : un revenu déclaré remplace cette lecture.'**
  String mortgagesRatioCaptionLedger(String charge, String income);

  /// Ratio card body when no income is known and no ratio can be computed.
  ///
  /// In fr, this message translates to:
  /// **'Aucun revenu connu : le grand livre ne contient pas de revenus réguliers et aucun revenu n\'est déclaré. Sans revenu, il n\'y a pas de taux à calculer.'**
  String get mortgagesRatioUnknown;

  /// Iris link on the ledger-income ratio card.
  ///
  /// In fr, this message translates to:
  /// **'Déclarer un revenu →'**
  String get mortgagesRatioDeclareLink;

  /// Outline button on the unknown-income ratio card.
  ///
  /// In fr, this message translates to:
  /// **'Déclarer un revenu'**
  String get mortgagesRatioDeclareButton;

  /// HCSF caveat, always shown as body content on the ratio card, never as a tooltip.
  ///
  /// In fr, this message translates to:
  /// **'Lecture informative : ce repère ne lie aucun prêteur.'**
  String get mortgagesRatioCaveat;

  /// Title of the declare-income modal.
  ///
  /// In fr, this message translates to:
  /// **'Déclarer un revenu'**
  String get mortgagesIncomeTitle;

  /// Intro line of the declare-income modal.
  ///
  /// In fr, this message translates to:
  /// **'Le revenu mensuel net du ménage sur lequel lire le taux d\'endettement. Il remplace le revenu médian du grand livre.'**
  String get mortgagesIncomeBody;

  /// Field label in the declare-income modal.
  ///
  /// In fr, this message translates to:
  /// **'Revenu mensuel'**
  String get mortgagesIncomeLabel;

  /// Validation message for a missing or non-positive declared income.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez un montant supérieur à zéro.'**
  String get mortgagesIncomeInvalid;

  /// Submit button of the declare-income modal.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get mortgagesIncomeSubmit;

  /// Inline error when the declared income cannot be saved.
  ///
  /// In fr, this message translates to:
  /// **'Le revenu n\'a pas pu être enregistré.'**
  String get mortgagesIncomeFailed;

  /// Credit product label for kind=mortgage.
  ///
  /// In fr, this message translates to:
  /// **'Crédit immobilier'**
  String get mortgageKindMortgage;

  /// Credit product label for kind=works.
  ///
  /// In fr, this message translates to:
  /// **'Prêt travaux'**
  String get mortgageKindWorks;

  /// Credit product label for kind=consumer.
  ///
  /// In fr, this message translates to:
  /// **'Crédit à la consommation'**
  String get mortgageKindConsumer;

  /// Credit product label for kind=auto.
  ///
  /// In fr, this message translates to:
  /// **'Crédit auto'**
  String get mortgageKindAuto;

  /// Repayment type label for constant_payment.
  ///
  /// In fr, this message translates to:
  /// **'Échéance constante'**
  String get mortgageRepaymentConstant;

  /// Repayment type label for interest_only.
  ///
  /// In fr, this message translates to:
  /// **'In fine'**
  String get mortgageRepaymentInterestOnly;

  /// Loan card sub-line: kind label, lender, term.
  ///
  /// In fr, this message translates to:
  /// **'{kind} · {lender} · {months} mois'**
  String mortgageCardSubline(String kind, String lender, int months);

  /// Unit under the loan card's instalment.
  ///
  /// In fr, this message translates to:
  /// **'/ mois'**
  String get mortgageCardPerMonth;

  /// Loan card label before the outstanding principal.
  ///
  /// In fr, this message translates to:
  /// **'Capital restant dû'**
  String get mortgageCardOutstandingLabel;

  /// Loan card: the principal the outstanding is measured against.
  ///
  /// In fr, this message translates to:
  /// **'sur {principal}'**
  String mortgageCardOutstandingOf(String principal);

  /// Loan card: word after the iris repaid percentage.
  ///
  /// In fr, this message translates to:
  /// **'remboursé'**
  String get mortgageCardRepaid;

  /// Loan card: instalments left.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{aucune échéance restante} =1{1 échéance restante} other{{count} échéances restantes}}'**
  String mortgageCardRemaining(int count);

  /// Nominal rate label (loan card footer and cost row). Rendered uppercase on the card.
  ///
  /// In fr, this message translates to:
  /// **'Taux nominal'**
  String get mortgageRateLabel;

  /// Insurance label in the loan card footer. Rendered uppercase.
  ///
  /// In fr, this message translates to:
  /// **'Assurance'**
  String get mortgageInsuranceLabel;

  /// Next instalment label (loan card footer and detail header). Rendered uppercase.
  ///
  /// In fr, this message translates to:
  /// **'Prochaine échéance'**
  String get mortgageNextLabel;

  /// Insurance premium per month.
  ///
  /// In fr, this message translates to:
  /// **'{amount} / mois'**
  String mortgageInsurancePerMonth(String amount);

  /// Title of the trajectory chart.
  ///
  /// In fr, this message translates to:
  /// **'Trajectoire du capital restant dû'**
  String get mortgagesChartTitle;

  /// Subtitle of the trajectory chart, by active loan count.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{Le crédit, échéance après échéance, jusqu\'au dernier remboursement} =2{Les deux crédits, échéance après échéance, jusqu\'au dernier remboursement} other{Les {count} crédits, échéance après échéance, jusqu\'au dernier remboursement}}'**
  String mortgagesChartSubtitle(int count);

  /// Chart legend for the combined outstanding line.
  ///
  /// In fr, this message translates to:
  /// **'Capital restant dû total'**
  String get mortgagesChartLegendTotal;

  /// Chart legend for the dashed today marker.
  ///
  /// In fr, this message translates to:
  /// **'aujourd\'hui'**
  String get mortgagesChartLegendToday;

  /// Chart annotation on today's month: the month and the combined outstanding.
  ///
  /// In fr, this message translates to:
  /// **'{month} · {amount}'**
  String mortgagesChartToday(String month, String amount);

  /// Chart annotation at a loan's last instalment: the kind label (lower-cased) and the month.
  ///
  /// In fr, this message translates to:
  /// **'fin {kind} · {month}'**
  String mortgagesChartLoanEnd(String kind, String month);

  /// Iris back link from the loan detail to the list.
  ///
  /// In fr, this message translates to:
  /// **'Retour aux crédits'**
  String get mortgageDetailBack;

  /// Error state when a loan's detail cannot be loaded.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger ce crédit.'**
  String get mortgageDetailLoadFailed;

  /// Detail header sub-line without upfront fees.
  ///
  /// In fr, this message translates to:
  /// **'{kind} · {lender} · {principal} sur {months} mois · 1re échéance le {date}'**
  String mortgageDetailSubline(
    String kind,
    String lender,
    String principal,
    int months,
    String date,
  );

  /// Detail header sub-line with upfront fees.
  ///
  /// In fr, this message translates to:
  /// **'{kind} · {lender} · {principal} sur {months} mois · 1re échéance le {date} · frais de dossier {fees}'**
  String mortgageDetailSublineFees(
    String kind,
    String lender,
    String principal,
    int months,
    String date,
    String fees,
  );

  /// Detail header stat label. Rendered uppercase.
  ///
  /// In fr, this message translates to:
  /// **'Échéance totale'**
  String get mortgageDetailInstalmentLabel;

  /// Detail header: the instalment split into payment and insurance.
  ///
  /// In fr, this message translates to:
  /// **'{payment} + {insurance} assurance'**
  String mortgageDetailInstalmentCaption(String payment, String insurance);

  /// Detail header caption for a loan without insurance.
  ///
  /// In fr, this message translates to:
  /// **'sans assurance'**
  String get mortgageDetailInstalmentNoInsurance;

  /// Detail header: repaid share and instalments left.
  ///
  /// In fr, this message translates to:
  /// **'{percent} remboursé · {count, plural, =1{1 échéance} other{{count} échéances}}'**
  String mortgageDetailOutstandingCaption(String percent, int count);

  /// Secondary button opening the loan form prefilled.
  ///
  /// In fr, this message translates to:
  /// **'Modifier'**
  String get mortgageDetailEdit;

  /// Cost row: caption under the nominal rate.
  ///
  /// In fr, this message translates to:
  /// **'fixe sur toute la durée'**
  String get mortgageCostRateCaption;

  /// Cost row: TAEG label.
  ///
  /// In fr, this message translates to:
  /// **'TAEG'**
  String get mortgageCostTaegLabel;

  /// Iris marker pill beside the TAEG label. Rendered uppercase.
  ///
  /// In fr, this message translates to:
  /// **'Indicatif'**
  String get mortgageCostIndicative;

  /// TAEG disclaimer read by assistive tech on the INDICATIF pill.
  ///
  /// In fr, this message translates to:
  /// **'Indicatif : un TAEG réel inclut des frais que FinStride ne voit pas.'**
  String get mortgageCostTaegDisclaimer;

  /// Cost row: caption under the TAEG.
  ///
  /// In fr, this message translates to:
  /// **'taux, assurance et frais inclus'**
  String get mortgageCostTaegCaption;

  /// Cost row: total interest label.
  ///
  /// In fr, this message translates to:
  /// **'Intérêts totaux'**
  String get mortgageCostInterestLabel;

  /// Cost row: interest still to pay after today.
  ///
  /// In fr, this message translates to:
  /// **'dont {amount} encore à verser'**
  String mortgageCostInterestCaption(String amount);

  /// Cost row: total cost label.
  ///
  /// In fr, this message translates to:
  /// **'Coût total du crédit'**
  String get mortgageCostTotalLabel;

  /// Cost row: what the total cost is made of.
  ///
  /// In fr, this message translates to:
  /// **'intérêts + assurance {insurance} + frais {fees}'**
  String mortgageCostTotalCaption(String insurance, String fees);

  /// Title of the loan form when creating.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau crédit'**
  String get mortgageFormCreateTitle;

  /// Title of the loan form when editing.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le crédit'**
  String get mortgageFormEditTitle;

  /// Subtitle of the loan form.
  ///
  /// In fr, this message translates to:
  /// **'La mensualité est calculée à partir du capital, du taux et de la durée.'**
  String get mortgageFormSubtitle;

  /// Loan form: label field.
  ///
  /// In fr, this message translates to:
  /// **'Libellé'**
  String get mortgageFormLabel;

  /// Loan form: missing label.
  ///
  /// In fr, this message translates to:
  /// **'Donnez un nom à ce crédit.'**
  String get mortgageFormLabelRequired;

  /// Loan form: lender field.
  ///
  /// In fr, this message translates to:
  /// **'Prêteur'**
  String get mortgageFormLender;

  /// Loan form: missing lender.
  ///
  /// In fr, this message translates to:
  /// **'Indiquez le prêteur.'**
  String get mortgageFormLenderRequired;

  /// Loan form: credit product select.
  ///
  /// In fr, this message translates to:
  /// **'Type'**
  String get mortgageFormKind;

  /// Loan form: repayment type control, a separate axis from Type.
  ///
  /// In fr, this message translates to:
  /// **'Remboursement'**
  String get mortgageFormRepayment;

  /// Loan form: principal field.
  ///
  /// In fr, this message translates to:
  /// **'Capital emprunté'**
  String get mortgageFormPrincipal;

  /// Loan form: an amount that is missing or not above zero.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez un montant supérieur à zéro.'**
  String get mortgageFormAmountInvalid;

  /// Loan form: nominal rate field, typed as a percent.
  ///
  /// In fr, this message translates to:
  /// **'Taux nominal'**
  String get mortgageFormRate;

  /// Loan form: unreadable rate.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez un taux, par exemple 3,45.'**
  String get mortgageFormRateInvalid;

  /// Loan form: term field.
  ///
  /// In fr, this message translates to:
  /// **'Durée'**
  String get mortgageFormTerm;

  /// Unit suffix inside the term field.
  ///
  /// In fr, this message translates to:
  /// **'mois'**
  String get mortgageFormTermUnit;

  /// Loan form: missing or zero term.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez une durée en mois.'**
  String get mortgageFormTermInvalid;

  /// Loan form: first instalment date field.
  ///
  /// In fr, this message translates to:
  /// **'1re échéance'**
  String get mortgageFormFirstPayment;

  /// Loan form: unreadable date.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez une date valide.'**
  String get mortgageFormDateInvalid;

  /// Tooltip of the date field's calendar button.
  ///
  /// In fr, this message translates to:
  /// **'Choisir une date'**
  String get mortgageFormCalendar;

  /// Loan form: monthly insurance field.
  ///
  /// In fr, this message translates to:
  /// **'Assurance / mois'**
  String get mortgageFormInsurance;

  /// Loan form: an optional amount that cannot be read.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez un montant valide ou laissez vide.'**
  String get mortgageFormAmountOptionalInvalid;

  /// Loan form: upfront fees field.
  ///
  /// In fr, this message translates to:
  /// **'Frais de dossier'**
  String get mortgageFormFees;

  /// Loan form: optional property link.
  ///
  /// In fr, this message translates to:
  /// **'Bien financé'**
  String get mortgageFormProperty;

  /// Loan form: no property linked.
  ///
  /// In fr, this message translates to:
  /// **'Aucun'**
  String get mortgageFormPropertyNone;

  /// Read-only computed instalment plate label.
  ///
  /// In fr, this message translates to:
  /// **'Mensualité calculée'**
  String get mortgageFormPlateLabel;

  /// Computed instalment plate: total instalment and total interest.
  ///
  /// In fr, this message translates to:
  /// **'échéance totale {instalment} — intérêts totaux {interest}'**
  String mortgageFormPlateDetail(String instalment, String interest);

  /// Computed instalment plate before the inputs are complete.
  ///
  /// In fr, this message translates to:
  /// **'Renseignez le capital, le taux et la durée.'**
  String get mortgageFormPlatePending;

  /// Computed instalment plate for an interest-only loan, which the simulator does not compute.
  ///
  /// In fr, this message translates to:
  /// **'La mensualité d\'un prêt in fine s\'affiche une fois le crédit enregistré.'**
  String get mortgageFormPlateInterestOnly;

  /// Loan form: cancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get mortgageFormCancel;

  /// Loan form: create.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter le crédit'**
  String get mortgageFormSubmit;

  /// Loan form: save edits.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get mortgageFormSave;

  /// Loan form: secondary text button deleting the loan.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le crédit'**
  String get mortgageFormDelete;

  /// Delete confirmation title.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer ce crédit ?'**
  String get mortgageDeleteTitle;

  /// Delete confirmation: both consequences.
  ///
  /// In fr, this message translates to:
  /// **'Il quittera le passif de la Synthèse et, s\'il est rattaché à un bien, la base de l\'IFI.'**
  String get mortgageDeleteBody;

  /// Delete confirmation: confirm.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get mortgageDeleteConfirm;

  /// Inline error for a loan whose instalment does not cover its first interest (422).
  ///
  /// In fr, this message translates to:
  /// **'Ce crédit ne se rembourse pas : l\'échéance ne couvre pas les intérêts du premier mois. Modifiez le taux, le capital ou la durée.'**
  String get mortgageErrorNonAmortizing;

  /// Inline error when upfront fees reach the principal.
  ///
  /// In fr, this message translates to:
  /// **'Les frais de dossier doivent rester inférieurs au capital emprunté.'**
  String get mortgageErrorFeesExceed;

  /// Inline error when the linked property no longer exists.
  ///
  /// In fr, this message translates to:
  /// **'Ce bien n\'existe plus.'**
  String get mortgageErrorPropertyInvalid;

  /// Error when the loan no longer exists.
  ///
  /// In fr, this message translates to:
  /// **'Ce crédit n\'existe plus.'**
  String get mortgageErrorNotFound;

  /// Error for any other rejected loan value.
  ///
  /// In fr, this message translates to:
  /// **'Certaines valeurs sont invalides.'**
  String get mortgageErrorValidation;

  /// Fallback error for loan actions.
  ///
  /// In fr, this message translates to:
  /// **'Une erreur est survenue. Réessayez.'**
  String get mortgageErrorGeneric;

  /// Title of the amortisation table card.
  ///
  /// In fr, this message translates to:
  /// **'Tableau d\'amortissement'**
  String get mortgageScheduleTitle;

  /// Subtitle of the amortisation table: the year's position in the loan's calendar years, its instalment count, and that insurance is counted separately.
  ///
  /// In fr, this message translates to:
  /// **'Année {position} sur {total} · {count, plural, =1{1 échéance} other{{count} échéances}} · l\'assurance est comptée à part'**
  String mortgageScheduleSubtitle(int position, int total, int count);

  /// Subtitle of the amortisation table while the year loads.
  ///
  /// In fr, this message translates to:
  /// **'Année {position} sur {total}'**
  String mortgageScheduleSubtitleLoading(int position, int total);

  /// Amortisation table column: due date. Rendered uppercase.
  ///
  /// In fr, this message translates to:
  /// **'Échéance'**
  String get mortgageScheduleDue;

  /// Amortisation table column: interest. Rendered uppercase.
  ///
  /// In fr, this message translates to:
  /// **'Intérêts'**
  String get mortgageScheduleInterest;

  /// Amortisation table column: principal repaid. Rendered uppercase.
  ///
  /// In fr, this message translates to:
  /// **'Capital'**
  String get mortgageSchedulePrincipal;

  /// Amortisation table column: insurance, kept apart from interest and principal. Rendered uppercase.
  ///
  /// In fr, this message translates to:
  /// **'Assurance'**
  String get mortgageScheduleInsurance;

  /// Amortisation table column: total paid for the instalment. Rendered uppercase.
  ///
  /// In fr, this message translates to:
  /// **'Total versé'**
  String get mortgageScheduleTotalPaid;

  /// Amortisation table column: principal still owed after the instalment. Rendered uppercase.
  ///
  /// In fr, this message translates to:
  /// **'Capital restant dû'**
  String get mortgageScheduleOutstanding;

  /// Amortisation table foot row label for the year's totals.
  ///
  /// In fr, this message translates to:
  /// **'Total {year}'**
  String mortgageScheduleFootTotal(String year);

  /// Amortisation table foot: principal still owed at year end.
  ///
  /// In fr, this message translates to:
  /// **'au {date} : {amount}'**
  String mortgageScheduleFootOutstanding(String date, String amount);

  /// Year switcher: previous year button.
  ///
  /// In fr, this message translates to:
  /// **'Année précédente'**
  String get mortgageScheduleYearPrevious;

  /// Year switcher: next year button.
  ///
  /// In fr, this message translates to:
  /// **'Année suivante'**
  String get mortgageScheduleYearNext;

  /// Error state when a schedule year cannot be loaded.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger le tableau d\'amortissement.'**
  String get mortgageScheduleLoadFailed;

  /// Simulator panel error state when the household or scenarios cannot be loaded.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger le simulateur.'**
  String get simulatorLoadFailed;

  /// Retry button of the simulator error state.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get simulatorRetry;

  /// Title of the simulator input card.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau crédit'**
  String get simulatorFormTitle;

  /// Subtitle of the simulator input card: results are live, nothing is saved.
  ///
  /// In fr, this message translates to:
  /// **'Le résultat se recalcule à chaque saisie'**
  String get simulatorFormSubtitle;

  /// Simulator field: property price.
  ///
  /// In fr, this message translates to:
  /// **'Prix du bien'**
  String get simulatorPrice;

  /// Simulator field: down payment.
  ///
  /// In fr, this message translates to:
  /// **'Apport'**
  String get simulatorDownPayment;

  /// Simulator field: upfront fees.
  ///
  /// In fr, this message translates to:
  /// **'Frais'**
  String get simulatorFees;

  /// Simulator field: borrowed amount, derived from price + fees − down payment until edited.
  ///
  /// In fr, this message translates to:
  /// **'Montant emprunté'**
  String get simulatorPrincipal;

  /// Gray marker pill beside the borrowed amount while it is still derived. Rendered uppercase.
  ///
  /// In fr, this message translates to:
  /// **'Dérivé'**
  String get simulatorDerivedPill;

  /// Simulator field: nominal annual rate, typed as a percent.
  ///
  /// In fr, this message translates to:
  /// **'Taux nominal'**
  String get simulatorRate;

  /// Inline error when the typed rate cannot be read.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez un taux, par exemple 3,25.'**
  String get simulatorRateInvalid;

  /// Simulator field: monthly insurance premium.
  ///
  /// In fr, this message translates to:
  /// **'Assurance / mois'**
  String get simulatorInsurance;

  /// Simulator term slider label, and the HCSF term column label.
  ///
  /// In fr, this message translates to:
  /// **'Durée'**
  String get simulatorTerm;

  /// Term slider value in both units.
  ///
  /// In fr, this message translates to:
  /// **'{months} mois · {years, plural, =1{1 an} other{{years} ans}}'**
  String simulatorTermValue(int months, num years);

  /// A duration in whole years.
  ///
  /// In fr, this message translates to:
  /// **'{years, plural, =1{1 an} other{{years} ans}}'**
  String simulatorYears(num years);

  /// A duration in months.
  ///
  /// In fr, this message translates to:
  /// **'{months} mois'**
  String simulatorMonths(int months);

  /// Switch adding the user's active loans to the HCSF reading.
  ///
  /// In fr, this message translates to:
  /// **'Inclure mes crédits actuels'**
  String get simulatorIncludeExisting;

  /// Sub-line of the existing-loans switch naming what it adds.
  ///
  /// In fr, this message translates to:
  /// **'Ajoute {amount} / mois à la lecture'**
  String simulatorIncludeExistingAdds(String amount);

  /// Sub-line of the existing-loans switch when the user has no active loan.
  ///
  /// In fr, this message translates to:
  /// **'Aucun crédit en cours à ajouter'**
  String get simulatorIncludeExistingNone;

  /// Hero result card label. Rendered uppercase.
  ///
  /// In fr, this message translates to:
  /// **'Échéance mensuelle'**
  String get simulatorInstalmentLabel;

  /// Hero caption: the instalment is the payment plus the insurance, named separately.
  ///
  /// In fr, this message translates to:
  /// **'{payment} de mensualité + {insurance} d\'assurance · {count, plural, =1{1 échéance} other{{count} échéances}}'**
  String simulatorInstalmentCaption(
    String payment,
    String insurance,
    int count,
  );

  /// Hero caption before anything can be computed.
  ///
  /// In fr, this message translates to:
  /// **'Renseignez un prix et un taux pour voir l\'échéance et sa part d\'assurance.'**
  String get simulatorInstalmentEmpty;

  /// Total cost result card label. Rendered uppercase.
  ///
  /// In fr, this message translates to:
  /// **'Coût total'**
  String get simulatorCostLabel;

  /// Total cost caption with its parts and its share of the property price.
  ///
  /// In fr, this message translates to:
  /// **'intérêts {interest} + assurance {insurance} + frais {fees} · {share} du prix'**
  String simulatorCostCaption(
    String interest,
    String insurance,
    String fees,
    String share,
  );

  /// Total cost caption when no price was entered, so there is no share of the price.
  ///
  /// In fr, this message translates to:
  /// **'intérêts {interest} + assurance {insurance} + frais {fees}'**
  String simulatorCostCaptionNoPrice(
    String interest,
    String insurance,
    String fees,
  );

  /// Total cost caption before anything can be computed.
  ///
  /// In fr, this message translates to:
  /// **'Renseignez un prix et un taux pour voir le coût total et sa part du prix.'**
  String get simulatorCostEmpty;

  /// Annual percentage rate result card label.
  ///
  /// In fr, this message translates to:
  /// **'TAEG'**
  String get simulatorTaegLabel;

  /// Iris marker pill always attached to the TAEG. Rendered uppercase.
  ///
  /// In fr, this message translates to:
  /// **'Indicatif'**
  String get simulatorIndicativePill;

  /// TAEG caption.
  ///
  /// In fr, this message translates to:
  /// **'taux, assurance et frais inclus'**
  String get simulatorTaegCaption;

  /// Title of the HCSF reading card.
  ///
  /// In fr, this message translates to:
  /// **'Lecture HCSF'**
  String get simulatorHcsfTitle;

  /// Amber status pill when the reading is above an HCSF reference. Information, never a refusal.
  ///
  /// In fr, this message translates to:
  /// **'Au-dessus du repère'**
  String get simulatorHcsfOver;

  /// HCSF caveat, always shown as body content on the card: no lender is bound by this reading.
  ///
  /// In fr, this message translates to:
  /// **'Informative — ne lie aucun prêteur'**
  String get simulatorHcsfCaveat;

  /// The HCSF reference beside a reading.
  ///
  /// In fr, this message translates to:
  /// **'repère {value}'**
  String simulatorReference(String value);

  /// HCSF card: debt ratio column label.
  ///
  /// In fr, this message translates to:
  /// **'Taux d\'endettement'**
  String get simulatorRatioLabel;

  /// Debt ratio caption: the instalment against the income and where the income came from.
  ///
  /// In fr, this message translates to:
  /// **'{instalment} sur un revenu {source, select, declared{déclaré} other{médian constaté}} de {income}'**
  String simulatorRatioCaption(String instalment, String source, String income);

  /// Debt ratio caption with the current loans counted.
  ///
  /// In fr, this message translates to:
  /// **'{instalment} + crédits actuels {existing} sur un revenu {source, select, declared{déclaré} other{médian constaté}} de {income}'**
  String simulatorRatioCaptionWithExisting(
    String instalment,
    String existing,
    String source,
    String income,
  );

  /// Debt ratio caption before anything can be computed.
  ///
  /// In fr, this message translates to:
  /// **'Renseignez un prix et un taux pour lire le taux d\'endettement.'**
  String get simulatorRatioEmpty;

  /// HCSF card when no income is known: no ratio and no capacity.
  ///
  /// In fr, this message translates to:
  /// **'Aucun revenu connu : le grand livre n\'a pas de revenus réguliers et aucun revenu n\'est déclaré. Sans revenu, ni taux ni capacité ne peuvent être lus.'**
  String get simulatorRatioUnknown;

  /// Outline button offering to declare an income when none is known.
  ///
  /// In fr, this message translates to:
  /// **'Déclarer un revenu'**
  String get simulatorDeclareIncome;

  /// HCSF term caption when the term equals the maximum.
  ///
  /// In fr, this message translates to:
  /// **'au repère, pas au-delà'**
  String get simulatorTermAtReference;

  /// HCSF term caption when the term is shorter than the maximum.
  ///
  /// In fr, this message translates to:
  /// **'sous le repère'**
  String get simulatorTermUnderReference;

  /// HCSF term caption when the term is longer than the maximum. Information only.
  ///
  /// In fr, this message translates to:
  /// **'au-delà du repère'**
  String get simulatorTermOverReference;

  /// HCSF card: borrowing capacity column label.
  ///
  /// In fr, this message translates to:
  /// **'Capacité d\'emprunt au repère'**
  String get simulatorCapacityLabel;

  /// Capacity caption: the instalment still available under the reference.
  ///
  /// In fr, this message translates to:
  /// **'{available} d\'échéance disponibles sous {limit}, à ces conditions'**
  String simulatorCapacityCaption(String available, String limit);

  /// Capacity caption when the current loans use up the room under the reference: explains the cause calmly.
  ///
  /// In fr, this message translates to:
  /// **'il ne reste que {available} d\'échéance sous le repère une fois vos crédits actuels comptés — c\'est ce qui rend la capacité si faible, pas le bien visé'**
  String simulatorCapacityCaptionExisting(String available);

  /// Capacity caption before anything can be computed.
  ///
  /// In fr, this message translates to:
  /// **'Renseignez un prix et un taux pour lire la capacité d\'emprunt.'**
  String get simulatorCapacityEmpty;

  /// Title of the yearly projection chart.
  ///
  /// In fr, this message translates to:
  /// **'Projection annuelle'**
  String get simulatorChartTitle;

  /// Subtitle of the yearly projection chart.
  ///
  /// In fr, this message translates to:
  /// **'Capital remboursé et intérêts versés, année par année'**
  String get simulatorChartSubtitle;

  /// Projection legend: principal repaid.
  ///
  /// In fr, this message translates to:
  /// **'Capital'**
  String get simulatorChartCapital;

  /// Projection legend: interest paid.
  ///
  /// In fr, this message translates to:
  /// **'Intérêts'**
  String get simulatorChartInterest;

  /// Projection chart invitation before anything can be computed.
  ///
  /// In fr, this message translates to:
  /// **'Renseignez un prix et un taux : la répartition capital / intérêts par année s\'affiche ici.'**
  String get simulatorChartEmpty;

  /// Banner when a live compute fails for a reason no field explains.
  ///
  /// In fr, this message translates to:
  /// **'Le calcul n\'a pas abouti. Réessayez dans un instant.'**
  String get simulatorComputeFailed;

  /// Inline error under the rate when the engine refuses a loan that never amortises.
  ///
  /// In fr, this message translates to:
  /// **'À ce taux, l\'échéance ne rembourse pas le capital : baissez le taux ou allongez la durée.'**
  String get simulatorErrorNonAmortizing;

  /// Inline error under the fees when they are not smaller than the borrowed amount.
  ///
  /// In fr, this message translates to:
  /// **'Les frais doivent rester inférieurs au montant emprunté.'**
  String get simulatorErrorFeesExceed;

  /// Generic validation refusal.
  ///
  /// In fr, this message translates to:
  /// **'Certaines valeurs ne sont pas acceptées.'**
  String get simulatorErrorValidation;

  /// Fallback simulator error.
  ///
  /// In fr, this message translates to:
  /// **'Une erreur est survenue. Réessayez.'**
  String get simulatorErrorGeneric;

  /// Title of the declare-income modal opened from the simulator.
  ///
  /// In fr, this message translates to:
  /// **'Déclarer un revenu'**
  String get simulatorIncomeTitle;

  /// Body of the declare-income modal.
  ///
  /// In fr, this message translates to:
  /// **'Le revenu mensuel déclaré sert de base au taux d\'endettement et à la capacité d\'emprunt.'**
  String get simulatorIncomeBody;

  /// Declare-income modal field label.
  ///
  /// In fr, this message translates to:
  /// **'Revenu mensuel net'**
  String get simulatorIncomeLabel;

  /// Declare-income modal validation error.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez un montant supérieur à zéro.'**
  String get simulatorIncomeInvalid;

  /// Declare-income modal submit button.
  ///
  /// In fr, this message translates to:
  /// **'Déclarer'**
  String get simulatorIncomeSubmit;

  /// Declare-income modal banner when the save fails.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'enregistrer ce revenu. Réessayez.'**
  String get simulatorIncomeFailed;

  /// Cancel button of the simulator modals.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get simulatorCancel;

  /// Secondary top-bar button saving the current inputs as a scenario, and the save modal title.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer le scénario'**
  String get simulatorSaveScenario;

  /// Save-scenario modal body: a scenario stores inputs only.
  ///
  /// In fr, this message translates to:
  /// **'Seules les valeurs saisies sont enregistrées : le résultat est recalculé à chaque fois.'**
  String get simulatorSaveBody;

  /// Save-scenario modal name field label.
  ///
  /// In fr, this message translates to:
  /// **'Nom'**
  String get simulatorSaveName;

  /// Prefill of the scenario name on the « lieu — prix k€ » pattern, with an empty place slot before the dash for the user to type into. Keep the leading space.
  ///
  /// In fr, this message translates to:
  /// **' — {price}'**
  String simulatorSaveNamePrefill(String price);

  /// Save-scenario modal validation error.
  ///
  /// In fr, this message translates to:
  /// **'Donnez un nom au scénario.'**
  String get simulatorSaveNameRequired;

  /// Save-scenario modal submit button.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get simulatorSaveSubmit;

  /// A property price in thousands of euros, as scenario names read it.
  ///
  /// In fr, this message translates to:
  /// **'{amount} k€'**
  String simulatorPriceThousands(String amount);

  /// Save refused because the per-user scenario cap is reached.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez atteint le nombre maximal de scénarios enregistrés. Supprimez-en un pour en ajouter un autre.'**
  String get simulatorErrorLimitReached;

  /// A scenario was deleted elsewhere.
  ///
  /// In fr, this message translates to:
  /// **'Ce scénario n\'existe plus.'**
  String get simulatorErrorNotFound;

  /// Title of the saved scenarios card.
  ///
  /// In fr, this message translates to:
  /// **'Scénarios enregistrés'**
  String get simulatorScenariosTitle;

  /// Outline button opening the side-by-side comparison, with the checked count and the cap.
  ///
  /// In fr, this message translates to:
  /// **'Comparer ({count}/{max})'**
  String simulatorCompareButton(int count, int max);

  /// Why the compare button is disabled with fewer than two rows checked.
  ///
  /// In fr, this message translates to:
  /// **'Cochez au moins deux scénarios pour les comparer.'**
  String get simulatorCompareNeedsTwo;

  /// Note under the list at the cap, naming the one row left out.
  ///
  /// In fr, this message translates to:
  /// **'Trois scénarios au plus, pour rester lisibles côte à côte. Décochez-en un pour ajouter {name}.'**
  String simulatorCompareCapNamed(String name);

  /// Note under the list at the cap when several rows are left out.
  ///
  /// In fr, this message translates to:
  /// **'Trois scénarios au plus, pour rester lisibles côte à côte. Décochez-en un pour en ajouter un autre.'**
  String get simulatorCompareCap;

  /// Iris marker pill on the live, unsaved simulation row. Rendered uppercase.
  ///
  /// In fr, this message translates to:
  /// **'En cours'**
  String get simulatorLivePill;

  /// Name of the live row before a price gives it one.
  ///
  /// In fr, this message translates to:
  /// **'Simulation en cours'**
  String get simulatorLiveName;

  /// Scenario row sub-line: rate, term and instalment.
  ///
  /// In fr, this message translates to:
  /// **'{rate} · {term} · {instalment}'**
  String simulatorScenarioSub(String rate, String term, String instalment);

  /// Scenario row sub-line before its instalment is known.
  ///
  /// In fr, this message translates to:
  /// **'{rate} · {term}'**
  String simulatorScenarioSubNoInstalment(String rate, String term);

  /// Tooltip of a scenario row's overflow menu.
  ///
  /// In fr, this message translates to:
  /// **'Actions du scénario'**
  String get simulatorScenarioActions;

  /// Scenario overflow action: hard delete, no confirmation.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get simulatorScenarioDelete;

  /// Semantic label of a scenario row checkbox.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionner {name} pour la comparaison'**
  String simulatorScenarioSelect(String name);

  /// Mini empty state of the scenarios card.
  ///
  /// In fr, this message translates to:
  /// **'Aucun scénario enregistré'**
  String get simulatorScenariosEmptyTitle;

  /// Mini empty state body of the scenarios card.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrez une simulation pour la retrouver ici et la comparer à deux autres.'**
  String get simulatorScenariosEmptyBody;

  /// Title of the comparison card.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{Comparaison d\'un scénario} other{Comparaison de {count} scénarios}}'**
  String simulatorCompareTitle(int count);

  /// Subtitle of the comparison card.
  ///
  /// In fr, this message translates to:
  /// **'Mêmes lignes pour chaque colonne · un tiret quand la donnée ne s\'applique pas'**
  String get simulatorCompareSubtitle;

  /// Secondary button closing the comparison.
  ///
  /// In fr, this message translates to:
  /// **'Fermer la comparaison'**
  String get simulatorCompareClose;

  /// Comparison card when a column cannot be computed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de calculer la comparaison.'**
  String get simulatorCompareFailed;

  /// Comparison row: total interest.
  ///
  /// In fr, this message translates to:
  /// **'Intérêts totaux'**
  String get simulatorCompareTotalInterest;

  /// Comparison row: total insurance.
  ///
  /// In fr, this message translates to:
  /// **'Assurance totale'**
  String get simulatorCompareTotalInsurance;

  /// Comparison row: total cost over the property price.
  ///
  /// In fr, this message translates to:
  /// **'Coût / prix'**
  String get simulatorCompareCostShare;

  /// Comparison row: indicative TAEG. Always labelled indicative.
  ///
  /// In fr, this message translates to:
  /// **'TAEG indicatif'**
  String get simulatorCompareTaeg;

  /// Comparison row: debt ratio with the current loans counted.
  ///
  /// In fr, this message translates to:
  /// **'Avec crédits actuels'**
  String get simulatorCompareWithExisting;

  /// Comparison foot: the income the ratios are read against, the reference, and the no-lender-is-bound statement.
  ///
  /// In fr, this message translates to:
  /// **'Taux d\'endettement sur un revenu {source, select, declared{déclaré} other{médian constaté}} de {income} · repère HCSF {limit} · lecture informative, ne lie aucun prêteur.'**
  String simulatorCompareFoot(String source, String income, String limit);

  /// Comparison foot when no income is known.
  ///
  /// In fr, this message translates to:
  /// **'Aucun revenu connu, donc aucun taux d\'endettement · repère HCSF {limit} · lecture informative, ne lie aucun prêteur.'**
  String simulatorCompareFootUnknown(String limit);

  /// Property nature: the household's main home (wire value primary_residence).
  ///
  /// In fr, this message translates to:
  /// **'Résidence principale'**
  String get propertyKindPrimaryResidence;

  /// Property nature: a property let to tenants (wire value rental).
  ///
  /// In fr, this message translates to:
  /// **'Locatif'**
  String get propertyKindRental;

  /// Property nature: a second home (wire value secondary).
  ///
  /// In fr, this message translates to:
  /// **'Résidence secondaire'**
  String get propertyKindSecondary;

  /// Property nature: land or anything else (wire value other).
  ///
  /// In fr, this message translates to:
  /// **'Autre bien'**
  String get propertyKindOther;

  /// Title of the property form when declaring a new property.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau bien'**
  String get propertyFormCreateTitle;

  /// Title of the property form when editing an existing property.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le bien'**
  String get propertyFormEditTitle;

  /// Subtitle under the property form title.
  ///
  /// In fr, this message translates to:
  /// **'La valeur déclarée entre dans la synthèse.'**
  String get propertyFormSubtitle;

  /// Property form field: the property's name.
  ///
  /// In fr, this message translates to:
  /// **'Libellé'**
  String get propertyFormLabel;

  /// Validation message when the property name is empty.
  ///
  /// In fr, this message translates to:
  /// **'Donnez un nom à ce bien.'**
  String get propertyFormLabelRequired;

  /// Property form field: the property's nature (select).
  ///
  /// In fr, this message translates to:
  /// **'Nature'**
  String get propertyFormKind;

  /// Property form field: the declared market value.
  ///
  /// In fr, this message translates to:
  /// **'Valeur déclarée'**
  String get propertyFormValue;

  /// Property form field: the date the value was estimated.
  ///
  /// In fr, this message translates to:
  /// **'Date d\'estimation'**
  String get propertyFormValuedOn;

  /// Property form field: the user's ownership share, typed as a percent.
  ///
  /// In fr, this message translates to:
  /// **'Quote-part détenue'**
  String get propertyFormOwnership;

  /// Live label beside the ownership field: the held share of the declared value.
  ///
  /// In fr, this message translates to:
  /// **'part : {amount}'**
  String propertyFormOwnershipShare(String amount);

  /// Validation message when the ownership share is not between 0.01 and 100 percent.
  ///
  /// In fr, this message translates to:
  /// **'Indiquez une quote-part entre 0,01 et 100 %.'**
  String get propertyFormOwnershipInvalid;

  /// Property form field: the optional purchase price.
  ///
  /// In fr, this message translates to:
  /// **'Prix d\'acquisition'**
  String get propertyFormAcquisitionPrice;

  /// Property form field: the optional purchase date.
  ///
  /// In fr, this message translates to:
  /// **'Date d\'acquisition'**
  String get propertyFormAcquiredOn;

  /// Validation message when a required amount is missing or not positive.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez un montant supérieur à zéro.'**
  String get propertyFormAmountInvalid;

  /// Validation message when an optional amount cannot be read.
  ///
  /// In fr, this message translates to:
  /// **'Montant illisible — laissez vide s\'il est inconnu.'**
  String get propertyFormAmountOptionalInvalid;

  /// Validation message when a date cannot be read.
  ///
  /// In fr, this message translates to:
  /// **'Date invalide (JJ/MM/AAAA).'**
  String get propertyFormDateInvalid;

  /// Tooltip of the calendar button beside a date field.
  ///
  /// In fr, this message translates to:
  /// **'Choisir une date'**
  String get propertyFormCalendar;

  /// Cancel action on the property modals.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get propertyFormCancel;

  /// Primary action of the new-property form.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter le bien'**
  String get propertyFormSubmit;

  /// Primary action of the edit-property form.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get propertyFormSave;

  /// Title of the modal that records a new declared value for a property.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle estimation'**
  String get propertyRevalueTitle;

  /// Subtitle of the new-valuation modal: the current declared value, and that the new one replaces it.
  ///
  /// In fr, this message translates to:
  /// **'{label} : {value} estimés le {date}. La nouvelle estimation remplace celle-ci.'**
  String propertyRevalueSubtitle(String label, String value, String date);

  /// Primary action of the new-valuation modal.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer l\'estimation'**
  String get propertyRevalueSubmit;

  /// Error when the valuation date is after today (PROPERTY_VALUATION_IN_FUTURE).
  ///
  /// In fr, this message translates to:
  /// **'Une date d\'estimation ne peut pas être dans le futur.'**
  String get propertyErrorValuationInFuture;

  /// Error when the property was not found (PROPERTY_NOT_FOUND).
  ///
  /// In fr, this message translates to:
  /// **'Ce bien n\'existe plus.'**
  String get propertyErrorNotFound;

  /// Error when the server rejected the payload (VALIDATION_ERROR).
  ///
  /// In fr, this message translates to:
  /// **'Certaines valeurs ont été refusées. Vérifiez le formulaire.'**
  String get propertyErrorValidation;

  /// Fallback error for a failed property write.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'enregistrer le bien. Réessayez.'**
  String get propertyErrorGeneric;

  /// Caption under a wholly owned property's value: the date of the declared estimate.
  ///
  /// In fr, this message translates to:
  /// **'valeur déclarée · estimée le {date}'**
  String propertyCardCaptionWhole(String date);

  /// Caption under a partly owned property's held value: the full declared value and its date.
  ///
  /// In fr, this message translates to:
  /// **'part détenue · sur {value} estimés le {date}'**
  String propertyCardCaptionPart(String value, String date);

  /// Property card row: the user's ownership share.
  ///
  /// In fr, this message translates to:
  /// **'Quote-part'**
  String get propertyCardOwnership;

  /// Property card row: purchase price and date.
  ///
  /// In fr, this message translates to:
  /// **'Prix d\'acquisition'**
  String get propertyCardAcquisition;

  /// Property card value: purchase price followed by its date.
  ///
  /// In fr, this message translates to:
  /// **'{price} · {date}'**
  String propertyCardAcquisitionValue(String price, String date);

  /// Property card row: how the held value compares with the held purchase price.
  ///
  /// In fr, this message translates to:
  /// **'Depuis l\'acquisition'**
  String get propertyCardSinceAcquisition;

  /// Property card value: the held value is this much above the purchase price; '(part)' when only a share is held.
  ///
  /// In fr, this message translates to:
  /// **'{amount} au-dessus{partial, select, true{ (part)} other{}}'**
  String propertyCardAbove(String amount, String partial);

  /// Property card value: the held value is this much below the purchase price; '(part)' when only a share is held.
  ///
  /// In fr, this message translates to:
  /// **'{amount} en dessous{partial, select, true{ (part)} other{}}'**
  String propertyCardBelow(String amount, String partial);

  /// Tooltip of a property card's overflow menu.
  ///
  /// In fr, this message translates to:
  /// **'Actions'**
  String get propertyMenuTooltip;

  /// Property menu: edit the property.
  ///
  /// In fr, this message translates to:
  /// **'Modifier'**
  String get propertyMenuEdit;

  /// Property menu: record a new declared value.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle estimation'**
  String get propertyMenuRevalue;

  /// Property menu: archive the property.
  ///
  /// In fr, this message translates to:
  /// **'Archiver'**
  String get propertyMenuArchive;

  /// Property menu on an archived property: bring it back.
  ///
  /// In fr, this message translates to:
  /// **'Désarchiver'**
  String get propertyMenuUnarchive;

  /// Dashed tile at the end of the property grid.
  ///
  /// In fr, this message translates to:
  /// **'+ Nouveau bien'**
  String get propertiesNewTileTitle;

  /// Line under the new-property tile.
  ///
  /// In fr, this message translates to:
  /// **'Résidence, locatif, terrain ou autre'**
  String get propertiesNewTileBody;

  /// Foot link that reveals archived properties; the count is the real number.
  ///
  /// In fr, this message translates to:
  /// **'Afficher les biens archivés ({count})'**
  String propertiesShowArchived(int count);

  /// The same link once archived properties are showing.
  ///
  /// In fr, this message translates to:
  /// **'Masquer les biens archivés ({count})'**
  String propertiesHideArchived(int count);

  /// Tooltip of the dismiss control on a property action error.
  ///
  /// In fr, this message translates to:
  /// **'Fermer'**
  String get propertiesDismiss;

  /// Segmented control on the net-worth panel: the summary view.
  ///
  /// In fr, this message translates to:
  /// **'Synthèse'**
  String get networthViewSummary;

  /// Segmented control on the net-worth panel: the property list, with the live property count.
  ///
  /// In fr, this message translates to:
  /// **'Biens ({count})'**
  String networthViewProperties(int count);

  /// Top-bar and empty-state action that opens the new-property form.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau bien'**
  String get networthAddProperty;

  /// Label of the net-worth hero card.
  ///
  /// In fr, this message translates to:
  /// **'Patrimoine net'**
  String get networthHeroLabel;

  /// Caption beside the month delta pill: the month it is measured against.
  ///
  /// In fr, this message translates to:
  /// **'vs {month}'**
  String networthDeltaCaption(String month);

  /// Caption beside the month delta pill when property values are held flat.
  ///
  /// In fr, this message translates to:
  /// **'vs {month} — valeur des biens inchangée'**
  String networthDeltaCaptionFlat(String month);

  /// Label of the assets card.
  ///
  /// In fr, this message translates to:
  /// **'Actif'**
  String get networthAssetsLabel;

  /// Caption of the assets card: accounts and held property shares.
  ///
  /// In fr, this message translates to:
  /// **'Comptes {accounts} · Biens {properties}'**
  String networthAssetsCaption(String accounts, String properties);

  /// Caption of the assets card when no property is declared.
  ///
  /// In fr, this message translates to:
  /// **'Comptes {accounts} · aucun bien déclaré'**
  String networthAssetsCaptionNoProperty(String accounts);

  /// Label of the liabilities card.
  ///
  /// In fr, this message translates to:
  /// **'Passif'**
  String get networthLiabilitiesLabel;

  /// Caption of the liabilities card: how many active loans the outstanding principal comes from.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucun crédit} =1{1 crédit} other{{count} crédits}} · capital restant dû'**
  String networthLiabilitiesCaption(int count);

  /// Title of the asset composition card.
  ///
  /// In fr, this message translates to:
  /// **'Composition de l\'actif'**
  String get networthCompositionTitle;

  /// Subtitle of the asset composition card.
  ///
  /// In fr, this message translates to:
  /// **'Comptes par type, biens par nature'**
  String get networthCompositionSubtitle;

  /// Composition row: checking accounts.
  ///
  /// In fr, this message translates to:
  /// **'Comptes courants'**
  String get networthCompositionChecking;

  /// Composition row: savings accounts.
  ///
  /// In fr, this message translates to:
  /// **'Épargne'**
  String get networthCompositionSavings;

  /// Composition row: credit accounts.
  ///
  /// In fr, this message translates to:
  /// **'Comptes de crédit'**
  String get networthCompositionCredit;

  /// Composition row: deferred-debit card accounts.
  ///
  /// In fr, this message translates to:
  /// **'Cartes à débit différé'**
  String get networthCompositionDeferredCard;

  /// Composition row: cash accounts.
  ///
  /// In fr, this message translates to:
  /// **'Espèces'**
  String get networthCompositionCash;

  /// Composition row: accounts of any other type.
  ///
  /// In fr, this message translates to:
  /// **'Autres comptes'**
  String get networthCompositionOtherAccounts;

  /// Composition row label for a property kind counted at a held share only.
  ///
  /// In fr, this message translates to:
  /// **'{label} (part détenue)'**
  String networthCompositionHeldShare(String label);

  /// Composition foot when every property is wholly owned.
  ///
  /// In fr, this message translates to:
  /// **'Les biens comptent pour la part détenue seulement.'**
  String get networthCompositionFootWhole;

  /// Composition foot naming each partly owned property with its held share and declared value.
  ///
  /// In fr, this message translates to:
  /// **'Les biens comptent pour la part détenue seulement ({items}).'**
  String networthCompositionFoot(String items);

  /// One partly owned property in the composition foot.
  ///
  /// In fr, this message translates to:
  /// **'{label} : {share} sur {value}'**
  String networthCompositionFootItem(String label, String share, String value);

  /// Dashed plate under the composition when no property is declared.
  ///
  /// In fr, this message translates to:
  /// **'Aucun bien déclaré : l\'actif ne compte que vos comptes.'**
  String get networthCompositionInvite;

  /// Link in the no-property plate that opens the new-property form.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau bien →'**
  String get networthCompositionInviteAction;

  /// Section label of the card listing what net worth deliberately leaves out.
  ///
  /// In fr, this message translates to:
  /// **'Volontairement non compté'**
  String get networthExclusionsLabel;

  /// Exclusion: savings goals.
  ///
  /// In fr, this message translates to:
  /// **'Objectifs'**
  String get networthExclusionGoalsTitle;

  /// Why goals are not counted in net worth.
  ///
  /// In fr, this message translates to:
  /// **'Une allocation étiquette de l\'argent déjà présent sur un compte — le compter reviendrait à le compter deux fois.'**
  String get networthExclusionGoalsBody;

  /// Exclusion: subscriptions.
  ///
  /// In fr, this message translates to:
  /// **'Abonnements'**
  String get networthExclusionSubscriptionsTitle;

  /// Why subscriptions are not counted as liabilities.
  ///
  /// In fr, this message translates to:
  /// **'Un prélèvement récurrent est une dépense à venir, pas une dette due aujourd\'hui.'**
  String get networthExclusionSubscriptionsBody;

  /// Empty-state title when there are no accounts, properties or loans.
  ///
  /// In fr, this message translates to:
  /// **'Rien à additionner pour l\'instant'**
  String get networthEmptyTitle;

  /// Empty-state body of the net-worth panel.
  ///
  /// In fr, this message translates to:
  /// **'Importez un compte ou déclarez un bien : la synthèse additionne ce que vous possédez et soustrait vos crédits, sans rien inventer entre les deux.'**
  String get networthEmptyBody;

  /// Empty-state secondary action that goes to imports.
  ///
  /// In fr, this message translates to:
  /// **'Importer un fichier'**
  String get networthEmptyImport;

  /// Error state when the net-worth summary or the properties cannot be loaded.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger la synthèse.'**
  String get networthLoadFailed;

  /// Retry action on the net-worth error state.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get networthRetry;
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
