import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n/locale_provider.dart';
import '../../../core/navigation/sidebar_controller.dart';
import '../../../core/session/current_user_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/app_segmented.dart';
import '../../../core/widgets/app_slider.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/money_field.dart';
import '../../../core/widgets/note_line.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/application/profile_controllers.dart';
import '../../auth/domain/theme_preference.dart';
import '../application/settings_controller.dart';
import '../domain/user_settings.dart';
import 'setting_row.dart';

/// The sample date the formats row prints, the spec's own.
final _sampleDate = DateTime(2026, 5, 14);

/// The sample amount the formats row prints: −1 234,56 €.
const _sampleAmountMinor = -123456;

/// Width of the declared income field (`09-settings.md` §Préférences).
const _incomeFieldWidth = 140.0;

/// Préférences: Affichage (theme, language, formats, sidebar), then Argent
/// (currency, savings-rate goal, declared income).
class PreferencesSection extends ConsumerWidget {
  const PreferencesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final activeLocale = Localizations.localeOf(context);
    final locale = activeLocale.toString();
    final user = ref.watch(currentUserProvider);
    final currency = user?.currency ?? '';
    // The switch is applied before the save answers; a refusal has already
    // put the previous theme back, so all that is left is to say so.
    ref.listen(themePreferenceControllerProvider, (_, next) {
      if (next.hasError) {
        showAppToast(
          context,
          title: l10n.settingsThemeSaveFailed,
          tone: BannerTone.error,
        );
      }
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroupTitle(title: l10n.settingsGroupDisplay, first: true),
        SettingRow(
          key: const Key('settingsThemeRow'),
          name: l10n.settingsThemeTitle,
          description: l10n.settingsThemeNote,
          children: [
            AppSegmented<ThemePreference>(
              value: user?.theme ?? ThemePreference.dark,
              // Applies at once, like the language below.
              onChanged: (value) => ref
                  .read(themePreferenceControllerProvider.notifier)
                  .choose(value),
              segments: [
                AppSegment(
                  key: const Key('settingsThemeSystemOption'),
                  value: ThemePreference.system,
                  label: l10n.settingsThemeSystem,
                ),
                AppSegment(
                  key: const Key('settingsThemeDarkOption'),
                  value: ThemePreference.dark,
                  label: l10n.settingsThemeDark,
                ),
                AppSegment(
                  key: const Key('settingsThemeLightOption'),
                  value: ThemePreference.light,
                  label: l10n.settingsThemeLight,
                ),
              ],
            ),
          ],
        ),
        SettingRow(
          key: const Key('settingsLanguageRow'),
          name: l10n.settingsLanguageTitle,
          description: l10n.settingsLanguageNote,
          children: [
            AppSegmented<String>(
              value: activeLocale.languageCode,
              // Switching takes effect immediately, including the chrome: the
              // description promises that, so it must not need a save.
              onChanged: (value) =>
                  ref.read(localeProvider.notifier).setLocale(Locale(value)),
              segments: [
                AppSegment(
                  key: const Key('settingsLocaleFrenchOption'),
                  value: 'fr',
                  label: l10n.authLocaleFrench,
                ),
                AppSegment(
                  key: const Key('settingsLocaleEnglishOption'),
                  value: 'en',
                  label: l10n.authLocaleEnglish,
                ),
              ],
            ),
          ],
        ),
        SettingRow(
          key: const Key('settingsFormatsRow'),
          name: l10n.settingsFormatsTitle,
          description: l10n.settingsFormatsNote,
          children: [
            _FormatsList(
              dateLabel: l10n.settingsFormatsDates,
              date: l10n.settingsFormatsDatePair(
                DateFormat.yMMMMd(locale).format(_sampleDate),
                DateFormat.yMd(locale).format(_sampleDate),
              ),
              amountLabel: l10n.settingsFormatsAmounts,
              amount: AmountText(
                key: const Key('settingsAmountPreview'),
                amountMinor: _sampleAmountMinor,
                currency: currency,
                // A sample figure, not a movement.
                colorize: false,
                style: Theme.of(context).textTheme.bodyMedium!,
              ),
            ),
          ],
        ),
        SettingRow(
          key: const Key('settingsSidebarRow'),
          name: l10n.settingsSidebarTitle,
          description: l10n.settingsSidebarNote,
          children: [
            AppSegmented<bool>(
              value: ref.watch(sidebarCollapsedProvider),
              // The same switch as Ctrl+B, so the two never disagree.
              onChanged: (collapsed) =>
                  ref.read(sidebarCollapsedProvider.notifier).set(collapsed),
              segments: [
                AppSegment(
                  key: const Key('settingsSidebarExpandedOption'),
                  value: false,
                  label: l10n.settingsSidebarExpanded,
                ),
                AppSegment(
                  key: const Key('settingsSidebarCollapsedOption'),
                  value: true,
                  label: l10n.settingsSidebarCollapsed,
                ),
              ],
            ),
          ],
        ),
        SettingsGroupTitle(title: l10n.settingsGroupMoney),
        SettingRow(
          key: const Key('settingsCurrencyRow'),
          name: l10n.settingsCurrencyTitle,
          description: l10n.settingsCurrencyNote,
          children: [
            ReadOnlyField(
              key: const Key('settingsCurrencyField'),
              value: currency.isEmpty
                  ? ''
                  : _currencyValue(l10n, currency, locale),
            ),
          ],
        ),
        SettingRow(
          key: const Key('settingsSavingsGoalRow'),
          name: l10n.settingsSavingsGoalTitle,
          description: l10n.settingsSavingsGoalNote,
          children: const [_SavingsGoal()],
        ),
        SettingRow(
          key: const Key('settingsIncomeRow'),
          name: l10n.settingsIncomeTitle,
          description: l10n.settingsIncomeNote,
          children: [_DeclaredIncome(currency: currency)],
        ),
      ],
    );
  }

  /// « EUR, euro (€) »; the symbol is left out where `intl` has none of its
  /// own and would only echo the code.
  static String _currencyValue(
    AppLocalizations l10n,
    String code,
    String locale,
  ) {
    final name = l10n.authCurrencyName(code);
    final symbol = NumberFormat.simpleCurrency(
      locale: locale,
      name: code,
    ).currencySymbol;
    return symbol == code
        ? l10n.authCurrencyOption(code, name)
        : l10n.settingsCurrencyValue(code, name, symbol);
  }
}

/// The formats row's key/value list, its values left-aligned beside their
/// labels as the mockup draws them.
class _FormatsList extends StatelessWidget {
  const _FormatsList({
    required this.dateLabel,
    required this.date,
    required this.amountLabel,
    required this.amount,
  });

  final String dateLabel;
  final String date;
  final String amountLabel;
  final Widget amount;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final labelStyle = textTheme.bodyMedium?.copyWith(
      color: context.colors.textSecondary,
    );

    return Table(
      defaultColumnWidth: const IntrinsicColumnWidth(),
      defaultVerticalAlignment: TableCellVerticalAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        TableRow(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xl),
              child: Text(dateLabel, style: labelStyle),
            ),
            Text(
              date,
              key: const Key('settingsDatePreview'),
              style: tabularNumberStyle(textTheme.bodyMedium!),
            ),
          ],
        ),
        TableRow(
          children: [
            Padding(
              padding: const EdgeInsets.only(
                right: AppSpacing.xl,
                top: AppSpacing.xsPlus,
              ),
              child: Text(amountLabel, style: labelStyle),
            ),
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xsPlus),
              child: amount,
            ),
          ],
        ),
      ],
    );
  }
}

/// The savings-rate goal: a slider from 0 to 50 %, step 1, its value printed
/// beside it. Saved with the settings debounce, so a drag sends one patch.
class _SavingsGoal extends ConsumerWidget {
  const _SavingsGoal();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final percent = NumberFormat.percentPattern(
      Localizations.localeOf(context).toString(),
    );
    final async = ref.watch(
      settingsControllerProvider.select(
        (value) =>
            value.whenData((state) => state.settings.savingsRateGoalPercent),
      ),
    );

    return async.when(
      loading: () => const SkeletonPulse(
        child: SkeletonBlock(
          height: AppSizes.formField,
          width: SettingRowMetrics.sliderWidth,
        ),
      ),
      error: (_, _) => NoteLine(text: l10n.settingsAiLoadFailed),
      data: (goal) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppSlider(
            key: const Key('settingsSavingsGoalSlider'),
            value: goal.toDouble(),
            max: UserSettings.maxSavingsRateGoalPercent.toDouble(),
            divisions: UserSettings.maxSavingsRateGoalPercent,
            width: SettingRowMetrics.sliderWidth,
            onChanged: (value) => ref
                .read(settingsControllerProvider.notifier)
                .setSavingsRateGoalPercent(value.round()),
            semanticFormatter: (value) => percent.format(value / 100),
          ),
          SizedBox(
            width: SettingRowMetrics.sliderValueWidth,
            child: Text(
              percent.format(goal / 100),
              key: const Key('settingsSavingsGoalValue'),
              textAlign: TextAlign.end,
              style: tabularNumberStyle(
                Theme.of(context).textTheme.bodyMedium!,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The declared income: an amount field and « par mois ». Empty means "not
/// declared". Commits on submit or when the field loses focus.
class _DeclaredIncome extends ConsumerWidget {
  const _DeclaredIncome({required this.currency});

  final String currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final async = ref.watch(
      settingsControllerProvider.select(
        (value) => value.whenData(
          (state) => state.settings.declaredMonthlyIncomeMinor,
        ),
      ),
    );

    return async.when(
      loading: () => const SkeletonPulse(
        child: SkeletonBlock(
          height: AppSizes.formField,
          width: _incomeFieldWidth,
        ),
      ),
      error: (_, _) => NoteLine(text: l10n.settingsAiLoadFailed),
      data: (minor) => _IncomeField(initialMinor: minor, currency: currency),
    );
  }
}

class _IncomeField extends ConsumerStatefulWidget {
  const _IncomeField({required this.initialMinor, required this.currency});

  final int? initialMinor;
  final String currency;

  @override
  ConsumerState<_IncomeField> createState() => _IncomeFieldState();
}

class _IncomeFieldState extends ConsumerState<_IncomeField> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _invalid = false;
  bool _seeded = false;

  /// What was last sent, so submitting and then leaving the field saves once.
  String? _committed;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Seeded once, with the locale's own spelling of the stored amount.
    if (_seeded) return;
    _seeded = true;
    final minor = widget.initialMinor;
    if (minor != null) {
      _controller.text = formatMoneyInput(
        minor,
        Localizations.localeOf(context).toString(),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _commit() async {
    if (!mounted) return;
    final locale = Localizations.localeOf(context).toString();
    final text = _controller.text.trim();
    if (text == _committed) return;
    final minor = text.isEmpty ? null : parseMoneyMinor(text, locale);
    final invalid = text.isNotEmpty && (minor == null || minor <= 0);
    setState(() => _invalid = invalid);
    if (invalid) return;

    _committed = text;
    final l10n = AppLocalizations.of(context)!;
    final saved = await ref
        .read(settingsControllerProvider.notifier)
        .declareIncome(minor);
    if (!saved && mounted) {
      // Refused: the next commit of the same text must try again.
      _committed = null;
      showAppToast(
        context,
        title: l10n.settingsIncomeSaveFailed,
        tone: BannerTone.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: _incomeFieldWidth,
              child: FocusGlow(
                child: Focus(
                  focusNode: _focus,
                  child: MoneyField(
                    key: const Key('settingsIncomeField'),
                    controller: _controller,
                    currency: widget.currency,
                    onFieldSubmitted: (_) => _commit(),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              l10n.settingsIncomePerMonth,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.colors.textTertiary,
              ),
            ),
          ],
        ),
        if (_invalid)
          FieldHelper(
            key: const Key('settingsIncomeInvalid'),
            text: l10n.settingsIncomeInvalid,
            isError: true,
          ),
      ],
    );
  }
}
