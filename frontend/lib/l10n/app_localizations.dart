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
  /// **'Bastide'**
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

  /// Sidebar group label, sentence case, over the dashboard, accounts and transactions destinations.
  ///
  /// In fr, this message translates to:
  /// **'Vue d’ensemble'**
  String get navSectionOverview;

  /// Sidebar group label, sentence case, over the imports, categories, recurring and goals destinations.
  ///
  /// In fr, this message translates to:
  /// **'Gestion'**
  String get navSectionManage;

  /// Accessible name of the group of window controls (minimize, maximize, close) drawn by the app on Windows and Linux.
  ///
  /// In fr, this message translates to:
  /// **'Fenêtre'**
  String get windowControls;

  /// Tooltip and accessible label of the window control that minimizes the window.
  ///
  /// In fr, this message translates to:
  /// **'Réduire'**
  String get windowMinimize;

  /// Tooltip and accessible label of the window control that maximizes the window.
  ///
  /// In fr, this message translates to:
  /// **'Agrandir'**
  String get windowMaximize;

  /// Tooltip and accessible label of the window control that restores a maximized window to its previous size.
  ///
  /// In fr, this message translates to:
  /// **'Restaurer'**
  String get windowRestore;

  /// Tooltip and accessible label of the window control that closes the window, and the app with it.
  ///
  /// In fr, this message translates to:
  /// **'Fermer'**
  String get windowClose;

  /// Label of the button just above « Paramètres » that collapses the sidebar to its icon rail.
  ///
  /// In fr, this message translates to:
  /// **'Replier'**
  String get sidebarCollapse;

  /// Tooltip and accessible label of the sidebar's collapse button, naming its keyboard shortcut.
  ///
  /// In fr, this message translates to:
  /// **'Replier la barre latérale (Ctrl+B)'**
  String get sidebarCollapseTooltip;

  /// Tooltip and accessible label of the collapsed sidebar's expand button, naming its keyboard shortcut.
  ///
  /// In fr, this message translates to:
  /// **'Déplier la barre latérale (Ctrl+B)'**
  String get sidebarExpandTooltip;

  /// Privacy line at the foot of the sidebar, beside a lock glyph. On the collapsed sidebar it becomes the lock's tooltip.
  ///
  /// In fr, this message translates to:
  /// **'Données locales'**
  String get sidebarPrivacyBadge;

  /// Accessible label of the review count beside « Transactions » in the sidebar.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 opération à vérifier} other{{count} opérations à vérifier}}'**
  String sidebarReviewCount(int count);

  /// Item in the sidebar user menu that ends the session.
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

  /// Settings › Préférences: title of the group holding theme, text size, language and formats.
  ///
  /// In fr, this message translates to:
  /// **'Affichage'**
  String get settingsGroupDisplay;

  /// Settings › Préférences: title of the group holding currency and declared income.
  ///
  /// In fr, this message translates to:
  /// **'Argent'**
  String get settingsGroupMoney;

  /// Settings › Préférences: description of the formats row.
  ///
  /// In fr, this message translates to:
  /// **'Dates et montants suivent la langue choisie.'**
  String get settingsFormatsNote;

  /// Settings › Préférences: one sample date in its long and short forms.
  ///
  /// In fr, this message translates to:
  /// **'{long} · {short}'**
  String settingsFormatsDatePair(String long, String short);

  /// Settings › Préférences: the user's currency, read-only: ISO code, name (authCurrencyName), symbol.
  ///
  /// In fr, this message translates to:
  /// **'{code}, {name} ({symbol})'**
  String settingsCurrencyValue(String code, String name, String symbol);

  /// Settings › Préférences: name of the savings-rate goal row.
  ///
  /// In fr, this message translates to:
  /// **'Objectif de taux d’épargne'**
  String get settingsSavingsGoalTitle;

  /// Settings › Préférences: description of the savings-rate goal row; the goal is the mark on the dashboard's savings-rate meter.
  ///
  /// In fr, this message translates to:
  /// **'Le repère affiché sur le tableau de bord.'**
  String get settingsSavingsGoalNote;

  /// Settings › Préférences: name of the declared monthly income row.
  ///
  /// In fr, this message translates to:
  /// **'Revenu déclaré'**
  String get settingsIncomeTitle;

  /// Settings › Préférences: description of the declared income row.
  ///
  /// In fr, this message translates to:
  /// **'Sert au taux d’endettement des panneaux Crédits et Simulateur. Sans lui, Bastide prend le revenu médian constaté.'**
  String get settingsIncomeNote;

  /// Settings › Préférences: unit after the declared income field.
  ///
  /// In fr, this message translates to:
  /// **'par mois'**
  String get settingsIncomePerMonth;

  /// Settings › Préférences: helper when the declared income cannot be read.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez un montant positif, ou laissez vide.'**
  String get settingsIncomeInvalid;

  /// Settings › Préférences: toast when saving the declared income fails.
  ///
  /// In fr, this message translates to:
  /// **'Le revenu n’a pas pu être enregistré. Rien n’a été modifié. Réessayez.'**
  String get settingsIncomeSaveFailed;

  /// Settings › Profil: title of the group holding the recovery code.
  ///
  /// In fr, this message translates to:
  /// **'Sécurité'**
  String get settingsGroupSecurity;

  /// Settings › Profil: title of the group holding sign-out.
  ///
  /// In fr, this message translates to:
  /// **'Session'**
  String get settingsGroupSession;

  /// Settings › Profil: name of the email row.
  ///
  /// In fr, this message translates to:
  /// **'Adresse e-mail'**
  String get settingsEmailTitle;

  /// Settings › Profil: description of the email row.
  ///
  /// In fr, this message translates to:
  /// **'Sert uniquement à vous connecter. Bastide n’envoie aucun message.'**
  String get settingsEmailNote;

  /// Settings › Profil: description of the username row.
  ///
  /// In fr, this message translates to:
  /// **'Vous pouvez vous connecter avec ce nom ou avec votre e-mail.'**
  String get settingsProfileNameNote;

  /// Settings › Profil: name of the sign-out row.
  ///
  /// In fr, this message translates to:
  /// **'Se déconnecter'**
  String get settingsLogoutTitle;

  /// Settings › Profil: description of the sign-out row.
  ///
  /// In fr, this message translates to:
  /// **'Vos données restent sur cet ordinateur, protégées par votre mot de passe.'**
  String get settingsLogoutNote;

  /// Settings › Données: name of the row holding the engine address, the model and the test button.
  ///
  /// In fr, this message translates to:
  /// **'Moteur'**
  String get settingsAiEngineTitle;

  /// Settings › Données: status text when the local engine answered.
  ///
  /// In fr, this message translates to:
  /// **'Connecté'**
  String get settingsAiConnected;

  /// Settings › Données: follows « Connecté », the number of models the engine lists.
  ///
  /// In fr, this message translates to:
  /// **'· {count, plural, =0{aucun modèle disponible} =1{1 modèle disponible} other{{count} modèles disponibles}}'**
  String settingsAiModelCount(int count);

  /// Settings › Données: name of the confidence threshold row.
  ///
  /// In fr, this message translates to:
  /// **'Seuil de confiance'**
  String get settingsAiThresholdTitle;

  /// Settings › Données: banner under the restore row when a file was refused; reason is one of the settingsBackupError messages.
  ///
  /// In fr, this message translates to:
  /// **'Restauration impossible. {reason}'**
  String settingsBackupRestoreRefused(String reason);

  /// Settings › Données: name of the reset row.
  ///
  /// In fr, this message translates to:
  /// **'Réinitialiser la base de données'**
  String get settingsResetRowTitle;

  /// Settings › Données: banner under the reset row when the reset was refused.
  ///
  /// In fr, this message translates to:
  /// **'Réinitialisation impossible. {reason}'**
  String settingsResetRefused(String reason);

  /// Settings › À propos: under « Bastide » in the header, the app version and the operating system.
  ///
  /// In fr, this message translates to:
  /// **'Version {version} · {os}'**
  String settingsAboutVersionLine(String version, String os);

  /// Settings › À propos: the operating system's name, by Flutter's Platform.operatingSystem.
  ///
  /// In fr, this message translates to:
  /// **'{os, select, windows{Windows} macos{macOS} linux{Linux} other{{os}}}'**
  String settingsAboutOs(String os);

  /// Settings › À propos: status text when no newer release exists.
  ///
  /// In fr, this message translates to:
  /// **'Vous utilisez la dernière version.'**
  String get settingsUpdatesLatest;

  /// Settings › À propos: secondary button that asks for the latest release again.
  ///
  /// In fr, this message translates to:
  /// **'Vérifier maintenant'**
  String get settingsUpdatesCheckNow;

  /// Settings › À propos: name of the privacy row.
  ///
  /// In fr, this message translates to:
  /// **'Confidentialité'**
  String get settingsAboutPrivacyTitle;

  /// Settings › À propos: description of the privacy row.
  ///
  /// In fr, this message translates to:
  /// **'Ce que Bastide fait de vos données.'**
  String get settingsAboutPrivacyNote;

  /// Settings › À propos: name of the row showing the database file path.
  ///
  /// In fr, this message translates to:
  /// **'Emplacement des données'**
  String get settingsAboutDataTitle;

  /// Settings › À propos: description of the data location row.
  ///
  /// In fr, this message translates to:
  /// **'Le fichier qui contient tout votre historique.'**
  String get settingsAboutDataNote;

  /// Settings › À propos: secondary button that opens the data folder.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir le dossier'**
  String get settingsAboutDataOpen;

  /// Settings › À propos: name of the licence row.
  ///
  /// In fr, this message translates to:
  /// **'Licence'**
  String get settingsAboutLicenseTitle;

  /// Settings › À propos: description of the licence row.
  ///
  /// In fr, this message translates to:
  /// **'Bastide est un logiciel libre. Son nom et son logo ne sont pas couverts par la licence.'**
  String get settingsAboutLicenseNote;

  /// Settings › À propos: the licence's official name, untranslated.
  ///
  /// In fr, this message translates to:
  /// **'GNU Affero General Public License v3.0'**
  String get settingsAboutLicenseName;

  /// Settings › À propos: secondary button opening the source repository.
  ///
  /// In fr, this message translates to:
  /// **'Code source'**
  String get settingsAboutSourceCode;

  /// Settings › À propos: secondary button opening the installation guide.
  ///
  /// In fr, this message translates to:
  /// **'Guide d’installation'**
  String get settingsAboutInstallGuide;

  /// Settings › À propos: description of the credits row.
  ///
  /// In fr, this message translates to:
  /// **'Les composants tiers fournis avec l’application.'**
  String get settingsAboutCreditsNote;

  /// Settings › À propos: credits key for the icon set.
  ///
  /// In fr, this message translates to:
  /// **'Icônes'**
  String get settingsAboutCreditsIconsLabel;

  /// Settings › À propos: credits key for the typeface.
  ///
  /// In fr, this message translates to:
  /// **'Police'**
  String get settingsAboutCreditsFontLabel;

  /// Settings › À propos: the typeface and its licence.
  ///
  /// In fr, this message translates to:
  /// **'Geist, licence SIL OFL'**
  String get settingsAboutCreditsFont;

  /// Settings › À propos: link to Flutter's licence page.
  ///
  /// In fr, this message translates to:
  /// **'Toutes les licences'**
  String get settingsAboutAllLicenses;

  /// Title of the theme row in settings preferences.
  ///
  /// In fr, this message translates to:
  /// **'Thème'**
  String get settingsThemeTitle;

  /// Note under the theme segmented control.
  ///
  /// In fr, this message translates to:
  /// **'Sombre, clair, ou celui de votre système.'**
  String get settingsThemeNote;

  /// Theme option that follows the operating system.
  ///
  /// In fr, this message translates to:
  /// **'Système'**
  String get settingsThemeSystem;

  /// Theme option for the dark theme.
  ///
  /// In fr, this message translates to:
  /// **'Sombre'**
  String get settingsThemeDark;

  /// Theme option for the light theme.
  ///
  /// In fr, this message translates to:
  /// **'Clair'**
  String get settingsThemeLight;

  /// Toast shown when saving the theme preference fails; the previous theme is restored.
  ///
  /// In fr, this message translates to:
  /// **'Le thème n’a pas pu être enregistré. Rien n’a été modifié. Réessayez.'**
  String get settingsThemeSaveFailed;

  /// Title of the text size row in settings preferences.
  ///
  /// In fr, this message translates to:
  /// **'Taille du texte'**
  String get settingsTextSizeTitle;

  /// Note under the text size segmented control.
  ///
  /// In fr, this message translates to:
  /// **'Agrandit tout le texte de l’application.'**
  String get settingsTextSizeNote;

  /// Text size option: the reference type scale, the default.
  ///
  /// In fr, this message translates to:
  /// **'Normal'**
  String get settingsTextSizeNormal;

  /// Text size option: every text a little larger.
  ///
  /// In fr, this message translates to:
  /// **'Grand'**
  String get settingsTextSizeLarge;

  /// Text size option: the largest text size.
  ///
  /// In fr, this message translates to:
  /// **'Très grand'**
  String get settingsTextSizeXLarge;

  /// Toast shown when saving the text size fails; the previous size is restored.
  ///
  /// In fr, this message translates to:
  /// **'La taille du texte n’a pas pu être enregistrée. Rien n’a été modifié. Réessayez.'**
  String get settingsTextSizeSaveFailed;

  /// Title of the language card in settings preferences.
  ///
  /// In fr, this message translates to:
  /// **'Langue'**
  String get settingsLanguageTitle;

  /// Note under the language segmented control.
  ///
  /// In fr, this message translates to:
  /// **'S’applique immédiatement à toute l’interface.'**
  String get settingsLanguageNote;

  /// Title of the currency card in settings preferences.
  ///
  /// In fr, this message translates to:
  /// **'Devise'**
  String get settingsCurrencyTitle;

  /// Note under the read-only currency field in settings, stating that it is permanent.
  ///
  /// In fr, this message translates to:
  /// **'Choisie à l’inscription et appliquée à tous vos comptes. Elle ne peut pas être modifiée dans cette version.'**
  String get settingsCurrencyNote;

  /// Settings › Préférences: name of the row showing how dates and amounts are formatted.
  ///
  /// In fr, this message translates to:
  /// **'Formats'**
  String get settingsFormatsTitle;

  /// Settings › Préférences: label of the sample date in the formats row.
  ///
  /// In fr, this message translates to:
  /// **'Date'**
  String get settingsFormatsDates;

  /// Settings › Préférences: label of the sample amount in the formats row.
  ///
  /// In fr, this message translates to:
  /// **'Montant'**
  String get settingsFormatsAmounts;

  /// Shown in place of the version number when the app could not read it.
  ///
  /// In fr, this message translates to:
  /// **'Indisponible'**
  String get settingsAboutVersionUnavailable;

  /// Title of the third-party credits card in the About section.
  ///
  /// In fr, this message translates to:
  /// **'Crédits'**
  String get settingsAboutCreditsTitle;

  /// Credit line for the Lucide icon set and its license, in the About section.
  ///
  /// In fr, this message translates to:
  /// **'Lucide, licence ISC'**
  String get settingsAboutCreditsIcons;

  /// Title of the update-check card in Settings › About.
  ///
  /// In fr, this message translates to:
  /// **'Mises à jour'**
  String get settingsUpdatesTitle;

  /// Subtitle beside the update-check toggle.
  ///
  /// In fr, this message translates to:
  /// **'Me prévenir d’une nouvelle version'**
  String get settingsUpdatesSubtitle;

  /// Accessibility label of the update-check toggle.
  ///
  /// In fr, this message translates to:
  /// **'Vérifier les mises à jour'**
  String get settingsUpdatesToggleLabel;

  /// Says exactly what the opt-in update check sends.
  ///
  /// In fr, this message translates to:
  /// **'Une fois par jour au plus, Bastide demande à GitHub le numéro de la dernière version publiée. Rien d’autre n’est envoyé, et rien n’est installé sans vous.'**
  String get settingsUpdatesNote;

  /// Shown while the update check runs.
  ///
  /// In fr, this message translates to:
  /// **'Vérification…'**
  String get settingsUpdatesChecking;

  /// Title of the plate announcing a newer release.
  ///
  /// In fr, this message translates to:
  /// **'Bastide {version} est disponible'**
  String settingsUpdatesAvailable(String version);

  /// Opens the release page in the browser.
  ///
  /// In fr, this message translates to:
  /// **'Télécharger'**
  String get settingsUpdatesDownload;

  /// The update check could not reach GitHub.
  ///
  /// In fr, this message translates to:
  /// **'GitHub n’a pas pu être joint.'**
  String get settingsUpdatesOffline;

  /// The app could not read the update status from its backend.
  ///
  /// In fr, this message translates to:
  /// **'État des mises à jour indisponible.'**
  String get settingsUpdatesUnavailable;

  /// Toast after « Vérifier maintenant » when no newer release exists.
  ///
  /// In fr, this message translates to:
  /// **'Bastide est à jour'**
  String get settingsUpdatesToastLatest;

  /// Toast after « Vérifier maintenant » when a newer release exists.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle version disponible : Bastide {version}'**
  String settingsUpdatesToastAvailable(String version);

  /// Title of the toast when « Vérifier maintenant » got no answer.
  ///
  /// In fr, this message translates to:
  /// **'La vérification a échoué'**
  String get settingsUpdatesToastFailed;

  /// Second line of the failed-check toast when GitHub was out of reach.
  ///
  /// In fr, this message translates to:
  /// **'GitHub n’a pas pu être joint. Réessayez plus tard.'**
  String get settingsUpdatesToastOffline;

  /// Second line of the failed-check toast when the backend could not be asked.
  ///
  /// In fr, this message translates to:
  /// **'Bastide n’a pas pu lancer la vérification. Réessayez.'**
  String get settingsUpdatesToastError;

  /// Local-privacy statement in the About section.
  ///
  /// In fr, this message translates to:
  /// **'Toutes vos données restent sur cet ordinateur. Bastide ne se connecte à aucune banque et n’envoie rien sur Internet, hormis la vérification des mises à jour si vous l’activez.'**
  String get settingsAboutPrivacy;

  /// Encouraging placeholder body on panels whose feature isn't built yet.
  ///
  /// In fr, this message translates to:
  /// **'Cet écran arrive dans une prochaine étape. En attendant, ajoutez vos comptes pour préparer le terrain.'**
  String get comingSoonBody;

  /// Privacy line on the signed-out screens, beside a lock glyph. One of the three places the privacy promise appears.
  ///
  /// In fr, this message translates to:
  /// **'Vos données restent sur cet ordinateur.'**
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

  /// Label for the email field on the register form.
  ///
  /// In fr, this message translates to:
  /// **'Adresse e-mail'**
  String get authEmailLabel;

  /// Label for the password field on login/register forms.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe'**
  String get authPasswordLabel;

  /// Helper under a new password field while it is not yet long enough.
  ///
  /// In fr, this message translates to:
  /// **'{minimum} caractères minimum.'**
  String authPasswordMinimum(int minimum);

  /// Helper under a new password field once it is long enough, after a check icon. {count} is never below {minimum}.
  ///
  /// In fr, this message translates to:
  /// **'{count} caractères. Le minimum est de {minimum}.'**
  String authPasswordLengthOk(int count, int minimum);

  /// Error under a new password field that was left too short. {count} is how many characters are missing.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{Encore 1 caractère.} other{Encore {count} caractères.}}'**
  String authPasswordTooShort(int count);

  /// Label of the field repeating the new password on the reset screen.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer le mot de passe'**
  String get authConfirmPasswordLabel;

  /// Error under the confirm field when it differs from the new password.
  ///
  /// In fr, this message translates to:
  /// **'Les mots de passe ne correspondent pas.'**
  String get authPasswordMismatch;

  /// Label of the user name field, on the register screen and in Settings › Profil.
  ///
  /// In fr, this message translates to:
  /// **'Nom d’utilisateur'**
  String get authDisplayNameLabel;

  /// Microcopy under the language and currency row at registration, stating which choice is permanent.
  ///
  /// In fr, this message translates to:
  /// **'La langue se change dans les paramètres. La devise est définitive et s’applique à tous vos comptes.'**
  String get authPreferencesNote;

  /// Validation helper shown when the chosen email already has an account.
  ///
  /// In fr, this message translates to:
  /// **'Cet e-mail a déjà un compte. Connectez-vous.'**
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

  /// A currency in the register currency select: ISO code then its name (authCurrencyName).
  ///
  /// In fr, this message translates to:
  /// **'{code}, {name}'**
  String authCurrencyOption(String code, String name);

  /// Name of a currency offered at registration, by ISO 4217 code. Falls back to the code.
  ///
  /// In fr, this message translates to:
  /// **'{code, select, EUR{euro} USD{dollar américain} GBP{livre sterling} CHF{franc suisse} CAD{dollar canadien} JPY{yen} AUD{dollar australien} CNY{yuan} INR{roupie indienne} BRL{réal brésilien} MXN{peso mexicain} SEK{couronne suédoise} NOK{couronne norvégienne} DKK{couronne danoise} PLN{zloty} CZK{couronne tchèque} HUF{forint} RON{leu roumain} ZAR{rand} AED{dirham des Émirats} SGD{dollar de Singapour} HKD{dollar de Hong Kong} NZD{dollar néo-zélandais} TRY{livre turque} ILS{shekel} KRW{won} THB{baht} MAD{dirham marocain} XOF{franc CFA d’Afrique de l’Ouest} XAF{franc CFA d’Afrique centrale} other{{code}}}'**
  String authCurrencyName(String code);

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

  /// Label replacing the register button text while the request is in flight.
  ///
  /// In fr, this message translates to:
  /// **'Création…'**
  String get authRegisterSubmitting;

  /// Link on the login screen, left of the link row, navigating to registration.
  ///
  /// In fr, this message translates to:
  /// **'Créer un compte'**
  String get authGoToRegister;

  /// Lead-in on the register screen, followed by the authGoToLoginLink link.
  ///
  /// In fr, this message translates to:
  /// **'Déjà un compte ?'**
  String get authGoToLogin;

  /// Link after authGoToLogin on the register screen, navigating to login.
  ///
  /// In fr, this message translates to:
  /// **'Se connecter'**
  String get authGoToLoginLink;

  /// Validation message when the password field is left empty.
  ///
  /// In fr, this message translates to:
  /// **'Le mot de passe est requis.'**
  String get authPasswordRequired;

  /// Localized message for the backend's INVALID_CREDENTIALS error code on login, where the identifier is the e-mail or the username.
  ///
  /// In fr, this message translates to:
  /// **'Identifiant ou mot de passe incorrect.'**
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

  /// Localized message for the backend's PASSWORD_TOO_SHORT error code.
  ///
  /// In fr, this message translates to:
  /// **'Le mot de passe doit contenir au moins {minimum} caractères.'**
  String authErrorPasswordTooShort(int minimum);

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

  /// Label on the summary card above the accounts list, over the sum of all account balances.
  ///
  /// In fr, this message translates to:
  /// **'Solde total'**
  String get accountsTotalBalanceLabel;

  /// Heading shown when the user has no accounts yet.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez votre premier compte'**
  String get accountsEmptyTitle;

  /// Encouraging subtext under the empty-state heading on the accounts screen.
  ///
  /// In fr, this message translates to:
  /// **'Créez un compte, ou importez un relevé : Bastide crée le compte qu’il décrit.'**
  String get accountsEmptyBody;

  /// Retry button label shown when the accounts list fails to load.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get accountsRetry;

  /// Segment of the accounts title bar: one section per account type.
  ///
  /// In fr, this message translates to:
  /// **'Par type'**
  String get accountsGroupByType;

  /// Segment of the accounts title bar: one section per institution.
  ///
  /// In fr, this message translates to:
  /// **'Par établissement'**
  String get accountsGroupByInstitution;

  /// Accounts section holding the checking accounts.
  ///
  /// In fr, this message translates to:
  /// **'Comptes courants'**
  String get accountsGroupChecking;

  /// Accounts section holding the savings accounts.
  ///
  /// In fr, this message translates to:
  /// **'Épargne'**
  String get accountsGroupSavings;

  /// Accounts section holding the deferred-debit cards that have a row of their own.
  ///
  /// In fr, this message translates to:
  /// **'Cartes à débit différé'**
  String get accountsGroupDeferredCards;

  /// Accounts section holding the credit-type accounts.
  ///
  /// In fr, this message translates to:
  /// **'Crédits'**
  String get accountsGroupCredits;

  /// Accounts section holding cash and other accounts.
  ///
  /// In fr, this message translates to:
  /// **'Autres'**
  String get accountsGroupOther;

  /// Accounts section, by institution, for the accounts that name none.
  ///
  /// In fr, this message translates to:
  /// **'Sans établissement'**
  String get accountsNoInstitution;

  /// Section header: the group's share of the total, one decimal.
  ///
  /// In fr, this message translates to:
  /// **'{share} % du total'**
  String accountsGroupShare(double share);

  /// Number of accounts on the total line.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 compte} other{{count} comptes}}'**
  String accountsCount(int count);

  /// Caption right of the total: the account count, then when the balances were recalculated.
  ///
  /// In fr, this message translates to:
  /// **'{accounts} · soldes recalculés {ago}'**
  String accountsSummaryCaption(String accounts, String ago);

  /// How long ago the balances were recalculated, under an hour.
  ///
  /// In fr, this message translates to:
  /// **'{minutes, plural, =0{à l’instant} =1{il y a 1 min} other{il y a {minutes} min}}'**
  String accountsAgoMinutes(int minutes);

  /// How long ago the balances were recalculated, an hour or more.
  ///
  /// In fr, this message translates to:
  /// **'{hours, plural, =1{il y a 1 h} other{il y a {hours} h}}'**
  String accountsAgoHours(int hours);

  /// Accounts table column header.
  ///
  /// In fr, this message translates to:
  /// **'Compte'**
  String get accountsColumnAccount;

  /// Accounts table column header.
  ///
  /// In fr, this message translates to:
  /// **'Établissement'**
  String get accountsColumnInstitution;

  /// Accounts table column header.
  ///
  /// In fr, this message translates to:
  /// **'Dernier import'**
  String get accountsColumnLastImport;

  /// Accounts table column header: the balance change over the current month, named.
  ///
  /// In fr, this message translates to:
  /// **'Variation en {month}'**
  String accountsColumnMonthChange(String month);

  /// Accounts table column header.
  ///
  /// In fr, this message translates to:
  /// **'Solde'**
  String get accountsColumnBalance;

  /// Accounts table cell when no statement was ever imported into the account.
  ///
  /// In fr, this message translates to:
  /// **'—'**
  String get accountsNoImport;

  /// Status after an account's name counting the cards settled on it; opens their menu.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 carte} other{{count} cartes}}'**
  String accountsCardCount(int count);

  /// Secondary action of the accounts empty state.
  ///
  /// In fr, this message translates to:
  /// **'Aller aux imports'**
  String get accountsGoToImports;

  /// Read-only currency field label in the account form.
  ///
  /// In fr, this message translates to:
  /// **'Devise'**
  String get accountCurrencyLabel;

  /// Read-only currency value in the account form: the code, then the currency's name when known.
  ///
  /// In fr, this message translates to:
  /// **'{currency, select, EUR{EUR, euro} USD{USD, dollar américain} GBP{GBP, livre sterling} CHF{CHF, franc suisse} other{{currency}}}'**
  String accountCurrencyValue(String currency);

  /// Helper under the read-only currency field of the account form.
  ///
  /// In fr, this message translates to:
  /// **'La devise est celle de votre profil.'**
  String get accountCurrencyHelper;

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

  /// Linked-card menu item, deferred-debit cards only: opens the rule filing the card's monthly debit as a transfer.
  ///
  /// In fr, this message translates to:
  /// **'Règle de prélèvement'**
  String get accountSettlementRule;

  /// Warning for a deferred-debit card with no settlement account.
  ///
  /// In fr, this message translates to:
  /// **'{card} : choisissez le compte sur lequel la carte est prélevée, pour que ses achats ne comptent qu’une fois.'**
  String cardSettlementNoAccount(String card);

  /// Action on the no-settlement-account warning: opens the card's account form.
  ///
  /// In fr, this message translates to:
  /// **'Choisir le compte'**
  String get cardSettlementChooseAccount;

  /// Warning for a deferred-debit card without a settlement rule.
  ///
  /// In fr, this message translates to:
  /// **'Le prélèvement mensuel de {card} compte comme une dépense, en plus des achats de la carte : créez sa règle de prélèvement.'**
  String cardSettlementNoRule(String card);

  /// Action on the no-rule warning: opens the settlement-rule dialog.
  ///
  /// In fr, this message translates to:
  /// **'Créer la règle'**
  String get cardSettlementCreateRule;

  /// Warning: a deferred card's purchases since its last settlement have no matching debit although the paying account is imported well past them. `amount` is pre-formatted, without a sign.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{Un achat de {card} ({amount}) attend son prélèvement depuis le {date} : la règle de la carte ne reconnaît peut-être plus le libellé de la banque.} other{{count} achats de {card} ({amount}) attendent leur prélèvement depuis le {date} : la règle de la carte ne reconnaît peut-être plus le libellé de la banque.}}'**
  String cardSettlementUnsettled(
    int count,
    String card,
    String amount,
    DateTime date,
  );

  /// Action on the unsettled-purchases warning: opens the settlement-rule dialog.
  ///
  /// In fr, this message translates to:
  /// **'Vérifier la règle'**
  String get cardSettlementCheckRule;

  /// Title of the dialog proposing the rule that files a deferred-debit card's monthly debit as a transfer.
  ///
  /// In fr, this message translates to:
  /// **'Règle de prélèvement de la carte'**
  String get settlementRuleTitle;

  /// Explanation at the top of the settlement-rule dialog.
  ///
  /// In fr, this message translates to:
  /// **'Chaque mois, la banque prélève le total de {card} sur le compte qui la règle. Ce prélèvement est un virement, pas une dépense : les achats de la carte sont déjà comptés un par un.'**
  String settlementRuleBody(String card);

  /// Label of the pattern field of the settlement-rule dialog.
  ///
  /// In fr, this message translates to:
  /// **'Le libellé du prélèvement contient'**
  String get settlementRulePatternLabel;

  /// Helper under the settlement-rule pattern field.
  ///
  /// In fr, this message translates to:
  /// **'Proposé à partir des libellés qui reviennent chaque mois sur le compte qui paie la carte.'**
  String get settlementRulePatternHelper;

  /// Validation error when the settlement-rule pattern is empty.
  ///
  /// In fr, this message translates to:
  /// **'Indiquez le texte qui désigne le prélèvement.'**
  String get settlementRulePatternRequired;

  /// Label of the start-date field of the settlement-rule dialog.
  ///
  /// In fr, this message translates to:
  /// **'S’applique à partir du'**
  String get settlementRuleFromLabel;

  /// Helper under the start-date field of the settlement-rule dialog.
  ///
  /// In fr, this message translates to:
  /// **'Les prélèvements plus anciens restent des dépenses : les achats qu’ils ont payés ne sont pas dans l’application. Proposé à partir de l’historique importé de la carte.'**
  String get settlementRuleFromHelper;

  /// Validation error when the settlement-rule start date can't be read.
  ///
  /// In fr, this message translates to:
  /// **'Date invalide.'**
  String get settlementRuleFromInvalid;

  /// Rules list: the date a rule starts applying from (deferred-card settlement rules).
  ///
  /// In fr, this message translates to:
  /// **'à partir du {date}'**
  String ruleAppliesFrom(DateTime date);

  /// Primary action of the settlement-rule dialog.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer la règle'**
  String get settlementRuleSave;

  /// Dismisses the settlement-rule dialog without saving.
  ///
  /// In fr, this message translates to:
  /// **'Plus tard'**
  String get settlementRuleLater;

  /// Snackbar after saving a card's settlement rule, with how many imported debits it filed.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Règle enregistrée.} =1{Règle enregistrée : 1 prélèvement classé en virement.} other{Règle enregistrée : {count} prélèvements classés en virement.}}'**
  String settlementRuleSaved(int count);

  /// Shown in the settlement-rule dialog when its state fails to load.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger la règle de la carte.'**
  String get settlementRuleLoadFailed;

  /// Shown in the settlement-rule dialog when saving fails.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d’enregistrer la règle. Réessayez.'**
  String get settlementRuleSaveFailed;

  /// Title of the archive confirmation dialog.
  ///
  /// In fr, this message translates to:
  /// **'Archiver ce compte ?'**
  String get accountArchiveConfirmTitle;

  /// Body text of the archive confirmation dialog.
  ///
  /// In fr, this message translates to:
  /// **'Vous pourrez toujours consulter son historique, mais il n’apparaîtra plus dans votre liste de comptes.'**
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

  /// Label of the question the account form asks when created from a card statement: how the card is debited.
  ///
  /// In fr, this message translates to:
  /// **'Débit de la carte'**
  String get accountCardDebitLabel;

  /// Answer to the card-debit question: a deferred-debit card, settled once a month on the current account.
  ///
  /// In fr, this message translates to:
  /// **'Débit différé'**
  String get accountCardDebitDeferred;

  /// Answer to the card-debit question: a credit card repaid on a credit line.
  ///
  /// In fr, this message translates to:
  /// **'Crédit'**
  String get accountCardDebitCredit;

  /// Label of the account form field choosing the account a deferred-debit card's monthly debit is drawn from.
  ///
  /// In fr, this message translates to:
  /// **'Prélevée sur'**
  String get accountSettlementLabel;

  /// Helper under the settlement-account field of the account form.
  ///
  /// In fr, this message translates to:
  /// **'Le compte débité chaque mois du total de la carte : ce prélèvement est un virement entre les deux, pas une dépense.'**
  String get accountSettlementHelper;

  /// Placeholder of the settlement-account select when none is chosen yet.
  ///
  /// In fr, this message translates to:
  /// **'Choisir un compte'**
  String get accountSettlementPlaceholder;

  /// Validation error when a deferred-debit card is saved without its settlement account.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez le compte prélevé.'**
  String get accountSettlementRequired;

  /// Localized message for the backend's ACCOUNT_SETTLEMENT_ACCOUNT_REQUIRED error code.
  ///
  /// In fr, this message translates to:
  /// **'Une carte à débit différé doit indiquer le compte sur lequel elle est prélevée.'**
  String get accountErrorSettlementRequired;

  /// Localized message for the backend's ACCOUNT_SETTLEMENT_ACCOUNT_INVALID error code: the chosen settlement account is a card, archived, or not the user's.
  ///
  /// In fr, this message translates to:
  /// **'Ce compte ne peut pas régler la carte.'**
  String get accountErrorSettlementInvalid;

  /// Helper under the card-debit question, explaining what deferred debit means so the user can recognise their card.
  ///
  /// In fr, this message translates to:
  /// **'Une carte à débit différé est prélevée en une fois sur votre compte courant chaque mois.'**
  String get accountCardDebitHelper;

  /// Label for the institution field on the account form.
  ///
  /// In fr, this message translates to:
  /// **'Établissement'**
  String get accountInstitutionLabel;

  /// Validation message when the institution field is left empty.
  ///
  /// In fr, this message translates to:
  /// **'L’établissement est requis.'**
  String get accountInstitutionRequired;

  /// Helper under the read-only institution field when the account is being created from a statement that names its bank.
  ///
  /// In fr, this message translates to:
  /// **'Repris de l’établissement déclaré par votre relevé.'**
  String get accountInstitutionFromStatementNote;

  /// Label for the opening balance field on the account form, when editing an account: the figure the account started from.
  ///
  /// In fr, this message translates to:
  /// **'Solde initial'**
  String get accountOpeningBalanceLabel;

  /// Label for the balance field when creating an account from a statement that dates its declared balance (OFX DTASOF): names the day the figure belongs to rather than calling it the current balance.
  ///
  /// In fr, this message translates to:
  /// **'Solde au {date}'**
  String accountBalanceAsOfLabel(DateTime date);

  /// Helper under the balance field when the account is being created from a statement: the import derives the real figure from the statement's declared balance, so an approximate entry here is harmless.
  ///
  /// In fr, this message translates to:
  /// **'Ajusté automatiquement d’après le solde déclaré par votre relevé lors du premier import.'**
  String get accountBalanceStatementNote;

  /// Helper under the read-only balance field when the account is being created from a statement that declares its closing balance: the figure is the statement's, not something to type.
  ///
  /// In fr, this message translates to:
  /// **'Repris du solde déclaré par votre relevé.'**
  String get accountBalanceFromStatementNote;

  /// Helper under the balance field when editing an existing account: explains that a manual correction shifts the cached balance and every saved snapshot by the same delta rather than rewriting the ledger.
  ///
  /// In fr, this message translates to:
  /// **'Corriger cette valeur décale le solde du compte et son historique enregistré du même montant. Aucune transaction n’est modifiée.'**
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

  /// Shown when the accounts list failed to load, so the statement cannot be matched against anything.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger vos comptes. Réessayez dans un instant.'**
  String get importAccountsUnavailable;

  /// First line of the imports drop target.
  ///
  /// In fr, this message translates to:
  /// **'Déposez un relevé OFX ou QFX'**
  String get importDropZoneTitle;

  /// Sub-line inside the imports drop zone, stating that the file itself names the destination account.
  ///
  /// In fr, this message translates to:
  /// **'Le relevé indique son compte. Rien n’est importé avant votre confirmation.'**
  String get importDropZoneHint;

  /// Size of the staged file, shown under its name. The number is already formatted for the locale.
  ///
  /// In fr, this message translates to:
  /// **'{size} Ko'**
  String importFileSize(String size);

  /// Ghost button removing one statement line of the selected file.
  ///
  /// In fr, this message translates to:
  /// **'Retirer'**
  String get importRemoveFile;

  /// Primary action that imports the staged file.
  ///
  /// In fr, this message translates to:
  /// **'Importer'**
  String get importSubmit;

  /// Label replacing the import button text while the upload is in flight.
  ///
  /// In fr, this message translates to:
  /// **'Import…'**
  String get importSubmitting;

  /// Primary action, shown when the selected file holds several statements, that imports every statement whose destination is settled.
  ///
  /// In fr, this message translates to:
  /// **'Importer tout'**
  String get importAll;

  /// Banner shown when the statement's bank matches several accounts and nothing in the file separates them; the user picks the destination.
  ///
  /// In fr, this message translates to:
  /// **'Ce relevé vient de {account}, mais plusieurs comptes y correspondent. Choisissez la destination.'**
  String importDetectedAccountAmbiguous(String account);

  /// Detection result on a selected-file line when the account the statement names matches none of the user's accounts.
  ///
  /// In fr, this message translates to:
  /// **'Compte inconnu : {account}'**
  String importDetectedAccountUnknown(String account);

  /// Action opening the account form pre-filled with the account read from the statement.
  ///
  /// In fr, this message translates to:
  /// **'Créer ce compte'**
  String get importCreateDetectedAccount;

  /// Leading word of the name proposed for an account created from a card statement, followed by the masked card number.
  ///
  /// In fr, this message translates to:
  /// **'Carte'**
  String get importCardAccountName;

  /// Placeholder option in the account picker shown when a statement could not name its own destination — the unanswered state.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez un compte'**
  String get importChooseAccount;

  /// Warning shown when the staged file declares no account block at all, so the user has to pick the destination from every account.
  ///
  /// In fr, this message translates to:
  /// **'Ce fichier n’indique aucun compte. Choisissez la destination.'**
  String get importUnreadableAccount;

  /// The coverage window of an import batch. Both ends are already formatted for the locale, the start shortened when it shares the end's month or year.
  ///
  /// In fr, this message translates to:
  /// **'{start} – {end}'**
  String importPeriodRange(String start, String end);

  /// Calm explanation shown on a failed import, stating that nothing was written.
  ///
  /// In fr, this message translates to:
  /// **'Fichier illisible. Rien n’a été modifié.'**
  String get importFailedNote;

  /// Note under a history row's filename when the run skipped duplicates.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 opération déjà présente a été ignorée.} other{{count} opérations déjà présentes ont été ignorées.}}'**
  String importDuplicatesNote(int count);

  /// Note under a history row's filename when the statement's declared balance disagrees with what the ledger implies — only ever set from an account's second import onward. `amount` is pre-formatted with a sign (see formatAmount).
  ///
  /// In fr, this message translates to:
  /// **'Écart de {amount} avec le solde de la banque au {date}.'**
  String importBalanceMismatchNote(String amount, DateTime date);

  /// Result of an import that completed.
  ///
  /// In fr, this message translates to:
  /// **'Réussi'**
  String get importStatusSuccess;

  /// Result of an import where only some rows landed.
  ///
  /// In fr, this message translates to:
  /// **'Partiel'**
  String get importStatusPartial;

  /// Result of an import that could not be parsed at all.
  ///
  /// In fr, this message translates to:
  /// **'Échec'**
  String get importStatusFailed;

  /// Heading of the import history section.
  ///
  /// In fr, this message translates to:
  /// **'Historique'**
  String get importHistoryTitle;

  /// Heading shown when the import history is empty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun import'**
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

  /// Localized message for the backend's IMPORT_STATEMENT_REQUIRED error code: a multi-account file was uploaded without naming the statement to import.
  ///
  /// In fr, this message translates to:
  /// **'Ce fichier contient plusieurs comptes et aucun n’a été désigné.'**
  String get importErrorStatementRequired;

  /// Localized message for the backend's IMPORT_STATEMENT_NOT_FOUND error code: the named statement is not in the file.
  ///
  /// In fr, this message translates to:
  /// **'Ce compte est introuvable dans le fichier.'**
  String get importErrorStatementNotFound;

  /// Detection result on each selected-file line whose statement resolves to the same account as another statement of the file; their import stays disabled.
  ///
  /// In fr, this message translates to:
  /// **'Deux relevés vont vers le même compte. Choisissez une destination différente.'**
  String get importDuplicateDestination;

  /// Fallback localized message for unrecognized or network errors on the imports panel.
  ///
  /// In fr, this message translates to:
  /// **'Une erreur est survenue. Veuillez réessayer.'**
  String get importErrorGeneric;

  /// Secondary button in the imports drop target, opening the file dialog.
  ///
  /// In fr, this message translates to:
  /// **'Parcourir'**
  String get importBrowse;

  /// Detection result on a selected-file line when the statement matched one of the user's accounts, shown before that account.
  ///
  /// In fr, this message translates to:
  /// **'Compte reconnu'**
  String get importDetectionRecognised;

  /// Detection result on a selected-file line when several accounts match the statement, shown before a select of the candidates.
  ///
  /// In fr, this message translates to:
  /// **'Plusieurs comptes correspondent'**
  String get importDetectionAmbiguous;

  /// Detection result on a selected-file line when the file names no account, shown before a select of every account.
  ///
  /// In fr, this message translates to:
  /// **'Aucun compte indiqué'**
  String get importDetectionNoAccount;

  /// Shown on a selected-file line for a file that is not OFX or QFX by its name (a CSV, say). Only removing it is offered.
  ///
  /// In fr, this message translates to:
  /// **'Format non pris en charge.'**
  String get importUnsupportedFormat;

  /// Toast confirming an import: new transactions, then skipped duplicates.
  ///
  /// In fr, this message translates to:
  /// **'{newCount, plural, =0{Aucune nouvelle opération} =1{1 nouvelle opération} other{{newCount} nouvelles opérations}} · {duplicateCount, plural, =0{aucun doublon} =1{1 doublon ignoré} other{{duplicateCount} doublons ignorés}}'**
  String importToastSummary(int newCount, int duplicateCount);

  /// Import history column header for the destination account.
  ///
  /// In fr, this message translates to:
  /// **'Compte'**
  String get importHistoryAccountHeader;

  /// Import history column header for the outcome.
  ///
  /// In fr, this message translates to:
  /// **'Résultat'**
  String get importHistoryResultHeader;

  /// Added to an import's result when the statement's declared balance disagrees with the ledger; the detail shows on hover.
  ///
  /// In fr, this message translates to:
  /// **'Écart de solde'**
  String get importBalanceMismatchStatus;

  /// Empty-value placeholder in the import history (the account or period of a failed import).
  ///
  /// In fr, this message translates to:
  /// **'—'**
  String get importHistoryNoValue;

  /// Placeholder in the transactions search pill in the top bar.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher'**
  String get transactionsSearchHint;

  /// Keyboard shortcut shown at the end of a search field; pressing it focuses the field.
  ///
  /// In fr, this message translates to:
  /// **'Ctrl K'**
  String get searchShortcutHint;

  /// Retry button label shown when the transaction list fails to load.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get transactionsRetry;

  /// Heading shown when the user has no transactions at all yet.
  ///
  /// In fr, this message translates to:
  /// **'Aucune transaction'**
  String get transactionsEmptyTitle;

  /// Encouraging subtext under the empty-state heading on the transactions screen.
  ///
  /// In fr, this message translates to:
  /// **'Importez un relevé pour voir vos opérations ici.'**
  String get transactionsEmptyBody;

  /// CTA on the transactions empty state, navigating to the imports panel.
  ///
  /// In fr, this message translates to:
  /// **'Aller aux imports'**
  String get transactionsGoToImports;

  /// The « À vérifier » tab of the Transactions panel; its count follows it.
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

  /// Chip in the transactions filter row naming the import the list is narrowed to (opened from an import history row).
  ///
  /// In fr, this message translates to:
  /// **'Import : {fileName}'**
  String transactionsFilterImport(String fileName);

  /// Tooltip and accessible label of the button that lifts the import filter.
  ///
  /// In fr, this message translates to:
  /// **'Retirer le filtre d’import'**
  String get transactionsFilterImportRemove;

  /// Chip in the transactions filter row naming the one operation the list is narrowed to (opened from a dashboard or account detail row).
  ///
  /// In fr, this message translates to:
  /// **'Opération : {name}'**
  String transactionsFilterOperation(String name);

  /// Tooltip and accessible label of the button that lifts the one-operation filter.
  ///
  /// In fr, this message translates to:
  /// **'Retirer le filtre d’opération'**
  String get transactionsFilterOperationRemove;

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

  /// Confirm button of the date range modal, applying the chosen range.
  ///
  /// In fr, this message translates to:
  /// **'Appliquer'**
  String get transactionsDateRangeApply;

  /// Pager label under the transaction list, showing the current page's row range and the total count.
  ///
  /// In fr, this message translates to:
  /// **'{from} – {to} sur {total}'**
  String transactionsPager(int from, int to, int total);

  /// The « Toutes » tab of the Transactions panel.
  ///
  /// In fr, this message translates to:
  /// **'Toutes'**
  String get transactionsTabAll;

  /// The period select's label once a range is set; both dates are already formatted.
  ///
  /// In fr, this message translates to:
  /// **'{from} – {to}'**
  String transactionsPeriodRange(String from, String to);

  /// End of the filter row: how many operations the filters match, before their signed net.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 opération · net} other{{count} opérations · net}}'**
  String transactionsCountNet(int count);

  /// Column header.
  ///
  /// In fr, this message translates to:
  /// **'Opération'**
  String get transactionsColumnOperation;

  /// Column header.
  ///
  /// In fr, this message translates to:
  /// **'Catégorie'**
  String get transactionsColumnCategory;

  /// Column header.
  ///
  /// In fr, this message translates to:
  /// **'Montant'**
  String get transactionsColumnAmount;

  /// Pager button tooltip.
  ///
  /// In fr, this message translates to:
  /// **'Page précédente'**
  String get transactionsPagerPrevious;

  /// Pager button tooltip.
  ///
  /// In fr, this message translates to:
  /// **'Page suivante'**
  String get transactionsPagerNext;

  /// Shown in the table area when the filters or the search match nothing.
  ///
  /// In fr, this message translates to:
  /// **'Aucune opération pour ces filtres.'**
  String get transactionsNoResult;

  /// Link after the no-result line; lifts every filter and the search.
  ///
  /// In fr, this message translates to:
  /// **'Effacer les filtres'**
  String get transactionsClearFilters;

  /// The inspector pane's note while no operation is selected.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionnez une opération pour voir son détail.'**
  String get transactionInspectorEmpty;

  /// Inspector key/value label.
  ///
  /// In fr, this message translates to:
  /// **'Date'**
  String get transactionInspectorDate;

  /// Inspector key/value label.
  ///
  /// In fr, this message translates to:
  /// **'Compte'**
  String get transactionInspectorAccount;

  /// Inspector key/value label.
  ///
  /// In fr, this message translates to:
  /// **'Catégorie'**
  String get transactionInspectorCategory;

  /// Inspector key/value label: what gave the operation its category.
  ///
  /// In fr, this message translates to:
  /// **'Classée par'**
  String get transactionInspectorClassifiedBy;

  /// Inspector key/value label.
  ///
  /// In fr, this message translates to:
  /// **'Import'**
  String get transactionInspectorImport;

  /// « Classée par » value when a rule filed the operation.
  ///
  /// In fr, this message translates to:
  /// **'règle « {pattern} »'**
  String transactionClassifiedByRule(String pattern);

  /// « Classée par » value when the local AI filed or proposed the category.
  ///
  /// In fr, this message translates to:
  /// **'IA locale, confiance {confidence}'**
  String transactionClassifiedByModel(double confidence);

  /// « Classée par » value when the user chose the category.
  ///
  /// In fr, this message translates to:
  /// **'vous'**
  String get transactionClassifiedByUser;

  /// « Classée par » value when nothing filed the operation.
  ///
  /// In fr, this message translates to:
  /// **'non classée'**
  String get transactionClassifiedByNone;

  /// Shown in the inspector when the operation's import, rule, series and history fail to load.
  ///
  /// In fr, this message translates to:
  /// **'Ce détail n’a pas pu être chargé. Rien n’a été modifié.'**
  String get transactionInspectorLoadError;

  /// Inspector: the operation belongs to a series.
  ///
  /// In fr, this message translates to:
  /// **'Paiement récurrent'**
  String get transactionRecurringTitle;

  /// Under « Paiement récurrent »: the series' cadence, then its next expected date, formatted.
  ///
  /// In fr, this message translates to:
  /// **'{cadence} · prochain le {date}'**
  String transactionRecurringNext(String cadence, String date);

  /// Inspector link opening the series in Abonnements.
  ///
  /// In fr, this message translates to:
  /// **'Voir la série'**
  String get transactionRecurringView;

  /// Inspector heading over the merchant's earlier operations.
  ///
  /// In fr, this message translates to:
  /// **'Même marchand'**
  String get transactionSameMerchant;

  /// Under « Même marchand » when the merchant has no earlier operation.
  ///
  /// In fr, this message translates to:
  /// **'Aucune opération antérieure.'**
  String get transactionSameMerchantNone;

  /// Opens « Toujours catégoriser ainsi ».
  ///
  /// In fr, this message translates to:
  /// **'Créer une règle'**
  String get transactionCreateRule;

  /// Opens the rule that filed the operation.
  ///
  /// In fr, this message translates to:
  /// **'Modifier la règle'**
  String get transactionEditRule;

  /// Review progress: operations filed out of the queue's size this session.
  ///
  /// In fr, this message translates to:
  /// **'{done} sur {total}'**
  String reviewProgressCount(int done, int total);

  /// Follows the review progress count.
  ///
  /// In fr, this message translates to:
  /// **'classées'**
  String get reviewProgressCaption;

  /// Note on the review progress row while local AI is on.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{L’IA locale n’a proposé aucune catégorie. Rien n’est classé sans votre accord.} =1{L’IA locale propose une catégorie pour 1 opération. Rien n’est classé sans votre accord.} other{L’IA locale propose une catégorie pour {count} opérations. Rien n’est classé sans votre accord.}}'**
  String reviewAiNote(int count);

  /// Column header.
  ///
  /// In fr, this message translates to:
  /// **'Libellé du relevé'**
  String get reviewColumnLabel;

  /// Column header.
  ///
  /// In fr, this message translates to:
  /// **'Date'**
  String get reviewColumnDate;

  /// Column header.
  ///
  /// In fr, this message translates to:
  /// **'Proposition'**
  String get reviewColumnProposal;

  /// Empty state of the « À vérifier » tab.
  ///
  /// In fr, this message translates to:
  /// **'Rien à vérifier'**
  String get reviewEmptyTitle;

  /// Empty state of the « À vérifier » tab.
  ///
  /// In fr, this message translates to:
  /// **'Toutes vos opérations ont une catégorie.'**
  String get reviewEmptyBody;

  /// Lead of the « Toujours catégoriser ainsi » modal.
  ///
  /// In fr, this message translates to:
  /// **'Une règle classe ces opérations à chaque import, sans IA.'**
  String get alwaysRuleLead;

  /// Toast after the rule is created, with how many existing operations it refiled.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Règle créée} =1{Règle créée · 1 opération recatégorisée} other{Règle créée · {count} opérations recatégorisées}}'**
  String alwaysRuleCreatedToast(int count);

  /// Affordance on a review queue row that, alongside picking a category, creates a matching categorization rule.
  ///
  /// In fr, this message translates to:
  /// **'Toujours catégoriser ainsi'**
  String get reviewAlwaysCategorize;

  /// Placeholder in the category picker popover's search field.
  ///
  /// In fr, this message translates to:
  /// **'Changer de catégorie'**
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
  /// **'Cette catégorie n’est plus disponible.'**
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

  /// Display name for the system category with i18n key category.housing.condo_fees.
  ///
  /// In fr, this message translates to:
  /// **'Charges de copropriété'**
  String get categorySystemHousingCondoFees;

  /// Display name for the system category with i18n key category.housing.maintenance.
  ///
  /// In fr, this message translates to:
  /// **'Travaux et entretien'**
  String get categorySystemHousingMaintenance;

  /// Display name for the system category with i18n key category.housing.home_services.
  ///
  /// In fr, this message translates to:
  /// **'Services à domicile'**
  String get categorySystemHousingHomeServices;

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

  /// Display name for the system category with i18n key category.food.takeaway.
  ///
  /// In fr, this message translates to:
  /// **'Livraison et à emporter'**
  String get categorySystemFoodTakeaway;

  /// Display name for the system category with i18n key category.food.canteen.
  ///
  /// In fr, this message translates to:
  /// **'Cantine'**
  String get categorySystemFoodCanteen;

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

  /// Display name for the system category with i18n key category.transport.car_insurance.
  ///
  /// In fr, this message translates to:
  /// **'Assurance auto'**
  String get categorySystemTransportCarInsurance;

  /// Display name for the system category with i18n key category.transport.tolls.
  ///
  /// In fr, this message translates to:
  /// **'Péages'**
  String get categorySystemTransportTolls;

  /// Display name for the system category with i18n key category.transport.taxi.
  ///
  /// In fr, this message translates to:
  /// **'Taxi et VTC'**
  String get categorySystemTransportTaxi;

  /// Display name for the system category with i18n key category.transport.rental.
  ///
  /// In fr, this message translates to:
  /// **'Location de véhicule'**
  String get categorySystemTransportRental;

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

  /// Display name for the system category with i18n key category.health.dentist.
  ///
  /// In fr, this message translates to:
  /// **'Dentiste'**
  String get categorySystemHealthDentist;

  /// Display name for the system category with i18n key category.health.optician.
  ///
  /// In fr, this message translates to:
  /// **'Optique'**
  String get categorySystemHealthOptician;

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

  /// Display name for the system category with i18n key category.leisure.accommodation.
  ///
  /// In fr, this message translates to:
  /// **'Hébergement'**
  String get categorySystemLeisureAccommodation;

  /// Display name for the system category with i18n key category.leisure.sports.
  ///
  /// In fr, this message translates to:
  /// **'Sport'**
  String get categorySystemLeisureSports;

  /// Display name for the system category with i18n key category.leisure.culture.
  ///
  /// In fr, this message translates to:
  /// **'Culture'**
  String get categorySystemLeisureCulture;

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

  /// Display name for the system category with i18n key category.shopping.personal_care.
  ///
  /// In fr, this message translates to:
  /// **'Beauté et soins'**
  String get categorySystemShoppingPersonalCare;

  /// Display name for the system category with i18n key category.shopping.gifts.
  ///
  /// In fr, this message translates to:
  /// **'Cadeaux'**
  String get categorySystemShoppingGifts;

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

  /// Display name for the system category with i18n key category.finance.card_settlement: the monthly debit settling a deferred-debit card on the current account.
  ///
  /// In fr, this message translates to:
  /// **'Règlement carte différée'**
  String get categorySystemFinanceCardSettlement;

  /// Display name for the system category with i18n key category.finance.interest.
  ///
  /// In fr, this message translates to:
  /// **'Intérêts'**
  String get categorySystemFinanceInterest;

  /// Display name for the system category with i18n key category.finance.investments.
  ///
  /// In fr, this message translates to:
  /// **'Investissements'**
  String get categorySystemFinanceInvestments;

  /// Display name for the system category with i18n key category.finance.loans.
  ///
  /// In fr, this message translates to:
  /// **'Remboursement de crédit'**
  String get categorySystemFinanceLoans;

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

  /// Display name for the system category with i18n key category.income.benefits.
  ///
  /// In fr, this message translates to:
  /// **'Allocations et aides'**
  String get categorySystemIncomeBenefits;

  /// Display name for the system category with i18n key category.income.rental.
  ///
  /// In fr, this message translates to:
  /// **'Revenus locatifs'**
  String get categorySystemIncomeRental;

  /// Display name for the system category with i18n key category.income.sales.
  ///
  /// In fr, this message translates to:
  /// **'Ventes'**
  String get categorySystemIncomeSales;

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

  /// Display name for the system category with i18n key category.other.cash.
  ///
  /// In fr, this message translates to:
  /// **'Retraits espèces'**
  String get categorySystemOtherCash;

  /// Display name for the system category with i18n key category.other.donations.
  ///
  /// In fr, this message translates to:
  /// **'Dons'**
  String get categorySystemOtherDonations;

  /// Display name for the system category with i18n key category.children.
  ///
  /// In fr, this message translates to:
  /// **'Enfants'**
  String get categorySystemChildren;

  /// Display name for the system category with i18n key category.children.childcare.
  ///
  /// In fr, this message translates to:
  /// **'Garde d’enfants'**
  String get categorySystemChildrenChildcare;

  /// Display name for the system category with i18n key category.children.school.
  ///
  /// In fr, this message translates to:
  /// **'Scolarité'**
  String get categorySystemChildrenSchool;

  /// Display name for the system category with i18n key category.children.activities.
  ///
  /// In fr, this message translates to:
  /// **'Activités enfants'**
  String get categorySystemChildrenActivities;

  /// Display name for the system category with i18n key category.pets.
  ///
  /// In fr, this message translates to:
  /// **'Animaux'**
  String get categorySystemPets;

  /// Display name for the system category with i18n key category.pets.food.
  ///
  /// In fr, this message translates to:
  /// **'Alimentation animaux'**
  String get categorySystemPetsFood;

  /// Display name for the system category with i18n key category.pets.vet.
  ///
  /// In fr, this message translates to:
  /// **'Vétérinaire'**
  String get categorySystemPetsVet;

  /// Label on the income column of the dashboard's KPI strip.
  ///
  /// In fr, this message translates to:
  /// **'Revenus'**
  String get dashboardStatIncome;

  /// Label on the expense column of the dashboard's KPI strip.
  ///
  /// In fr, this message translates to:
  /// **'Dépenses'**
  String get dashboardStatExpense;

  /// Label on the net (income minus expense) column of the dashboard's KPI strip.
  ///
  /// In fr, this message translates to:
  /// **'Net'**
  String get dashboardStatNet;

  /// Label on the savings rate column, the first and widest of the dashboard's KPI strip.
  ///
  /// In fr, this message translates to:
  /// **'Taux d’épargne'**
  String get dashboardStatSavingsRate;

  /// Trend line under the net, income and expense figures, after the arrow and percentage: names the month compared against. French renders the month lowercase (« vs avril »), English capitalized ("vs April").
  ///
  /// In fr, this message translates to:
  /// **'vs {month}'**
  String dashboardStatVsPreviousMonth(DateTime month);

  /// Status under the savings rate repère when the month met its goal; a check icon precedes it.
  ///
  /// In fr, this message translates to:
  /// **'Objectif atteint'**
  String get dashboardSavingsGoalReached;

  /// Goal line under the savings rate's progress bar when the rate is still below the goal; the point delta follows it. Phrased as progress rather than shortfall — the panel leads with encouragement.
  ///
  /// In fr, this message translates to:
  /// **'Objectif {goal} en cours'**
  String dashboardSavingsGoalPending(String goal);

  /// The savings rate's change in percentage points since the previous month, after the goal status (« +1,9 pt depuis avril »).
  ///
  /// In fr, this message translates to:
  /// **'{delta} pt depuis {month}'**
  String dashboardSavingsDeltaSince(String delta, DateTime month);

  /// Label of the goal mark on the savings rate repère (« objectif 20 % »). Lowercase: it sits on the meter.
  ///
  /// In fr, this message translates to:
  /// **'objectif {goal}'**
  String dashboardSavingsGoalMark(String goal);

  /// Placeholder for a reading-line figure the month has no value for.
  ///
  /// In fr, this message translates to:
  /// **'—'**
  String get dashboardNoValue;

  /// Title of the by-category expense breakdown chart card.
  ///
  /// In fr, this message translates to:
  /// **'Dépenses par catégorie'**
  String get dashboardCategoryBreakdownTitle;

  /// The row the smallest categories fold into past eight rows of « Dépenses par catégorie ».
  ///
  /// In fr, this message translates to:
  /// **'Autres'**
  String get dashboardCategoryOthers;

  /// Note in « Dépenses par catégorie » for a month without any expense.
  ///
  /// In fr, this message translates to:
  /// **'Aucune dépense ce mois.'**
  String get dashboardCategoryNoSpending;

  /// Title of the monthly savings chart (bar or line view).
  ///
  /// In fr, this message translates to:
  /// **'Épargne mensuelle'**
  String get dashboardSavingsTrendTitle;

  /// Follows the signed 12-month average on the right of the « Épargne mensuelle » heading.
  ///
  /// In fr, this message translates to:
  /// **'en moyenne sur 12 mois'**
  String get dashboardSavingsTrendAverage;

  /// Title of the recent-transactions card.
  ///
  /// In fr, this message translates to:
  /// **'Activité récente'**
  String get dashboardRecentActivityTitle;

  /// Link on the right of the « Activité récente » heading, opening Transactions.
  ///
  /// In fr, this message translates to:
  /// **'Toutes les transactions'**
  String get dashboardViewAllTransactions;

  /// Heading shown when the dashboard has no transactions to show.
  ///
  /// In fr, this message translates to:
  /// **'Aucune donnée pour ce mois'**
  String get dashboardEmptyTitle;

  /// Body under the dashboard empty-state heading, saying what to do.
  ///
  /// In fr, this message translates to:
  /// **'Importez un relevé OFX ou QFX pour voir vos revenus, vos dépenses et votre taux d’épargne.'**
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
  /// **'Le mois demandé n’est pas valide.'**
  String get dashboardErrorInvalidMonth;

  /// Fallback localized message for unrecognized or network errors on the dashboard.
  ///
  /// In fr, this message translates to:
  /// **'Le tableau de bord n’a pas pu être chargé. Rien n’a été modifié.'**
  String get dashboardErrorGeneric;

  /// Tooltip on the top bar's month label, which opens a month-and-year picker.
  ///
  /// In fr, this message translates to:
  /// **'Choisir un mois'**
  String get dashboardChooseMonth;

  /// Tooltip on the month selector's left chevron.
  ///
  /// In fr, this message translates to:
  /// **'Mois précédent'**
  String get dashboardPreviousMonth;

  /// Tooltip on the month selector's right chevron.
  ///
  /// In fr, this message translates to:
  /// **'Mois suivant'**
  String get dashboardNextMonth;

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
  /// **'Aucune catégorie'**
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

  /// Title-bar title of the categories and rules panel.
  ///
  /// In fr, this message translates to:
  /// **'Catégories et règles'**
  String get categoriesPanelTitle;

  /// Heading of the category tree, left pane of the categories panel.
  ///
  /// In fr, this message translates to:
  /// **'Catégories'**
  String get categoriesTreeTitle;

  /// First item of the category tree: shows every rule.
  ///
  /// In fr, this message translates to:
  /// **'Toutes les règles'**
  String get categoriesAllRules;

  /// Note at the foot of the category tree.
  ///
  /// In fr, this message translates to:
  /// **'Les catégories fournies avec Bastide ne peuvent pas être supprimées.'**
  String get categoriesSystemNote;

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
  /// **'{count, plural, =0{aucune règle} one{1 règle} other{{count} règles}}'**
  String categoryRuleCount(int count);

  /// Title of the delete-category confirmation; also its accessible name.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer la catégorie « {name} » ?'**
  String categoryDeleteConfirmTitle(String name);

  /// Lead of the delete-category confirmation. Names what else goes with it, since the deletion cascades.
  ///
  /// In fr, this message translates to:
  /// **'Ses sous-catégories seront supprimées aussi. Les transactions concernées redeviendront non catégorisées.'**
  String get categoryDeleteConfirmLead;

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

  /// Accessible name and tooltip of a colour square in the category form, by slot.
  ///
  /// In fr, this message translates to:
  /// **'{slot, select, cat1{Bleu} cat2{Orange} cat3{Vert} cat4{Ambre} cat5{Rose} cat6{Violet} other{Gris}}'**
  String categoryColorName(String slot);

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

  /// Icon choice in the category form: piggy bank glyph.
  ///
  /// In fr, this message translates to:
  /// **'Épargne'**
  String get categoryIconSavings;

  /// Icon choice in the category form: coins glyph.
  ///
  /// In fr, this message translates to:
  /// **'Autre'**
  String get categoryIconOther;

  /// Icon choice in the category form: key glyph.
  ///
  /// In fr, this message translates to:
  /// **'Clé'**
  String get categoryIconKey;

  /// Icon choice in the category form: lightning bolt glyph.
  ///
  /// In fr, this message translates to:
  /// **'Énergie'**
  String get categoryIconEnergy;

  /// Icon choice in the category form: wrench glyph.
  ///
  /// In fr, this message translates to:
  /// **'Travaux'**
  String get categoryIconRepairs;

  /// Icon choice in the category form: sofa glyph.
  ///
  /// In fr, this message translates to:
  /// **'Ameublement'**
  String get categoryIconFurniture;

  /// Icon choice in the category form: shopping cart glyph.
  ///
  /// In fr, this message translates to:
  /// **'Courses'**
  String get categoryIconGroceries;

  /// Icon choice in the category form: fork and knife glyph.
  ///
  /// In fr, this message translates to:
  /// **'Restaurant'**
  String get categoryIconRestaurant;

  /// Icon choice in the category form: coffee cup glyph.
  ///
  /// In fr, this message translates to:
  /// **'Café'**
  String get categoryIconCoffee;

  /// Icon choice in the category form: bus glyph.
  ///
  /// In fr, this message translates to:
  /// **'Transports en commun'**
  String get categoryIconPublicTransport;

  /// Icon choice in the category form: fuel pump glyph.
  ///
  /// In fr, this message translates to:
  /// **'Carburant'**
  String get categoryIconFuel;

  /// Icon choice in the category form: plane glyph.
  ///
  /// In fr, this message translates to:
  /// **'Voyages'**
  String get categoryIconTravel;

  /// Icon choice in the category form: ticket glyph.
  ///
  /// In fr, this message translates to:
  /// **'Sorties'**
  String get categoryIconOutings;

  /// Icon choice in the category form: game controller glyph.
  ///
  /// In fr, this message translates to:
  /// **'Jeux'**
  String get categoryIconGames;

  /// Icon choice in the category form: open book glyph.
  ///
  /// In fr, this message translates to:
  /// **'Lecture'**
  String get categoryIconReading;

  /// Icon choice in the category form: dumbbell glyph.
  ///
  /// In fr, this message translates to:
  /// **'Sport'**
  String get categoryIconSport;

  /// Icon choice in the category form: smartphone glyph.
  ///
  /// In fr, this message translates to:
  /// **'Téléphone'**
  String get categoryIconPhone;

  /// Icon choice in the category form: wifi glyph.
  ///
  /// In fr, this message translates to:
  /// **'Internet'**
  String get categoryIconInternet;

  /// Icon choice in the category form: pill glyph.
  ///
  /// In fr, this message translates to:
  /// **'Pharmacie'**
  String get categoryIconPharmacy;

  /// Icon choice in the category form: credit card glyph.
  ///
  /// In fr, this message translates to:
  /// **'Carte bancaire'**
  String get categoryIconCard;

  /// Icon choice in the category form: bank building glyph.
  ///
  /// In fr, this message translates to:
  /// **'Banque'**
  String get categoryIconBank;

  /// Icon choice in the category form: rising chart glyph.
  ///
  /// In fr, this message translates to:
  /// **'Placements'**
  String get categoryIconInvestments;

  /// Icon choice in the category form: receipt glyph.
  ///
  /// In fr, this message translates to:
  /// **'Factures'**
  String get categoryIconBills;

  /// Icon choice in the category form: briefcase glyph.
  ///
  /// In fr, this message translates to:
  /// **'Salaire'**
  String get categoryIconSalary;

  /// Icon choice in the category form: gift glyph.
  ///
  /// In fr, this message translates to:
  /// **'Cadeaux'**
  String get categoryIconGifts;

  /// Icon choice in the category form: shirt glyph.
  ///
  /// In fr, this message translates to:
  /// **'Vêtements'**
  String get categoryIconClothing;

  /// Icon choice in the category form: shopping bag glyph.
  ///
  /// In fr, this message translates to:
  /// **'Achats'**
  String get categoryIconShopping;

  /// Icon choice in the category form: graduation cap glyph.
  ///
  /// In fr, this message translates to:
  /// **'Éducation'**
  String get categoryIconEducation;

  /// Icon choice in the category form: baby glyph.
  ///
  /// In fr, this message translates to:
  /// **'Enfants'**
  String get categoryIconChildren;

  /// Icon choice in the category form: paw print glyph.
  ///
  /// In fr, this message translates to:
  /// **'Animaux'**
  String get categoryIconPets;

  /// Icon choice in the category form: hand holding a heart glyph.
  ///
  /// In fr, this message translates to:
  /// **'Dons'**
  String get categoryIconDonations;

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

  /// Top-bar primary button while the rules view is showing.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle règle'**
  String get rulesAddButton;

  /// Note beside the view switch on the rules view, stating both how rules are ordered and what they will never overwrite.
  ///
  /// In fr, this message translates to:
  /// **'Appliquées dans cet ordre. Une catégorie choisie à la main n’est jamais remplacée.'**
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
  /// **'{count, plural, =0{Aucune opération recatégorisée} one{{count} opération recatégorisée} other{{count} opérations recatégorisées}}'**
  String rulesApplyToastTitle(int count);

  /// Second line of the rule-run toast. Answers the question the count alone raises.
  ///
  /// In fr, this message translates to:
  /// **'Vos catégories choisies à la main n’ont pas été modifiées.'**
  String get rulesApplyToastBody;

  /// Toast headline when the rule run itself failed.
  ///
  /// In fr, this message translates to:
  /// **'L’exécution des règles a échoué'**
  String get rulesApplyFailed;

  /// Toast headline when persisting a drag-reorder failed and the previous order was restored.
  ///
  /// In fr, this message translates to:
  /// **'L’ordre n’a pas pu être enregistré'**
  String get rulesReorderFailed;

  /// Toast headline when enabling or disabling a rule failed and the switch was put back.
  ///
  /// In fr, this message translates to:
  /// **'La règle n’a pas pu être modifiée'**
  String get rulesToggleFailed;

  /// Tooltip on the ✕ beside the category filter chip in the rules view, opened from a category card's footer.
  ///
  /// In fr, this message translates to:
  /// **'Afficher toutes les règles'**
  String get rulesFilterClear;

  /// Shown inside the rules card when the category filter leaves no rule.
  ///
  /// In fr, this message translates to:
  /// **'Aucune règle pour cette catégorie.'**
  String get rulesFilterEmpty;

  /// Retry button shown when the rules list fails to load.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get rulesRetry;

  /// Heading of the rules pane, right of the category tree.
  ///
  /// In fr, this message translates to:
  /// **'Règles'**
  String get rulesPaneTitle;

  /// Rules table column: the rule's position in the evaluation order.
  ///
  /// In fr, this message translates to:
  /// **'Ordre'**
  String get rulesColumnOrder;

  /// Rules table column: the transaction field the rule reads.
  ///
  /// In fr, this message translates to:
  /// **'Champ'**
  String get rulesColumnField;

  /// Rules table column: how the pattern is compared.
  ///
  /// In fr, this message translates to:
  /// **'Condition'**
  String get rulesColumnCondition;

  /// Rules table column: the rule's pattern.
  ///
  /// In fr, this message translates to:
  /// **'Motif'**
  String get rulesColumnPattern;

  /// Rules table column: the category the rule gives.
  ///
  /// In fr, this message translates to:
  /// **'Catégorie'**
  String get rulesColumnCategory;

  /// Rules table column: how many transactions the rule classes.
  ///
  /// In fr, this message translates to:
  /// **'Correspondances'**
  String get rulesColumnMatches;

  /// Rules table column: the rule's on/off toggle.
  ///
  /// In fr, this message translates to:
  /// **'Active'**
  String get rulesColumnActive;

  /// Heading of the rules empty state.
  ///
  /// In fr, this message translates to:
  /// **'Aucune règle'**
  String get rulesEmptyTitle;

  /// Body of the rules empty state, explaining what a rule does before asking the user to write one.
  ///
  /// In fr, this message translates to:
  /// **'Une règle reconnaît un libellé, « CARREFOUR » par exemple, et attribue sa catégorie à chaque opération correspondante, aujourd’hui et aux prochains imports.'**
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
  /// **'Description'**
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
  /// **'Indiquez une priorité d’au moins 1.'**
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
  /// **'Catégorie cible'**
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
  /// **'Active'**
  String get ruleFormEnabledLabel;

  /// Label of the rule editor's logo section.
  ///
  /// In fr, this message translates to:
  /// **'Logo'**
  String get ruleFormLogoLabel;

  /// Helper under the rule editor's logo section.
  ///
  /// In fr, this message translates to:
  /// **'Affiché à la place du monogramme sur les transactions et les abonnements que cette règle reconnaît.'**
  String get ruleFormLogoHelper;

  /// Button of the rule editor picking a logo picture.
  ///
  /// In fr, this message translates to:
  /// **'Choisir une image'**
  String get ruleFormLogoChoose;

  /// Button of the rule editor picking a picture to replace the rule's logo.
  ///
  /// In fr, this message translates to:
  /// **'Remplacer…'**
  String get ruleFormLogoReplace;

  /// Tooltip and semantic label of the rule editor's bin icon button removing the rule's logo.
  ///
  /// In fr, this message translates to:
  /// **'Retirer'**
  String get ruleFormLogoRemove;

  /// Shown instead of the logo buttons while creating a rule: a logo is attached to a saved rule.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrez la règle pour lui ajouter un logo.'**
  String get ruleFormLogoSaveFirst;

  /// The secondary action of a modal: leaves it without saving.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get modalCancel;

  /// The single action of an acknowledgement modal, and the footer action of a list editor.
  ///
  /// In fr, this message translates to:
  /// **'Fermer'**
  String get modalClose;

  /// The secondary action of the banner shown when a modal’s body cannot load.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get modalRetry;

  /// Title of the confirmation asked when leaving a form that holds unsaved input.
  ///
  /// In fr, this message translates to:
  /// **'Abandonner les modifications ?'**
  String get modalDiscardTitle;

  /// Lead of the discard confirmation, naming the form being left.
  ///
  /// In fr, this message translates to:
  /// **'Ce que vous avez saisi dans « {form} » sera perdu.'**
  String modalDiscardLead(String form);

  /// Secondary action of the discard confirmation: back to the form.
  ///
  /// In fr, this message translates to:
  /// **'Continuer la saisie'**
  String get modalDiscardContinue;

  /// Primary action of the discard confirmation: closes the form and loses the input.
  ///
  /// In fr, this message translates to:
  /// **'Abandonner'**
  String get modalDiscardConfirm;

  /// Screen-reader label of the crop window. With it focused, arrow keys move the picture and + / − zoom.
  ///
  /// In fr, this message translates to:
  /// **'Cadrage'**
  String get modalCropWindow;

  /// Screen-reader label of the crop step’s zoom slider.
  ///
  /// In fr, this message translates to:
  /// **'Zoom'**
  String get modalCropZoom;

  /// The crop zoom factor printed beside its slider, formatted with one decimal (« 2,2 × »).
  ///
  /// In fr, this message translates to:
  /// **'{value} ×'**
  String modalCropZoomValue(String value);

  /// Screen-reader label of a small logo picture that opens it enlarged when clicked.
  ///
  /// In fr, this message translates to:
  /// **'Afficher le logo en grand'**
  String get logoZoomOpen;

  /// Screen-reader label of the enlarged logo picture in its dialog.
  ///
  /// In fr, this message translates to:
  /// **'Logo agrandi'**
  String get logoZoomLabel;

  /// Error when the picked logo file is not a supported picture.
  ///
  /// In fr, this message translates to:
  /// **'Ce fichier n’est pas une image PNG, JPEG ou WebP.'**
  String get ruleLogoInvalid;

  /// Error when the logo could not be saved or removed for another reason.
  ///
  /// In fr, this message translates to:
  /// **'Le logo n’a pas pu être enregistré. Réessayez.'**
  String get ruleLogoError;

  /// Title of the modal where the user crops the picked logo to a square.
  ///
  /// In fr, this message translates to:
  /// **'Recadrer le logo'**
  String get ruleLogoCropTitle;

  /// Lead text of the logo crop modal.
  ///
  /// In fr, this message translates to:
  /// **'Faites glisser l’image pour cadrer le logo.'**
  String get ruleLogoCropLead;

  /// Confirm button of the logo crop modal, uploading the cropped logo.
  ///
  /// In fr, this message translates to:
  /// **'Utiliser ce logo'**
  String get ruleLogoCropSave;

  /// Error when the picked logo is over the size limit; {megabytes} is that limit.
  ///
  /// In fr, this message translates to:
  /// **'Cette image est trop lourde : choisissez un fichier de moins de {megabytes} Mo.'**
  String ruleLogoTooLarge(int megabytes);

  /// Button of the rule editor opening the dialog that downloads a logo from a web address.
  ///
  /// In fr, this message translates to:
  /// **'Depuis une adresse…'**
  String get ruleFormLogoFromUrl;

  /// Title of the dialog where the user pastes the web address of a logo picture.
  ///
  /// In fr, this message translates to:
  /// **'Logo depuis une adresse'**
  String get ruleLogoUrlTitle;

  /// Lead text of the logo-from-address dialog: the app downloads the picture itself, then the crop step follows.
  ///
  /// In fr, this message translates to:
  /// **'Collez l’adresse d’une image. Bastide la télécharge depuis cet ordinateur, puis vous la recadrez.'**
  String get ruleLogoUrlLead;

  /// Label of the web address field in the logo-from-address dialog.
  ///
  /// In fr, this message translates to:
  /// **'Adresse de l’image'**
  String get ruleLogoUrlLabel;

  /// Placeholder of the web address field in the logo-from-address dialog.
  ///
  /// In fr, this message translates to:
  /// **'https://…'**
  String get ruleLogoUrlHint;

  /// Confirm button of the logo-from-address dialog: downloads the picture.
  ///
  /// In fr, this message translates to:
  /// **'Télécharger'**
  String get ruleLogoUrlFetch;

  /// Error when the pasted logo address is not an http or https address.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez une adresse qui commence par http:// ou https://.'**
  String get ruleLogoUrlInvalidAddress;

  /// Error when the logo address could not be reached, answered an error or timed out.
  ///
  /// In fr, this message translates to:
  /// **'L’image n’a pas pu être téléchargée. Vérifiez l’adresse et votre connexion.'**
  String get ruleLogoUrlUnreachable;

  /// Error when the downloaded logo is over the upload size limit; {megabytes} is that limit.
  ///
  /// In fr, this message translates to:
  /// **'Cette image dépasse {megabytes} Mo.'**
  String ruleLogoUrlTooLarge(int megabytes);

  /// Error when the downloaded file is not a picture.
  ///
  /// In fr, this message translates to:
  /// **'Cette adresse ne mène pas à une image.'**
  String get ruleLogoUrlNotAPicture;

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

  /// Title of the confirmation before a rule is deleted; also its accessible name.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer la règle « {pattern} » ?'**
  String ruleDeleteConfirmTitle(String pattern);

  /// Lead of the confirmation before a rule is deleted.
  ///
  /// In fr, this message translates to:
  /// **'Les opérations qu’elle a déjà classées gardent leur catégorie.'**
  String get ruleDeleteConfirmLead;

  /// Info banner shown while the match preview is in flight.
  ///
  /// In fr, this message translates to:
  /// **'Recherche des transactions correspondantes…'**
  String get rulePreviewLoading;

  /// Match-preview banner when the backend returned no example to quote.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Ne correspond à aucune opération existante.} one{Correspond à {count} opération existante.} other{Correspond à {count} opérations existantes.}}'**
  String rulePreviewCount(int count);

  /// Match-preview banner naming one of the matched transactions, so the user can tell whether the rule caught what they meant.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{Correspond à {count} opération existante : « {sample} » du {date}.} other{Correspond à {count} opérations existantes, dont « {sample} » du {date}.}}'**
  String rulePreviewCountWithSample(int count, String sample, String date);

  /// Localized message for RULE_PATTERN_INVALID. Rendered on the pattern field, never as a match count of zero.
  ///
  /// In fr, this message translates to:
  /// **'Ce motif n’est pas une expression régulière valide.'**
  String get ruleErrorPatternInvalid;

  /// Localized message for the backend's RULE_NOT_FOUND code.
  ///
  /// In fr, this message translates to:
  /// **'Cette règle n’existe plus.'**
  String get ruleErrorNotFound;

  /// Localized message when a rule targets a category the backend can no longer resolve.
  ///
  /// In fr, this message translates to:
  /// **'La catégorie visée n’existe plus.'**
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

  /// Tooltip on the rules view's button opening the pack file picker.
  ///
  /// In fr, this message translates to:
  /// **'Importer un pack de règles'**
  String get rulePackImportFile;

  /// Tooltip on the rules view's button importing one of the packs bundled with the app.
  ///
  /// In fr, this message translates to:
  /// **'Importer « {name} »'**
  String rulePackImportBuiltin(String name);

  /// Tooltip on the rules view's button opening the export review sheet.
  ///
  /// In fr, this message translates to:
  /// **'Exporter mes règles'**
  String get rulePackExportAction;

  /// Title of the dialog explaining why a pack was refused.
  ///
  /// In fr, this message translates to:
  /// **'Ce fichier n’a pas été accepté'**
  String get rulePackRefusedTitle;

  /// Refusal reason: the file isn't a pack-shaped JSON document.
  ///
  /// In fr, this message translates to:
  /// **'Ce fichier n’est pas un pack de règles Bastide. Attendu : un fichier JSON avec un nom, une version de format et une liste de règles.'**
  String get rulePackRefusedMalformed;

  /// Refusal reason: unsupported format_version. Says why the pack is refused outright rather than read best-effort.
  ///
  /// In fr, this message translates to:
  /// **'Ce pack utilise une version de format que cette version de Bastide ne lit pas. Elle lit la version {version}. Un pack partiellement compris perdrait silencieusement des règles, il est donc refusé en entier.'**
  String rulePackRefusedVersion(int version);

  /// Refusal reason: the pack contains a regex rule. Names the risk, and the three types that are accepted.
  ///
  /// In fr, this message translates to:
  /// **'Rien n’a été importé. Ce pack contient une règle « regex », que Bastide n’accepte pas d’un fichier partagé : écrite par quelqu’un d’autre, elle pourrait ralentir fortement l’application. Les conditions « contient », « égal à » et « plage » sont acceptées.'**
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
  /// **'Appliquer les règles à mes transactions existantes après l’import'**
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
  /// **'{count, plural, =0{Aucune transaction n’a changé de catégorie.} one{{count} transaction recatégorisée.} other{{count} transactions recatégorisées.}}'**
  String rulePackImportedBody(int count);

  /// Toast headline when a pack import failed.
  ///
  /// In fr, this message translates to:
  /// **'L’import a échoué'**
  String get rulePackImportFailed;

  /// Title of the export review sheet.
  ///
  /// In fr, this message translates to:
  /// **'Exporter mes règles'**
  String get rulePackExportTitle;

  /// Warning at the top of the export sheet. Names a concrete example, because the abstract warning is the one nobody reads.
  ///
  /// In fr, this message translates to:
  /// **'Relisez avant d’enregistrer. Un motif peut contenir des informations personnelles, comme le nom de votre propriétaire : « VIR LOYER DUPONT ».'**
  String get rulePackExportPrivacyNotice;

  /// Section label above the verbatim pack contents in the export sheet.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Contenu du fichier : aucune règle} one{Contenu du fichier : {count} règle} other{Contenu du fichier : {count} règles}}'**
  String rulePackExportContents(int count);

  /// Section label above the rules an export could not carry.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{{count} règle non exportable} other{{count} règles non exportables}}'**
  String rulePackOmittedLabel(int count);

  /// Explains one omitted rule: it uses a regex, which no importer accepts.
  ///
  /// In fr, this message translates to:
  /// **'« {pattern} » : les règles regex ne peuvent pas figurer dans un pack.'**
  String rulePackOmittedRegex(String pattern);

  /// Explains one omitted rule: it targets a user-defined category, which has no portable key.
  ///
  /// In fr, this message translates to:
  /// **'« {pattern} » : vise une catégorie personnalisée, qui n’a pas d’identifiant partageable.'**
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
  /// **'L’export a échoué'**
  String get rulePackExportFailed;

  /// CTA on the rules empty state offering the bundled pack, named and sized.
  ///
  /// In fr, this message translates to:
  /// **'Commencer avec « {name} » ({count} règles)'**
  String rulePackStartWith(String name, int count);

  /// Reassurance under the bundled-pack CTA: the preview step always comes first.
  ///
  /// In fr, this message translates to:
  /// **'Vous verrez ce que le pack ferait avant de l’importer.'**
  String get rulePackStartWithHelper;

  /// Section label over the list of a pack's rules on the import sheet, each with its logo or monogram.
  ///
  /// In fr, this message translates to:
  /// **'Règles du pack'**
  String get rulePackRulesLabel;

  /// Import report line: how many logos the import would attach.
  ///
  /// In fr, this message translates to:
  /// **'Logos à ajouter'**
  String get rulePackLogoCount;

  /// Checkbox on the import sheet, off by default: also download the logos the pack links to.
  ///
  /// In fr, this message translates to:
  /// **'Télécharger les logos ({count})'**
  String rulePackLogoDownload(int count);

  /// Line under the logo download checkbox saying where linked logos come from.
  ///
  /// In fr, this message translates to:
  /// **'Ces logos viennent de Wikimedia Commons et ne sont téléchargés que si vous cochez la case.'**
  String get rulePackLogoDownloadHelper;

  /// Title of the dialog listing the pack logos an import could not attach.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{Un logo n’a pas pu être ajouté} other{{count} logos n’ont pas pu être ajoutés}}'**
  String rulePackLogoFailuresTitle(int count);

  /// Reassurance at the top of the logo failures dialog: the import itself succeeded.
  ///
  /// In fr, this message translates to:
  /// **'Les règles ont bien été importées : seuls ces logos n’ont pas été ajoutés.'**
  String get rulePackLogoFailuresNotice;

  /// A logo that failed because it is not a supported picture, named by its rule's pattern.
  ///
  /// In fr, this message translates to:
  /// **'« {pattern} » : le fichier n’est pas une image PNG, JPEG ou WebP.'**
  String rulePackLogoFailureInvalidImage(String pattern);

  /// A logo that failed because it is too large, named by its rule's pattern.
  ///
  /// In fr, this message translates to:
  /// **'« {pattern} » : l’image dépasse la taille autorisée.'**
  String rulePackLogoFailureTooLarge(String pattern);

  /// A linked logo that could not be downloaded, named by its rule's pattern.
  ///
  /// In fr, this message translates to:
  /// **'« {pattern} » : le téléchargement a échoué.'**
  String rulePackLogoFailureDownloadFailed(String pattern);

  /// Toggle on the export sheet: embed each rule's logo in the pack.
  ///
  /// In fr, this message translates to:
  /// **'Inclure les logos'**
  String get rulePackExportIncludeLogos;

  /// Under the include-logos toggle: how many logos the export embeds.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucune règle n’a de logo à inclure.} one{{count} logo inclus.} other{{count} logos inclus.}}'**
  String rulePackExportLogoCount(int count);

  /// Warning on the export sheet when the logos would take the pack over the size an import accepts.
  ///
  /// In fr, this message translates to:
  /// **'Les logos n’ont pas été inclus : le pack serait trop volumineux pour être importé. Toutes les règles sont exportées, sans leurs logos.'**
  String get rulePackExportLogosTooLarge;

  /// Stand-in shown in the export preview instead of an embedded logo's base64; the saved file keeps the picture.
  ///
  /// In fr, this message translates to:
  /// **'‹ image de {kilobytes} Ko ›'**
  String rulePackExportLogoElided(int kilobytes);

  /// Calm invitation at the foot of the review queue's header card when AI is off or the runtime is unreachable. The only place in the app that mentions it.
  ///
  /// In fr, this message translates to:
  /// **'Activez l’IA locale pour classer les opérations que vos règles n’ont pas reconnues.'**
  String get reviewAiInvitation;

  /// Link at the end of the AI invitation, opening the settings panel.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres'**
  String get reviewAiInvitationLink;

  /// Caption after a proposed category. Always a percentage, never the raw [0,1] value the API returns.
  ///
  /// In fr, this message translates to:
  /// **'confiance {confidence}'**
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
  /// **'Aucune proposition'**
  String get reviewNoProposal;

  /// Link on a review row with no proposal, opening the category picker.
  ///
  /// In fr, this message translates to:
  /// **'Choisir une catégorie'**
  String get reviewChooseCategory;

  /// Label of the always-categorize modal's target-category select.
  ///
  /// In fr, this message translates to:
  /// **'Catégorie cible'**
  String get alwaysRuleCategoryLabel;

  /// Checkbox in the always-categorize modal: re-run the new rule over transactions already imported.
  ///
  /// In fr, this message translates to:
  /// **'Appliquer aux opérations existantes'**
  String get alwaysRuleApplyExisting;

  /// Confirm button of the always-categorize modal.
  ///
  /// In fr, this message translates to:
  /// **'Créer la règle'**
  String get alwaysRuleSubmit;

  /// Shown in the always-categorize modal when the server-side pre-fill could not be fetched — the form stays usable.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de pré-remplir la règle. Renseignez le motif vous-même.'**
  String get alwaysRuleSuggestionFailed;

  /// Action on the review queue's header card that starts a local-AI categorization run over the pending rows.
  ///
  /// In fr, this message translates to:
  /// **'Catégoriser avec l’IA'**
  String get reviewQueueRunAction;

  /// Headline of the banner that replaces the review queue's header card while a run is classifying.
  ///
  /// In fr, this message translates to:
  /// **'{total, plural, one{Catégorisation en cours : {processed} sur {total} opération} other{Catégorisation en cours : {processed} sur {total} opérations}}'**
  String runBannerRunning(int processed, int total);

  /// Sub-line under the running banner: what the run has settled, what it has left for the user, and the reassurance that nothing is blocked.
  ///
  /// In fr, this message translates to:
  /// **'{assigned, plural, one{{assigned} classée · {deferred} à vérifier} other{{assigned} classées · {deferred} à vérifier}}'**
  String runBannerRunningDetail(int assigned, int deferred);

  /// Cancels the categorization run in flight. The executor stops after the batch it is on.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get runBannerCancel;

  /// Dismissible amber banner after a run that ended `partial`. A report, not an error wall.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{Catégorisation terminée. {count} opération n’a pas pu être analysée.} other{Catégorisation terminée. {count} opérations n’ont pas pu être analysées.}}'**
  String runBannerPartial(int count);

  /// Link on the partial-run banner, showing the transactions the run could not analyse.
  ///
  /// In fr, this message translates to:
  /// **'Voir'**
  String get runBannerPartialAction;

  /// Banner after a run that ended `failed` — reported plainly; the queue stays fully usable.
  ///
  /// In fr, this message translates to:
  /// **'La catégorisation n’a pas pu s’exécuter.'**
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

  /// Name of the AI card's opt-in row, shown beside its toggle, and the toggle's accessible label.
  ///
  /// In fr, this message translates to:
  /// **'Catégorisation par IA'**
  String get settingsAiToggleLabel;

  /// The card's privacy callout — its centerpiece. Visible whenever the card is, whether or not AI is enabled.
  ///
  /// In fr, this message translates to:
  /// **'Les libellés de vos opérations sont envoyés à un modèle qui s’exécute sur cet ordinateur. Rien ne quitte votre machine.'**
  String get settingsAiPrivacy;

  /// Label of the inference base URL field.
  ///
  /// In fr, this message translates to:
  /// **'Adresse du moteur'**
  String get settingsAiBaseUrlLabel;

  /// Helper under the engine address field, stating the loopback-only rule.
  ///
  /// In fr, this message translates to:
  /// **'Adresse locale uniquement : 127.0.0.1 ou localhost.'**
  String get settingsAiBaseUrlHelp;

  /// Inline validation shown on the address field when the backend refuses a non-loopback URL (422). States why it was refused, not only that it was.
  ///
  /// In fr, this message translates to:
  /// **'Adresse refusée : le moteur doit s’exécuter sur cet ordinateur (127.0.0.1 ou localhost). Une adresse distante enverrait les descriptions de vos transactions hors de votre machine.'**
  String get settingsAiBaseUrlRejected;

  /// Label of the model tag field.
  ///
  /// In fr, this message translates to:
  /// **'Modèle'**
  String get settingsAiModelLabel;

  /// Helper under the model field when no engine answered, where the field degrades to a dashed read-only dash.
  ///
  /// In fr, this message translates to:
  /// **'Moteur injoignable : aucun modèle à proposer.'**
  String get settingsAiModelUnavailable;

  /// Accessible label of the control opening the list of models the engine reported.
  ///
  /// In fr, this message translates to:
  /// **'Choisir un modèle'**
  String get settingsAiModelChoose;

  /// Helper under the threshold slider, stating what the threshold decides.
  ///
  /// In fr, this message translates to:
  /// **'En dessous, l’opération vous est proposée pour vérification au lieu d’être classée.'**
  String get settingsAiThresholdHelp;

  /// Status row when nothing answered at the configured address.
  ///
  /// In fr, this message translates to:
  /// **'Aucun moteur détecté à cette adresse.'**
  String get settingsAiStatusUnreachable;

  /// Link beside the no-engine status, opening the local runtime's download page in the browser.
  ///
  /// In fr, this message translates to:
  /// **'En savoir plus'**
  String get settingsAiLearnMore;

  /// Button that probes the configured runtime.
  ///
  /// In fr, this message translates to:
  /// **'Tester'**
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
  /// **'Sauvegarde'**
  String get settingsBackupTitle;

  /// Label of the export row on the backup card.
  ///
  /// In fr, this message translates to:
  /// **'Exporter toutes les données'**
  String get settingsBackupExportLabel;

  /// Caption under the export row's label: what the file contains.
  ///
  /// In fr, this message translates to:
  /// **'Un fichier .bastide, non chiffré, avec tout votre historique. Conservez-le en lieu sûr.'**
  String get settingsBackupExportCaption;

  /// Replaces the export caption while the archive is being built.
  ///
  /// In fr, this message translates to:
  /// **'Préparation de l’archive…'**
  String get settingsBackupExportPreparing;

  /// Primary button that exports a full backup.
  ///
  /// In fr, this message translates to:
  /// **'Exporter'**
  String get settingsBackupExport;

  /// Line under the export row with the time of the latest backup.
  ///
  /// In fr, this message translates to:
  /// **'Dernière sauvegarde le {when}'**
  String settingsBackupLast(String when);

  /// Shown under the export row when the user has never exported a backup.
  ///
  /// In fr, this message translates to:
  /// **'Aucune sauvegarde.'**
  String get settingsBackupNone;

  /// A backup timestamp: a locale-formatted date then time.
  ///
  /// In fr, this message translates to:
  /// **'{date} à {time}'**
  String settingsBackupDateTime(String date, String time);

  /// Label of the restore row on the backup card.
  ///
  /// In fr, this message translates to:
  /// **'Restaurer une sauvegarde'**
  String get settingsBackupRestoreTitle;

  /// Line under the restore row's label.
  ///
  /// In fr, this message translates to:
  /// **'Remplace toutes les données actuelles, après confirmation.'**
  String get settingsBackupRestoreSubtitle;

  /// Secondary button that opens the file picker to restore a backup.
  ///
  /// In fr, this message translates to:
  /// **'Importer un fichier'**
  String get settingsBackupRestoreButton;

  /// Restore refused: the archive was written by a newer app version (BACKUP_TOO_NEW).
  ///
  /// In fr, this message translates to:
  /// **'Ce fichier provient d’une version plus récente de Bastide. Mettez l’application à jour pour le restaurer.'**
  String get settingsBackupErrorTooNew;

  /// Restore refused: not a Bastide archive or corrupted (BACKUP_INVALID).
  ///
  /// In fr, this message translates to:
  /// **'Ce fichier n’est pas une sauvegarde Bastide valide, ou il est endommagé.'**
  String get settingsBackupErrorInvalid;

  /// Restore refused: the archive's currency differs from the user's (BACKUP_CURRENCY_MISMATCH).
  ///
  /// In fr, this message translates to:
  /// **'Cette sauvegarde utilise une autre devise que votre compte.'**
  String get settingsBackupErrorCurrency;

  /// Restore refused while a categorization run is in flight (BACKUP_RUN_ACTIVE).
  ///
  /// In fr, this message translates to:
  /// **'Une catégorisation est en cours. Attendez qu’elle se termine, puis réessayez.'**
  String get settingsBackupErrorRunActive;

  /// Restore refused: its rows belong to another account still in this database (BACKUP_CONFLICT).
  ///
  /// In fr, this message translates to:
  /// **'Cette sauvegarde appartient à un autre compte présent sur cet ordinateur.'**
  String get settingsBackupErrorConflict;

  /// Restore failed for any other reason; nothing was changed.
  ///
  /// In fr, this message translates to:
  /// **'La restauration a échoué. Vos données n’ont pas été modifiées.'**
  String get settingsBackupErrorUnknown;

  /// Toast after a backup was written. The String placeholders are the locale-formatted counts.
  ///
  /// In fr, this message translates to:
  /// **'Sauvegarde enregistrée · {transactionCount, plural, one{{transactions} opération} other{{transactions} opérations}}, {accountCount, plural, one{{accounts} compte} other{{accounts} comptes}}.'**
  String settingsBackupExported(
    int transactionCount,
    String transactions,
    int accountCount,
    String accounts,
  );

  /// Error toast when building or writing the backup failed.
  ///
  /// In fr, this message translates to:
  /// **'L’export a échoué. Réessayez.'**
  String get settingsBackupExportFailed;

  /// Title of the restore confirmation modal.
  ///
  /// In fr, this message translates to:
  /// **'Restaurer cette sauvegarde ?'**
  String get settingsBackupConfirmTitle;

  /// Lead of the restore confirmation; the date is the long export date (« 11 mai 2026 »).
  ///
  /// In fr, this message translates to:
  /// **'Les données exportées le {date} remplacent toutes vos données actuelles.'**
  String settingsBackupConfirmLead(String date);

  /// Header of the restore comparison's column for the chosen file.
  ///
  /// In fr, this message translates to:
  /// **'Sauvegarde'**
  String get settingsBackupConfirmBackupColumn;

  /// Header of the restore comparison's column for the data as it stands.
  ///
  /// In fr, this message translates to:
  /// **'Actuel'**
  String get settingsBackupConfirmCurrentColumn;

  /// Comparison row: the date of the latest import on each side.
  ///
  /// In fr, this message translates to:
  /// **'Dernier import'**
  String get settingsBackupConfirmLastImport;

  /// Warning status text when the backup was exported before the latest import; long date.
  ///
  /// In fr, this message translates to:
  /// **'Cette sauvegarde est antérieure à votre dernier import du {date}.'**
  String settingsBackupConfirmOlder(String date);

  /// Banner when the current data to compare with could not load.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de lire vos données actuelles.'**
  String get settingsBackupConfirmCurrentError;

  /// Ghost action of the restore and reset confirmations: exports without closing the modal.
  ///
  /// In fr, this message translates to:
  /// **'Exporter d’abord'**
  String get settingsBackupExportFirst;

  /// Positive status text replacing « Exporter d’abord » once the file is saved.
  ///
  /// In fr, this message translates to:
  /// **'Sauvegarde enregistrée'**
  String get settingsBackupSaved;

  /// Summary row: the app version that wrote the backup.
  ///
  /// In fr, this message translates to:
  /// **'Version de l’application'**
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
  /// **'Abonnements'**
  String get navSubscriptions;

  /// Button re-running detection over the imported ledger: secondary in the top bar, primary on the empty state.
  ///
  /// In fr, this message translates to:
  /// **'Détecter'**
  String get subscriptionsDetect;

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
  /// **'La détection n’a pas pu s’exécuter.'**
  String get subscriptionsDetectFailed;

  /// Label of the lead figure of the summary line: every running series brought back to one month.
  ///
  /// In fr, this message translates to:
  /// **'Charge mensuelle'**
  String get subscriptionsBurdenLabel;

  /// Caption under the monthly charge, naming the normalisation it applies.
  ///
  /// In fr, this message translates to:
  /// **'Trimestriels et annuels ramenés au mois'**
  String get subscriptionsBurdenCaption;

  /// Label of the summary-line figure counting the recurring payments still running.
  ///
  /// In fr, this message translates to:
  /// **'Actifs'**
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

  /// Label of the card naming the soonest charge ahead.
  ///
  /// In fr, this message translates to:
  /// **'Prochain prélèvement'**
  String get subscriptionsNextLabel;

  /// Value line of the next-charge card: the payment and how far off it is.
  ///
  /// In fr, this message translates to:
  /// **'{label}, {when}'**
  String subscriptionsNextValue(String label, String when);

  /// Caption of the next-charge card: the amount and the exact date.
  ///
  /// In fr, this message translates to:
  /// **'{amount} · {date}'**
  String subscriptionsNextCaption(String amount, String date);

  /// Relative phrasing for a charge due today.
  ///
  /// In fr, this message translates to:
  /// **'aujourd’hui'**
  String get subscriptionsNextToday;

  /// Relative phrasing for a charge due tomorrow.
  ///
  /// In fr, this message translates to:
  /// **'demain'**
  String get subscriptionsNextTomorrow;

  /// Relative phrasing for a charge further ahead.
  ///
  /// In fr, this message translates to:
  /// **'{days, plural, =1{dans 1 jour} other{dans {days} jours}}'**
  String subscriptionsNextInDays(int days);

  /// Label of the summary-line figure counting the series that carry a price rise or a missed charge. Hidden at 0.
  ///
  /// In fr, this message translates to:
  /// **'À regarder'**
  String get subscriptionsWatchLabel;

  /// Part of the caption under « À regarder »: how many series rose in price.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 hausse} other{{count} hausses}}'**
  String subscriptionsWatchIncreases(int count);

  /// Part of the caption under « À regarder »: how many series missed a charge.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 prélèvement manquant} other{{count} prélèvements manquants}}'**
  String subscriptionsWatchMissed(int count);

  /// Table header over the payment name column.
  ///
  /// In fr, this message translates to:
  /// **'Abonnement'**
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
  /// **'État'**
  String get subscriptionsColumnStatus;

  /// Tooltip on the subscriptions table's name header while it is not the sort column.
  ///
  /// In fr, this message translates to:
  /// **'Trier par nom'**
  String get subscriptionsSortByName;

  /// Tooltip on the subscriptions table's amount header while it is not the sort column.
  ///
  /// In fr, this message translates to:
  /// **'Trier par montant'**
  String get subscriptionsSortByAmount;

  /// Tooltip on the subscriptions table's next-charge header while it is not the sort column.
  ///
  /// In fr, this message translates to:
  /// **'Trier par prochaine échéance'**
  String get subscriptionsSortByNext;

  /// Tooltip on the header the subscriptions table is sorted on, ascending.
  ///
  /// In fr, this message translates to:
  /// **'Tri croissant. Cliquez pour inverser.'**
  String get subscriptionsSortedAscending;

  /// Tooltip on the header the subscriptions table is sorted on, descending.
  ///
  /// In fr, this message translates to:
  /// **'Tri décroissant. Cliquez pour inverser.'**
  String get subscriptionsSortedDescending;

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
  /// **'Hausse : {from} → {to}'**
  String subscriptionSignalIncrease(String from, String to);

  /// Amber status pill on a row whose charge has not landed past its tolerance.
  ///
  /// In fr, this message translates to:
  /// **'{days, plural, =1{Prélèvement manquant depuis 1 jour} other{Prélèvement manquant depuis {days} jours}}'**
  String subscriptionSignalMissed(int days);

  /// Gray status pill on a recurring payment the user ended. It stays listed, dimmed.
  ///
  /// In fr, this message translates to:
  /// **'Résilié, dernier prélèvement le {date}'**
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
  /// **'Marquer comme résilié'**
  String get subscriptionActionCancel;

  /// Kebab action opening the series in the edit form.
  ///
  /// In fr, this message translates to:
  /// **'Modifier'**
  String get subscriptionActionEdit;

  /// Kebab and detail action putting a series away: it leaves the list, the summary and detection, history kept.
  ///
  /// In fr, this message translates to:
  /// **'Archiver'**
  String get subscriptionActionArchive;

  /// Kebab and detail action on an archived series: bring it back.
  ///
  /// In fr, this message translates to:
  /// **'Désarchiver'**
  String get subscriptionActionUnarchive;

  /// Toast title when archiving or unarchiving a series from its detail fails.
  ///
  /// In fr, this message translates to:
  /// **'L’archivage de ce paiement n’a pas pu être modifié.'**
  String get subscriptionArchiveFailed;

  /// Link below the table that reveals archived series in place; the count is the real number.
  ///
  /// In fr, this message translates to:
  /// **'Afficher les paiements archivés ({count})'**
  String subscriptionsShowArchived(int count);

  /// The same link once the archived series are showing.
  ///
  /// In fr, this message translates to:
  /// **'Masquer les paiements archivés ({count})'**
  String subscriptionsHideArchived(int count);

  /// Section label in the table above the archived series, once revealed.
  ///
  /// In fr, this message translates to:
  /// **'Archivés'**
  String get subscriptionsArchivedSection;

  /// Localized RECURRING_INVALID_TRANSITION.
  ///
  /// In fr, this message translates to:
  /// **'Ce changement de statut n’est pas possible pour ce paiement.'**
  String get subscriptionErrorInvalidTransition;

  /// Localized RECURRING_SERIES_EXISTS.
  ///
  /// In fr, this message translates to:
  /// **'Ce compte suit déjà un paiement récurrent sous ce nom.'**
  String get subscriptionErrorExists;

  /// Localized RECURRING_SERIES_NOT_FOUND.
  ///
  /// In fr, this message translates to:
  /// **'Ce paiement récurrent n’existe plus.'**
  String get subscriptionErrorNotFound;

  /// Localized ACCOUNT_NOT_FOUND, reachable from the creation form's account select.
  ///
  /// In fr, this message translates to:
  /// **'Ce compte n’existe plus.'**
  String get subscriptionErrorAccountNotFound;

  /// Localized CATEGORY_INVALID on the recurring payment form, returned when the chosen category is not one the user may assign.
  ///
  /// In fr, this message translates to:
  /// **'Cette catégorie n’est plus disponible.'**
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

  /// RECURRING_MERGE_INVALID: the two series are on different accounts, one was declared by hand, or they are the same series.
  ///
  /// In fr, this message translates to:
  /// **'Ces deux abonnements ne peuvent pas être fusionnés.'**
  String get subscriptionErrorMergeInvalid;

  /// Banner on the subscriptions panel proposing to merge two series. source is the older label that would fold into target, the label kept.
  ///
  /// In fr, this message translates to:
  /// **'« {source} » et « {target} » semblent être le même abonnement, renommé par la banque.'**
  String subscriptionsMergeSuggestion(String source, String target);

  /// Button on the merge banner: fold the two series into one.
  ///
  /// In fr, this message translates to:
  /// **'Fusionner'**
  String get subscriptionsMergeAction;

  /// Button on the merge banner: the two series are distinct; never propose the pair again.
  ///
  /// In fr, this message translates to:
  /// **'Ce sont deux abonnements'**
  String get subscriptionsMergeKeepApart;

  /// Toast after a merge.
  ///
  /// In fr, this message translates to:
  /// **'Abonnements fusionnés'**
  String get subscriptionsMergeDone;

  /// Toast detail after a merge: later charges under either label land in the kept series.
  ///
  /// In fr, this message translates to:
  /// **'Les prochains prélèvements des deux libellés iront dans « {target} ».'**
  String subscriptionsMergeDoneDetail(String target);

  /// Header above the list of merge suggestions, shown when there are several.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 suggestion de fusion} other{{count} suggestions de fusion}}'**
  String subscriptionsMergeSuggestionsCount(int count);

  /// Tooltip on the chevron that collapses the list of merge suggestions.
  ///
  /// In fr, this message translates to:
  /// **'Masquer les suggestions'**
  String get subscriptionsMergeSuggestionsHide;

  /// Tooltip on the chevron that expands the collapsed list of merge suggestions.
  ///
  /// In fr, this message translates to:
  /// **'Afficher les suggestions'**
  String get subscriptionsMergeSuggestionsShow;

  /// Error state replacing the panel when the list or summary failed to load.
  ///
  /// In fr, this message translates to:
  /// **'Les abonnements n’ont pas pu être chargés. Rien n’a été modifié.'**
  String get subscriptionsLoadFailed;

  /// Retry action on the recurring payments error state.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get subscriptionsRetry;

  /// Empty-state title on the recurring payments panel.
  ///
  /// In fr, this message translates to:
  /// **'Aucun paiement récurrent détecté'**
  String get subscriptionsEmptyTitle;

  /// Empty-state body, stating the three-repeat rule so the absence reads as a threshold rather than a failure.
  ///
  /// In fr, this message translates to:
  /// **'Bastide repère un paiement récurrent lorsqu’un prélèvement s’est répété trois fois. Importer davantage d’historique accélère la détection.'**
  String get subscriptionsEmptyBody;

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
  /// **'Hausse : {from} → {to} le {date}, soit {annual} par an.'**
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
  /// **'{account}'**
  String subscriptionDetailHistorySubtitle(String account);

  /// Amber pill marking the occurrence where the price stepped up.
  ///
  /// In fr, this message translates to:
  /// **'{from} → {to}'**
  String subscriptionDetailChange(String from, String to);

  /// Foot note under the history: the user is being asked to trust a deduction, so the evidence is part of the screen.
  ///
  /// In fr, this message translates to:
  /// **'La série est déduite de ces prélèvements. Vérifiez-les avant de confirmer un changement.'**
  String get subscriptionDetailFootnote;

  /// Error state replacing the detail when it failed to load.
  ///
  /// In fr, this message translates to:
  /// **'Ce paiement récurrent n’a pas pu être chargé. Rien n’a été modifié.'**
  String get subscriptionDetailLoadFailed;

  /// Accessible name of the series detail's ellipsis button in the title bar.
  ///
  /// In fr, this message translates to:
  /// **'Plus d’actions'**
  String get subscriptionDetailMoreActions;

  /// Title of the modal when editing an existing series.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le paiement récurrent'**
  String get subscriptionFormEditTitle;

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

  /// Primary top-bar action opening the goal form.
  ///
  /// In fr, this message translates to:
  /// **'Nouvel objectif'**
  String get goalsAdd;

  /// Label of the summary line's lead figure: the total reserved across the active goals.
  ///
  /// In fr, this message translates to:
  /// **'Réservé sur {count, plural, =1{1 objectif} other{{count} objectifs}}'**
  String goalsSummaryReserved(int count);

  /// Label of the summary line's second figure: the total of the savings accounts.
  ///
  /// In fr, this message translates to:
  /// **'Épargne disponible'**
  String get goalsSummarySavings;

  /// Empty-value placeholder of « Épargne disponible » when the user has no savings account.
  ///
  /// In fr, this message translates to:
  /// **'—'**
  String get goalsNoValue;

  /// Goals table header: the goal's name.
  ///
  /// In fr, this message translates to:
  /// **'Objectif'**
  String get goalsColumnGoal;

  /// Goals table header: the deadline.
  ///
  /// In fr, this message translates to:
  /// **'Échéance'**
  String get goalsColumnDeadline;

  /// Goals table header: the repère.
  ///
  /// In fr, this message translates to:
  /// **'Avancement'**
  String get goalsColumnProgress;

  /// Goals table header: saved / target.
  ///
  /// In fr, this message translates to:
  /// **'Réservé'**
  String get goalsColumnReserved;

  /// After the saved amount in the table, in textTertiary.
  ///
  /// In fr, this message translates to:
  /// **'/ {target}'**
  String goalsTargetSuffix(String target);

  /// Deadline of a goal without one.
  ///
  /// In fr, this message translates to:
  /// **'Sans échéance'**
  String get goalNoDeadline;

  /// Deadline cell and banner line of a reached goal. month is « avril 2026 » / « April 2026 ».
  ///
  /// In fr, this message translates to:
  /// **'Atteint en {month}'**
  String goalReachedIn(String month);

  /// Link under the table that shows or hides the archived goals.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 objectif archivé} other{{count} objectifs archivés}}'**
  String goalsArchivedLink(int count);

  /// Note at the bottom of the list pane.
  ///
  /// In fr, this message translates to:
  /// **'Un objectif réserve une somme sur le papier. Vos comptes ne sont pas modifiés. Les images restent sur cet ordinateur.'**
  String get goalsNote;

  /// After the saved figure in the inspector.
  ///
  /// In fr, this message translates to:
  /// **'sur {target}'**
  String goalOfTarget(String target);

  /// Inspector line under the repère of a goal not yet reached.
  ///
  /// In fr, this message translates to:
  /// **'{deadline} · reste {remaining}'**
  String goalDeadlineRemaining(String deadline, String remaining);

  /// Inspector icon action archiving the goal; its tooltip and accessible name.
  ///
  /// In fr, this message translates to:
  /// **'Archiver'**
  String get goalArchive;

  /// Inspector icon action restoring an archived goal; its tooltip and accessible name.
  ///
  /// In fr, this message translates to:
  /// **'Désarchiver'**
  String get goalUnarchive;

  /// Inspector icon action opening the goal form; its tooltip and accessible name.
  ///
  /// In fr, this message translates to:
  /// **'Modifier'**
  String get goalEdit;

  /// Inspector icon action opening the delete goal confirmation; its tooltip and accessible name.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get goalDelete;

  /// Inspector section heading.
  ///
  /// In fr, this message translates to:
  /// **'Allocations'**
  String get goalAllocationsTitle;

  /// Inspector action opening the allocation modal.
  ///
  /// In fr, this message translates to:
  /// **'Allouer'**
  String get goalAllocate;

  /// Inspector table without rows.
  ///
  /// In fr, this message translates to:
  /// **'Aucune allocation.'**
  String get goalAllocationsEmpty;

  /// Inspector table when the allocations fail to load.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger les allocations. Rien n’a été modifié.'**
  String get goalAllocationsFailed;

  /// Trailing action of an allocation row in the inspector; opens the confirmation.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer l’allocation'**
  String get goalAllocationDelete;

  /// Title of the confirmation before deleting an allocation line, naming its date (goalAllocationDeleteDate).
  ///
  /// In fr, this message translates to:
  /// **'Supprimer l’allocation du {date} ?'**
  String goalAllocationDeleteTitle(String date);

  /// The allocation's date in the delete title, written out: « 1er mai 2026 », « 12 mai 2026 ». month is the locale's full month name.
  ///
  /// In fr, this message translates to:
  /// **'{day, plural, =1{1er} other{{day}}} {month} {year}'**
  String goalAllocationDeleteDate(int day, String month, String year);

  /// Lead of the confirmation when the deleted line put money aside.
  ///
  /// In fr, this message translates to:
  /// **'Le montant mis de côté pour « {goal} » baisse de {amount}. Vos comptes ne sont pas modifiés.'**
  String goalAllocationDeleteLeadDown(String goal, String amount);

  /// Lead of the confirmation when the deleted line was a withdrawal (negative).
  ///
  /// In fr, this message translates to:
  /// **'Le montant mis de côté pour « {goal} » remonte de {amount}. Vos comptes ne sont pas modifiés.'**
  String goalAllocationDeleteLeadUp(String goal, String amount);

  /// Destructive button of the delete confirmation.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get goalAllocationDeleteSubmit;

  /// Button on the banner image; opens a menu.
  ///
  /// In fr, this message translates to:
  /// **'Changer'**
  String get goalImageChange;

  /// Item of the « Changer » menu: picks a new banner image.
  ///
  /// In fr, this message translates to:
  /// **'Choisir une autre image'**
  String get goalImageReplace;

  /// Item of the « Changer » menu.
  ///
  /// In fr, this message translates to:
  /// **'Retirer l’image'**
  String get goalImageRemove;

  /// Button on a banner without an image.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une image'**
  String get goalImageAdd;

  /// Title of the banner crop modal.
  ///
  /// In fr, this message translates to:
  /// **'Recadrer l’image'**
  String get goalImageCropTitle;

  /// Lead of the banner crop modal.
  ///
  /// In fr, this message translates to:
  /// **'Faites glisser l’image pour cadrer la bannière.'**
  String get goalImageCropLead;

  /// Confirm action of the crop modal.
  ///
  /// In fr, this message translates to:
  /// **'Utiliser cette image'**
  String get goalImageCropSave;

  /// Refused banner image: over the size limit. Same wording as the avatar.
  ///
  /// In fr, this message translates to:
  /// **'Cette image est trop lourde : choisissez un fichier de moins de {megabytes} Mo.'**
  String goalImageTooLarge(int megabytes);

  /// Refused banner image: wrong type. Same wording as the avatar.
  ///
  /// In fr, this message translates to:
  /// **'Ce fichier n’est pas une image PNG, JPEG ou WebP.'**
  String get goalImageInvalid;

  /// Banner image upload or removal failed.
  ///
  /// In fr, this message translates to:
  /// **'L’image n’a pas pu être enregistrée. Réessayez.'**
  String get goalImageError;

  /// Screen-reader label of a goal's banner image.
  ///
  /// In fr, this message translates to:
  /// **'Image de l’objectif {name}'**
  String goalImageAlt(String name);

  /// Goal form field: the optional banner image.
  ///
  /// In fr, this message translates to:
  /// **'Image (facultative)'**
  String get goalFormImageLabel;

  /// Goal form button picking an image.
  ///
  /// In fr, this message translates to:
  /// **'Choisir une image'**
  String get goalFormImagePick;

  /// Goal form button dropping the chosen image.
  ///
  /// In fr, this message translates to:
  /// **'Retirer'**
  String get goalFormImageRemove;

  /// The over-allocation banner. Neutral, dismissible, never blocking.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez réservé {delta} de plus que le total de vos comptes d’épargne.'**
  String goalsOverAllocated(String delta);

  /// Tooltip on the over-allocation banner's dismiss control.
  ///
  /// In fr, this message translates to:
  /// **'Masquer cet avertissement'**
  String get goalsDismissBanner;

  /// Empty-state title of the goals panel.
  ///
  /// In fr, this message translates to:
  /// **'Aucun objectif'**
  String get goalsEmptyTitle;

  /// Empty-state body explaining what a virtual envelope is.
  ///
  /// In fr, this message translates to:
  /// **'Un objectif réserve une somme sur le papier. Vos comptes ne sont pas modifiés.'**
  String get goalsEmptyBody;

  /// Error state when the goals list fails to load.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger vos objectifs. Rien n’a été modifié.'**
  String get goalsLoadFailed;

  /// Retry action on the goals error states.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get goalsRetry;

  /// Title of the goal modal when creating.
  ///
  /// In fr, this message translates to:
  /// **'Nouvel objectif'**
  String get goalFormCreateTitle;

  /// Title of the goal modal when editing.
  ///
  /// In fr, this message translates to:
  /// **'Modifier l’objectif'**
  String get goalFormEditTitle;

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

  /// Goal form field: the optional deadline, a month.
  ///
  /// In fr, this message translates to:
  /// **'Échéance (facultative)'**
  String get goalFormDateLabel;

  /// Placeholder of the empty deadline field: the month spelling it reads.
  ///
  /// In fr, this message translates to:
  /// **'MM/AAAA'**
  String get goalFormDateHint;

  /// Tooltip of the calendar button beside the deadline field.
  ///
  /// In fr, this message translates to:
  /// **'Choisir un mois'**
  String get goalFormDatePick;

  /// Validation message when the deadline does not read as a month.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez un mois au format MM/AAAA.'**
  String get goalFormDateInvalid;

  /// Cancel action in the goal modal footer.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get goalFormCancel;

  /// Confirm action when editing a goal.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get goalFormSave;

  /// Title of the delete goal confirmation.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer l’objectif « {name} » ?'**
  String goalDeleteTitle(String name);

  /// Lead of the delete goal confirmation.
  ///
  /// In fr, this message translates to:
  /// **'Ses allocations et son image seront supprimées. Pour garder son historique, archivez-le plutôt. Vos comptes ne sont pas modifiés.'**
  String get goalDeleteLead;

  /// Delete goal confirmation button.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get goalDeleteSubmit;

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
  /// **'Un montant négatif retire de l’objectif.'**
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
  /// **'Note (facultative)'**
  String get allocationNoteLabel;

  /// Placeholder example in the allocation note field.
  ///
  /// In fr, this message translates to:
  /// **'Ex. Virement mensuel'**
  String get allocationNoteHint;

  /// Confirm action appending the allocation.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter'**
  String get allocationSubmit;

  /// Message for the backend's GOAL_NOT_FOUND code.
  ///
  /// In fr, this message translates to:
  /// **'Cet objectif n’existe plus.'**
  String get goalErrorNotFound;

  /// Message for the backend's GOAL_ALLOCATION_NOT_FOUND code.
  ///
  /// In fr, this message translates to:
  /// **'Cette allocation n’existe plus.'**
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

  /// Link on the right of the « Objectifs » heading, opening the goals panel.
  ///
  /// In fr, this message translates to:
  /// **'Tous les objectifs'**
  String get dashboardGoalsViewAll;

  /// The target half of a dashboard goal row's « saved / target », set after the saved amount in a lighter tone.
  ///
  /// In fr, this message translates to:
  /// **'/ {target}'**
  String dashboardGoalsTarget(String target);

  /// Tooltip on the calendar button of the allocation modal's date field.
  ///
  /// In fr, this message translates to:
  /// **'Choisir une date'**
  String get allocationDatePick;

  /// Title of the danger zone card in Settings › Données.
  ///
  /// In fr, this message translates to:
  /// **'Réinitialisation'**
  String get settingsResetTitle;

  /// What a database reset deletes, and what it leaves alone.
  ///
  /// In fr, this message translates to:
  /// **'Supprime opérations, comptes, règles, catégories personnalisées, objectifs, abonnements, crédits, biens, placements et simulations de ce profil. Les sauvegardes exportées ne sont pas touchées.'**
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
  /// **'Les catégories fournies, vos préférences et le réglage IA sont conservés.'**
  String get settingsResetConfirmNote;

  /// The word to type to enable the reset. Matched in any case.
  ///
  /// In fr, this message translates to:
  /// **'supprimer'**
  String get settingsResetConfirmWord;

  /// Label of the typed-confirmation field.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez « {word} » pour confirmer'**
  String settingsResetConfirmLabel(String word);

  /// Helper under the typed-confirmation field.
  ///
  /// In fr, this message translates to:
  /// **'Majuscules ou minuscules, peu importe.'**
  String get settingsResetConfirmHelper;

  /// Destructive confirm action of the reset modal.
  ///
  /// In fr, this message translates to:
  /// **'Tout supprimer'**
  String get settingsResetConfirmSubmit;

  /// Toast shown once the reset has completed.
  ///
  /// In fr, this message translates to:
  /// **'Base de données réinitialisée.'**
  String get settingsResetDone;

  /// Fallback message for any other reset failure.
  ///
  /// In fr, this message translates to:
  /// **'La réinitialisation a échoué. Vos données n’ont pas été modifiées.'**
  String get settingsResetErrorUnknown;

  /// Left nav section heading grouping the loans, simulator and net-worth destinations. Rendered uppercase.
  ///
  /// In fr, this message translates to:
  /// **'Patrimoine'**
  String get navSectionWealth;

  /// Left nav label for the loans screen.
  ///
  /// In fr, this message translates to:
  /// **'Crédits'**
  String get navMortgages;

  /// Sidebar label for the investments panel, in the Patrimoine group after Crédits.
  ///
  /// In fr, this message translates to:
  /// **'Placements'**
  String get navPlacements;

  /// Left nav label for the new-loan simulator screen.
  ///
  /// In fr, this message translates to:
  /// **'Simulateur'**
  String get navSimulator;

  /// Left nav label for the net-worth screen. The EN label is 'Net worth', not 'Overview': the Overview group already owns that word.
  ///
  /// In fr, this message translates to:
  /// **'Synthèse'**
  String get navNetworth;

  /// Title of the investments panel empty state.
  ///
  /// In fr, this message translates to:
  /// **'Aucun placement'**
  String get placementsEmptyTitle;

  /// Sentence of the investments panel empty state.
  ///
  /// In fr, this message translates to:
  /// **'Suivez un PEA, une assurance vie ou un autre placement à partir des valeurs de vos relevés.'**
  String get placementsEmptyMessage;

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
  /// **'Ajoutez un emprunt pour suivre son coût, son échéancier et votre taux d’endettement.'**
  String get mortgagesEmptyBody;

  /// Label of the lead figure of the loans summary line.
  ///
  /// In fr, this message translates to:
  /// **'Charge mensuelle'**
  String get mortgagesChargeLabel;

  /// Caption of the monthly charge: how many instalments fall on the next due date.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 échéance le {date}} other{{count} échéances le {date}}}, assurance comprise'**
  String mortgagesChargeCaption(int count, String date);

  /// Caption of the monthly charge when no instalment remains.
  ///
  /// In fr, this message translates to:
  /// **'Assurance comprise'**
  String get mortgagesChargeCaptionNoNext;

  /// Label of the outstanding principal, in the summary line, the loans table and the detail.
  ///
  /// In fr, this message translates to:
  /// **'Capital restant dû'**
  String get mortgagesOutstandingLabel;

  /// Caption of the outstanding principal: the amount borrowed and the share repaid.
  ///
  /// In fr, this message translates to:
  /// **'sur {principal} · {percent} remboursés'**
  String mortgagesOutstandingCaption(String principal, String percent);

  /// Label of the debt ratio item of the summary line.
  ///
  /// In fr, this message translates to:
  /// **'Taux d’endettement'**
  String get mortgagesRatioLabel;

  /// Label of the mark on the debt ratio repère.
  ///
  /// In fr, this message translates to:
  /// **'repère HCSF {percent}'**
  String mortgagesRatioReference(String percent);

  /// Amber status pill when the ratio is above the HCSF reference. Information, never a refusal.
  ///
  /// In fr, this message translates to:
  /// **'Au-dessus du repère'**
  String get mortgagesRatioOverLimit;

  /// Ratio caption when the income was declared by the user. The HCSF caveat follows it.
  ///
  /// In fr, this message translates to:
  /// **'{charge} sur un revenu déclaré de {income}.'**
  String mortgagesRatioCaptionDeclared(String charge, String income);

  /// Ratio caption when the income is the median of the ledger's last 12 complete months. Says median, never average.
  ///
  /// In fr, this message translates to:
  /// **'{charge} sur un revenu médian constaté de {income} (12 mois). Un revenu déclaré remplace cette lecture.'**
  String mortgagesRatioCaptionLedger(String charge, String income);

  /// Ratio caption when no income is known: no ratio is drawn.
  ///
  /// In fr, this message translates to:
  /// **'Aucun revenu connu. Sans revenu, il n’y a pas de taux à calculer.'**
  String get mortgagesRatioUnknown;

  /// Opens Settings, Preferences, where the declared income is edited.
  ///
  /// In fr, this message translates to:
  /// **'Déclarer un revenu'**
  String get mortgagesRatioDeclareLink;

  /// HCSF caveat, always shown as body content on the ratio card, never as a tooltip.
  ///
  /// In fr, this message translates to:
  /// **'Lecture indicative, qui n’engage aucun prêteur.'**
  String get mortgagesRatioCaveat;

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

  /// Heading of the trajectory chart.
  ///
  /// In fr, this message translates to:
  /// **'Capital restant dû jusqu’au dernier remboursement'**
  String get mortgagesChartTitle;

  /// Chart annotation on today's month: the month and the combined outstanding.
  ///
  /// In fr, this message translates to:
  /// **'{month} · {amount}'**
  String mortgagesChartToday(String month, String amount);

  /// Annotation of the month a loan ends on the trajectory chart. {kind} is the loan's type, lower-cased.
  ///
  /// In fr, this message translates to:
  /// **'fin du {kind}'**
  String mortgagesChartLoanEnd(String kind);

  /// Error state when a loan's detail cannot be loaded.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger ce crédit.'**
  String get mortgageDetailLoadFailed;

  /// Detail header stat label. Rendered uppercase.
  ///
  /// In fr, this message translates to:
  /// **'Échéance totale'**
  String get mortgageDetailInstalmentLabel;

  /// Caption of the total instalment: the instalment and the monthly insurance.
  ///
  /// In fr, this message translates to:
  /// **'{payment} + {insurance} d’assurance'**
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
  /// **'TAEG indicatif'**
  String get mortgageCostTaegLabel;

  /// Caption of the indicative APR.
  ///
  /// In fr, this message translates to:
  /// **'taux, assurance et frais'**
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

  /// Loan form field: the monthly insurance.
  ///
  /// In fr, this message translates to:
  /// **'Assurance par mois'**
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
  /// **'Bien financé (facultatif)'**
  String get mortgageFormProperty;

  /// Loan form: no property linked.
  ///
  /// In fr, this message translates to:
  /// **'Aucun'**
  String get mortgageFormPropertyNone;

  /// Loan form reading pane: caption under the dashed instalment before the inputs are complete.
  ///
  /// In fr, this message translates to:
  /// **'Renseignez le capital et le taux pour voir l’échéance.'**
  String get mortgageFormInstalmentEmpty;

  /// Loan form reading pane: caption under the instalment for an interest-only loan, which the simulator does not compute.
  ///
  /// In fr, this message translates to:
  /// **'La mensualité d’un prêt in fine s’affiche une fois le crédit enregistré.'**
  String get mortgageFormInterestOnly;

  /// Loan form reading pane: note in the yearly projection before the inputs are complete.
  ///
  /// In fr, this message translates to:
  /// **'Renseignez le capital et le taux : la répartition par année s’affiche ici.'**
  String get mortgageFormChartEmpty;

  /// Loan form reading pane: note in the yearly projection for an interest-only loan.
  ///
  /// In fr, this message translates to:
  /// **'La répartition par année d’un prêt in fine se lit dans son tableau d’amortissement, une fois le crédit enregistré.'**
  String get mortgageFormChartInterestOnly;

  /// Loan form: cancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get mortgageFormCancel;

  /// Loan form: save edits.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get mortgageFormSave;

  /// Ghost button of the loan form, edit only.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get mortgageFormDelete;

  /// Delete confirmation title, naming the loan.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le crédit « {label} » ?'**
  String mortgageDeleteTitle(String label);

  /// Delete confirmation lead: what changes and what does not.
  ///
  /// In fr, this message translates to:
  /// **'Il ne sera plus déduit de votre patrimoine dans la Synthèse, et son tableau d’amortissement disparaît. Vos comptes ne sont pas modifiés.'**
  String get mortgageDeleteBody;

  /// Delete confirmation: confirm.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get mortgageDeleteConfirm;

  /// Inline error for a loan whose instalment does not cover its first interest (422).
  ///
  /// In fr, this message translates to:
  /// **'Ce crédit ne se rembourse pas : l’échéance ne couvre pas les intérêts du premier mois. Modifiez le taux, le capital ou la durée.'**
  String get mortgageErrorNonAmortizing;

  /// Inline error when upfront fees reach the principal.
  ///
  /// In fr, this message translates to:
  /// **'Les frais de dossier doivent rester inférieurs au capital emprunté.'**
  String get mortgageErrorFeesExceed;

  /// Inline error when the linked property no longer exists.
  ///
  /// In fr, this message translates to:
  /// **'Ce bien n’existe plus.'**
  String get mortgageErrorPropertyInvalid;

  /// Error when the loan no longer exists.
  ///
  /// In fr, this message translates to:
  /// **'Ce crédit n’existe plus.'**
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

  /// Heading of the schedule block of the loan detail.
  ///
  /// In fr, this message translates to:
  /// **'Tableau d’amortissement'**
  String get mortgageScheduleTitle;

  /// Line under the schedule heading.
  ///
  /// In fr, this message translates to:
  /// **'Année {position} sur {total} · {count, plural, =1{1 échéance} other{{count} échéances}} · l’assurance est comptée à part'**
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
  /// **'Impossible de charger le tableau d’amortissement.'**
  String get mortgageScheduleLoadFailed;

  /// Loans table column header: the loan.
  ///
  /// In fr, this message translates to:
  /// **'Crédit'**
  String get mortgagesTableLoan;

  /// Loans table column header: the lender and the term.
  ///
  /// In fr, this message translates to:
  /// **'Prêteur'**
  String get mortgagesTableLender;

  /// Loans table column header: the nominal rate.
  ///
  /// In fr, this message translates to:
  /// **'Taux'**
  String get mortgagesTableRate;

  /// Loans table column header: the monthly insurance.
  ///
  /// In fr, this message translates to:
  /// **'Assurance'**
  String get mortgagesTableInsurance;

  /// Loans table column header: the share of the principal repaid.
  ///
  /// In fr, this message translates to:
  /// **'Remboursé'**
  String get mortgagesTableRepaid;

  /// Loans table column header: the month of the last instalment.
  ///
  /// In fr, this message translates to:
  /// **'Fin'**
  String get mortgagesTableEnd;

  /// Loans table column header: the instalment, insurance included.
  ///
  /// In fr, this message translates to:
  /// **'Échéance'**
  String get mortgagesTableInstalment;

  /// Loans table cell: the lender and the term in months.
  ///
  /// In fr, this message translates to:
  /// **'{lender} · {months} mois'**
  String mortgagesTableLenderTerm(String lender, int months);

  /// Loans table cell under the repère: the share repaid and the instalments left.
  ///
  /// In fr, this message translates to:
  /// **'{percent} · {count, plural, =0{aucune échéance restante} =1{1 échéance restante} other{{count} échéances restantes}}'**
  String mortgagesTableRepaidCaption(String percent, int count);

  /// First right-aligned line of the loan detail summary.
  ///
  /// In fr, this message translates to:
  /// **'{kind} · {lender} · {principal} sur {months} mois'**
  String mortgageDetailFacts(
    String kind,
    String lender,
    String principal,
    int months,
  );

  /// Second right-aligned line of the loan detail summary, without upfront fees.
  ///
  /// In fr, this message translates to:
  /// **'1re échéance le {date}'**
  String mortgageDetailFirstPayment(String date);

  /// Second right-aligned line of the loan detail summary, with upfront fees.
  ///
  /// In fr, this message translates to:
  /// **'1re échéance le {date} · frais de dossier {fees}'**
  String mortgageDetailFirstPaymentFees(String date, String fees);

  /// Accessible name of the select listing every year of the schedule.
  ///
  /// In fr, this message translates to:
  /// **'Année'**
  String get mortgageScheduleYearSelect;

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

  /// Placeholder for a figure that cannot be read yet or does not apply.
  ///
  /// In fr, this message translates to:
  /// **'—'**
  String get simulatorNoValue;

  /// Title of the simulator input card.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau crédit'**
  String get simulatorFormTitle;

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

  /// Helper under the borrowed amount while it is still computed from the price, the down payment and the fees. Editing the field takes it over.
  ///
  /// In fr, this message translates to:
  /// **'calculé : prix − apport + frais'**
  String get simulatorPrincipalDerivedHelper;

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
  /// **'Assurance par mois'**
  String get simulatorInsurance;

  /// Simulator term slider label, and the HCSF term column label.
  ///
  /// In fr, this message translates to:
  /// **'Durée'**
  String get simulatorTerm;

  /// Term slider value in both units.
  ///
  /// In fr, this message translates to:
  /// **'{years, plural, =1{1 an} other{{years} ans}} · {months} mois'**
  String simulatorTermValue(int months, num years);

  /// A duration in whole years.
  ///
  /// In fr, this message translates to:
  /// **'{years, plural, =1{1 an} other{{years} ans}}'**
  String simulatorYears(num years);

  /// A duration in months.
  ///
  /// In fr, this message translates to:
  /// **'{months} mois'**
  String simulatorMonths(int months);

  /// Switch adding the user's active loans to the HCSF reading.
  ///
  /// In fr, this message translates to:
  /// **'Inclure mes crédits actuels'**
  String get simulatorIncludeExisting;

  /// Sub-line of the existing-loans switch naming what it adds.
  ///
  /// In fr, this message translates to:
  /// **'Ajoute {amount} par mois à la lecture'**
  String simulatorIncludeExistingAdds(String amount);

  /// Sub-line of the existing-loans switch when the user has no active loan.
  ///
  /// In fr, this message translates to:
  /// **'Aucun crédit en cours à ajouter'**
  String get simulatorIncludeExistingNone;

  /// Lead label of the summary line.
  ///
  /// In fr, this message translates to:
  /// **'Échéance mensuelle'**
  String get simulatorInstalmentLabel;

  /// Caption under the lead figure: the instalment is the payment plus the insurance, named separately.
  ///
  /// In fr, this message translates to:
  /// **'{payment} de mensualité + {insurance} d’assurance · {count, plural, =1{1 échéance} other{{count} échéances}}'**
  String simulatorInstalmentCaption(
    String payment,
    String insurance,
    int count,
  );

  /// Caption under the lead figure before anything can be computed.
  ///
  /// In fr, this message translates to:
  /// **'Renseignez un prix et un taux pour voir l’échéance.'**
  String get simulatorInstalmentEmpty;

  /// Summary line label of the total cost.
  ///
  /// In fr, this message translates to:
  /// **'Coût total'**
  String get simulatorCostLabel;

  /// Total cost caption naming its parts.
  ///
  /// In fr, this message translates to:
  /// **'intérêts {interest} · assurance {insurance} · frais {fees}'**
  String simulatorCostCaption(String interest, String insurance, String fees);

  /// Summary line label of the APR; « indicatif » is part of it.
  ///
  /// In fr, this message translates to:
  /// **'TAEG indicatif'**
  String get simulatorTaegLabel;

  /// TAEG caption.
  ///
  /// In fr, this message translates to:
  /// **'taux, assurance et frais'**
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
  /// **'Lecture indicative, qui n’engage aucun prêteur.'**
  String get simulatorHcsfCaveat;

  /// The HCSF reference beside a reading.
  ///
  /// In fr, this message translates to:
  /// **'repère {value}'**
  String simulatorReference(String value);

  /// HCSF card: debt ratio column label.
  ///
  /// In fr, this message translates to:
  /// **'Taux d’endettement'**
  String get simulatorRatioLabel;

  /// Debt ratio caption: the instalment against the income and where the income came from.
  ///
  /// In fr, this message translates to:
  /// **'{instalment} sur un revenu {source, select, declared{déclaré} other{médian constaté}} de {income}'**
  String simulatorRatioCaption(String instalment, String source, String income);

  /// Debt ratio caption with the current loans counted: the total charge, then its two parts.
  ///
  /// In fr, this message translates to:
  /// **'{total} ({instalment} + crédits actuels {existing}) sur un revenu {source, select, declared{déclaré} other{médian constaté}} de {income}'**
  String simulatorRatioCaptionWithExisting(
    String total,
    String instalment,
    String existing,
    String source,
    String income,
  );

  /// Debt ratio caption before anything can be computed.
  ///
  /// In fr, this message translates to:
  /// **'Renseignez un prix et un taux pour lire le taux d’endettement.'**
  String get simulatorRatioEmpty;

  /// HCSF card when no income is known: no ratio and no capacity.
  ///
  /// In fr, this message translates to:
  /// **'Aucun revenu connu. Sans revenu, ni taux ni capacité ne peuvent être lus.'**
  String get simulatorRatioUnknown;

  /// Outline button offering to declare an income when none is known.
  ///
  /// In fr, this message translates to:
  /// **'Déclarer un revenu'**
  String get simulatorDeclareIncome;

  /// HCSF term caption when the term equals the maximum.
  ///
  /// In fr, this message translates to:
  /// **'Au repère, pas au-delà'**
  String get simulatorTermAtReference;

  /// HCSF term caption when the term is shorter than the maximum.
  ///
  /// In fr, this message translates to:
  /// **'Sous le repère'**
  String get simulatorTermUnderReference;

  /// HCSF term caption when the term is longer than the maximum. Information only.
  ///
  /// In fr, this message translates to:
  /// **'Au-delà du repère'**
  String get simulatorTermOverReference;

  /// HCSF card: borrowing capacity column label.
  ///
  /// In fr, this message translates to:
  /// **'Capacité d’emprunt au repère'**
  String get simulatorCapacityLabel;

  /// Capacity caption: the instalment still available under the reference.
  ///
  /// In fr, this message translates to:
  /// **'{available} d’échéance disponibles sous {limit}, à ces conditions'**
  String simulatorCapacityCaption(String available, String limit);

  /// Capacity caption when the current loans are what shrink it: names the cause.
  ///
  /// In fr, this message translates to:
  /// **'Vos crédits actuels laissent {available} d’échéance sous {limit}. C’est ce qui limite la capacité, pas le bien visé.'**
  String simulatorCapacityCaptionExisting(String available, String limit);

  /// Capacity caption before anything can be computed.
  ///
  /// In fr, this message translates to:
  /// **'Renseignez un prix et un taux pour lire la capacité d’emprunt.'**
  String get simulatorCapacityEmpty;

  /// Title of the yearly projection chart.
  ///
  /// In fr, this message translates to:
  /// **'Projection annuelle'**
  String get simulatorChartTitle;

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

  /// Projection hover card: the principal repaid that year.
  ///
  /// In fr, this message translates to:
  /// **'Capital : {amount}'**
  String simulatorChartTooltipCapital(String amount);

  /// Projection hover card: the interest paid that year.
  ///
  /// In fr, this message translates to:
  /// **'Intérêts : {amount}'**
  String simulatorChartTooltipInterest(String amount);

  /// Projection chart invitation before anything can be computed.
  ///
  /// In fr, this message translates to:
  /// **'Renseignez un prix et un taux : la répartition par année s’affiche ici.'**
  String get simulatorChartEmpty;

  /// Banner when a live compute fails for a reason no field explains.
  ///
  /// In fr, this message translates to:
  /// **'Le calcul n’a pas abouti. Réessayez dans un instant.'**
  String get simulatorComputeFailed;

  /// Inline error under the rate when the engine refuses a loan that never amortises.
  ///
  /// In fr, this message translates to:
  /// **'À ce taux, l’échéance ne rembourse pas le capital : baissez le taux ou allongez la durée.'**
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

  /// Save-scenario modal name field label.
  ///
  /// In fr, this message translates to:
  /// **'Nom'**
  String get simulatorSaveName;

  /// Prefill of the scenario name on the « lieu, prix k€ » pattern, with an empty place slot before the comma for the user to type into.
  ///
  /// In fr, this message translates to:
  /// **', {price}'**
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
  /// **'{amount} k€'**
  String simulatorPriceThousands(String amount);

  /// Save refused because the per-user scenario cap is reached.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez atteint le nombre maximal de scénarios enregistrés. Supprimez-en un pour en ajouter un autre.'**
  String get simulatorErrorLimitReached;

  /// A scenario was deleted elsewhere.
  ///
  /// In fr, this message translates to:
  /// **'Ce scénario n’existe plus.'**
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

  /// Note under the list at the cap, naming the one row left out.
  ///
  /// In fr, this message translates to:
  /// **'Trois scénarios au plus. Décochez-en un pour ajouter {name}.'**
  String simulatorCompareCapNamed(String name);

  /// Note under the list at the cap when several rows are left out.
  ///
  /// In fr, this message translates to:
  /// **'Trois scénarios au plus. Décochez-en un pour en ajouter un autre.'**
  String get simulatorCompareCap;

  /// Name of the live row before a price gives it one.
  ///
  /// In fr, this message translates to:
  /// **'Simulation en cours'**
  String get simulatorLiveName;

  /// Marks the live, unsaved simulation in the scenario list and the comparison.
  ///
  /// In fr, this message translates to:
  /// **'en cours'**
  String get simulatorLiveMarker;

  /// Sub-line of a saved scenario row: its rate and term.
  ///
  /// In fr, this message translates to:
  /// **'{rate} · {term}'**
  String simulatorScenarioSub(String rate, String term);

  /// Sub-line of the live simulation row.
  ///
  /// In fr, this message translates to:
  /// **'en cours · {rate} · {term}'**
  String simulatorScenarioSubLive(String rate, String term);

  /// Tooltip of a scenario row's overflow menu.
  ///
  /// In fr, this message translates to:
  /// **'Actions du scénario'**
  String get simulatorScenarioActions;

  /// Scenario row menu item.
  ///
  /// In fr, this message translates to:
  /// **'Renommer'**
  String get simulatorScenarioRename;

  /// Title of the rename dialog.
  ///
  /// In fr, this message translates to:
  /// **'Renommer le scénario'**
  String get simulatorRenameTitle;

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

  /// Note in the scenarios block when nothing is saved.
  ///
  /// In fr, this message translates to:
  /// **'Aucun scénario enregistré.'**
  String get simulatorScenariosEmpty;

  /// Title of the comparison card.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{Comparaison d’un scénario} other{Comparaison de {count} scénarios}}'**
  String simulatorCompareTitle(int count);

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
  /// **'Taux d’endettement sur un revenu {source, select, declared{déclaré} other{médian constaté}} de {income} · repère HCSF {limit}. Lecture indicative, qui n’engage aucun prêteur.'**
  String simulatorCompareFoot(String source, String income, String limit);

  /// Comparison foot when no income is known.
  ///
  /// In fr, this message translates to:
  /// **'Aucun revenu connu, donc aucun taux d’endettement · repère HCSF {limit}. Lecture indicative, qui n’engage aucun prêteur.'**
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

  /// Property form field: the property's optional postal address, free text.
  ///
  /// In fr, this message translates to:
  /// **'Adresse (facultative)'**
  String get propertyFormAddress;

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
  /// **'Date d’estimation'**
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
  /// **'Indiquez une quote-part entre 0,01 et 100 %.'**
  String get propertyFormOwnershipInvalid;

  /// Property form field: the optional purchase price.
  ///
  /// In fr, this message translates to:
  /// **'Prix d’acquisition'**
  String get propertyFormAcquisitionPrice;

  /// Property form field: the optional purchase date.
  ///
  /// In fr, this message translates to:
  /// **'Date d’acquisition'**
  String get propertyFormAcquiredOn;

  /// Validation message when a required amount is missing or not positive.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez un montant supérieur à zéro.'**
  String get propertyFormAmountInvalid;

  /// Validation message when an optional amount cannot be read.
  ///
  /// In fr, this message translates to:
  /// **'Montant illisible. Laissez vide s’il est inconnu.'**
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

  /// Error when the valuation date is after today (PROPERTY_VALUATION_IN_FUTURE).
  ///
  /// In fr, this message translates to:
  /// **'Une date d’estimation ne peut pas être dans le futur.'**
  String get propertyErrorValuationInFuture;

  /// Error when the property was not found (PROPERTY_NOT_FOUND).
  ///
  /// In fr, this message translates to:
  /// **'Ce bien n’existe plus.'**
  String get propertyErrorNotFound;

  /// Error when the server rejected the payload (VALIDATION_ERROR).
  ///
  /// In fr, this message translates to:
  /// **'Certaines valeurs ont été refusées. Vérifiez le formulaire.'**
  String get propertyErrorValidation;

  /// Fallback error for a failed property write.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d’enregistrer le bien. Réessayez.'**
  String get propertyErrorGeneric;

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

  /// Tooltip of the dismiss control on a property action error.
  ///
  /// In fr, this message translates to:
  /// **'Fermer'**
  String get propertiesDismiss;

  /// Top-bar and empty-state action that opens the new-property form.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau bien'**
  String get networthAddProperty;

  /// Label of the net-worth figure on the equation line.
  ///
  /// In fr, this message translates to:
  /// **'Patrimoine net'**
  String get networthNetWorthLabel;

  /// Operator between assets and liabilities on the equation line (U+2212).
  ///
  /// In fr, this message translates to:
  /// **'−'**
  String get networthEquationMinus;

  /// Operator before the net worth on the equation line.
  ///
  /// In fr, this message translates to:
  /// **'='**
  String get networthEquationEquals;

  /// Part of the assets caption: the account balances.
  ///
  /// In fr, this message translates to:
  /// **'Comptes {amount}'**
  String networthAssetsPartAccounts(String amount);

  /// Part of the assets caption: the held property shares.
  ///
  /// In fr, this message translates to:
  /// **'Biens {amount}'**
  String networthAssetsPartProperties(String amount);

  /// Note under the composition table, one per partly owned property.
  ///
  /// In fr, this message translates to:
  /// **'Un bien compte pour la part détenue : {label}, {held} sur {full}.'**
  String networthCompositionPartNote(String label, String held, String full);

  /// Heading of the notes on what the net worth does not count.
  ///
  /// In fr, this message translates to:
  /// **'À savoir'**
  String get networthNotesTitle;

  /// Note in the properties block when no property is declared.
  ///
  /// In fr, this message translates to:
  /// **'Aucun bien déclaré : l’actif ne compte que vos comptes et vos placements.'**
  String get networthNoPropertyNote;

  /// Heading of the properties block of the net-worth panel.
  ///
  /// In fr, this message translates to:
  /// **'Biens'**
  String get propertiesTitle;

  /// Properties table column: the property.
  ///
  /// In fr, this message translates to:
  /// **'Bien'**
  String get propertiesColumnProperty;

  /// Properties table column: the property's nature.
  ///
  /// In fr, this message translates to:
  /// **'Nature'**
  String get propertiesColumnKind;

  /// Properties table column: the share owned.
  ///
  /// In fr, this message translates to:
  /// **'Quote-part'**
  String get propertiesColumnShare;

  /// Properties table column: the held share of the declared value.
  ///
  /// In fr, this message translates to:
  /// **'Valeur détenue'**
  String get propertiesColumnHeldValue;

  /// Link under the properties table that shows or hides the archived properties.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 bien archivé} other{{count} biens archivés}}'**
  String propertiesArchivedLink(int count);

  /// Status text under the net worth: this month's change and the month it is measured from.
  ///
  /// In fr, this message translates to:
  /// **'{delta} depuis {month}'**
  String networthDeltaCaption(String delta, String month);

  /// Label of the assets card.
  ///
  /// In fr, this message translates to:
  /// **'Actif'**
  String get networthAssetsLabel;

  /// Label of the liabilities card.
  ///
  /// In fr, this message translates to:
  /// **'Passif'**
  String get networthLiabilitiesLabel;

  /// Caption under the liabilities figure: how many active loans the outstanding principal comes from.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucun crédit} =1{1 crédit, capital restant dû} other{{count} crédits, capital restant dû}}'**
  String networthLiabilitiesCaption(int count);

  /// Title of the asset composition card.
  ///
  /// In fr, this message translates to:
  /// **'Composition de l’actif'**
  String get networthCompositionTitle;

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

  /// Composition row of a property nature that holds a partly owned property.
  ///
  /// In fr, this message translates to:
  /// **'{label}, part détenue'**
  String networthCompositionHeldShare(String label);

  /// Why goals are not counted in net worth.
  ///
  /// In fr, this message translates to:
  /// **'Les objectifs réservent de l’argent déjà présent sur un compte. Ils ne sont pas comptés une seconde fois.'**
  String get networthExclusionGoalsBody;

  /// Note under « À savoir »: why subscriptions are not counted.
  ///
  /// In fr, this message translates to:
  /// **'Un abonnement est une dépense à venir, pas une dette due aujourd’hui.'**
  String get networthExclusionSubscriptionsBody;

  /// Empty-state title when there are no accounts, properties or loans.
  ///
  /// In fr, this message translates to:
  /// **'Aucun compte, bien ou crédit'**
  String get networthEmptyTitle;

  /// Empty-state body of the net-worth panel.
  ///
  /// In fr, this message translates to:
  /// **'Importez un compte ou déclarez un bien. La synthèse additionne vos avoirs et soustrait vos crédits.'**
  String get networthEmptyBody;

  /// Secondary action of the net-worth empty state.
  ///
  /// In fr, this message translates to:
  /// **'Aller aux imports'**
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

  /// Title of the net-worth series card.
  ///
  /// In fr, this message translates to:
  /// **'Patrimoine net'**
  String get networthSeriesTitle;

  /// The months the net-worth chart shows, after its heading.
  ///
  /// In fr, this message translates to:
  /// **'{from} – {to}'**
  String networthSeriesRange(String from, String to);

  /// Shown in place of the chart when the series has no closed month yet.
  ///
  /// In fr, this message translates to:
  /// **'Aucun historique : la série commence au premier mois clos d’un compte importé, ou au premier montant que vous déclarez.'**
  String get networthSeriesEmpty;

  /// Info banner under the series when property values are held flat, naming the oldest current valuation date.
  ///
  /// In fr, this message translates to:
  /// **'Les biens sont maintenus à leur valeur déclarée (estimation la plus ancienne : {date}) et ne comptent qu’à partir de leur date d’acquisition, les crédits qu’à partir de leur déblocage. Les mois sans donnée sont absents.'**
  String networthSeriesCaveat(String date);

  /// Series range segment: the last 12 months.
  ///
  /// In fr, this message translates to:
  /// **'12 mois'**
  String get networthRangeYear;

  /// Series range segment: the last 3 years.
  ///
  /// In fr, this message translates to:
  /// **'3 ans'**
  String get networthRangeThreeYears;

  /// Series range segment: the whole history.
  ///
  /// In fr, this message translates to:
  /// **'Tout'**
  String get networthRangeAll;

  /// Chart legend for the solid line: months computed from imported statements.
  ///
  /// In fr, this message translates to:
  /// **'Comptes importés'**
  String get networthLegendLedger;

  /// Chart legend for the dashed line: months the user declared a total for.
  ///
  /// In fr, this message translates to:
  /// **'Montants déclarés'**
  String get networthLegendDeclared;

  /// Link on the series card opening the declared-history modal.
  ///
  /// In fr, this message translates to:
  /// **'Historique déclaré'**
  String get networthDeclaredOpen;

  /// Declared-history modal title.
  ///
  /// In fr, this message translates to:
  /// **'Historique déclaré'**
  String get networthDeclaredTitle;

  /// Declared-history modal subtitle: what a declared total is, and that imports win.
  ///
  /// In fr, this message translates to:
  /// **'Le total de tous vos comptes à la fin d’un mois, pour la période avant vos imports. Un mois couvert par vos imports garde le chiffre importé.'**
  String get networthDeclaredSubtitle;

  /// Label of the month field.
  ///
  /// In fr, this message translates to:
  /// **'Mois'**
  String get networthDeclaredMonth;

  /// Placeholder of the month field.
  ///
  /// In fr, this message translates to:
  /// **'MM/AAAA'**
  String get networthDeclaredMonthHint;

  /// Month field error: the input doesn't read as a month.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez un mois au format MM/AAAA.'**
  String get networthDeclaredMonthInvalid;

  /// Month field error: the current month or a later one (DECLARED_MONTH_NOT_CLOSED).
  ///
  /// In fr, this message translates to:
  /// **'Seul un mois terminé peut être déclaré.'**
  String get networthDeclaredMonthNotClosed;

  /// Label of the amount field: all accounts together at that month end.
  ///
  /// In fr, this message translates to:
  /// **'Total des comptes'**
  String get networthDeclaredAmount;

  /// Amount field error.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez un montant.'**
  String get networthDeclaredAmountInvalid;

  /// Saves the month's total (adds or replaces).
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get networthDeclaredSave;

  /// Shown in the modal when nothing is declared.
  ///
  /// In fr, this message translates to:
  /// **'Aucun montant déclaré.'**
  String get networthDeclaredEmpty;

  /// Chip on a declared month the imports cover: the chart shows the imported figure.
  ///
  /// In fr, this message translates to:
  /// **'Couvert par vos imports'**
  String get networthDeclaredSuperseded;

  /// Tooltip: load this month into the form.
  ///
  /// In fr, this message translates to:
  /// **'Modifier'**
  String get networthDeclaredEdit;

  /// Tooltip: delete this month's total.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get networthDeclaredDelete;

  /// Error state of the declared-history list.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger l’historique déclaré.'**
  String get networthDeclaredLoadFailed;

  /// DECLARED_BALANCE_NOT_FOUND.
  ///
  /// In fr, this message translates to:
  /// **'Ce montant n’existe plus.'**
  String get networthDeclaredErrorNotFound;

  /// Any other failure writing a declared total.
  ///
  /// In fr, this message translates to:
  /// **'L’enregistrement a échoué. Réessayez.'**
  String get networthDeclaredErrorGeneric;

  /// Link on the login screen, right of the link row, opening the password reset screen.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe oublié'**
  String get authForgotPasswordLink;

  /// Label for the recovery code field on the password reset form.
  ///
  /// In fr, this message translates to:
  /// **'Code de récupération'**
  String get authRecoveryCodeLabel;

  /// Validation message when the recovery code field is left empty.
  ///
  /// In fr, this message translates to:
  /// **'Le code de récupération est requis.'**
  String get authRecoveryCodeRequired;

  /// Label for the new password field on the password reset form.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau mot de passe'**
  String get authNewPasswordLabel;

  /// Submit button of the password reset form.
  ///
  /// In fr, this message translates to:
  /// **'Réinitialiser le mot de passe'**
  String get authResetSubmit;

  /// Label replacing the reset button text while the request is in flight.
  ///
  /// In fr, this message translates to:
  /// **'Réinitialisation…'**
  String get authResetSubmitting;

  /// Note under the password reset form explaining where the code comes from and why there is no other way.
  ///
  /// In fr, this message translates to:
  /// **'Le code vous a été remis à la création du compte. Sans lui, le mot de passe ne peut pas être réinitialisé : vos données ne quittent jamais cet ordinateur.'**
  String get authResetNote;

  /// Link under the password reset card, returning to the login screen.
  ///
  /// In fr, this message translates to:
  /// **'Retour à la connexion'**
  String get authBackToLogin;

  /// Banner when a password reset's email and recovery code don't match.
  ///
  /// In fr, this message translates to:
  /// **'Identifiant ou code de récupération incorrect. Vérifiez le code et réessayez.'**
  String get authErrorInvalidRecoveryCode;

  /// Button copying the recovery code to the clipboard.
  ///
  /// In fr, this message translates to:
  /// **'Copier'**
  String get authRecoveryCodeCopy;

  /// Label the copy button takes once the recovery code has been copied.
  ///
  /// In fr, this message translates to:
  /// **'Copié'**
  String get authRecoveryCodeCopied;

  /// Sentence under a newly issued recovery code on the signed-out column.
  ///
  /// In fr, this message translates to:
  /// **'Notez ce code et gardez-le en lieu sûr : il ne sera plus affiché.'**
  String get authRecoveryCodeKeep;

  /// Primary button releasing the user from the recovery code screen.
  ///
  /// In fr, this message translates to:
  /// **'J’ai noté ce code'**
  String get authRecoveryCodeAcknowledge;

  /// Title of the recovery code card in Settings › Profile.
  ///
  /// In fr, this message translates to:
  /// **'Code de récupération'**
  String get settingsRecoveryTitle;

  /// Subtitle of the recovery code card in Settings › Profile.
  ///
  /// In fr, this message translates to:
  /// **'Permet de réinitialiser votre mot de passe si vous l’oubliez. En générer un nouveau invalide l’ancien.'**
  String get settingsRecoverySubtitle;

  /// Button on the recovery code card opening the regeneration modal.
  ///
  /// In fr, this message translates to:
  /// **'Générer un nouveau code'**
  String get settingsRecoveryButton;

  /// Title of the modal generating a new recovery code.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau code de récupération'**
  String get settingsRecoveryModalTitle;

  /// Lead of the regeneration modal, before the password is entered.
  ///
  /// In fr, this message translates to:
  /// **'Confirmez votre mot de passe pour générer un nouveau code. L’ancien cessera de fonctionner.'**
  String get settingsRecoveryModalLead;

  /// Lead of the regeneration modal once the new code is shown.
  ///
  /// In fr, this message translates to:
  /// **'Notez ce code et gardez-le en lieu sûr : il ne sera plus affiché.'**
  String get settingsRecoveryModalGenerated;

  /// Confirm button of the regeneration modal.
  ///
  /// In fr, this message translates to:
  /// **'Générer'**
  String get settingsRecoveryModalGenerate;

  /// Secondary button of the regeneration modal writing the new code to a text file on this machine.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer dans un fichier'**
  String get settingsRecoveryModalSaveFile;

  /// Label the save-to-file button takes once the code has been written to a file.
  ///
  /// In fr, this message translates to:
  /// **'Enregistré'**
  String get settingsRecoveryModalSaved;

  /// Banner in the regeneration modal when the code could not be written to a file.
  ///
  /// In fr, this message translates to:
  /// **'Le fichier n’a pas pu être enregistré. Réessayez.'**
  String get settingsRecoveryModalSaveFailed;

  /// File name suggested when saving the new recovery code to a text file.
  ///
  /// In fr, this message translates to:
  /// **'code-de-recuperation-bastide.txt'**
  String get settingsRecoveryFileName;

  /// Button closing the regeneration modal once the new code has been shown.
  ///
  /// In fr, this message translates to:
  /// **'Terminé'**
  String get settingsRecoveryModalDone;

  /// Error in the regeneration modal when the confirmation password is wrong.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe incorrect.'**
  String get settingsRecoveryWrongPassword;

  /// Name of the password row in Settings › Profil › Sécurité.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe'**
  String get settingsPasswordTitle;

  /// Description of the password row in Settings › Profil › Sécurité. No date: nothing records when the password last changed.
  ///
  /// In fr, this message translates to:
  /// **'Au moins {minimum} caractères. Il protège l’accès à vos données sur cet ordinateur.'**
  String settingsPasswordSubtitle(int minimum);

  /// Button on the password row opening the password change modal.
  ///
  /// In fr, this message translates to:
  /// **'Changer le mot de passe'**
  String get settingsPasswordButton;

  /// Title of the password change modal.
  ///
  /// In fr, this message translates to:
  /// **'Changer le mot de passe'**
  String get settingsPasswordModalTitle;

  /// Lead of the password change modal.
  ///
  /// In fr, this message translates to:
  /// **'Votre code de récupération reste valable.'**
  String get settingsPasswordModalLead;

  /// Label of the current password field in the password change modal.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe actuel'**
  String get settingsPasswordCurrentLabel;

  /// Confirm button of the password change modal.
  ///
  /// In fr, this message translates to:
  /// **'Changer le mot de passe'**
  String get settingsPasswordModalSave;

  /// Error under the current password field when it is wrong.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe incorrect.'**
  String get settingsPasswordWrongPassword;

  /// Toast once the password has been changed.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe modifié.'**
  String get settingsPasswordChanged;

  /// Label for the field on the login and password-reset forms that accepts either the email or the username.
  ///
  /// In fr, this message translates to:
  /// **'E-mail ou nom d’utilisateur'**
  String get authIdentifierLabel;

  /// Validation error when the login/reset identifier field is empty.
  ///
  /// In fr, this message translates to:
  /// **'L’e-mail ou le nom d’utilisateur est requis.'**
  String get authIdentifierRequired;

  /// Helper under the username field: what it's for and its format.
  ///
  /// In fr, this message translates to:
  /// **'Sert aussi à vous connecter. 3 à 32 caractères : lettres, chiffres, espaces, « . », « _ » ou « - ».'**
  String get authDisplayNameHelper;

  /// Error when the typed username breaks the format.
  ///
  /// In fr, this message translates to:
  /// **'3 à 32 caractères : lettres sans accent, chiffres, espaces, « . », « _ » ou « - ».'**
  String get authDisplayNameInvalid;

  /// Error when the username (display name) is already used by another account.
  ///
  /// In fr, this message translates to:
  /// **'Ce nom d’utilisateur est déjà pris.'**
  String get authDisplayNameTaken;

  /// Title of the Settings › Profile card showing the username.
  ///
  /// In fr, this message translates to:
  /// **'Nom d’utilisateur'**
  String get settingsProfileNameTitle;

  /// Button opening the modal that changes the username.
  ///
  /// In fr, this message translates to:
  /// **'Modifier'**
  String get settingsProfileNameButton;

  /// Title of the Settings › Profile card that sets the user's avatar.
  ///
  /// In fr, this message translates to:
  /// **'Avatar'**
  String get settingsAvatarTitle;

  /// Subtitle of the avatar card.
  ///
  /// In fr, this message translates to:
  /// **'Un monogramme, une pastille de couleur ou une photo. La photo reste sur cet ordinateur.'**
  String get settingsAvatarSubtitle;

  /// Tooltip and accessible name of the initials monogram option.
  ///
  /// In fr, this message translates to:
  /// **'Monogramme'**
  String get settingsAvatarMonogram;

  /// Tooltip and accessible name of a preset avatar option: the user's initials on a plate of this category slot, named by the hue it shows.
  ///
  /// In fr, this message translates to:
  /// **'{slot, select, cat1{Pastille bleue} cat2{Pastille orange} cat3{Pastille verte} cat4{Pastille ambre} cat5{Pastille rose} cat6{Pastille violette} other{Pastille}}'**
  String settingsAvatarPreset(String slot);

  /// Banner in the avatar card when the choice could not be saved.
  ///
  /// In fr, this message translates to:
  /// **'L’avatar n’a pas pu être enregistré. Réessayez.'**
  String get settingsAvatarError;

  /// Button of the avatar card opening the file picker for a picture of the user's own.
  ///
  /// In fr, this message translates to:
  /// **'Choisir une photo'**
  String get settingsAvatarChoosePicture;

  /// Button of the avatar card dropping the uploaded picture and going back to the previous default avatar.
  ///
  /// In fr, this message translates to:
  /// **'Retirer la photo'**
  String get settingsAvatarRemovePicture;

  /// Error when the picked picture is over the size limit; {megabytes} is that limit.
  ///
  /// In fr, this message translates to:
  /// **'Cette image est trop lourde : choisissez un fichier de moins de {megabytes} Mo.'**
  String settingsAvatarPictureTooLarge(int megabytes);

  /// Error when the picked file is not a supported picture.
  ///
  /// In fr, this message translates to:
  /// **'Ce fichier n’est pas une image PNG, JPEG ou WebP.'**
  String get settingsAvatarPictureInvalid;

  /// Error when the picture could not be saved for another reason.
  ///
  /// In fr, this message translates to:
  /// **'La photo n’a pas pu être enregistrée. Réessayez.'**
  String get settingsAvatarPictureError;

  /// Title of the modal where the user crops the picked picture to a square.
  ///
  /// In fr, this message translates to:
  /// **'Recadrer la photo'**
  String get settingsAvatarCropTitle;

  /// Lead text of the crop modal.
  ///
  /// In fr, this message translates to:
  /// **'Faites glisser l’image pour cadrer votre avatar.'**
  String get settingsAvatarCropLead;

  /// Cancel button of the crop modal.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get settingsAvatarCropCancel;

  /// Confirm button of the crop modal, uploading the cropped picture.
  ///
  /// In fr, this message translates to:
  /// **'Utiliser cette photo'**
  String get settingsAvatarCropSave;

  /// Title of the modal that changes the username.
  ///
  /// In fr, this message translates to:
  /// **'Changer de nom d’utilisateur'**
  String get settingsProfileNameModalTitle;

  /// Lead sentence in the change-username modal.
  ///
  /// In fr, this message translates to:
  /// **'Le nouveau nom remplace l’ancien pour vous connecter.'**
  String get settingsProfileNameModalLead;

  /// Button saving the new username.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get settingsProfileNameModalSave;

  /// Secondary button on the email row of Settings › Profil, opening the change-email modal.
  ///
  /// In fr, this message translates to:
  /// **'Modifier'**
  String get settingsEmailButton;

  /// Title of the modal that changes the email address.
  ///
  /// In fr, this message translates to:
  /// **'Changer d’adresse e-mail'**
  String get settingsEmailModalTitle;

  /// Lead sentence in the change-email modal.
  ///
  /// In fr, this message translates to:
  /// **'La nouvelle adresse remplace l’ancienne pour vous connecter.'**
  String get settingsEmailModalLead;

  /// Label of the new email field in the change-email modal.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle adresse e-mail'**
  String get settingsEmailNewLabel;

  /// Button saving the new email address.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get settingsEmailModalSave;

  /// Error under the email field when another account already uses the address.
  ///
  /// In fr, this message translates to:
  /// **'Cette adresse e-mail est déjà utilisée.'**
  String get settingsEmailTaken;

  /// The privacy promise under the product name on the startup screen.
  ///
  /// In fr, this message translates to:
  /// **'Vos données restent sur cet ordinateur.'**
  String get startupPrivacy;

  /// Status line under the privacy promise while the app starts its local engine.
  ///
  /// In fr, this message translates to:
  /// **'Démarrage du moteur local…'**
  String get startupEngineStarting;

  /// Button on the startup error screen that starts the local engine again.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get startupRetry;

  /// Button on the developer version warning that restarts the local engine.
  ///
  /// In fr, this message translates to:
  /// **'Relancer'**
  String get startupRelaunch;

  /// Button on the startup error screen that opens the folder holding the app's log files.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir le dossier des journaux'**
  String get startupOpenLogs;

  /// Title when the local engine did not start.
  ///
  /// In fr, this message translates to:
  /// **'Bastide n’a pas pu démarrer'**
  String get startupDidNotStartTitle;

  /// Message when the local engine did not start or did not answer in time.
  ///
  /// In fr, this message translates to:
  /// **'Le moteur local de l’application ne s’est pas lancé. Réessayez ; si cela se reproduit, les journaux indiquent pourquoi.'**
  String get startupDidNotStartMessage;

  /// Message when the local engine is missing from the installed app.
  ///
  /// In fr, this message translates to:
  /// **'Des fichiers de l’application manquent. Réinstallez Bastide : vos données sont conservées à part et ne seront pas touchées.'**
  String get startupNotFoundMessage;

  /// Message when the app was told to use an engine started separately (development) and none answers.
  ///
  /// In fr, this message translates to:
  /// **'Aucun moteur local ne répond. Lancez-le, puis réessayez.'**
  String get startupUnreachableMessage;

  /// Title when the local engine stopped while the app was running.
  ///
  /// In fr, this message translates to:
  /// **'Bastide s’est arrêté de façon inattendue'**
  String get startupCrashedTitle;

  /// Message when the local engine stopped while the app was running.
  ///
  /// In fr, this message translates to:
  /// **'Le moteur local s’est interrompu. Vos données sont enregistrées au fil de l’eau ; réessayez pour le relancer.'**
  String get startupCrashedMessage;

  /// Title when the database was written by a newer version of the app (the user downgraded).
  ///
  /// In fr, this message translates to:
  /// **'Ces données viennent d’une version plus récente'**
  String get startupSchemaTooNewTitle;

  /// Message when the database was written by a newer version of the app.
  ///
  /// In fr, this message translates to:
  /// **'Vos données ont été enregistrées par une version plus récente de Bastide. Réinstallez cette version pour les ouvrir ; rien n’a été modifié.'**
  String get startupSchemaTooNewMessage;

  /// Title when the app and its local engine come from different versions.
  ///
  /// In fr, this message translates to:
  /// **'Versions incompatibles'**
  String get startupVersionMismatchTitle;

  /// Message when the app and its local engine come from different versions (release builds).
  ///
  /// In fr, this message translates to:
  /// **'L’application ({app}) et son moteur local ({backend}) ne viennent pas de la même version. Réinstallez Bastide pour les remettre d’accord ; vos données ne sont pas touchées.'**
  String startupVersionMismatchMessage(String app, String backend);

  /// Developer warning when a debug build reaches a local engine from another version.
  ///
  /// In fr, this message translates to:
  /// **'Le moteur local ({backend}) ne correspond pas à l’application ({app}) : il est sans doute resté d’une session précédente. Relancez-le, ou continuez quand même.'**
  String startupVersionMismatchDebugMessage(String app, String backend);

  /// Button on the developer version warning that opens the app anyway.
  ///
  /// In fr, this message translates to:
  /// **'Continuer quand même'**
  String get startupContinueAnyway;

  /// Settings › Données: banner offered when Ollama answers on its default address and the engine address points elsewhere; count is the number of installed models.
  ///
  /// In fr, this message translates to:
  /// **'Ollama détecté sur cet ordinateur · {count, plural, =0{aucun modèle installé} =1{1 modèle installé} other{{count} modèles installés}}'**
  String settingsAiOllamaFound(int count);

  /// Button pointing the engine address at the detected Ollama.
  ///
  /// In fr, this message translates to:
  /// **'Utiliser Ollama'**
  String get settingsAiOllamaUse;

  /// Tooltip of the account detail top bar's overflow button.
  ///
  /// In fr, this message translates to:
  /// **'Plus d’actions'**
  String get accountDetailMoreActions;

  /// Section label above a deferred card's headline: what its open cycle has charged so far.
  ///
  /// In fr, this message translates to:
  /// **'Encours du cycle'**
  String get accountDetailCycleLabel;

  /// Label of the account detail's lead figure: the balance today.
  ///
  /// In fr, this message translates to:
  /// **'Solde au {date}'**
  String accountDetailBalanceOn(String date);

  /// Summary line label: what came into the account this month.
  ///
  /// In fr, this message translates to:
  /// **'Entrées en {month}'**
  String accountDetailMonthInflow(String month);

  /// Summary line label: what left the account this month.
  ///
  /// In fr, this message translates to:
  /// **'Sorties en {month}'**
  String accountDetailMonthOutflow(String month);

  /// Summary line label: this month's money in plus money out.
  ///
  /// In fr, this message translates to:
  /// **'Net'**
  String get accountDetailNet;

  /// Summary line label of a deferred card: what its last settled cycle came to.
  ///
  /// In fr, this message translates to:
  /// **'Cycle précédent'**
  String get accountDetailPreviousCycle;

  /// Summary line label of a deferred card, above the date its open cycle will be debited.
  ///
  /// In fr, this message translates to:
  /// **'Prélevé le'**
  String get accountDetailDebitDateLabel;

  /// First line at the right of the summary line: the bank and the account type.
  ///
  /// In fr, this message translates to:
  /// **'{institution} · {type}'**
  String accountDetailIdentity(String institution, String type);

  /// Separator between the history fact and the last-import link on the summary line.
  ///
  /// In fr, this message translates to:
  /// **' · '**
  String get accountDetailMetaSeparator;

  /// Meta strip fact: booking date of the account's earliest transaction.
  ///
  /// In fr, this message translates to:
  /// **'Historique depuis le {date}'**
  String accountDetailHistorySince(String date);

  /// Meta strip fact on an account with no transaction yet.
  ///
  /// In fr, this message translates to:
  /// **'Aucune opération'**
  String get accountDetailNoHistory;

  /// Link to the imports panel at the end of the summary line: when a statement was last imported into this account.
  ///
  /// In fr, this message translates to:
  /// **'dernier import le {date}'**
  String accountDetailLastImport(String date);

  /// A card number masked to its last four digits.
  ///
  /// In fr, this message translates to:
  /// **'•••• {digits}'**
  String accountDetailMaskedNumber(String digits);

  /// Second line of a linked card's transaction listed with its settlement account (account detail, Transactions filtered by that account): which card it was made with.
  ///
  /// In fr, this message translates to:
  /// **'{card} · •••• {digits}'**
  String transactionRowCardLabel(String card, String digits);

  /// Title of the account detail's month-end balance chart.
  ///
  /// In fr, this message translates to:
  /// **'Solde en fin de mois'**
  String get accountDetailBalanceChartTitle;

  /// Title of a deferred card's chart: one bar per settlement cycle.
  ///
  /// In fr, this message translates to:
  /// **'Dépenses par cycle'**
  String get accountDetailCyclesChartTitle;

  /// Balance chart range segment.
  ///
  /// In fr, this message translates to:
  /// **'6 mois'**
  String get accountDetailRangeSixMonths;

  /// Balance chart range segment.
  ///
  /// In fr, this message translates to:
  /// **'12 mois'**
  String get accountDetailRangeTwelveMonths;

  /// Balance chart range segment: the whole history.
  ///
  /// In fr, this message translates to:
  /// **'Tout'**
  String get accountDetailRangeAll;

  /// Shown in place of the balance chart while the account has under two months of history.
  ///
  /// In fr, this message translates to:
  /// **'Le graphique apparaîtra après le deuxième mois d’historique.'**
  String get accountDetailChartEmpty;

  /// Ghost button opening the imports panel from the empty balance chart.
  ///
  /// In fr, this message translates to:
  /// **'Importer un relevé'**
  String get accountDetailImportCta;

  /// Balance chart tooltip line: the change from the previous month-end.
  ///
  /// In fr, this message translates to:
  /// **'{amount} vs mois précédent'**
  String accountDetailTooltipDelta(String amount);

  /// Balance chart tooltip line for the first month, which has no previous one.
  ///
  /// In fr, this message translates to:
  /// **'Premier mois suivi'**
  String get accountDetailTooltipFirstMonth;

  /// Cycle chart tooltip line: when that cycle was debited.
  ///
  /// In fr, this message translates to:
  /// **'Réglé le {date}'**
  String accountDetailCycleSettledOn(String date);

  /// Cycle chart tooltip line for the open cycle.
  ///
  /// In fr, this message translates to:
  /// **'En cours'**
  String get accountDetailCycleOpen;

  /// Sentence under the balance chart, shown only when the balance rose at least two month-ends running.
  ///
  /// In fr, this message translates to:
  /// **'Votre solde progresse depuis {count} mois.'**
  String accountDetailRisingStreak(int count);

  /// Summary line label of a deferred card: the mean of its last settled cycles.
  ///
  /// In fr, this message translates to:
  /// **'Moyenne sur {count} cycles'**
  String accountDetailCycleAverage(int count);

  /// Stats card value while there is nothing to measure yet.
  ///
  /// In fr, this message translates to:
  /// **'—'**
  String get accountDetailNoStats;

  /// Title of the section listing the deferred cards settled on this account.
  ///
  /// In fr, this message translates to:
  /// **'Cartes rattachées'**
  String get accountDetailLinkedTitle;

  /// Neutral text on a linked card's row: the card is debited once a cycle.
  ///
  /// In fr, this message translates to:
  /// **'Débit différé'**
  String get accountDetailDeferredDebit;

  /// Caption under a linked card's open-cycle total: its expected debit date.
  ///
  /// In fr, this message translates to:
  /// **'Prélevé le {date}'**
  String accountDetailDebitOn(String date);

  /// Caption under a linked card's total when no debit date can be projected yet.
  ///
  /// In fr, this message translates to:
  /// **'Prélèvement non planifié'**
  String get accountDetailNoDebitScheduled;

  /// Warning chip on a linked card without a settlement rule; opens the rule dialog.
  ///
  /// In fr, this message translates to:
  /// **'Règle de règlement à configurer'**
  String get accountDetailRuleMissing;

  /// Accessible label of the chevron opening another account's detail.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir {name}'**
  String accountDetailOpenAccount(String name);

  /// Title of a deferred card's section naming the account it is paid from.
  ///
  /// In fr, this message translates to:
  /// **'Compte de règlement'**
  String get accountDetailSettleTitle;

  /// Dashed row on a deferred card that names no paying account.
  ///
  /// In fr, this message translates to:
  /// **'Aucun compte de règlement'**
  String get accountDetailNoPayingAccount;

  /// A deferred card's settlement rule: the label fragment it matches and its start date.
  ///
  /// In fr, this message translates to:
  /// **'Libellé : {pattern} · appliquée depuis le {date}'**
  String accountDetailRuleSummary(String pattern, String date);

  /// A deferred card's settlement rule, when it has no start date.
  ///
  /// In fr, this message translates to:
  /// **'Libellé : {pattern}'**
  String accountDetailRuleSummaryUndated(String pattern);

  /// Ghost button opening a deferred card's settlement rule dialog.
  ///
  /// In fr, this message translates to:
  /// **'Modifier la règle'**
  String get accountDetailEditRule;

  /// Ghost button opening the settlement rule dialog for a card with none.
  ///
  /// In fr, this message translates to:
  /// **'Configurer la règle'**
  String get accountDetailSetUpRule;

  /// Ghost button in an account's linked-cards section opening the dialog that links an unlinked deferred card to it.
  ///
  /// In fr, this message translates to:
  /// **'Lier une carte'**
  String get accountDetailLinkCard;

  /// Title of the dialog linking a deferred card to an account.
  ///
  /// In fr, this message translates to:
  /// **'Lier une carte'**
  String get linkCardTitle;

  /// Explanation in the link-card dialog.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez la carte à débit différé dont le relevé mensuel est prélevé sur {account}.'**
  String linkCardBody(String account);

  /// Label of the card picker in the link-card dialog.
  ///
  /// In fr, this message translates to:
  /// **'Carte'**
  String get linkCardLabel;

  /// Placeholder of the card picker before a card is chosen.
  ///
  /// In fr, this message translates to:
  /// **'Choisir une carte'**
  String get linkCardPlaceholder;

  /// Button closing the link-card dialog without linking.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get linkCardCancel;

  /// Button linking the chosen card to the account.
  ///
  /// In fr, this message translates to:
  /// **'Lier'**
  String get linkCardConfirm;

  /// Shown in the link-card dialog when linking fails.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de lier la carte. Réessayez.'**
  String get linkCardFailed;

  /// Toast once a card is linked to the account.
  ///
  /// In fr, this message translates to:
  /// **'{card} est liée à ce compte'**
  String linkCardLinked(String card);

  /// Heading of the account detail's latest transactions.
  ///
  /// In fr, this message translates to:
  /// **'Opérations'**
  String get accountDetailRecentTitle;

  /// Column header of the account detail's transactions table.
  ///
  /// In fr, this message translates to:
  /// **'Opération'**
  String get accountDetailColumnOperation;

  /// Column header of the account detail's transactions table.
  ///
  /// In fr, this message translates to:
  /// **'Catégorie'**
  String get accountDetailColumnCategory;

  /// Column header of the account detail's transactions table.
  ///
  /// In fr, this message translates to:
  /// **'Date'**
  String get accountDetailColumnDate;

  /// Column header of the account detail's transactions table.
  ///
  /// In fr, this message translates to:
  /// **'Montant'**
  String get accountDetailColumnAmount;

  /// Link beside the transactions heading: opens the Transactions panel filtered on this account.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir dans Transactions'**
  String get accountDetailSeeAll;

  /// Dashed row in the recent transactions card of an account with none.
  ///
  /// In fr, this message translates to:
  /// **'Aucune opération'**
  String get accountDetailNoTransactions;

  /// Tooltip of the row action opening the « Marquer comme récurrent » dialog on an outflow.
  ///
  /// In fr, this message translates to:
  /// **'Marquer comme récurrent'**
  String get markRecurringAction;

  /// Tooltip of the same row action on an outflow that already belongs to a recurring series: it opens that series in Abonnements.
  ///
  /// In fr, this message translates to:
  /// **'Déjà récurrent : voir la série'**
  String get markRecurringOpenSeriesAction;

  /// Toast title when a row's series was deleted since the list loaded, instead of opening it.
  ///
  /// In fr, this message translates to:
  /// **'Ce paiement récurrent n’existe plus'**
  String get recurringSeriesGoneTitle;

  /// Toast body under recurringSeriesGoneTitle; the row reloads with the « Marquer comme récurrent » action.
  ///
  /// In fr, this message translates to:
  /// **'Il a été supprimé entre-temps : l’opération n’est plus marquée comme récurrente.'**
  String get recurringSeriesGoneMessage;

  /// Title of the dialog previewing the series a transaction would start.
  ///
  /// In fr, this message translates to:
  /// **'Marquer comme récurrent'**
  String get markRecurringTitle;

  /// Intro line of the mark-as-recurring dialog.
  ///
  /// In fr, this message translates to:
  /// **'Voici les opérations que Bastide regrouperait. Décochez celles qui n’en font pas partie.'**
  String get markRecurringIntro;

  /// Confidence chip: the matches pass the detector as they are.
  ///
  /// In fr, this message translates to:
  /// **'Confiance élevée'**
  String get markRecurringConfidenceHigh;

  /// Confidence chip: a cadence is recognised but the evidence is thin.
  ///
  /// In fr, this message translates to:
  /// **'Confiance moyenne'**
  String get markRecurringConfidenceMedium;

  /// Confidence chip: no rhythm was found.
  ///
  /// In fr, this message translates to:
  /// **'Confiance faible'**
  String get markRecurringConfidenceLow;

  /// Reason: how many matching transactions the preview found.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 opération trouvée} other{{count} opérations trouvées}}'**
  String markRecurringReasonOccurrences(int count);

  /// Reason: the gaps match a weekly cadence.
  ///
  /// In fr, this message translates to:
  /// **'Rythme hebdomadaire reconnu'**
  String get markRecurringReasonCadenceWeekly;

  /// Reason: the gaps match a monthly cadence.
  ///
  /// In fr, this message translates to:
  /// **'Rythme mensuel reconnu'**
  String get markRecurringReasonCadenceMonthly;

  /// Reason: the gaps match a quarterly cadence.
  ///
  /// In fr, this message translates to:
  /// **'Rythme trimestriel reconnu'**
  String get markRecurringReasonCadenceQuarterly;

  /// Reason: the gaps match a yearly cadence.
  ///
  /// In fr, this message translates to:
  /// **'Rythme annuel reconnu'**
  String get markRecurringReasonCadenceYearly;

  /// Reason: every amount sits within tolerance.
  ///
  /// In fr, this message translates to:
  /// **'Montant stable'**
  String get markRecurringReasonAmountStable;

  /// Reason: the newest charge is a price change.
  ///
  /// In fr, this message translates to:
  /// **'Le montant a changé récemment'**
  String get markRecurringReasonAmountChanged;

  /// Reason: one amount is outside tolerance.
  ///
  /// In fr, this message translates to:
  /// **'Un montant s’écarte des autres'**
  String get markRecurringReasonAmountOutsideTolerance;

  /// Reason: one gap between charges is outside tolerance.
  ///
  /// In fr, this message translates to:
  /// **'Un intervalle s’écarte du rythme'**
  String get markRecurringReasonGapOutsideTolerance;

  /// Reason: fewer charges than detection needs.
  ///
  /// In fr, this message translates to:
  /// **'Moins de trois prélèvements'**
  String get markRecurringReasonTooFewOccurrences;

  /// Reason: no cadence could be recognised.
  ///
  /// In fr, this message translates to:
  /// **'Aucun rythme régulier'**
  String get markRecurringReasonNoRhythm;

  /// Label of the proposed cadence in the dialog summary.
  ///
  /// In fr, this message translates to:
  /// **'Rythme proposé'**
  String get markRecurringCadenceLabel;

  /// Label of the proposed amount in the dialog summary.
  ///
  /// In fr, this message translates to:
  /// **'Montant attendu'**
  String get markRecurringAmountLabel;

  /// Summary line: how many transactions saving will link.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucune opération cochée} =1{1 opération cochée} other{{count} opérations cochées}}'**
  String markRecurringTickedCount(int count);

  /// Summary line under the charges: how many are ticked, and the dates of the oldest and newest of them.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 opération cochée} other{{count} opérations cochées}} · du {from} au {to}'**
  String markRecurringTickedRange(int count, String from, String to);

  /// Hint shown when every transaction is unticked.
  ///
  /// In fr, this message translates to:
  /// **'Cochez au moins une opération pour enregistrer la série.'**
  String get markRecurringNoneTicked;

  /// Primary button creating the series from the ticked transactions.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer la série'**
  String get markRecurringSave;

  /// Shown when the preview request failed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de préparer l’aperçu. Rien n’a été modifié.'**
  String get markRecurringLoadError;

  /// Error RECURRING_PREVIEW_INFLOW: a preview was asked for an inflow.
  ///
  /// In fr, this message translates to:
  /// **'Seule une dépense peut être marquée comme récurrente.'**
  String get subscriptionErrorPreviewInflow;

  /// Error RECURRING_TRANSACTIONS_INVALID.
  ///
  /// In fr, this message translates to:
  /// **'Certaines opérations ne peuvent pas être rattachées à cette série.'**
  String get subscriptionErrorTransactionsInvalid;

  /// Error RECURRING_TRANSACTION_LINKED.
  ///
  /// In fr, this message translates to:
  /// **'Certaines opérations appartiennent déjà à une série.'**
  String get subscriptionErrorTransactionLinked;

  /// Info banner when the transaction's merchant is already tracked by a series.
  ///
  /// In fr, this message translates to:
  /// **'Cette dépense correspond à « {label} », déjà suivi dans vos abonnements. Cochez les opérations à y ajouter.'**
  String markRecurringExistingIntro(String label);

  /// Link in the dialog body: closes it and opens the existing series in Abonnements.
  ///
  /// In fr, this message translates to:
  /// **'Voir la série « {label} »'**
  String markRecurringViewSeries(String label);

  /// Primary button adding the ticked transactions to the existing series.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter à cette série'**
  String get markRecurringAddToSeries;

  /// Opens the picker of the user's series, to add this transaction to one of them.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter à une série existante…'**
  String get markRecurringPickSeries;

  /// Intro of the series picker in the mark-as-recurring dialog.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez la série dont fait partie cette opération. Bastide retiendra son libellé pour les prochaines.'**
  String get seriesPickerIntro;

  /// Placeholder of the series picker's search field.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher une série'**
  String get seriesPickerSearchHint;

  /// Series picker: the user has no series to offer.
  ///
  /// In fr, this message translates to:
  /// **'Vous ne suivez aucune série.'**
  String get seriesPickerEmpty;

  /// Series picker: the search matched nothing.
  ///
  /// In fr, this message translates to:
  /// **'Aucune série ne correspond à « {query} ».'**
  String seriesPickerNoMatch(String query);

  /// Series picker: the list request failed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger vos séries.'**
  String get seriesPickerLoadError;

  /// Leaves the series picker for the preview.
  ///
  /// In fr, this message translates to:
  /// **'Retour à l’aperçu'**
  String get seriesPickerBack;

  /// Second line of a series in the picker: its account, cadence and expected amount.
  ///
  /// In fr, this message translates to:
  /// **'{account} · {cadence} · {amount}'**
  String seriesPickerRowDetail(String account, String cadence, String amount);

  /// Series picker button adding the transaction to the selected series.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer'**
  String get seriesPickerConfirm;

  /// Toast once the transaction was added to the series picked.
  ///
  /// In fr, this message translates to:
  /// **'Opération ajoutée à « {label} »'**
  String seriesPickerAdded(String label);

  /// Toast headline when adding the transaction to the series picked failed; the reason follows beneath.
  ///
  /// In fr, this message translates to:
  /// **'L’opération n’a pas pu être ajoutée'**
  String get seriesPickerAddFailed;

  /// Series detail button opening the picker of transactions to add to the series.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une opération'**
  String get chargePickerAction;

  /// Title of the dialog adding transactions to a series.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter à « {label} »'**
  String chargePickerTitle(String label);

  /// Intro of the dialog adding transactions to a series.
  ///
  /// In fr, this message translates to:
  /// **'Les opérations qui ne font partie d’aucune série, les plus proches en premier.'**
  String get chargePickerIntro;

  /// Placeholder of the transaction picker's search field.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un libellé'**
  String get chargePickerSearchHint;

  /// Transaction picker: no candidate at all.
  ///
  /// In fr, this message translates to:
  /// **'Aucune opération à ajouter : toutes vos dépenses font déjà partie d’une série.'**
  String get chargePickerEmpty;

  /// Transaction picker: the search matched nothing.
  ///
  /// In fr, this message translates to:
  /// **'Aucune opération ne correspond à « {query} ».'**
  String chargePickerNoMatch(String query);

  /// Transaction picker: the candidates request failed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger les opérations.'**
  String get chargePickerLoadError;

  /// Transaction picker: fetches the next page.
  ///
  /// In fr, this message translates to:
  /// **'Afficher plus'**
  String get chargePickerLoadMore;

  /// Transaction picker's primary button.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Ajouter} =1{Ajouter 1 opération} other{Ajouter {count} opérations}}'**
  String chargePickerSave(int count);

  /// Progress line in the pack import sheet while the pack's linked logos download.
  ///
  /// In fr, this message translates to:
  /// **'Téléchargement des logos… {done} / {total}'**
  String rulePackLogoProgress(int done, int total);

  /// Under the logo progress bar: the rules are already in, only the logos are left.
  ///
  /// In fr, this message translates to:
  /// **'Les règles sont importées : il ne reste que leurs logos.'**
  String get rulePackLogoProgressNotice;

  /// Shown in the pack import sheet when the background import failed.
  ///
  /// In fr, this message translates to:
  /// **'L’import n’a pas pu aller jusqu’au bout. Vérifiez vos règles avant de réessayer.'**
  String get rulePackImportRunFailed;

  /// Error when the bundled pack to import no longer exists (RULE_PACK_NOT_FOUND).
  ///
  /// In fr, this message translates to:
  /// **'Ce pack de règles est introuvable.'**
  String get ruleErrorPackNotFound;

  /// Error when another pack import of the user is still running (RULE_PACK_IMPORT_IN_PROGRESS).
  ///
  /// In fr, this message translates to:
  /// **'Un autre import de règles est déjà en cours. Attendez qu’il se termine.'**
  String get ruleErrorPackImportInProgress;

  /// Error when the background pack import can no longer be read (RULE_PACK_IMPORT_RUN_NOT_FOUND).
  ///
  /// In fr, this message translates to:
  /// **'Le suivi de cet import a été perdu. Vérifiez vos règles.'**
  String get ruleErrorPackImportRunNotFound;

  /// Title-bar primary button and empty-state button of the investments panel.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau placement'**
  String get placementsAdd;

  /// Label of the summary line's lead figure: the sum of the latest declared values.
  ///
  /// In fr, this message translates to:
  /// **'Valeur déclarée'**
  String get placementsSummaryValue;

  /// Caption under the declared value when no value has been entered yet.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 placement} other{{count} placements}}'**
  String placementsSummaryCount(int count);

  /// Caption under the declared value: open investments and the most recent value date.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 placement} other{{count} placements}} · dernière valeur saisie le {date}'**
  String placementsSummaryCaption(int count, String date);

  /// Label of the summary line's net payments figure.
  ///
  /// In fr, this message translates to:
  /// **'Versements nets'**
  String get placementsSummaryNetPayments;

  /// Caption under the net payments figure, explaining the calculation.
  ///
  /// In fr, this message translates to:
  /// **'versé − retiré'**
  String get placementsSummaryNetPaymentsCaption;

  /// Label of the summary line's unrealised gain figure.
  ///
  /// In fr, this message translates to:
  /// **'Plus-value latente'**
  String get placementsSummaryGain;

  /// Trend line under the unrealised gain: the gain as a share of net payments.
  ///
  /// In fr, this message translates to:
  /// **'{percent} des versements'**
  String placementsSummaryGainShare(String percent);

  /// Investments table column header.
  ///
  /// In fr, this message translates to:
  /// **'Placement'**
  String get placementsColumnPlacement;

  /// Investments table column header.
  ///
  /// In fr, this message translates to:
  /// **'Versements nets'**
  String get placementsColumnNetPayments;

  /// Investments table column header.
  ///
  /// In fr, this message translates to:
  /// **'Valeur déclarée'**
  String get placementsColumnValue;

  /// Investments table column header.
  ///
  /// In fr, this message translates to:
  /// **'Plus-value'**
  String get placementsColumnGain;

  /// Investments table column header: the date of the latest declared value.
  ///
  /// In fr, this message translates to:
  /// **'Valeur au'**
  String get placementsColumnValuedOn;

  /// Second line of an investment row.
  ///
  /// In fr, this message translates to:
  /// **'{envelope} · {institution} · ouvert en {month}'**
  String placementsRowSubtitle(
    String envelope,
    String institution,
    String month,
  );

  /// Banner for an investment whose latest declared value is stale.
  ///
  /// In fr, this message translates to:
  /// **'{name} : la valeur date de plus de quatre mois.'**
  String placementsStaleBanner(String name);

  /// Action of the stale-value banner.
  ///
  /// In fr, this message translates to:
  /// **'Mettre à jour la valeur'**
  String get placementsStaleAction;

  /// Under the stale-value banners when more than three investments are stale.
  ///
  /// In fr, this message translates to:
  /// **'et {count, plural, =1{1 autre} other{{count} autres}}'**
  String placementsStaleMore(int count);

  /// Note at the bottom of the investments list.
  ///
  /// In fr, this message translates to:
  /// **'Bastide ne se connecte à aucun courtier et ne télécharge aucun cours. La valeur est celle que vous recopiez depuis votre relevé. La plus-value est calculée, jamais enregistrée.'**
  String get placementsNote;

  /// Placeholder for a missing value or gain.
  ///
  /// In fr, this message translates to:
  /// **'—'**
  String get placementsNoValue;

  /// Tooltip of the close button of an investments banner.
  ///
  /// In fr, this message translates to:
  /// **'Fermer'**
  String get placementsDismissBanner;

  /// Error state of the investments panel.
  ///
  /// In fr, this message translates to:
  /// **'Les placements n’ont pas pu être chargés. Rien n’a été modifié.'**
  String get placementsLoadFailed;

  /// Retry button of the investments error state.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get placementsRetry;

  /// Inspector subtitle: the institution and the opening date.
  ///
  /// In fr, this message translates to:
  /// **'{institution} · ouvert le {date}'**
  String placementOpenedOn(String institution, String date);

  /// Inspector subtitle of a closed investment.
  ///
  /// In fr, this message translates to:
  /// **'{institution} · clôturé le {date}'**
  String placementClosedOn(String institution, String date);

  /// Tooltip of the inspector's overflow menu button.
  ///
  /// In fr, this message translates to:
  /// **'Actions du placement'**
  String get placementMenuTooltip;

  /// Overflow menu item.
  ///
  /// In fr, this message translates to:
  /// **'Modifier'**
  String get placementMenuEdit;

  /// Overflow menu item: close the investment.
  ///
  /// In fr, this message translates to:
  /// **'Clôturer'**
  String get placementMenuClose;

  /// Overflow menu item of a closed investment.
  ///
  /// In fr, this message translates to:
  /// **'Rouvrir'**
  String get placementMenuReopen;

  /// Overflow menu item: delete the investment.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get placementMenuDelete;

  /// Beside the inspector's value: the date it was declared.
  ///
  /// In fr, this message translates to:
  /// **'au {date}'**
  String placementValueAt(String date);

  /// Inspector primary button and title of the value modal.
  ///
  /// In fr, this message translates to:
  /// **'Saisir la valeur'**
  String get placementEnterValue;

  /// Inspector secondary button and title of the movement modal.
  ///
  /// In fr, this message translates to:
  /// **'Versement ou retrait'**
  String get placementAddMovement;

  /// Chart legend: the declared value series.
  ///
  /// In fr, this message translates to:
  /// **'Valeur déclarée'**
  String get placementLegendValue;

  /// Chart legend: the net payments series.
  ///
  /// In fr, this message translates to:
  /// **'Versements nets'**
  String get placementLegendNetPayments;

  /// Note under the chart of an investment without a declared value.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez une valeur pour voir la plus-value.'**
  String get placementNoValueNote;

  /// Chart hover card line: the declared value.
  ///
  /// In fr, this message translates to:
  /// **'Valeur {amount}'**
  String placementChartValue(String amount);

  /// Chart hover card line: the net payments.
  ///
  /// In fr, this message translates to:
  /// **'Versements nets {amount}'**
  String placementChartNetPayments(String amount);

  /// Semantic label of the investment chart.
  ///
  /// In fr, this message translates to:
  /// **'Valeur déclarée et versements nets de {name}'**
  String placementChartLabel(String name);

  /// Repère label: net payments against the envelope's ceiling.
  ///
  /// In fr, this message translates to:
  /// **'Plafond de versement'**
  String get placementCeilingLabel;

  /// After the net payments on the ceiling repère.
  ///
  /// In fr, this message translates to:
  /// **'sur {ceiling}'**
  String placementCeilingOf(String ceiling);

  /// Caption when the net payments reach the ceiling.
  ///
  /// In fr, this message translates to:
  /// **'Plafond de versement atteint.'**
  String get placementCeilingReached;

  /// Repère label: time since the opening.
  ///
  /// In fr, this message translates to:
  /// **'Ancienneté'**
  String get placementAgeLabel;

  /// Age of an investment, whole years.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 an} other{{count} ans}}'**
  String placementAgeYears(int count);

  /// Age of an investment, months.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 mois} other{{count} mois}}'**
  String placementAgeMonths(int count);

  /// Age of an investment: years then months.
  ///
  /// In fr, this message translates to:
  /// **'{years} {months}'**
  String placementAgeBoth(String years, String months);

  /// Label of the age repère's mark: the milestone and the month it falls in.
  ///
  /// In fr, this message translates to:
  /// **'repère {years} ans · {month}'**
  String placementMilestoneMark(int years, String month);

  /// Caption under the age repère of a PEA.
  ///
  /// In fr, this message translates to:
  /// **'Avant 5 ans, un retrait clôt en principe le plan. Lecture indicative, qui ne vaut pas conseil fiscal.'**
  String get placementMilestonePea;

  /// Caption under the age repère of a life insurance policy.
  ///
  /// In fr, this message translates to:
  /// **'Après 8 ans, la fiscalité des retraits s’allège. Lecture indicative, qui ne vaut pas conseil fiscal.'**
  String get placementMilestoneLifeInsurance;

  /// Inspector section heading: payments, withdrawals and declared values.
  ///
  /// In fr, this message translates to:
  /// **'Mouvements'**
  String get placementMovementsTitle;

  /// Right of the movements heading: movements linked to an imported transaction.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 rapproché avec vos transactions} other{{count} rapprochés avec vos transactions}}'**
  String placementMovementsLinked(int count);

  /// Movements section without any entry.
  ///
  /// In fr, this message translates to:
  /// **'Aucun mouvement.'**
  String get placementMovementsEmpty;

  /// Movements section when the history failed to load.
  ///
  /// In fr, this message translates to:
  /// **'L’historique n’a pas pu être chargé.'**
  String get placementMovementsFailed;

  /// Movements row: a payment in.
  ///
  /// In fr, this message translates to:
  /// **'Versement'**
  String get placementEntryPayment;

  /// Movements row: a withdrawal.
  ///
  /// In fr, this message translates to:
  /// **'Retrait'**
  String get placementEntryWithdrawal;

  /// Movements row: a declared value.
  ///
  /// In fr, this message translates to:
  /// **'Valeur saisie'**
  String get placementEntryValuation;

  /// Movements row label followed by its note.
  ///
  /// In fr, this message translates to:
  /// **'{label} · {note}'**
  String placementEntryWithNote(String label, String note);

  /// Envelope: plan d’épargne en actions.
  ///
  /// In fr, this message translates to:
  /// **'PEA'**
  String get placementEnvelopePea;

  /// Envelope: PEA for small and medium businesses.
  ///
  /// In fr, this message translates to:
  /// **'PEA-PME'**
  String get placementEnvelopePeaPme;

  /// Envelope: assurance vie.
  ///
  /// In fr, this message translates to:
  /// **'Assurance vie'**
  String get placementEnvelopeLifeInsurance;

  /// Envelope: plan d’épargne retraite.
  ///
  /// In fr, this message translates to:
  /// **'PER'**
  String get placementEnvelopePer;

  /// Envelope: plan d’épargne entreprise.
  ///
  /// In fr, this message translates to:
  /// **'PEE'**
  String get placementEnvelopePee;

  /// Envelope: compte-titres ordinaire.
  ///
  /// In fr, this message translates to:
  /// **'Compte-titres'**
  String get placementEnvelopeSecuritiesAccount;

  /// Envelope: anything else.
  ///
  /// In fr, this message translates to:
  /// **'Autre'**
  String get placementEnvelopeOther;

  /// Title of the new investment modal.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau placement'**
  String get placementFormCreateTitle;

  /// Title of the edit investment modal.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le placement'**
  String get placementFormEditTitle;

  /// Investment form field label.
  ///
  /// In fr, this message translates to:
  /// **'Nom'**
  String get placementFormName;

  /// Investment form error: empty name.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez un nom.'**
  String get placementFormNameRequired;

  /// Investment form field label.
  ///
  /// In fr, this message translates to:
  /// **'Enveloppe'**
  String get placementFormEnvelope;

  /// Investment form field label.
  ///
  /// In fr, this message translates to:
  /// **'Établissement'**
  String get placementFormInstitution;

  /// Investment form error: empty institution.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez l’établissement.'**
  String get placementFormInstitutionRequired;

  /// Investment form field label.
  ///
  /// In fr, this message translates to:
  /// **'Date d’ouverture'**
  String get placementFormOpenedOn;

  /// Investment form field label (optional).
  ///
  /// In fr, this message translates to:
  /// **'Valeur actuelle (facultative)'**
  String get placementFormCurrentValue;

  /// Investment form field label (optional).
  ///
  /// In fr, this message translates to:
  /// **'Versements déjà effectués (facultatif)'**
  String get placementFormInitialPayments;

  /// Helper of the initial payments field.
  ///
  /// In fr, this message translates to:
  /// **'Comptés comme un versement à l’ouverture.'**
  String get placementFormInitialPaymentsHelp;

  /// Form error: unreadable or future date.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez une date passée ou celle du jour.'**
  String get placementFormDateInvalid;

  /// Form error: amount not positive.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez un montant positif.'**
  String get placementFormAmountInvalid;

  /// Tooltip of a date field's calendar button.
  ///
  /// In fr, this message translates to:
  /// **'Choisir une date'**
  String get placementFormDatePick;

  /// Modal save button.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get placementFormSave;

  /// Ghost delete button on the footer of an edit modal.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get placementFormDelete;

  /// Title of the value modal when editing a declared value.
  ///
  /// In fr, this message translates to:
  /// **'Modifier la valeur'**
  String get placementValuationEditTitle;

  /// Value modal field label.
  ///
  /// In fr, this message translates to:
  /// **'Valeur'**
  String get placementValuationValue;

  /// Helper of the value field.
  ///
  /// In fr, this message translates to:
  /// **'Recopiez la valeur totale indiquée sur votre relevé.'**
  String get placementValuationHelp;

  /// Value modal error: empty or unreadable value.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez une valeur.'**
  String get placementValuationValueInvalid;

  /// Date field label of the value and movement modals.
  ///
  /// In fr, this message translates to:
  /// **'Date'**
  String get placementFieldDate;

  /// Note field label of the value and movement modals.
  ///
  /// In fr, this message translates to:
  /// **'Note (facultative)'**
  String get placementFieldNote;

  /// Placeholder of the note field of the value modal.
  ///
  /// In fr, this message translates to:
  /// **'Ex. Relevé trimestriel'**
  String get placementValuationNoteHint;

  /// Placeholder of the note field of the movement modal.
  ///
  /// In fr, this message translates to:
  /// **'Ex. Versement mensuel'**
  String get placementMovementNoteHint;

  /// Title of the movement modal when editing.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le mouvement'**
  String get placementMovementEditTitle;

  /// Movement modal field label.
  ///
  /// In fr, this message translates to:
  /// **'Montant'**
  String get placementMovementAmount;

  /// Helper of the movement amount field.
  ///
  /// In fr, this message translates to:
  /// **'Un montant négatif est un retrait.'**
  String get placementMovementAmountHelp;

  /// Movement modal error: zero or unreadable amount.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez un montant différent de zéro.'**
  String get placementMovementAmountInvalid;

  /// Movement modal field label (optional).
  ///
  /// In fr, this message translates to:
  /// **'Transaction liée (facultative)'**
  String get placementMovementLink;

  /// Helper under the linked transaction select.
  ///
  /// In fr, this message translates to:
  /// **'Les virements récents du même montant.'**
  String get placementMovementLinkHelp;

  /// Linked transaction select: no link.
  ///
  /// In fr, this message translates to:
  /// **'Aucune'**
  String get placementMovementLinkNone;

  /// Detail after a linked transaction's bank label: its date and amount.
  ///
  /// In fr, this message translates to:
  /// **'{date} · {amount}'**
  String placementMovementLinkDetail(String date, String amount);

  /// Title of the close modal.
  ///
  /// In fr, this message translates to:
  /// **'Clôturer ce placement ?'**
  String get placementCloseTitle;

  /// Lead of the close modal.
  ///
  /// In fr, this message translates to:
  /// **'Il quitte la synthèse à la date de clôture et reste dans la liste, grisé. Son historique est conservé.'**
  String get placementCloseLead;

  /// Close modal field label.
  ///
  /// In fr, this message translates to:
  /// **'Date de clôture'**
  String get placementCloseDate;

  /// Close modal field label.
  ///
  /// In fr, this message translates to:
  /// **'Montant final reçu'**
  String get placementCloseAmount;

  /// Close modal error: unreadable amount.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez un montant, zéro si rien n’a été reçu.'**
  String get placementCloseAmountInvalid;

  /// Close modal confirm button.
  ///
  /// In fr, this message translates to:
  /// **'Clôturer'**
  String get placementCloseSubmit;

  /// Title of the delete confirmation.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le placement « {name} » ?'**
  String placementDeleteTitle(String name);

  /// Lead of the delete confirmation.
  ///
  /// In fr, this message translates to:
  /// **'Ses valeurs saisies et ses versements seront supprimés. Vos comptes ne sont pas modifiés.'**
  String get placementDeleteLead;

  /// Delete confirmation button.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get placementDeleteSubmit;

  /// Error INVESTMENT_NOT_FOUND.
  ///
  /// In fr, this message translates to:
  /// **'Ce placement n’existe plus. Rien n’a été modifié.'**
  String get placementErrorNotFound;

  /// Error INVESTMENT_MOVEMENT_NOT_FOUND.
  ///
  /// In fr, this message translates to:
  /// **'Ce mouvement n’existe plus. Rien n’a été modifié.'**
  String get placementErrorMovementNotFound;

  /// Error INVESTMENT_VALUATION_NOT_FOUND.
  ///
  /// In fr, this message translates to:
  /// **'Cette valeur n’existe plus. Rien n’a été modifié.'**
  String get placementErrorValuationNotFound;

  /// Error INVESTMENT_DATE_IN_FUTURE.
  ///
  /// In fr, this message translates to:
  /// **'La date est dans le futur. Rien n’a été modifié.'**
  String get placementErrorDateInFuture;

  /// Error INVESTMENT_DATE_BEFORE_OPENING.
  ///
  /// In fr, this message translates to:
  /// **'La date précède l’ouverture du placement. Rien n’a été modifié.'**
  String get placementErrorDateBeforeOpening;

  /// Error INVESTMENT_DATE_AFTER_CLOSING.
  ///
  /// In fr, this message translates to:
  /// **'La date suit la clôture du placement. Rien n’a été modifié.'**
  String get placementErrorDateAfterClosing;

  /// Error INVESTMENT_ALREADY_CLOSED.
  ///
  /// In fr, this message translates to:
  /// **'Ce placement est déjà clôturé. Rien n’a été modifié.'**
  String get placementErrorAlreadyClosed;

  /// Error INVESTMENT_NOT_CLOSED.
  ///
  /// In fr, this message translates to:
  /// **'Ce placement n’est pas clôturé. Rien n’a été modifié.'**
  String get placementErrorNotClosed;

  /// Error INVESTMENT_VALUATION_EXISTS.
  ///
  /// In fr, this message translates to:
  /// **'Une valeur est déjà saisie à cette date. Modifiez-la depuis les mouvements.'**
  String get placementErrorValuationExists;

  /// Error INVESTMENT_LINKED_TRANSACTION_NOT_FOUND.
  ///
  /// In fr, this message translates to:
  /// **'Cette transaction n’existe plus. Rien n’a été modifié.'**
  String get placementErrorLinkNotFound;

  /// Error INVESTMENT_TRANSACTION_ALREADY_LINKED.
  ///
  /// In fr, this message translates to:
  /// **'Cette transaction est déjà liée à un autre mouvement. Rien n’a été modifié.'**
  String get placementErrorAlreadyLinked;

  /// Error VALIDATION_ERROR on an investment write.
  ///
  /// In fr, this message translates to:
  /// **'Un champ n’est pas valide. Rien n’a été modifié.'**
  String get placementErrorValidation;

  /// Fallback error of an investment write.
  ///
  /// In fr, this message translates to:
  /// **'L’opération a échoué. Rien n’a été modifié. Réessayez.'**
  String get placementErrorGeneric;

  /// Part of the assets caption: the investments at their declared value.
  ///
  /// In fr, this message translates to:
  /// **'Placements {amount}'**
  String networthAssetsPartInvestments(String amount);

  /// Composition row: every investment together.
  ///
  /// In fr, this message translates to:
  /// **'Placements'**
  String get networthCompositionInvestments;

  /// Net worth note on how investments are counted.
  ///
  /// In fr, this message translates to:
  /// **'Les placements comptent pour leur dernière valeur saisie. Entre deux saisies, la courbe reste plate.'**
  String get networthNoteInvestments;
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
