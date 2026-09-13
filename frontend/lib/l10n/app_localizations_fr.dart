// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'FinStride';

  @override
  String get navDashboard => 'Tableau de bord';

  @override
  String get navAccounts => 'Comptes';

  @override
  String get navTransactions => 'Transactions';

  @override
  String get navImports => 'Imports';

  @override
  String get navCategories => 'Catégories';

  @override
  String get navSettings => 'Paramètres';

  @override
  String get navSectionOverview => 'Vue d\'ensemble';

  @override
  String get navSectionManage => 'Gestion';

  @override
  String get navDashboardSubtitle => 'Votre mois en un coup d\'œil';

  @override
  String get navAccountsSubtitle => 'Tous vos comptes, une seule devise';

  @override
  String get navTransactionsSubtitle => 'Toutes vos opérations, en un seul fil';

  @override
  String get navImportsSubtitle =>
      'Relevés OFX et QFX — traités sur cet ordinateur';

  @override
  String get navCategoriesSubtitle =>
      'Organisez vos dépenses, automatisez avec des règles';

  @override
  String get navSettingsSubtitle =>
      'Profil, préférences et vos données locales';

  @override
  String get sidebarPrivacyBadge => 'Données 100 % locales';

  @override
  String get sidebarCollapse => 'Réduire le menu';

  @override
  String get sidebarExpand => 'Déployer le menu';

  @override
  String get userMenuLogout => 'Se déconnecter';

  @override
  String get comingSoonTitle => 'Bientôt disponible';

  @override
  String get settingsSectionProfile => 'Profil';

  @override
  String get settingsSectionPreferences => 'Préférences';

  @override
  String get settingsSectionData => 'Données';

  @override
  String get settingsSectionAbout => 'À propos';

  @override
  String get settingsLanguageTitle => 'Langue';

  @override
  String get settingsLanguageNote =>
      'S\'applique immédiatement à toute l\'interface.';

  @override
  String get settingsCurrencyTitle => 'Devise';

  @override
  String get settingsCurrencyNote =>
      'Choisie à l\'inscription et appliquée à tous vos comptes. Elle ne peut pas être modifiée dans cette version.';

  @override
  String get settingsFormatsTitle => 'Aperçu des formats';

  @override
  String get settingsFormatsDates => 'Dates';

  @override
  String get settingsFormatsAmounts => 'Montants';

  @override
  String get settingsAboutVersion => 'Version';

  @override
  String get settingsAboutPrivacy =>
      'Toutes vos données restent sur cet ordinateur. FinStride ne se connecte à aucune banque et n\'envoie rien sur Internet.';

  @override
  String get comingSoonBody =>
      'Cet écran arrive dans une prochaine étape. En attendant, ajoutez vos comptes pour préparer le terrain.';

  @override
  String get authTagline => 'Votre argent, en clair.';

  @override
  String get authPrivacyLine =>
      'Local et privé — vos données ne quittent jamais cet ordinateur.';

  @override
  String get authLoginSubmitting => 'Connexion…';

  @override
  String get authPasswordShow => 'Afficher le mot de passe';

  @override
  String get authPasswordHide => 'Masquer le mot de passe';

  @override
  String get authEmailLabel => 'Adresse e-mail';

  @override
  String get authPasswordLabel => 'Mot de passe';

  @override
  String get authDisplayNameLabel => 'Nom affiché';

  @override
  String get authPasswordStrengthWeak => 'Trop faible';

  @override
  String get authPasswordStrengthFair => 'Moyen';

  @override
  String get authPasswordStrengthStrong => 'Robuste';

  @override
  String get authPasswordStrengthHint =>
      'Ajoutez quelques caractères, un chiffre et une majuscule.';

  @override
  String get authPreferencesNote =>
      'Vous pourrez changer la langue plus tard ; la devise s\'applique à tous vos comptes et ne pourra plus être modifiée dans cette version.';

  @override
  String get authEmailTaken =>
      'Cet e-mail est déjà utilisé — connectez-vous plutôt.';

  @override
  String get authEmailInvalid => 'Saisissez une adresse e-mail valide.';

  @override
  String get authLocaleLabel => 'Langue';

  @override
  String get authLocaleFrench => 'Français';

  @override
  String get authLocaleEnglish => 'English';

  @override
  String get authCurrencyLabel => 'Devise';

  @override
  String get authLoginSubmit => 'Se connecter';

  @override
  String get authRegisterSubmit => 'Créer mon compte';

  @override
  String get authGoToRegister => 'Pas encore de compte ? Créer un compte';

  @override
  String get authGoToLogin => 'Déjà un compte ? Se connecter';

  @override
  String get authEmailRequired => 'L\'e-mail est requis.';

  @override
  String get authPasswordRequired => 'Le mot de passe est requis.';

  @override
  String get authDisplayNameRequired => 'Le nom est requis.';

  @override
  String get authErrorInvalidCredentials =>
      'E-mail ou mot de passe incorrect. Vérifiez vos identifiants et réessayez.';

  @override
  String get authErrorEmailTaken => 'Un compte existe déjà avec cet e-mail.';

  @override
  String get authErrorValidation => 'Certaines informations sont invalides.';

  @override
  String get authErrorGeneric => 'Une erreur est survenue. Veuillez réessayer.';

  @override
  String get accountsAddButton => 'Ajouter un compte';

  @override
  String accountsBalancesAsOf(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Soldes au $dateString';
  }

  @override
  String get accountsTotalBalanceLabel => 'Solde total';

  @override
  String accountsActiveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count comptes actifs',
      one: '1 compte actif',
      zero: 'Aucun compte actif',
    );
    return '$_temp0';
  }

  @override
  String get accountsEmptyTitle => 'Ajoutez votre premier compte';

  @override
  String get accountsEmptyBody =>
      'Suivez vos soldes et vos mouvements en un seul endroit.';

  @override
  String get accountsRetry => 'Réessayer';

  @override
  String get accountEdit => 'Modifier';

  @override
  String get accountArchive => 'Archiver';

  @override
  String get accountFormCancel => 'Annuler';

  @override
  String get accountArchiveConfirmTitle => 'Archiver ce compte ?';

  @override
  String get accountArchiveConfirmBody =>
      'Vous pourrez toujours consulter son historique, mais il n\'apparaîtra plus dans votre liste de comptes.';

  @override
  String get accountFormCreateTitle => 'Nouveau compte';

  @override
  String get accountFormPrefilledNote =>
      'Champs pré-remplis depuis votre relevé.';

  @override
  String get accountFormEditTitle => 'Modifier le compte';

  @override
  String get accountNameLabel => 'Nom';

  @override
  String get accountNameRequired => 'Le nom est requis.';

  @override
  String get accountTypeLabel => 'Type';

  @override
  String get accountTypeChecking => 'Courant';

  @override
  String get accountTypeSavings => 'Épargne';

  @override
  String get accountTypeCredit => 'Crédit';

  @override
  String get accountTypeDeferredCard => 'Carte à débit différé';

  @override
  String get accountTypeCash => 'Espèces';

  @override
  String get accountTypeOther => 'Autre';

  @override
  String get accountInstitutionLabel => 'Établissement';

  @override
  String get accountInstitutionRequired => 'L\'établissement est requis.';

  @override
  String get accountInstitutionFromStatementNote =>
      'Repris de l\'établissement déclaré par votre relevé.';

  @override
  String get accountOpeningBalanceLabel => 'Solde initial';

  @override
  String get accountCurrentBalanceLabel => 'Solde actuel';

  @override
  String accountBalanceAsOfLabel(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Solde au $dateString';
  }

  @override
  String get accountBalanceStatementNote =>
      'Ajusté automatiquement d\'après le solde déclaré par votre relevé lors du premier import.';

  @override
  String get accountBalanceFromStatementNote =>
      'Repris du solde déclaré par votre relevé.';

  @override
  String get accountOpeningBalanceEditNote =>
      'Corriger cette valeur décale le solde du compte et son historique enregistré du même montant — aucune transaction n\'est modifiée.';

  @override
  String get accountOpeningBalanceRequired => 'Le solde est requis.';

  @override
  String get accountOpeningBalanceInvalid => 'Entrez un montant valide.';

  @override
  String get accountFormSubmitCreate => 'Créer le compte';

  @override
  String get accountFormSubmitEdit => 'Enregistrer';

  @override
  String get accountErrorNotFound => 'Compte introuvable.';

  @override
  String get accountErrorOfxIdTaken =>
      'Un autre compte utilise déjà cet identifiant bancaire.';

  @override
  String get accountErrorValidation => 'Certaines informations sont invalides.';

  @override
  String get accountErrorGeneric =>
      'Une erreur est survenue. Veuillez réessayer.';

  @override
  String get importNewTitle => 'Nouvel import';

  @override
  String get importAccountLabel => 'Compte de destination';

  @override
  String get importAccountsUnavailable =>
      'Impossible de charger vos comptes. Réessayez dans un instant.';

  @override
  String get importDropZoneTitle => 'Déposez un fichier OFX ou QFX';

  @override
  String get importDropZoneHint =>
      'ou cliquez pour parcourir — le relevé indique lui-même son compte';

  @override
  String importFileSize(String size) {
    return '$size ko';
  }

  @override
  String get importRemoveFile => 'Retirer le fichier';

  @override
  String get importSubmit => 'Importer';

  @override
  String get importSubmitting => 'Import en cours…';

  @override
  String importDetectedAccount(String account) {
    return 'Compte reconnu dans le fichier : $account.';
  }

  @override
  String importDetectedAccountAmbiguous(String account) {
    return 'Ce relevé vient de $account, mais plusieurs comptes y correspondent — choisissez la destination.';
  }

  @override
  String importDetectedAccountUnknown(String account) {
    return 'Aucun compte ne correspond au compte $account de ce relevé.';
  }

  @override
  String get importCreateDetectedAccount => 'Créer ce compte';

  @override
  String get importChooseAccount => 'Choisissez un compte';

  @override
  String get importUnreadableAccount =>
      'Ce fichier n\'indique aucun compte — choisissez la destination.';

  @override
  String get importResultTitle => 'Dernier import';

  @override
  String importResultNewLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'nouvelles opérations',
      one: 'nouvelle opération',
      zero: 'aucune nouvelle opération',
    );
    return '$_temp0';
  }

  @override
  String importResultDuplicateLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'doublons ignorés',
      one: 'doublon ignoré',
      zero: 'aucun doublon',
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

    return 'Le relevé indique un solde à $amount de votre suivi au $dateString. Vérifiez un import manquant, ou corrigez le solde d\'ouverture du compte si l\'écart persiste.';
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
      'Le fichier n\'a pas pu être lu — rien n\'a été modifié.';

  @override
  String importDuplicatesNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count opérations déjà présentes, ignorées',
      one: '1 opération déjà présente, ignorée',
    );
    return '$_temp0';
  }

  @override
  String importBalanceMismatchNote(String amount, DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Écart de $amount avec le solde de la banque au $dateString.';
  }

  @override
  String get importStatusSuccess => 'Réussi';

  @override
  String get importStatusPartial => 'Partiel';

  @override
  String get importStatusFailed => 'Échec';

  @override
  String get importHistoryTitle => 'Historique des imports';

  @override
  String get importHistoryEmptyTitle => 'Aucun import pour l\'instant';

  @override
  String get importHistoryEmptyBody =>
      'Déposez un relevé ci-dessus : vos opérations apparaîtront ici.';

  @override
  String get importHistoryFileHeader => 'Fichier';

  @override
  String get importHistoryFormatHeader => 'Format';

  @override
  String get importHistoryImportedHeader => 'Importé le';

  @override
  String get importHistoryPeriodHeader => 'Période couverte';

  @override
  String get importHistoryNewHeader => 'Nouvelles';

  @override
  String get importHistoryDuplicatesHeader => 'Doublons';

  @override
  String get importHistoryStatusHeader => 'Statut';

  @override
  String get importRetry => 'Réessayer';

  @override
  String get importErrorAccountNotFound => 'Compte introuvable.';

  @override
  String get importErrorBatchNotFound => 'Import introuvable.';

  @override
  String get importErrorGeneric =>
      'Une erreur est survenue. Veuillez réessayer.';

  @override
  String get transactionsSearchHint =>
      'Rechercher une description ou un marchand…';

  @override
  String get transactionsSearchEmpty =>
      'Aucune transaction ne correspond à votre recherche.';

  @override
  String get transactionsRetry => 'Réessayer';

  @override
  String get transactionsEmptyTitle => 'Aucune transaction pour l\'instant';

  @override
  String get transactionsEmptyBody =>
      'Importez un relevé pour voir vos opérations apparaître ici.';

  @override
  String get transactionsGoToImports => 'Aller aux imports';

  @override
  String get transactionsNeedsReviewLabel => 'À vérifier';

  @override
  String get transactionsFilterAllAccounts => 'Tous les comptes';

  @override
  String get transactionsFilterAllCategories => 'Toutes les catégories';

  @override
  String get transactionsFilterAllDates => 'Toutes les dates';

  @override
  String get transactionsDateRangeTitle => 'Période';

  @override
  String get transactionsDateRangeFromLabel => 'Du';

  @override
  String get transactionsDateRangeToLabel => 'Au';

  @override
  String get transactionsDateRangeHelp =>
      'Laissez les deux dates vides pour voir toutes les dates.';

  @override
  String get transactionsDateRangePickFrom => 'Choisir la date de début';

  @override
  String get transactionsDateRangePickTo => 'Choisir la date de fin';

  @override
  String get transactionsDateRangeInvalid => 'Date invalide.';

  @override
  String get transactionsDateRangeIncomplete =>
      'Renseignez les deux dates, ou aucune.';

  @override
  String get transactionsDateRangeOrder =>
      'La date de fin précède la date de début.';

  @override
  String get transactionsDateRangeCancel => 'Annuler';

  @override
  String get transactionsDateRangeApply => 'Appliquer';

  @override
  String transactionsPager(int from, int to, int total) {
    return '$from–$to sur $total';
  }

  @override
  String transactionRowMemoAndAccount(String memo, String account) {
    return '$memo · $account';
  }

  @override
  String get reviewQueueEmpty => 'Aucune transaction à vérifier.';

  @override
  String reviewQueueCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions à vérifier',
      one: '1 transaction à vérifier',
      zero: 'Aucune transaction à vérifier',
    );
    return '$_temp0';
  }

  @override
  String get reviewQueueEncouragement => 'Vous y êtes presque, continuez !';

  @override
  String get reviewAlwaysCategorize => 'Toujours catégoriser ainsi';

  @override
  String get categoryPickerSearchHint => 'Changer de catégorie…';

  @override
  String get categoryPickerLoadError => 'Impossible de charger les catégories.';

  @override
  String get categoryPickerEmpty => 'Aucune catégorie ne correspond.';

  @override
  String get categoryUncategorized => 'Non catégorisé';

  @override
  String get transactionErrorNotFound => 'Transaction introuvable.';

  @override
  String get transactionErrorCategoryInvalid =>
      'Cette catégorie n\'est plus disponible.';

  @override
  String get transactionErrorValidation =>
      'Certaines informations sont invalides.';

  @override
  String get transactionErrorGeneric =>
      'Une erreur est survenue. Veuillez réessayer.';

  @override
  String get categorySystemHousing => 'Logement';

  @override
  String get categorySystemHousingRent => 'Loyer';

  @override
  String get categorySystemHousingMortgage => 'Prêt immobilier';

  @override
  String get categorySystemHousingUtilities => 'Charges';

  @override
  String get categorySystemHousingHomeInsurance => 'Assurance habitation';

  @override
  String get categorySystemFood => 'Alimentation';

  @override
  String get categorySystemFoodGroceries => 'Courses';

  @override
  String get categorySystemFoodRestaurants => 'Restaurants';

  @override
  String get categorySystemFoodCoffee => 'Café';

  @override
  String get categorySystemTransport => 'Transport';

  @override
  String get categorySystemTransportFuel => 'Carburant';

  @override
  String get categorySystemTransportPublicTransit => 'Transports en commun';

  @override
  String get categorySystemTransportParking => 'Stationnement';

  @override
  String get categorySystemTransportCarMaintenance => 'Entretien auto';

  @override
  String get categorySystemHealth => 'Santé';

  @override
  String get categorySystemHealthDoctor => 'Médecin';

  @override
  String get categorySystemHealthPharmacy => 'Pharmacie';

  @override
  String get categorySystemHealthInsurance => 'Mutuelle';

  @override
  String get categorySystemLeisure => 'Loisirs';

  @override
  String get categorySystemLeisureOutings => 'Sorties';

  @override
  String get categorySystemLeisureTravel => 'Voyages';

  @override
  String get categorySystemSubscriptions => 'Abonnements';

  @override
  String get categorySystemShopping => 'Achats';

  @override
  String get categorySystemShoppingClothing => 'Vêtements';

  @override
  String get categorySystemShoppingElectronics => 'Électronique';

  @override
  String get categorySystemShoppingHome => 'Maison';

  @override
  String get categorySystemFinance => 'Finances';

  @override
  String get categorySystemFinanceBankFees => 'Frais bancaires';

  @override
  String get categorySystemFinanceTaxes => 'Impôts';

  @override
  String get categorySystemFinanceSavings => 'Épargne';

  @override
  String get categorySystemFinanceInterest => 'Intérêts';

  @override
  String get categorySystemIncome => 'Revenus';

  @override
  String get categorySystemIncomeSalary => 'Salaire';

  @override
  String get categorySystemIncomePension => 'Retraite';

  @override
  String get categorySystemIncomeDividends => 'Dividendes';

  @override
  String get categorySystemIncomeRefunds => 'Remboursements';

  @override
  String get categorySystemIncomeOther => 'Autres revenus';

  @override
  String get categorySystemOther => 'Divers';

  @override
  String get categorySystemOtherUncategorized => 'Non catégorisé';

  @override
  String get dashboardStatIncome => 'Revenus (mois)';

  @override
  String get dashboardStatExpense => 'Dépenses (mois)';

  @override
  String get dashboardStatNet => 'Net';

  @override
  String get dashboardStatSavingsRate => 'Taux d\'épargne';

  @override
  String dashboardStatVsPreviousMonth(DateTime month) {
    final intl.DateFormat monthDateFormat = intl.DateFormat.MMMM(localeName);
    final String monthString = monthDateFormat.format(month);

    return 'vs $monthString';
  }

  @override
  String get dashboardStatNetCaption => 'revenus − dépenses';

  @override
  String dashboardSavingsDeltaPoints(String delta) {
    return '$delta pt';
  }

  @override
  String dashboardSavingsGoalReached(String goal) {
    return 'Objectif : $goal · atteint';
  }

  @override
  String dashboardSavingsGoalPending(String goal) {
    return 'Objectif : $goal · en cours';
  }

  @override
  String get dashboardCategoryBreakdownTitle => 'Dépenses par catégorie';

  @override
  String dashboardCategoryBreakdownSubtitle(String month, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count catégories',
      one: '1 catégorie',
    );
    return '$month · $_temp0';
  }

  @override
  String get dashboardDonutCenterCaption => 'dépensés';

  @override
  String get dashboardSavingsTrendTitle => 'Évolution de l\'épargne';

  @override
  String dashboardSavingsTrendSubtitle(int count) {
    return 'Épargne cumulée · $count mois';
  }

  @override
  String dashboardSavingsTrendDelta(String amount, String month) {
    return '$amount en $month';
  }

  @override
  String get dashboardIncomeVsExpenseTitle => 'Revenus vs dépenses';

  @override
  String dashboardIncomeVsExpenseSubtitle(int count) {
    return '$count derniers mois';
  }

  @override
  String get dashboardLegendIncome => 'Revenus';

  @override
  String get dashboardLegendExpense => 'Dépenses';

  @override
  String get dashboardRecentActivityTitle => 'Activité récente';

  @override
  String get dashboardViewAllTransactions => 'Voir toutes les transactions';

  @override
  String get dashboardRecentActivityEmpty =>
      'Vos transactions apparaîtront ici.';

  @override
  String get dashboardEmptyTitle =>
      'Importez un relevé pour donner vie à votre argent';

  @override
  String get dashboardEmptyBody =>
      'Tout reste sur cet ordinateur — rien n\'est envoyé en ligne.';

  @override
  String get dashboardGoToImports => 'Aller aux imports';

  @override
  String get dashboardRetry => 'Réessayer';

  @override
  String get dashboardErrorInvalidMonth => 'Le mois demandé n\'est pas valide.';

  @override
  String get dashboardErrorGeneric =>
      'Une erreur est survenue. Veuillez réessayer.';

  @override
  String get dashboardChooseMonth => 'Choisir un mois';

  @override
  String get dashboardPreviousYear => 'Année précédente';

  @override
  String get dashboardNextYear => 'Année suivante';

  @override
  String get categoriesAddButton => 'Nouvelle catégorie';

  @override
  String get categoriesEmptyTitle => 'Aucune catégorie pour l\'instant';

  @override
  String get categoriesEmptyBody =>
      'Les catégories classent vos dépenses. Créez-en une pour commencer.';

  @override
  String get categoriesRetry => 'Réessayer';

  @override
  String get categoryBadgeSystem => 'Système';

  @override
  String get categoryBadgeCustom => 'Personnalisée';

  @override
  String get categorySystemLockedTooltip =>
      'Catégorie du système : elle ne peut pas être modifiée ni supprimée.';

  @override
  String get categoryActionsTooltip => 'Actions';

  @override
  String get categoryEdit => 'Modifier';

  @override
  String get categoryDelete => 'Supprimer';

  @override
  String get categoryAddSubcategory => 'Sous-catégorie';

  @override
  String categoryRuleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count règles automatiques',
      one: '1 règle automatique',
      zero: 'Aucune règle',
    );
    return '$_temp0';
  }

  @override
  String get categoryDeleteConfirmTitle => 'Supprimer cette catégorie ?';

  @override
  String categoryDeleteConfirmBody(String name) {
    return '« $name » et ses sous-catégories seront supprimées. Les transactions concernées redeviendront non catégorisées.';
  }

  @override
  String get categoryFormCreateTitle => 'Nouvelle catégorie';

  @override
  String get categoryFormEditTitle => 'Modifier la catégorie';

  @override
  String get categoryFormNameLabel => 'Nom';

  @override
  String get categoryFormNameHint => 'Épargne projet';

  @override
  String get categoryFormNameRequired => 'Donnez un nom à cette catégorie.';

  @override
  String get categoryFormKindLabel => 'Type';

  @override
  String get categoryFormKindHelper =>
      'Une dépense sort de vos comptes, un revenu y entre, un transfert circule entre eux.';

  @override
  String get categoryFormParentLabel => 'Catégorie parente';

  @override
  String get categoryFormParentNone => 'Aucune (catégorie principale)';

  @override
  String get categoryFormIconLabel => 'Icône';

  @override
  String get categoryFormColorLabel => 'Couleur';

  @override
  String get categoryFormColorHelper =>
      'La couleur suit la catégorie partout : graphiques, légendes et étiquettes.';

  @override
  String get categoryFormCancel => 'Annuler';

  @override
  String get categoryFormSave => 'Enregistrer';

  @override
  String get categoryKindExpense => 'Dépense';

  @override
  String get categoryKindIncome => 'Revenu';

  @override
  String get categoryKindTransfer => 'Transfert';

  @override
  String get categoryIconHousing => 'Logement';

  @override
  String get categoryIconFood => 'Alimentation';

  @override
  String get categoryIconTransport => 'Transport';

  @override
  String get categoryIconLeisure => 'Loisirs';

  @override
  String get categoryIconSubscriptions => 'Abonnements';

  @override
  String get categoryIconHealth => 'Santé';

  @override
  String get categoryIconIncome => 'Revenus';

  @override
  String get categoryIconSavings => 'Épargne';

  @override
  String get categoryIconOther => 'Autre';

  @override
  String get categoryErrorNotEditable =>
      'Cette catégorie appartient au système : elle ne peut pas être modifiée ni supprimée.';

  @override
  String get categoryErrorValidation =>
      'Ces informations ne sont pas valides. Vérifiez le nom et le type.';

  @override
  String get categoryErrorGeneric =>
      'Une erreur est survenue. Veuillez réessayer.';

  @override
  String get categoriesTabCategories => 'Catégories';

  @override
  String get categoriesTabRules => 'Règles';

  @override
  String get rulesAddButton => 'Nouvelle règle';

  @override
  String get rulesPriorityNote =>
      'Évaluées dans l\'ordre de priorité — une règle ne remplace jamais une catégorie choisie manuellement.';

  @override
  String get rulesApplyButton => 'Exécuter les règles';

  @override
  String get rulesApplyRunning => 'Exécution…';

  @override
  String rulesApplyToastTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions recatégorisées',
      one: '$count transaction recatégorisée',
      zero: 'Aucune transaction recatégorisée',
    );
    return '$_temp0';
  }

  @override
  String get rulesApplyToastBody =>
      'Vos catégories choisies manuellement n\'ont pas été modifiées.';

  @override
  String get rulesApplyFailed => 'L\'exécution des règles a échoué';

  @override
  String get rulesReorderFailed => 'L\'ordre n\'a pas pu être enregistré';

  @override
  String get rulesToggleFailed => 'La règle n\'a pas pu être modifiée';

  @override
  String get rulesFilterClear => 'Afficher toutes les règles';

  @override
  String get rulesFilterEmpty => 'Aucune règle ne cible cette catégorie.';

  @override
  String get rulesRetry => 'Réessayer';

  @override
  String get rulesEmptyTitle => 'Automatisez votre classement';

  @override
  String get rulesEmptyBody =>
      'Une règle reconnaît un libellé — « CARREFOUR » — et attribue sa catégorie à chaque transaction correspondante, aujourd\'hui et aux prochains imports.';

  @override
  String get ruleToggleSemantics => 'Activer la règle';

  @override
  String get ruleTargetMissing => 'Catégorie introuvable';

  @override
  String get ruleFieldDescription => 'Libellé';

  @override
  String get ruleFieldMerchant => 'Commerçant';

  @override
  String get ruleFieldAmount => 'Montant';

  @override
  String get ruleConditionContains => 'contient';

  @override
  String get ruleConditionEquals => 'égal à';

  @override
  String get ruleConditionRegex => 'regex';

  @override
  String get ruleConditionRange => 'plage';

  @override
  String get ruleFormCreateTitle => 'Nouvelle règle';

  @override
  String get ruleFormEditTitle => 'Modifier la règle';

  @override
  String get ruleFormFieldLabel => 'Champ';

  @override
  String get ruleFormConditionLabel => 'Condition';

  @override
  String get ruleFormPriorityLabel => 'Priorité';

  @override
  String get ruleFormPriorityInvalid => 'Indiquez une priorité d\'au moins 1.';

  @override
  String get ruleFormPatternLabel => 'Motif';

  @override
  String get ruleFormPatternRequired =>
      'Indiquez ce que la règle doit reconnaître.';

  @override
  String get rulePatternHelperText =>
      'Recherche insensible à la casse dans le champ choisi.';

  @override
  String get rulePatternHelperRegex =>
      'Expression régulière, sensible à la casse. Testée en direct ci-dessous.';

  @override
  String get rulePatternHelperRange =>
      'Plage de montants en centimes, « min:max ». Laissez un côté vide pour une borne ouverte ; les dépenses sont négatives.';

  @override
  String get rulePatternHintText => 'CARREFOUR';

  @override
  String get rulePatternHintRegex => '^CB .*CARREFOUR';

  @override
  String get rulePatternHintRange => '-10000:-5000';

  @override
  String get ruleFormCategoryLabel => 'Catégorie attribuée';

  @override
  String get ruleFormCategoryNone => 'Choisir une catégorie';

  @override
  String get ruleFormCategoryRequired =>
      'Choisissez la catégorie que cette règle attribue.';

  @override
  String get ruleFormEnabledLabel => 'Règle active';

  @override
  String get ruleFormCancel => 'Annuler';

  @override
  String get ruleFormSave => 'Enregistrer';

  @override
  String get ruleFormDelete => 'Supprimer';

  @override
  String get rulePreviewLoading =>
      'Recherche des transactions correspondantes…';

  @override
  String rulePreviewCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Correspond à $count transactions existantes.',
      one: 'Correspond à $count transaction existante.',
      zero: 'Ne correspond à aucune transaction existante.',
    );
    return '$_temp0';
  }

  @override
  String rulePreviewCountWithSample(int count, String sample, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Correspond à $count transactions existantes — dont « $sample » du $date.',
      one: 'Correspond à $count transaction existante — « $sample » du $date.',
    );
    return '$_temp0';
  }

  @override
  String get ruleErrorPatternInvalid =>
      'Ce motif n\'est pas une expression régulière valide.';

  @override
  String get ruleErrorNotFound => 'Cette règle n\'existe plus.';

  @override
  String get ruleErrorCategoryNotFound => 'La catégorie visée n\'existe plus.';

  @override
  String get ruleErrorValidation =>
      'Ces informations ne sont pas valides. Vérifiez le motif et la priorité.';

  @override
  String get ruleErrorGeneric => 'Une erreur est survenue. Veuillez réessayer.';

  @override
  String get rulePackMenuTooltip => 'Importer / Exporter des règles';

  @override
  String get rulePackImportFile => 'Importer un fichier…';

  @override
  String rulePackImportBuiltin(String name) {
    return 'Importer « $name »';
  }

  @override
  String get rulePackExportAction => 'Exporter mes règles…';

  @override
  String get rulePackCancel => 'Annuler';

  @override
  String get rulePackClose => 'Fermer';

  @override
  String get rulePackRefusedTitle => 'Ce fichier n\'a pas été accepté';

  @override
  String get rulePackRefusedMalformed =>
      'Ce fichier n\'est pas un pack de règles FinStride. Attendu : un fichier JSON avec un nom, une version de format et une liste de règles.';

  @override
  String rulePackRefusedVersion(int version) {
    return 'Ce pack utilise une version de format que cette version de FinStride ne lit pas. Elle lit la version $version. Un pack partiellement compris perdrait silencieusement des règles, il est donc refusé en entier.';
  }

  @override
  String get rulePackRefusedRegex =>
      'Ce pack contient une règle « regex ». Les expressions régulières ne sont pas acceptées dans un pack partagé : une expression venue d\'un fichier tiers peut bloquer votre machine. Utilisez « contient », « égal à » ou « plage ».';

  @override
  String rulePackWouldMatch(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Ce pack catégoriserait $count de vos transactions non catégorisées.',
      one:
          'Ce pack catégoriserait $count de vos transactions non catégorisées.',
      zero:
          'Ce pack ne catégoriserait aucune de vos transactions non catégorisées.',
    );
    return '$_temp0';
  }

  @override
  String get rulePackRuleCount => 'Règles dans le pack';

  @override
  String get rulePackNewCount => 'Nouvelles règles';

  @override
  String get rulePackDuplicateCount => 'Doublons ignorés';

  @override
  String get rulePackUnresolvedCount => 'Catégories introuvables';

  @override
  String rulePackUnresolvedDetail(String keys) {
    return 'Ces règles seront ignorées : $keys';
  }

  @override
  String get rulePackSamplesLabel => 'Exemples de transactions concernées';

  @override
  String get rulePackApplyNowLabel =>
      'Appliquer les règles à mes transactions existantes après l\'import';

  @override
  String get rulePackImportConfirm => 'Importer';

  @override
  String rulePackImportedTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count règles importées',
      one: '$count règle importée',
      zero: 'Aucune règle importée',
    );
    return '$_temp0';
  }

  @override
  String rulePackImportedBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions recatégorisées.',
      one: '$count transaction recatégorisée.',
      zero: 'Aucune transaction n\'a changé de catégorie.',
    );
    return '$_temp0';
  }

  @override
  String get rulePackImportFailed => 'L\'import a échoué';

  @override
  String get rulePackExportTitle => 'Exporter mes règles';

  @override
  String get rulePackExportPrivacyNotice =>
      'Relisez avant d\'enregistrer : un motif peut contenir des informations personnelles — le nom de votre propriétaire, « VIR SALAIRE DUPONT ».';

  @override
  String rulePackExportContents(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Contenu du fichier — $count règles',
      one: 'Contenu du fichier — $count règle',
      zero: 'Contenu du fichier — aucune règle',
    );
    return '$_temp0';
  }

  @override
  String rulePackOmittedLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count règles non exportables',
      one: '$count règle non exportable',
    );
    return '$_temp0';
  }

  @override
  String rulePackOmittedRegex(String pattern) {
    return '« $pattern » — les règles regex ne peuvent pas figurer dans un pack.';
  }

  @override
  String rulePackOmittedUserCategory(String pattern) {
    return '« $pattern » — vise une catégorie personnalisée, qui n\'a pas d\'identifiant partageable.';
  }

  @override
  String get rulePackExportSave => 'Enregistrer';

  @override
  String get rulePackExportedTitle => 'Pack enregistré';

  @override
  String get rulePackExportFailed => 'L\'export a échoué';

  @override
  String rulePackStartWith(String name, int count) {
    return 'Commencer avec « $name » ($count règles)';
  }

  @override
  String get rulePackStartWithHelper =>
      'Vous verrez ce que le pack ferait avant de l\'importer.';

  @override
  String reviewQueueAiSubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'L\'IA locale propose une catégorie pour $count d\'entre elles — confirmez ou corrigez, rien n\'est classé sans vous.',
      one:
          'L\'IA locale propose une catégorie pour l\'une d\'entre elles — confirmez ou corrigez, rien n\'est classé sans vous.',
      zero:
          'Aucune de ces transactions n\'a reçu de proposition de l\'IA locale — confirmez ou corrigez, rien n\'est classé sans vous.',
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
      'Activez l\'IA locale pour classer automatiquement les transactions que vos règles n\'ont pas reconnues.';

  @override
  String get reviewAiInvitationLink => 'Paramètres';

  @override
  String reviewConfidence(double confidence) {
    final intl.NumberFormat confidenceNumberFormat =
        intl.NumberFormat.percentPattern(localeName);
    final String confidenceString = confidenceNumberFormat.format(confidence);

    return 'Confiance $confidenceString';
  }

  @override
  String get reviewConfirm => 'Confirmer';

  @override
  String get reviewCorrect => 'Corriger';

  @override
  String get reviewNoProposal => '— aucune proposition';

  @override
  String get reviewChooseCategory => 'Choisir une catégorie';

  @override
  String alwaysRuleSubtitle(String label) {
    return 'Une règle classe ces transactions sans IA, à chaque import — pré-remplie depuis « $label ».';
  }

  @override
  String get alwaysRuleCategoryLabel => 'Catégorie cible';

  @override
  String get alwaysRuleApplyExisting => 'Appliquer aux transactions existantes';

  @override
  String get alwaysRuleSubmit => 'Créer la règle';

  @override
  String get alwaysRuleCreatedTitle => 'Règle créée';

  @override
  String alwaysRuleCreatedBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions recatégorisées.',
      one: '$count transaction recatégorisée.',
      zero: 'Aucune autre transaction n\'a changé de catégorie.',
    );
    return '$_temp0';
  }

  @override
  String get alwaysRuleSuggestionFailed =>
      'Impossible de pré-remplir la règle. Renseignez le motif vous-même.';

  @override
  String get reviewQueueRunAction => 'Catégoriser avec l\'IA';

  @override
  String runBannerRunning(int processed, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: 'Catégorisation en cours — $processed sur $total transactions',
      one: 'Catégorisation en cours — $processed sur $total transaction',
    );
    return '$_temp0';
  }

  @override
  String runBannerRunningDetail(int assigned, int deferred) {
    String _temp0 = intl.Intl.pluralLogic(
      assigned,
      locale: localeName,
      other:
          '$assigned classées · $deferred à vérifier · le panneau reste utilisable',
      one:
          '$assigned classée · $deferred à vérifier · le panneau reste utilisable',
    );
    return '$_temp0';
  }

  @override
  String get runBannerCancel => 'Annuler';

  @override
  String runBannerPartial(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Catégorisation terminée — $count transactions n\'ont pas pu être analysées.',
      one:
          'Catégorisation terminée — $count transaction n\'a pas pu être analysée.',
    );
    return '$_temp0';
  }

  @override
  String get runBannerPartialAction => 'Voir';

  @override
  String get runBannerFailed => 'La catégorisation n\'a pas pu s\'exécuter.';

  @override
  String get runBannerDismiss => 'Fermer';

  @override
  String get runStartFailed =>
      'Impossible de lancer la catégorisation pour le moment.';

  @override
  String get settingsAiTitle => 'IA locale';

  @override
  String get settingsAiSubtitle => 'Activer la catégorisation par IA';

  @override
  String get settingsAiToggleLabel => 'Catégorisation par IA';

  @override
  String get settingsAiPrivacy =>
      'Les descriptions de vos transactions sont envoyées à un modèle qui s\'exécute sur cet ordinateur. Rien ne quitte votre machine.';

  @override
  String get settingsAiBaseUrlLabel => 'Adresse du moteur';

  @override
  String get settingsAiBaseUrlHelp =>
      'Adresse locale uniquement — 127.0.0.1 ou localhost.';

  @override
  String get settingsAiBaseUrlRejected =>
      'Adresse refusée : le moteur doit s\'exécuter sur cet ordinateur (127.0.0.1 ou localhost). Une adresse distante enverrait les descriptions de vos transactions hors de votre machine.';

  @override
  String get settingsAiModelLabel => 'Modèle';

  @override
  String get settingsAiModelHelp =>
      'Liste fournie par le moteur — saisie manuelle possible.';

  @override
  String get settingsAiModelUnavailable => 'Aucun modèle — moteur injoignable.';

  @override
  String get settingsAiModelChoose => 'Choisir un modèle';

  @override
  String settingsAiThresholdLabel(double threshold) {
    final intl.NumberFormat thresholdNumberFormat =
        intl.NumberFormat.percentPattern(localeName);
    final String thresholdString = thresholdNumberFormat.format(threshold);

    return 'Seuil de confiance — $thresholdString';
  }

  @override
  String get settingsAiThresholdHelp =>
      'En dessous de ce seuil, la transaction vous est proposée pour vérification plutôt que classée automatiquement.';

  @override
  String settingsAiStatusConnected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Connecté — $count modèles disponibles',
      one: 'Connecté — 1 modèle disponible',
      zero: 'Connecté — aucun modèle disponible',
    );
    return '$_temp0';
  }

  @override
  String get settingsAiStatusUnreachable =>
      'Aucun moteur détecté à cette adresse.';

  @override
  String get settingsAiStatusDisabled => 'Catégorisation par IA désactivée.';

  @override
  String get settingsAiLearnMore => 'En savoir plus';

  @override
  String get settingsAiTest => 'Tester la connexion';

  @override
  String get settingsAiTesting => 'Test en cours…';

  @override
  String get settingsAiLoadFailed =>
      'Impossible de charger vos paramètres pour le moment.';

  @override
  String get settingsAiRetry => 'Réessayer';

  @override
  String get settingsBackupTitle => 'Sauvegarde et restauration';

  @override
  String get settingsBackupSubtitle =>
      'Exportez toutes vos données dans un fichier que vous pourrez réimporter.';

  @override
  String get settingsBackupExportLabel => 'Exporter toutes les données';

  @override
  String get settingsBackupExportCaption =>
      'Fichier .finstride — comptes, transactions, catégories, règles, objectifs, crédits, biens, paramètres.';

  @override
  String get settingsBackupExportPreparing => 'Préparation de l\'archive…';

  @override
  String get settingsBackupExport => 'Exporter';

  @override
  String settingsBackupLast(String when) {
    return 'Dernière sauvegarde : $when';
  }

  @override
  String get settingsBackupNone => 'Aucune sauvegarde pour l\'instant.';

  @override
  String settingsBackupDateTime(String date, String time) {
    return '$date à $time';
  }

  @override
  String get settingsBackupPrivacy =>
      'Le fichier n\'est pas chiffré. Conservez-le en lieu sûr — il contient tout votre historique financier.';

  @override
  String get settingsBackupRestoreTitle => 'Restaurer une sauvegarde';

  @override
  String get settingsBackupRestoreSubtitle =>
      'Remplace toutes les données actuelles.';

  @override
  String get settingsBackupRestoreButton => 'Importer un fichier…';

  @override
  String get settingsBackupRestoreFailedLead => 'Restauration impossible.';

  @override
  String get settingsBackupErrorTooNew =>
      'Ce fichier provient d\'une version plus récente de FinStride. Mettez l\'application à jour pour le restaurer.';

  @override
  String get settingsBackupErrorInvalid =>
      'Ce fichier n\'est pas une sauvegarde FinStride valide, ou il est endommagé.';

  @override
  String get settingsBackupErrorCurrency =>
      'Cette sauvegarde utilise une autre devise que votre compte.';

  @override
  String get settingsBackupErrorRunActive =>
      'Une catégorisation est en cours. Attendez qu\'elle se termine, puis réessayez.';

  @override
  String get settingsBackupErrorConflict =>
      'Cette sauvegarde appartient à un autre compte présent sur cet ordinateur.';

  @override
  String get settingsBackupErrorUnknown =>
      'La restauration a échoué. Vos données n\'ont pas été modifiées.';

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
      other: '$accounts comptes',
      one: '$accounts compte',
    );
    return 'Sauvegarde enregistrée — $_temp0, $_temp1.';
  }

  @override
  String get settingsBackupExportFailed => 'L\'export a échoué. Réessayez.';

  @override
  String get settingsBackupConfirmTitle => 'Restaurer cette sauvegarde ?';

  @override
  String get settingsBackupConfirmFile => 'Fichier sélectionné :';

  @override
  String get settingsBackupConfirmExportedAt => 'Exporté le';

  @override
  String get settingsBackupConfirmVersion => 'Version de l\'application';

  @override
  String get settingsBackupConfirmAccounts => 'Comptes';

  @override
  String get settingsBackupConfirmTransactions => 'Transactions';

  @override
  String get settingsBackupConfirmCategories => 'Catégories';

  @override
  String get settingsBackupConfirmRules => 'Règles';

  @override
  String get settingsBackupConfirmSubscriptions => 'Abonnements';

  @override
  String get settingsBackupConfirmGoals => 'Objectifs';

  @override
  String get settingsBackupConfirmMortgages => 'Crédits';

  @override
  String get settingsBackupConfirmProperties => 'Biens';

  @override
  String get settingsBackupConfirmSimulations => 'Simulations';

  @override
  String get settingsBackupConfirmWarning =>
      'Toutes vos données actuelles seront remplacées. Exportez-les d\'abord si besoin.';

  @override
  String get settingsBackupCancel => 'Annuler';

  @override
  String get settingsBackupReplace => 'Remplacer mes données';

  @override
  String get settingsBackupRestored => 'Sauvegarde restaurée';

  @override
  String get navSubscriptions => 'Récurrents';

  @override
  String get navSubscriptionsSubtitle =>
      'Vos paiements récurrents, détectés automatiquement';

  @override
  String get subscriptionsDetect => 'Détecter';

  @override
  String get subscriptionsDetectRunning => 'Détection…';

  @override
  String get subscriptionsAdd => 'Nouveau paiement récurrent';

  @override
  String subscriptionsDetectResult(int created) {
    String _temp0 = intl.Intl.pluralLogic(
      created,
      locale: localeName,
      other: '$created nouveaux paiements récurrents détectés',
      one: '1 nouveau paiement récurrent détecté',
      zero: 'Aucun nouveau paiement récurrent détecté',
    );
    return '$_temp0';
  }

  @override
  String subscriptionsDetectResultDetail(int updated) {
    String _temp0 = intl.Intl.pluralLogic(
      updated,
      locale: localeName,
      other: '$updated séries existantes mises à jour',
      one: '1 série existante mise à jour',
      zero: 'Aucune série existante mise à jour',
    );
    return '$_temp0';
  }

  @override
  String get subscriptionsDetectFailed =>
      'La détection n\'a pas pu s\'exécuter.';

  @override
  String get subscriptionsBurdenLabel => 'Charge mensuelle';

  @override
  String get subscriptionsBurdenCaption =>
      'Charges trimestrielles et annuelles ramenées au mois.';

  @override
  String subscriptionsBurdenExcluded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count paiements terminés exclus.',
      one: '1 paiement terminé exclu.',
    );
    return '$_temp0';
  }

  @override
  String get subscriptionsActiveLabel => 'Paiements actifs';

  @override
  String subscriptionsCadenceWeeklyCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hebdomadaires',
      one: '1 hebdomadaire',
    );
    return '$_temp0';
  }

  @override
  String subscriptionsCadenceMonthlyCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mensuels',
      one: '1 mensuel',
    );
    return '$_temp0';
  }

  @override
  String subscriptionsCadenceQuarterlyCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count trimestriels',
      one: '1 trimestriel',
    );
    return '$_temp0';
  }

  @override
  String subscriptionsCadenceYearlyCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count annuels',
      one: '1 annuel',
    );
    return '$_temp0';
  }

  @override
  String subscriptionsCadenceIrregularCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count irréguliers',
      one: '1 irrégulier',
    );
    return '$_temp0';
  }

  @override
  String subscriptionsCancelledCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count terminés',
      one: '1 terminé',
    );
    return '$_temp0';
  }

  @override
  String get subscriptionsNextLabel => 'Prochain prélèvement';

  @override
  String subscriptionsNextValue(String label, String when) {
    return '$label — $when';
  }

  @override
  String subscriptionsNextCaption(String amount, String date) {
    return '$amount · $date';
  }

  @override
  String get subscriptionsNextToday => 'aujourd\'hui';

  @override
  String get subscriptionsNextTomorrow => 'demain';

  @override
  String subscriptionsNextInDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'dans $days jours',
      one: 'dans 1 jour',
    );
    return '$_temp0';
  }

  @override
  String get subscriptionsNextNone => 'Aucun prélèvement à venir';

  @override
  String get subscriptionsColumnName => 'Libellé';

  @override
  String get subscriptionsColumnCategory => 'Catégorie';

  @override
  String get subscriptionsColumnCadence => 'Cadence';

  @override
  String get subscriptionsColumnAmount => 'Montant';

  @override
  String get subscriptionsColumnNext => 'Prochain';

  @override
  String get subscriptionsColumnStatus => 'Statut';

  @override
  String get subscriptionsValueNone => '—';

  @override
  String get cadenceWeekly => 'Hebdomadaire';

  @override
  String get cadenceMonthly => 'Mensuel';

  @override
  String get cadenceQuarterly => 'Trimestriel';

  @override
  String get cadenceYearly => 'Annuel';

  @override
  String get cadenceIrregular => 'Irrégulier';

  @override
  String subscriptionSignalIncrease(String from, String to) {
    return 'Augmentation · $from → $to';
  }

  @override
  String subscriptionSignalMissed(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Prélèvement manquant · $days jours de retard',
      one: 'Prélèvement manquant · 1 jour de retard',
    );
    return '$_temp0';
  }

  @override
  String subscriptionSignalCancelled(String date) {
    return 'Terminé · dernier prélèvement $date';
  }

  @override
  String subscriptionNextExpected(String date) {
    return 'attendu le $date';
  }

  @override
  String get subscriptionActionsTooltip => 'Actions du paiement';

  @override
  String get subscriptionActionConfirm => 'Confirmer';

  @override
  String get subscriptionActionDismiss => 'Ignorer';

  @override
  String get subscriptionActionCancel => 'Marquer comme terminé';

  @override
  String get subscriptionActionEdit => 'Modifier';

  @override
  String get subscriptionErrorInvalidTransition =>
      'Ce changement de statut n\'est pas possible pour ce paiement.';

  @override
  String get subscriptionErrorExists =>
      'Ce compte suit déjà un paiement récurrent sous ce nom.';

  @override
  String get subscriptionErrorNotFound =>
      'Ce paiement récurrent n\'existe plus.';

  @override
  String get subscriptionErrorAccountNotFound => 'Ce compte n\'existe plus.';

  @override
  String get subscriptionErrorCategoryInvalid =>
      'Cette catégorie n\'est plus disponible.';

  @override
  String get subscriptionErrorValidation =>
      'Vérifiez les informations saisies.';

  @override
  String get subscriptionErrorGeneric => 'Une erreur est survenue. Réessayez.';

  @override
  String get subscriptionsLoadFailed =>
      'Impossible de charger vos paiements récurrents pour le moment.';

  @override
  String get subscriptionsRetry => 'Réessayer';

  @override
  String get subscriptionsEmptyTitle =>
      'Aucun paiement récurrent détecté pour l\'instant';

  @override
  String get subscriptionsEmptyBody =>
      'FinStride repère un paiement récurrent lorsqu\'un prélèvement s\'est répété trois fois. Importer davantage d\'historique accélère la détection.';

  @override
  String get subscriptionsEmptyCta => 'Aller aux imports';

  @override
  String get subscriptionDetailBack => 'Retour aux récurrents';

  @override
  String subscriptionDetailDetectedSince(String account, String month) {
    return '$account · détecté depuis $month';
  }

  @override
  String subscriptionDetailTrackedSince(String account, String month) {
    return '$account · suivi depuis $month';
  }

  @override
  String get subscriptionDetailCadence => 'Cadence';

  @override
  String get subscriptionDetailExpectedAmount => 'Montant attendu';

  @override
  String get subscriptionDetailNextCharge => 'Prochain prélèvement';

  @override
  String subscriptionDetailIncrease(
    String from,
    String to,
    String date,
    String annual,
  ) {
    return 'Augmentation : $from → $to le $date — soit $annual par an.';
  }

  @override
  String get subscriptionDetailHistoryTitle => 'Historique des prélèvements';

  @override
  String subscriptionDetailHistorySubtitle(String account) {
    return 'Les transactions dont cette série est déduite · $account';
  }

  @override
  String get subscriptionDetailHistoryEmpty =>
      'Aucun prélèvement rattaché à ce paiement pour l\'instant.';

  @override
  String subscriptionDetailChange(String from, String to) {
    return '$from → $to';
  }

  @override
  String get subscriptionDetailFootnote =>
      'FinStride déduit la série de ces occurrences — vérifiez-les avant de confirmer un changement.';

  @override
  String get subscriptionDetailLoadFailed =>
      'Impossible de charger ce paiement récurrent pour le moment.';

  @override
  String get subscriptionFormCreateTitle => 'Nouveau paiement récurrent';

  @override
  String get subscriptionFormEditTitle => 'Modifier le paiement récurrent';

  @override
  String get subscriptionFormIntro =>
      'Suivez un paiement récurrent que la détection n\'a pas encore repéré.';

  @override
  String get subscriptionFormNameLabel => 'Nom';

  @override
  String get subscriptionFormNameRequired => 'Donnez un nom à ce paiement.';

  @override
  String get subscriptionFormAccountLabel => 'Compte';

  @override
  String get subscriptionFormAmountLabel => 'Montant';

  @override
  String get subscriptionFormAmountInvalid =>
      'Saisissez un montant supérieur à zéro.';

  @override
  String get subscriptionFormCadenceLabel => 'Cadence';

  @override
  String get subscriptionFormCadenceHelp =>
      'Hebdomadaire · Mensuel · Trimestriel · Annuel · Irrégulier';

  @override
  String get subscriptionFormCategoryLabel => 'Catégorie';

  @override
  String get subscriptionFormCategoryNone => 'Aucune';

  @override
  String get subscriptionFormNoAccounts =>
      'Créez d\'abord un compte pour y suivre un paiement récurrent.';

  @override
  String get subscriptionFormCancel => 'Annuler';

  @override
  String get subscriptionFormSubmit => 'Créer le paiement récurrent';

  @override
  String get subscriptionFormSave => 'Enregistrer';

  @override
  String get navGoals => 'Objectifs';

  @override
  String get navGoalsSubtitle =>
      'Mettez de côté, virtuellement, pour ce qui compte';

  @override
  String get goalsAdd => 'Nouvel objectif';

  @override
  String get goalsReassurance =>
      'Répartition sur le papier : vos comptes ne sont pas modifiés.';

  @override
  String goalsOverAllocated(String allocated, String savings) {
    return 'Vous avez réparti $allocated alors que vos comptes d\'épargne totalisent $savings.';
  }

  @override
  String get goalsDismissBanner => 'Masquer cet avertissement';

  @override
  String goalsShowArchived(int count) {
    return 'Afficher les objectifs archivés ($count)';
  }

  @override
  String goalsHideArchived(int count) {
    return 'Masquer les objectifs archivés ($count)';
  }

  @override
  String get goalsEmptyTitle => 'Donnez un nom à ce qui compte';

  @override
  String get goalsEmptyBody =>
      'Un objectif est une enveloppe virtuelle : vous y mettez de côté à votre rythme, sans toucher à vos comptes.';

  @override
  String get goalsLoadFailed =>
      'Impossible de charger vos objectifs pour le moment.';

  @override
  String get goalsRetry => 'Réessayer';

  @override
  String get goalPillNoDeadline => 'Sans échéance';

  @override
  String get goalPillReached => 'Objectif atteint';

  @override
  String goalPillReachedOn(String month) {
    return 'Objectif atteint · $month';
  }

  @override
  String get goalDetailBack => 'Retour aux objectifs';

  @override
  String goalDetailTargetDate(String month) {
    return 'Échéance $month';
  }

  @override
  String get goalDetailArchive => 'Archiver';

  @override
  String get goalDetailRestore => 'Restaurer';

  @override
  String get goalDetailNewAllocation => 'Nouvelle allocation';

  @override
  String get goalDetailMissing => 'Cet objectif n\'est plus disponible.';

  @override
  String get goalDetailFootnote =>
      'Aucune transaction n\'est créée : ces lignes n\'existent que sur le papier de l\'objectif.';

  @override
  String get goalDetailHistoryFailed =>
      'Impossible de charger l\'historique des allocations.';

  @override
  String get goalHistoryTitle => 'Historique des allocations';

  @override
  String get goalHistorySubtitle =>
      'Une seule liste, montants signés — un retrait est une ligne négative.';

  @override
  String get goalHistoryDate => 'Date';

  @override
  String get goalHistoryAmount => 'Montant';

  @override
  String get goalHistoryNote => 'Note';

  @override
  String get goalHistoryDelete => 'Supprimer cette allocation';

  @override
  String get goalHistoryEmpty => 'Aucune allocation pour l\'instant.';

  @override
  String get goalFormCreateTitle => 'Nouvel objectif';

  @override
  String get goalFormEditTitle => 'Modifier l\'objectif';

  @override
  String get goalFormIntro =>
      'Une enveloppe virtuelle : vous y mettez de côté sur le papier, sans toucher à vos comptes.';

  @override
  String get goalFormNameLabel => 'Nom';

  @override
  String get goalFormNameRequired => 'Donnez un nom à cet objectif.';

  @override
  String get goalFormTargetLabel => 'Montant cible';

  @override
  String get goalFormTargetInvalid => 'Saisissez un montant supérieur à zéro.';

  @override
  String get goalFormDateLabel => 'Date cible';

  @override
  String get goalFormDateHelp => 'Facultative';

  @override
  String get goalFormDateInvalid => 'Date invalide.';

  @override
  String get goalFormIconLabel => 'Icône';

  @override
  String get goalFormColorLabel => 'Couleur';

  @override
  String get goalFormCancel => 'Annuler';

  @override
  String get goalFormSubmit => 'Créer l\'objectif';

  @override
  String get goalFormSave => 'Enregistrer';

  @override
  String get allocationModalTitle => 'Nouvelle allocation';

  @override
  String get allocationAmountLabel => 'Montant';

  @override
  String get allocationAmountHelp =>
      'Un montant négatif retire de l\'objectif.';

  @override
  String get allocationAmountInvalid =>
      'Saisissez un montant différent de zéro.';

  @override
  String get allocationDateLabel => 'Date';

  @override
  String get allocationDateInvalid => 'Date invalide.';

  @override
  String get allocationNoteLabel => 'Note (optionnelle)';

  @override
  String get allocationNoteHint => 'Ex. Virement mensuel';

  @override
  String get allocationCancel => 'Annuler';

  @override
  String get allocationSubmit => 'Ajouter';

  @override
  String get goalErrorNotFound => 'Cet objectif n\'existe plus.';

  @override
  String get goalErrorAllocationNotFound => 'Cette allocation n\'existe plus.';

  @override
  String get goalErrorValidation => 'Vérifiez les informations saisies.';

  @override
  String get goalErrorGeneric => 'Une erreur est survenue. Réessayez.';

  @override
  String get dashboardGoalsTitle => 'Objectifs';

  @override
  String get dashboardGoalsViewAll => 'Voir tout';

  @override
  String dashboardGoalsProgress(String saved, String target) {
    return '$saved / $target';
  }

  @override
  String get dashboardGoalsReached => 'Atteint';

  @override
  String get goalFormDatePick => 'Choisir une date cible';

  @override
  String get allocationDatePick => 'Choisir une date';

  @override
  String get settingsResetTitle => 'Zone de danger';

  @override
  String get settingsResetBadge => 'IRRÉVERSIBLE';

  @override
  String get settingsResetSubtitle =>
      'Réinitialiser la base de données supprime transactions, comptes, règles, catégories personnalisées, objectifs, abonnements, crédits, biens et simulations de ce profil. Les sauvegardes exportées ne sont pas touchées.';

  @override
  String get settingsResetButton => 'Réinitialiser…';

  @override
  String get settingsResetConfirmTitle => 'Réinitialiser la base de données ?';

  @override
  String settingsResetConfirmLead(String name) {
    return 'Tout le contenu du profil $name sera supprimé définitivement :';
  }

  @override
  String get settingsResetConfirmCategories => 'Catégories personnalisées';

  @override
  String get settingsResetConfirmNote =>
      'Les catégories système, vos préférences et le réglage IA sont conservés. Les fichiers de sauvegarde déjà exportés restent intacts.';

  @override
  String get settingsResetConfirmWarning =>
      'Cette action est irréversible. Exportez une sauvegarde avant de continuer.';

  @override
  String get settingsResetConfirmWord => 'SUPPRIMER';

  @override
  String settingsResetConfirmLabel(String word) {
    return 'Saisissez $word pour confirmer';
  }

  @override
  String get settingsResetConfirmSubmit => 'Tout supprimer';

  @override
  String get settingsResetDone =>
      'Base de données réinitialisée. Les catégories système ont été restaurées.';

  @override
  String get settingsResetFailedLead => 'Réinitialisation impossible.';

  @override
  String get settingsResetErrorUnknown =>
      'La réinitialisation a échoué. Vos données n\'ont pas été modifiées.';

  @override
  String get navSectionWealth => 'Patrimoine';

  @override
  String get navMortgages => 'Crédits';

  @override
  String get navMortgagesSubtitle =>
      'Vos emprunts, leur coût et votre capacité';

  @override
  String get navSimulator => 'Simulateur';

  @override
  String get navSimulatorSubtitle => 'Ce qu\'un nouveau crédit changerait';

  @override
  String get navNetworth => 'Synthèse';

  @override
  String get navNetworthSubtitle => 'Ce que vous possédez, ce que vous devez';

  @override
  String get mortgagesAdd => 'Nouveau crédit';

  @override
  String get mortgagesLoadFailed => 'Impossible de charger vos crédits.';

  @override
  String get mortgagesRetry => 'Réessayer';

  @override
  String get mortgagesEmptyTitle => 'Aucun crédit enregistré';

  @override
  String get mortgagesEmptyBody =>
      'Ajoutez vos emprunts pour suivre leur coût réel, leur trajectoire et votre capacité — sans jamais relier FinStride à une banque.';

  @override
  String get mortgagesChargeLabel => 'Charge mensuelle';

  @override
  String mortgagesChargeCaption(int count, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count échéances le $date',
      one: '1 échéance le $date',
    );
    return '$_temp0 · assurance comprise';
  }

  @override
  String get mortgagesChargeCaptionNoNext => 'assurance comprise';

  @override
  String get mortgagesOutstandingLabel => 'Capital restant dû';

  @override
  String mortgagesOutstandingCaption(String principal, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count crédits',
      one: '1 crédit',
    );
    return 'sur $principal empruntés · $_temp0';
  }

  @override
  String mortgagesRepaidLine(String amount, String percent) {
    return '$amount remboursés · $percent';
  }

  @override
  String get mortgagesRatioLabel => 'Taux d\'endettement';

  @override
  String mortgagesRatioReference(String percent) {
    return 'repère HCSF $percent';
  }

  @override
  String get mortgagesRatioOverLimit => 'Au-dessus du repère';

  @override
  String mortgagesRatioCaptionDeclared(String charge, String income) {
    return 'Charge $charge sur un revenu déclaré de $income';
  }

  @override
  String mortgagesRatioCaptionLedger(String charge, String income) {
    return 'Charge $charge sur un revenu médian constaté de $income (12 mois du grand livre). Le ménage perçoit peut-être des revenus hors application : un revenu déclaré remplace cette lecture.';
  }

  @override
  String get mortgagesRatioUnknown =>
      'Aucun revenu connu : le grand livre ne contient pas de revenus réguliers et aucun revenu n\'est déclaré. Sans revenu, il n\'y a pas de taux à calculer.';

  @override
  String get mortgagesRatioDeclareLink => 'Déclarer un revenu →';

  @override
  String get mortgagesRatioDeclareButton => 'Déclarer un revenu';

  @override
  String get mortgagesRatioCaveat =>
      'Lecture informative : ce repère ne lie aucun prêteur.';

  @override
  String get mortgagesIncomeTitle => 'Déclarer un revenu';

  @override
  String get mortgagesIncomeBody =>
      'Le revenu mensuel net du ménage sur lequel lire le taux d\'endettement. Il remplace le revenu médian du grand livre.';

  @override
  String get mortgagesIncomeLabel => 'Revenu mensuel';

  @override
  String get mortgagesIncomeInvalid => 'Saisissez un montant supérieur à zéro.';

  @override
  String get mortgagesIncomeSubmit => 'Enregistrer';

  @override
  String get mortgagesIncomeFailed => 'Le revenu n\'a pas pu être enregistré.';

  @override
  String get mortgageKindMortgage => 'Crédit immobilier';

  @override
  String get mortgageKindWorks => 'Prêt travaux';

  @override
  String get mortgageKindConsumer => 'Crédit à la consommation';

  @override
  String get mortgageKindAuto => 'Crédit auto';

  @override
  String get mortgageRepaymentConstant => 'Échéance constante';

  @override
  String get mortgageRepaymentInterestOnly => 'In fine';

  @override
  String mortgageCardSubline(String kind, String lender, int months) {
    return '$kind · $lender · $months mois';
  }

  @override
  String get mortgageCardPerMonth => '/ mois';

  @override
  String get mortgageCardOutstandingLabel => 'Capital restant dû';

  @override
  String mortgageCardOutstandingOf(String principal) {
    return 'sur $principal';
  }

  @override
  String get mortgageCardRepaid => 'remboursé';

  @override
  String mortgageCardRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count échéances restantes',
      one: '1 échéance restante',
      zero: 'aucune échéance restante',
    );
    return '$_temp0';
  }

  @override
  String get mortgageRateLabel => 'Taux nominal';

  @override
  String get mortgageInsuranceLabel => 'Assurance';

  @override
  String get mortgageNextLabel => 'Prochaine échéance';

  @override
  String mortgageInsurancePerMonth(String amount) {
    return '$amount / mois';
  }

  @override
  String get mortgagesChartTitle => 'Trajectoire du capital restant dû';

  @override
  String mortgagesChartSubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Les $count crédits, échéance après échéance, jusqu\'au dernier remboursement',
      two:
          'Les deux crédits, échéance après échéance, jusqu\'au dernier remboursement',
      one:
          'Le crédit, échéance après échéance, jusqu\'au dernier remboursement',
    );
    return '$_temp0';
  }

  @override
  String get mortgagesChartLegendTotal => 'Capital restant dû total';

  @override
  String get mortgagesChartLegendToday => 'aujourd\'hui';

  @override
  String mortgagesChartToday(String month, String amount) {
    return '$month · $amount';
  }

  @override
  String mortgagesChartLoanEnd(String kind, String month) {
    return 'fin $kind · $month';
  }

  @override
  String get mortgageDetailBack => 'Retour aux crédits';

  @override
  String get mortgageDetailLoadFailed => 'Impossible de charger ce crédit.';

  @override
  String mortgageDetailSubline(
    String kind,
    String lender,
    String principal,
    int months,
    String date,
  ) {
    return '$kind · $lender · $principal sur $months mois · 1re échéance le $date';
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
    return '$kind · $lender · $principal sur $months mois · 1re échéance le $date · frais de dossier $fees';
  }

  @override
  String get mortgageDetailInstalmentLabel => 'Échéance totale';

  @override
  String mortgageDetailInstalmentCaption(String payment, String insurance) {
    return '$payment + $insurance assurance';
  }

  @override
  String get mortgageDetailInstalmentNoInsurance => 'sans assurance';

  @override
  String mortgageDetailOutstandingCaption(String percent, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count échéances',
      one: '1 échéance',
    );
    return '$percent remboursé · $_temp0';
  }

  @override
  String get mortgageDetailEdit => 'Modifier';

  @override
  String get mortgageCostRateCaption => 'fixe sur toute la durée';

  @override
  String get mortgageCostTaegLabel => 'TAEG';

  @override
  String get mortgageCostIndicative => 'Indicatif';

  @override
  String get mortgageCostTaegDisclaimer =>
      'Indicatif : un TAEG réel inclut des frais que FinStride ne voit pas.';

  @override
  String get mortgageCostTaegCaption => 'taux, assurance et frais inclus';

  @override
  String get mortgageCostInterestLabel => 'Intérêts totaux';

  @override
  String mortgageCostInterestCaption(String amount) {
    return 'dont $amount encore à verser';
  }

  @override
  String get mortgageCostTotalLabel => 'Coût total du crédit';

  @override
  String mortgageCostTotalCaption(String insurance, String fees) {
    return 'intérêts + assurance $insurance + frais $fees';
  }

  @override
  String get mortgageFormCreateTitle => 'Nouveau crédit';

  @override
  String get mortgageFormEditTitle => 'Modifier le crédit';

  @override
  String get mortgageFormSubtitle =>
      'La mensualité est calculée à partir du capital, du taux et de la durée.';

  @override
  String get mortgageFormLabel => 'Libellé';

  @override
  String get mortgageFormLabelRequired => 'Donnez un nom à ce crédit.';

  @override
  String get mortgageFormLender => 'Prêteur';

  @override
  String get mortgageFormLenderRequired => 'Indiquez le prêteur.';

  @override
  String get mortgageFormKind => 'Type';

  @override
  String get mortgageFormRepayment => 'Remboursement';

  @override
  String get mortgageFormPrincipal => 'Capital emprunté';

  @override
  String get mortgageFormAmountInvalid =>
      'Saisissez un montant supérieur à zéro.';

  @override
  String get mortgageFormRate => 'Taux nominal';

  @override
  String get mortgageFormRateInvalid => 'Saisissez un taux, par exemple 3,45.';

  @override
  String get mortgageFormTerm => 'Durée';

  @override
  String get mortgageFormTermUnit => 'mois';

  @override
  String get mortgageFormTermInvalid => 'Saisissez une durée en mois.';

  @override
  String get mortgageFormFirstPayment => '1re échéance';

  @override
  String get mortgageFormDateInvalid => 'Saisissez une date valide.';

  @override
  String get mortgageFormCalendar => 'Choisir une date';

  @override
  String get mortgageFormInsurance => 'Assurance / mois';

  @override
  String get mortgageFormAmountOptionalInvalid =>
      'Saisissez un montant valide ou laissez vide.';

  @override
  String get mortgageFormFees => 'Frais de dossier';

  @override
  String get mortgageFormProperty => 'Bien financé';

  @override
  String get mortgageFormPropertyNone => 'Aucun';

  @override
  String get mortgageFormPlateLabel => 'Mensualité calculée';

  @override
  String mortgageFormPlateDetail(String instalment, String interest) {
    return 'échéance totale $instalment — intérêts totaux $interest';
  }

  @override
  String get mortgageFormPlatePending =>
      'Renseignez le capital, le taux et la durée.';

  @override
  String get mortgageFormPlateInterestOnly =>
      'La mensualité d\'un prêt in fine s\'affiche une fois le crédit enregistré.';

  @override
  String get mortgageFormCancel => 'Annuler';

  @override
  String get mortgageFormSubmit => 'Ajouter le crédit';

  @override
  String get mortgageFormSave => 'Enregistrer';

  @override
  String get mortgageFormDelete => 'Supprimer le crédit';

  @override
  String get mortgageDeleteTitle => 'Supprimer ce crédit ?';

  @override
  String get mortgageDeleteBody =>
      'Il quittera le passif de la Synthèse et, s\'il est rattaché à un bien, la base de l\'IFI.';

  @override
  String get mortgageDeleteConfirm => 'Supprimer';

  @override
  String get mortgageErrorNonAmortizing =>
      'Ce crédit ne se rembourse pas : l\'échéance ne couvre pas les intérêts du premier mois. Modifiez le taux, le capital ou la durée.';

  @override
  String get mortgageErrorFeesExceed =>
      'Les frais de dossier doivent rester inférieurs au capital emprunté.';

  @override
  String get mortgageErrorPropertyInvalid => 'Ce bien n\'existe plus.';

  @override
  String get mortgageErrorNotFound => 'Ce crédit n\'existe plus.';

  @override
  String get mortgageErrorValidation => 'Certaines valeurs sont invalides.';

  @override
  String get mortgageErrorGeneric => 'Une erreur est survenue. Réessayez.';

  @override
  String get mortgageScheduleTitle => 'Tableau d\'amortissement';

  @override
  String mortgageScheduleSubtitle(int position, int total, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count échéances',
      one: '1 échéance',
    );
    return 'Année $position sur $total · $_temp0 · l\'assurance est comptée à part';
  }

  @override
  String mortgageScheduleSubtitleLoading(int position, int total) {
    return 'Année $position sur $total';
  }

  @override
  String get mortgageScheduleDue => 'Échéance';

  @override
  String get mortgageScheduleInterest => 'Intérêts';

  @override
  String get mortgageSchedulePrincipal => 'Capital';

  @override
  String get mortgageScheduleInsurance => 'Assurance';

  @override
  String get mortgageScheduleTotalPaid => 'Total versé';

  @override
  String get mortgageScheduleOutstanding => 'Capital restant dû';

  @override
  String mortgageScheduleFootTotal(String year) {
    return 'Total $year';
  }

  @override
  String mortgageScheduleFootOutstanding(String date, String amount) {
    return 'au $date : $amount';
  }

  @override
  String get mortgageScheduleYearPrevious => 'Année précédente';

  @override
  String get mortgageScheduleYearNext => 'Année suivante';

  @override
  String get mortgageScheduleLoadFailed =>
      'Impossible de charger le tableau d\'amortissement.';

  @override
  String get simulatorLoadFailed => 'Impossible de charger le simulateur.';

  @override
  String get simulatorRetry => 'Réessayer';

  @override
  String get simulatorFormTitle => 'Nouveau crédit';

  @override
  String get simulatorFormSubtitle =>
      'Le résultat se recalcule à chaque saisie';

  @override
  String get simulatorPrice => 'Prix du bien';

  @override
  String get simulatorDownPayment => 'Apport';

  @override
  String get simulatorFees => 'Frais';

  @override
  String get simulatorPrincipal => 'Montant emprunté';

  @override
  String get simulatorDerivedPill => 'Dérivé';

  @override
  String get simulatorRate => 'Taux nominal';

  @override
  String get simulatorRateInvalid => 'Saisissez un taux, par exemple 3,25.';

  @override
  String get simulatorInsurance => 'Assurance / mois';

  @override
  String get simulatorTerm => 'Durée';

  @override
  String simulatorTermValue(int months, num years) {
    final intl.NumberFormat yearsNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String yearsString = yearsNumberFormat.format(years);

    String _temp0 = intl.Intl.pluralLogic(
      years,
      locale: localeName,
      other: '$yearsString ans',
      one: '1 an',
    );
    return '$months mois · $_temp0';
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
      other: '$yearsString ans',
      one: '1 an',
    );
    return '$_temp0';
  }

  @override
  String simulatorMonths(int months) {
    return '$months mois';
  }

  @override
  String get simulatorIncludeExisting => 'Inclure mes crédits actuels';

  @override
  String simulatorIncludeExistingAdds(String amount) {
    return 'Ajoute $amount / mois à la lecture';
  }

  @override
  String get simulatorIncludeExistingNone => 'Aucun crédit en cours à ajouter';

  @override
  String get simulatorInstalmentLabel => 'Échéance mensuelle';

  @override
  String simulatorInstalmentCaption(
    String payment,
    String insurance,
    int count,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count échéances',
      one: '1 échéance',
    );
    return '$payment de mensualité + $insurance d\'assurance · $_temp0';
  }

  @override
  String get simulatorInstalmentEmpty =>
      'Renseignez un prix et un taux pour voir l\'échéance et sa part d\'assurance.';

  @override
  String get simulatorCostLabel => 'Coût total';

  @override
  String simulatorCostCaption(
    String interest,
    String insurance,
    String fees,
    String share,
  ) {
    return 'intérêts $interest + assurance $insurance + frais $fees · $share du prix';
  }

  @override
  String simulatorCostCaptionNoPrice(
    String interest,
    String insurance,
    String fees,
  ) {
    return 'intérêts $interest + assurance $insurance + frais $fees';
  }

  @override
  String get simulatorCostEmpty =>
      'Renseignez un prix et un taux pour voir le coût total et sa part du prix.';

  @override
  String get simulatorTaegLabel => 'TAEG';

  @override
  String get simulatorIndicativePill => 'Indicatif';

  @override
  String get simulatorTaegCaption => 'taux, assurance et frais inclus';

  @override
  String get simulatorHcsfTitle => 'Lecture HCSF';

  @override
  String get simulatorHcsfOver => 'Au-dessus du repère';

  @override
  String get simulatorHcsfCaveat => 'Informative — ne lie aucun prêteur';

  @override
  String simulatorReference(String value) {
    return 'repère $value';
  }

  @override
  String get simulatorRatioLabel => 'Taux d\'endettement';

  @override
  String simulatorRatioCaption(
    String instalment,
    String source,
    String income,
  ) {
    String _temp0 = intl.Intl.selectLogic(source, {
      'declared': 'déclaré',
      'other': 'médian constaté',
    });
    return '$instalment sur un revenu $_temp0 de $income';
  }

  @override
  String simulatorRatioCaptionWithExisting(
    String instalment,
    String existing,
    String source,
    String income,
  ) {
    String _temp0 = intl.Intl.selectLogic(source, {
      'declared': 'déclaré',
      'other': 'médian constaté',
    });
    return '$instalment + crédits actuels $existing sur un revenu $_temp0 de $income';
  }

  @override
  String get simulatorRatioEmpty =>
      'Renseignez un prix et un taux pour lire le taux d\'endettement.';

  @override
  String get simulatorRatioUnknown =>
      'Aucun revenu connu : le grand livre n\'a pas de revenus réguliers et aucun revenu n\'est déclaré. Sans revenu, ni taux ni capacité ne peuvent être lus.';

  @override
  String get simulatorDeclareIncome => 'Déclarer un revenu';

  @override
  String get simulatorTermAtReference => 'au repère, pas au-delà';

  @override
  String get simulatorTermUnderReference => 'sous le repère';

  @override
  String get simulatorTermOverReference => 'au-delà du repère';

  @override
  String get simulatorCapacityLabel => 'Capacité d\'emprunt au repère';

  @override
  String simulatorCapacityCaption(String available, String limit) {
    return '$available d\'échéance disponibles sous $limit, à ces conditions';
  }

  @override
  String simulatorCapacityCaptionExisting(String available) {
    return 'il ne reste que $available d\'échéance sous le repère une fois vos crédits actuels comptés — c\'est ce qui rend la capacité si faible, pas le bien visé';
  }

  @override
  String get simulatorCapacityEmpty =>
      'Renseignez un prix et un taux pour lire la capacité d\'emprunt.';

  @override
  String get simulatorChartTitle => 'Projection annuelle';

  @override
  String get simulatorChartSubtitle =>
      'Capital remboursé et intérêts versés, année par année';

  @override
  String get simulatorChartCapital => 'Capital';

  @override
  String get simulatorChartInterest => 'Intérêts';

  @override
  String get simulatorChartEmpty =>
      'Renseignez un prix et un taux : la répartition capital / intérêts par année s\'affiche ici.';

  @override
  String get simulatorComputeFailed =>
      'Le calcul n\'a pas abouti. Réessayez dans un instant.';

  @override
  String get simulatorErrorNonAmortizing =>
      'À ce taux, l\'échéance ne rembourse pas le capital : baissez le taux ou allongez la durée.';

  @override
  String get simulatorErrorFeesExceed =>
      'Les frais doivent rester inférieurs au montant emprunté.';

  @override
  String get simulatorErrorValidation =>
      'Certaines valeurs ne sont pas acceptées.';

  @override
  String get simulatorErrorGeneric => 'Une erreur est survenue. Réessayez.';

  @override
  String get simulatorIncomeTitle => 'Déclarer un revenu';

  @override
  String get simulatorIncomeBody =>
      'Le revenu mensuel déclaré sert de base au taux d\'endettement et à la capacité d\'emprunt.';

  @override
  String get simulatorIncomeLabel => 'Revenu mensuel net';

  @override
  String get simulatorIncomeInvalid => 'Saisissez un montant supérieur à zéro.';

  @override
  String get simulatorIncomeSubmit => 'Déclarer';

  @override
  String get simulatorIncomeFailed =>
      'Impossible d\'enregistrer ce revenu. Réessayez.';

  @override
  String get simulatorCancel => 'Annuler';

  @override
  String get simulatorSaveScenario => 'Enregistrer le scénario';

  @override
  String get simulatorSaveBody =>
      'Seules les valeurs saisies sont enregistrées : le résultat est recalculé à chaque fois.';

  @override
  String get simulatorSaveName => 'Nom';

  @override
  String simulatorSaveNamePrefill(String price) {
    return ' — $price';
  }

  @override
  String get simulatorSaveNameRequired => 'Donnez un nom au scénario.';

  @override
  String get simulatorSaveSubmit => 'Enregistrer';

  @override
  String simulatorPriceThousands(String amount) {
    return '$amount k€';
  }

  @override
  String get simulatorErrorLimitReached =>
      'Vous avez atteint le nombre maximal de scénarios enregistrés. Supprimez-en un pour en ajouter un autre.';

  @override
  String get simulatorErrorNotFound => 'Ce scénario n\'existe plus.';

  @override
  String get simulatorScenariosTitle => 'Scénarios enregistrés';

  @override
  String simulatorCompareButton(int count, int max) {
    return 'Comparer ($count/$max)';
  }

  @override
  String get simulatorCompareNeedsTwo =>
      'Cochez au moins deux scénarios pour les comparer.';

  @override
  String simulatorCompareCapNamed(String name) {
    return 'Trois scénarios au plus, pour rester lisibles côte à côte. Décochez-en un pour ajouter $name.';
  }

  @override
  String get simulatorCompareCap =>
      'Trois scénarios au plus, pour rester lisibles côte à côte. Décochez-en un pour en ajouter un autre.';

  @override
  String get simulatorLivePill => 'En cours';

  @override
  String get simulatorLiveName => 'Simulation en cours';

  @override
  String simulatorScenarioSub(String rate, String term, String instalment) {
    return '$rate · $term · $instalment';
  }

  @override
  String simulatorScenarioSubNoInstalment(String rate, String term) {
    return '$rate · $term';
  }

  @override
  String get simulatorScenarioActions => 'Actions du scénario';

  @override
  String get simulatorScenarioDelete => 'Supprimer';

  @override
  String simulatorScenarioSelect(String name) {
    return 'Sélectionner $name pour la comparaison';
  }

  @override
  String get simulatorScenariosEmptyTitle => 'Aucun scénario enregistré';

  @override
  String get simulatorScenariosEmptyBody =>
      'Enregistrez une simulation pour la retrouver ici et la comparer à deux autres.';

  @override
  String simulatorCompareTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Comparaison de $count scénarios',
      one: 'Comparaison d\'un scénario',
    );
    return '$_temp0';
  }

  @override
  String get simulatorCompareSubtitle =>
      'Mêmes lignes pour chaque colonne · un tiret quand la donnée ne s\'applique pas';

  @override
  String get simulatorCompareClose => 'Fermer la comparaison';

  @override
  String get simulatorCompareFailed => 'Impossible de calculer la comparaison.';

  @override
  String get simulatorCompareTotalInterest => 'Intérêts totaux';

  @override
  String get simulatorCompareTotalInsurance => 'Assurance totale';

  @override
  String get simulatorCompareCostShare => 'Coût / prix';

  @override
  String get simulatorCompareTaeg => 'TAEG indicatif';

  @override
  String get simulatorCompareWithExisting => 'Avec crédits actuels';

  @override
  String simulatorCompareFoot(String source, String income, String limit) {
    String _temp0 = intl.Intl.selectLogic(source, {
      'declared': 'déclaré',
      'other': 'médian constaté',
    });
    return 'Taux d\'endettement sur un revenu $_temp0 de $income · repère HCSF $limit · lecture informative, ne lie aucun prêteur.';
  }

  @override
  String simulatorCompareFootUnknown(String limit) {
    return 'Aucun revenu connu, donc aucun taux d\'endettement · repère HCSF $limit · lecture informative, ne lie aucun prêteur.';
  }

  @override
  String get propertyKindPrimaryResidence => 'Résidence principale';

  @override
  String get propertyKindRental => 'Locatif';

  @override
  String get propertyKindSecondary => 'Résidence secondaire';

  @override
  String get propertyKindOther => 'Autre bien';

  @override
  String get propertyFormCreateTitle => 'Nouveau bien';

  @override
  String get propertyFormEditTitle => 'Modifier le bien';

  @override
  String get propertyFormSubtitle =>
      'La valeur déclarée entre dans la synthèse.';

  @override
  String get propertyFormLabel => 'Libellé';

  @override
  String get propertyFormLabelRequired => 'Donnez un nom à ce bien.';

  @override
  String get propertyFormKind => 'Nature';

  @override
  String get propertyFormValue => 'Valeur déclarée';

  @override
  String get propertyFormValuedOn => 'Date d\'estimation';

  @override
  String get propertyFormOwnership => 'Quote-part détenue';

  @override
  String propertyFormOwnershipShare(String amount) {
    return 'part : $amount';
  }

  @override
  String get propertyFormOwnershipInvalid =>
      'Indiquez une quote-part entre 0,01 et 100 %.';

  @override
  String get propertyFormAcquisitionPrice => 'Prix d\'acquisition';

  @override
  String get propertyFormAcquiredOn => 'Date d\'acquisition';

  @override
  String get propertyFormAmountInvalid =>
      'Saisissez un montant supérieur à zéro.';

  @override
  String get propertyFormAmountOptionalInvalid =>
      'Montant illisible — laissez vide s\'il est inconnu.';

  @override
  String get propertyFormDateInvalid => 'Date invalide (JJ/MM/AAAA).';

  @override
  String get propertyFormCalendar => 'Choisir une date';

  @override
  String get propertyFormCancel => 'Annuler';

  @override
  String get propertyFormSubmit => 'Ajouter le bien';

  @override
  String get propertyFormSave => 'Enregistrer';

  @override
  String get propertyRevalueTitle => 'Nouvelle estimation';

  @override
  String propertyRevalueSubtitle(String label, String value, String date) {
    return '$label : $value estimés le $date. La nouvelle estimation remplace celle-ci.';
  }

  @override
  String get propertyRevalueSubmit => 'Enregistrer l\'estimation';

  @override
  String get propertyErrorValuationInFuture =>
      'Une date d\'estimation ne peut pas être dans le futur.';

  @override
  String get propertyErrorNotFound => 'Ce bien n\'existe plus.';

  @override
  String get propertyErrorValidation =>
      'Certaines valeurs ont été refusées. Vérifiez le formulaire.';

  @override
  String get propertyErrorGeneric =>
      'Impossible d\'enregistrer le bien. Réessayez.';
}
