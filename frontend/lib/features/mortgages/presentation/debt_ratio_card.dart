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
import '../../../core/widgets/repere_meter.dart';
import '../../../core/widgets/status_text.dart';
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
                  style: context.textStyles.statLabel,
                ),
              ),
              if (known && summary.overLimit)
                StatusText(
                  key: const Key('ratioOverLimitPill'),
                  label: l10n.mortgagesRatioOverLimit,
                  tone: StatusTone.warning,
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
                  color: known
                      ? context.colors.text
                      : context.colors.textTertiary,
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
                    color: context.colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
          if (known) ...[
            // The tone follows the API's `over_limit` rather than a
            // comparison made here; the scale is the fixed 0–60 % of `00` §8.
            RepereMeter(
              key: const Key('ratioGauge'),
              fraction: ratio / ratioGaugeScaleBps,
              tone: summary.overLimit ? RepereTone.over : RepereTone.normal,
              markFraction: summary.hcsfLimitBps / ratioGaugeScaleBps,
              markLabel: formatBps(summary.hcsfLimitBps, locale, digits: 0),
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
              style: context.textStyles.helper.copyWith(fontSize: 12),
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
                      color: context.colors.accent,
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
                color: context.colors.textSecondary,
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
                    foregroundColor: context.colors.accent,
                    side: BorderSide(color: context.colors.line),
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
              Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(
                  Icons.info_outline_rounded,
                  size: 12,
                  color: context.colors.textTertiary,
                ),
              ),
              const SizedBox(width: AppSpacing.xs + 1),
              Expanded(
                child: Text(
                  l10n.mortgagesRatioCaveat,
                  key: const Key('ratioCaveat'),
                  style: context.textStyles.helper.copyWith(
                    fontSize: 11,
                    color: context.colors.textTertiary,
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
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.colors.textSecondary,
              ),
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
