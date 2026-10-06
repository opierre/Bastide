import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Active app locale. French first; switchable in settings.
class LocaleController extends Notifier<Locale> {
  @override
  Locale build() => const Locale('fr');

  void setLocale(Locale locale) => state = locale;
}

final localeProvider = NotifierProvider<LocaleController, Locale>(
  LocaleController.new,
);
