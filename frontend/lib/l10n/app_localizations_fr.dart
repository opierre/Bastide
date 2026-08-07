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
      'Relevés OFX, QFX et CSV — traités sur cet ordinateur';

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
  String get authLoginTitle => 'Se connecter';

  @override
  String get authRegisterTitle => 'Créer un compte';

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
  String get accountsSearchHint => 'Rechercher…';

  @override
  String get accountsSearchEmpty =>
      'Aucun compte ne correspond à votre recherche.';

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
  String get importDropZoneTitle => 'Déposez un fichier OFX, QFX ou CSV';

  @override
  String get importDropZoneHint =>
      'ou cliquez pour parcourir — un CSV ouvre l\'assistant de correspondance';

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
  String get importOpenWizard => 'Configurer et importer';

  @override
  String importTemplateReuse(String bank) {
    return 'Format CSV mémorisé pour $bank — il sera réutilisé pour ce fichier.';
  }

  @override
  String get importReconfigureTemplate => 'Reconfigurer';

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
  String get csvWizardTitle => 'Assistant CSV';

  @override
  String get csvWizardStepFormat => 'Format';

  @override
  String get csvWizardStepColumns => 'Colonnes & aperçu';

  @override
  String get csvWizardCancel => 'Annuler';

  @override
  String get csvWizardNext => 'Continuer';

  @override
  String get csvWizardConfirm => 'Valider et importer';

  @override
  String get csvWizardConfirming => 'Import en cours…';

  @override
  String get csvWizardBankLabel => 'Banque';

  @override
  String get csvWizardBankHelper =>
      'Ce format sera mémorisé sous ce nom et réutilisé à chaque import de cette banque.';

  @override
  String get csvWizardDelimiterLabel => 'Délimiteur';

  @override
  String get csvDelimiterSemicolon => 'Point-virgule ( ; )';

  @override
  String get csvDelimiterComma => 'Virgule ( , )';

  @override
  String get csvDelimiterTab => 'Tabulation';

  @override
  String get csvDelimiterPipe => 'Barre verticale ( | )';

  @override
  String get csvWizardEncodingLabel => 'Encodage';

  @override
  String get csvWizardDateFormatLabel => 'Format de date';

  @override
  String get csvWizardDecimalLabel => 'Séparateur décimal';

  @override
  String get csvDecimalComma => 'Virgule ( , )';

  @override
  String get csvDecimalPeriod => 'Point ( . )';

  @override
  String get csvWizardAmountsLabel => 'Montants';

  @override
  String get csvAmountStrategySigned => 'Signé';

  @override
  String get csvAmountStrategyDebitCredit => 'Débit / Crédit';

  @override
  String get csvWizardHeaderOffsetLabel => 'Lignes à ignorer';

  @override
  String get csvWizardHeaderOffsetHelper => 'Avant la ligne d\'en-tête.';

  @override
  String get csvWizardColumnsHint =>
      'Indiquez le nom de la colonne du fichier (ou son numéro, à partir de 0) pour chaque information.';

  @override
  String get csvWizardColumnHint => 'Nom ou numéro de colonne';

  @override
  String get csvWizardColumnOptional => 'facultatif';

  @override
  String get csvColumnBookedDate => 'Date d\'opération';

  @override
  String get csvColumnValueDate => 'Date de valeur';

  @override
  String get csvColumnDescription => 'Libellé';

  @override
  String get csvColumnAmount => 'Montant';

  @override
  String get csvColumnDebit => 'Débit';

  @override
  String get csvColumnCredit => 'Crédit';

  @override
  String get csvWizardPreviewTitle => 'Aperçu';

  @override
  String get csvWizardPreviewPending =>
      'Renseignez les colonnes obligatoires pour voir un aperçu.';

  @override
  String get csvWizardPreviewEmpty =>
      'Aucune ligne lisible avec ce paramétrage.';

  @override
  String get csvPreviewDateHeader => 'Date';

  @override
  String get csvPreviewDescriptionHeader => 'Libellé';

  @override
  String get csvPreviewAmountHeader => 'Montant';

  @override
  String get importErrorAccountNotFound => 'Compte introuvable.';

  @override
  String get importErrorBatchNotFound => 'Import introuvable.';

  @override
  String get importErrorTemplateNotFound =>
      'Format CSV introuvable — relancez l\'assistant.';

  @override
  String get importErrorTemplateInvalid =>
      'Ce paramétrage ne correspond pas au fichier — ajustez les colonnes ci-dessus.';

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
  String transactionsPager(int from, int to, int total) {
    return '$from–$to sur $total';
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
  String get dashboardEmptyTitle =>
      'Importez un relevé pour donner vie à votre argent';

  @override
  String get dashboardEmptyBody =>
      'Vos revenus, vos dépenses et votre taux d\'épargne apparaîtront ici dès votre premier import.';

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
}
