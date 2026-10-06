import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_modal.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/money_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../application/mortgages_controller.dart';
import '../domain/mortgage.dart';
import 'mortgage_labels.dart';

/// The ratio gauge's fixed scale, in bps: 0–60 % on Crédits (`00` §Patrimoine additions),
/// so the 35 % reference tick sits at the same x in every state.
const ratioGaugeScaleBps = 6000;

/// « Taux d'endettement » (`12-credits.md` §1, frames ① ④ ⑤).
///
/// The ratio is a *reading*, stated with its income, the income's source and
/// the HCSF reference. Above the reference is information in the warning tone —
/// an amber pill and fill, the border unchanged — never an error and never a
/// block. With no income there is no ratio, so no gauge is drawn: the card says
/// why and offers the way out.
class DebtRatioCard extends StatelessWidget {
  const DebtRatioCard({super.key, required this.summary});

  final MortgageSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final textTheme = Theme.of(context).textTheme;
    final ratio = summary.debtRatioBps;
    final income = summary.monthlyIncomeMinor;
    final known =
        summary.incomeSource != IncomeSource.unknown &&
        ratio != null &&
        income != null;

    String money(int minor) => formatAmount(
      amountMinor: minor,
      currency: summary.currency,
      locale: locale,
    );

    return AppCard(
      key: const Key('debtRatioCard'),
      padding: const EdgeInsets.symmetric(
        horizontal: 22,
        vertical: AppSpacing.cardPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.mortgagesRatioLabel.toUpperCase(),
                  style: AppTextStyles.statLabel,
                ),
              ),
              if (known && summary.overLimit)
                StatusPill(
                  key: const Key('ratioOverLimitPill'),
                  label: l10n.mortgagesRatioOverLimit,
                  tone: StatusPillTone.warning,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                known ? formatBps(ratio, locale) : '—',
                key: const Key('ratioValue'),
                style: tabularNumberStyle(textTheme.displayMedium!).copyWith(
                  color: known ? AppColors.textPrimary : AppColors.textDisabled,
                ),
              ),
              const SizedBox(width: AppSpacing.sm + 2),
              Flexible(
                child: Text(
                  l10n.mortgagesRatioReference(
                    formatBps(summary.hcsfLimitBps, locale, digits: 0),
                  ),
                  style: textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
          if (known) ...[
            RatioGauge(
              ratioBps: ratio,
              referenceBps: summary.hcsfLimitBps,
              overLimit: summary.overLimit,
            ),
            const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
            Text(
              summary.incomeSource == IncomeSource.declared
                  ? l10n.mortgagesRatioCaptionDeclared(
                      money(summary.monthlyChargeMinor),
                      money(income),
                    )
                  : l10n.mortgagesRatioCaptionLedger(
                      money(summary.monthlyChargeMinor),
                      money(income),
                    ),
              key: const Key('ratioCaption'),
              style: AppTextStyles.helper.copyWith(fontSize: 12),
            ),
            if (summary.incomeSource == IncomeSource.ledger) ...[
              const SizedBox(height: AppSpacing.xs + 2),
              Align(
                alignment: Alignment.centerLeft,
                child: InkWell(
                  key: const Key('ratioDeclareIncomeLink'),
                  onTap: () => showDeclareIncomeModal(context),
                  child: Text(
                    l10n.mortgagesRatioDeclareLink,
                    style: textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.iris,
                    ),
                  ),
                ),
              ),
            ],
          ] else ...[
            Text(
              l10n.mortgagesRatioUnknown,
              key: const Key('ratioUnknownText'),
              style: textTheme.bodySmall?.copyWith(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm + 2),
            Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                height: 30,
                child: OutlinedButton.icon(
                  key: const Key('ratioDeclareIncomeButton'),
                  onPressed: () => showDeclareIncomeModal(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.iris,
                    side: const BorderSide(color: AppColors.irisBorderStrong),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm + AppSpacing.xs,
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 15),
                  label: Text(l10n.mortgagesRatioDeclareButton),
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
          // Body content, never a tooltip: the app makes no lending decisions
          // and says so where the ratio is read.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(
                  Icons.info_outline_rounded,
                  size: 12,
                  color: AppColors.textDisabled,
                ),
              ),
              const SizedBox(width: AppSpacing.xs + 1),
              Expanded(
                child: Text(
                  l10n.mortgagesRatioCaveat,
                  key: const Key('ratioCaveat'),
                  style: AppTextStyles.helper.copyWith(
                    fontSize: 11,
                    color: AppColors.textDisabled,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The 8 px ratio gauge on a fixed 0–60 % scale, with the reference tick.
///
/// Iris under the reference, amber above it — the tone follows the API's
/// `over_limit` rather than a comparison made here. A ratio past the scale
/// clamps the fill; the card still prints the exact percent beside it.
class RatioGauge extends StatelessWidget {
  const RatioGauge({
    super.key,
    required this.ratioBps,
    required this.referenceBps,
    required this.overLimit,
  });

  final int ratioBps;
  final int referenceBps;
  final bool overLimit;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final fill = (ratioBps / ratioGaugeScaleBps).clamp(0.0, 1.0);
    final tick = (referenceBps / ratioGaugeScaleBps).clamp(0.0, 1.0);

    return Column(
      key: const Key('ratioGauge'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 16,
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: tick,
            child: Align(
              alignment: Alignment.centerRight,
              child: FractionalTranslation(
                translation: const Offset(0.5, 0),
                child: Text(
                  formatBps(referenceBps, locale, digits: 0),
                  style: AppTextStyles.helper.copyWith(
                    fontSize: 10.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        SizedBox(
          height: 12,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.xs),
                child: Container(
                  height: 8,
                  color: AppColors.surfaceHover,
                  child: FractionallySizedBox(
                    key: const Key('ratioGaugeFill'),
                    alignment: Alignment.centerLeft,
                    widthFactor: fill,
                    child: ColoredBox(
                      color: overLimit ? AppColors.warning : AppColors.iris,
                    ),
                  ),
                ),
              ),
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: tick,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FractionalTranslation(
                    translation: const Offset(0.5, 0),
                    child: Container(
                      key: const Key('ratioGaugeTick'),
                      width: 2,
                      height: 12,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

Future<void> showDeclareIncomeModal(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const DeclareIncomeModal(),
  );
}

/// « Déclarer un revenu » — the way out of an unknown or ledger-read ratio.
/// A declared income replaces the ledger median as the ratio's denominator.
class DeclareIncomeModal extends ConsumerStatefulWidget {
  const DeclareIncomeModal({super.key});

  @override
  ConsumerState<DeclareIncomeModal> createState() => _DeclareIncomeModalState();
}

class _DeclareIncomeModalState extends ConsumerState<DeclareIncomeModal> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorText;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final locale = Localizations.localeOf(context).toString();
    final amount = parseMoneyMinor(_amountController.text, locale);
    if (amount == null || amount <= 0) return;

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });
    try {
      await ref
          .read(mortgagesControllerProvider.notifier)
          .declareIncome(amount);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorText = AppLocalizations.of(context)!.mortgagesIncomeFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currency =
        ref.watch(mortgagesControllerProvider).value?.summary.currency ?? '';

    return AppModal(
      title: l10n.mortgagesIncomeTitle,
      width: 440,
      actions: [
        OutlinedButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.mortgageFormCancel),
        ),
        PrimaryButton(
          key: const Key('declareIncomeSubmit'),
          label: l10n.mortgagesIncomeSubmit,
          isLoading: _isSubmitting,
          onPressed: _isSubmitting ? null : _submit,
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.mortgagesIncomeBody,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            if (_errorText != null) ...[
              InlineBanner(message: _errorText!),
              const SizedBox(height: AppSpacing.md),
            ],
            LabeledField(
              label: l10n.mortgagesIncomeLabel,
              child: MoneyField(
                key: const Key('declareIncomeAmount'),
                controller: _amountController,
                currency: currency,
                autofocus: true,
                validator: (value) {
                  final locale = Localizations.localeOf(context).toString();
                  final amount = parseMoneyMinor(value ?? '', locale);
                  return amount == null || amount <= 0
                      ? l10n.mortgagesIncomeInvalid
                      : null;
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
