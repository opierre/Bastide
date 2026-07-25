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
  String get statusBarReady => 'Prêt';

  @override
  String get authLoginTitle => 'Se connecter';

  @override
  String get authRegisterTitle => 'Créer un compte';

  @override
  String get authEmailLabel => 'E-mail';

  @override
  String get authPasswordLabel => 'Mot de passe';

  @override
  String get authDisplayNameLabel => 'Nom affiché';

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
  String get authErrorInvalidCredentials => 'E-mail ou mot de passe incorrect.';

  @override
  String get authErrorEmailTaken => 'Un compte existe déjà avec cet e-mail.';

  @override
  String get authErrorValidation => 'Certaines informations sont invalides.';

  @override
  String get authErrorGeneric => 'Une erreur est survenue. Veuillez réessayer.';
}
