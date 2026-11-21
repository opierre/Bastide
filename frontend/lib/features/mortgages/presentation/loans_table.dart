import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/app_table.dart';
import '../../../core/widgets/institution_avatar.dart';
import '../../../core/widgets/repere_meter.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/mortgage.dart';
import 'mortgage_labels.dart';

/// The loans table of `12-credits.md` §2: one 48 px row per loan, every figure
/// neutral (a scheduled amount, not a booked transaction). A row opens the
/// loan detail.
class LoansTable extends StatelessWidget {
  const LoansTable({super.key, required this.mortgages, required this.onOpen});

  final List<Mortgage> mortgages;
  final ValueChanged<Mortgage> onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // « Remboursé » takes 22 % of the width; the seven others share the rest.
    final columns = [
      AppTableColumn(label: l10n.mortgagesTableLoan, flex: 16),
      AppTableColumn(label: l10n.mortgagesTableLender, flex: 13),
      AppTableColumn(label: l10n.mortgagesTableRate, flex: 7, numeric: true),
      AppTableColumn(
        label: l10n.mortgagesTableInsurance,
        flex: 8,
        numeric: true,
      ),
      AppTableColumn(
        label: l10n.mortgagesTableRepaid,
        flex: AppLoans.repaidFlex,
      ),
      AppTableColumn(
        label: l10n.mortgagesOutstandingLabel,
        flex: 12,
        numeric: true,
      ),
      AppTableColumn(label: l10n.mortgagesTableEnd, flex: 9, numeric: true),
      AppTableColumn(
        label: l10n.mortgagesTableInstalment,
        flex: 13,
        numeric: true,
      ),
    ];

    return Column(
      key: const Key('loansTable'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTableHeader(columns: columns),
        for (final mortgage in mortgages)
          _LoanRow(
            columns: columns,
            mortgage: mortgage,
            onTap: () => onOpen(mortgage),
          ),
      ],
    );
  }
}

class _LoanRow extends StatelessWidget {
  const _LoanRow({
    required this.columns,
    required this.mortgage,
    required this.onTap,
  });

  final List<AppTableColumn> columns;
  final Mortgage mortgage;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final secondary = TextStyle(color: colors.textSecondary);
    final id = mortgage.id;

    String money(int minor) => formatAmount(
      amountMinor: minor,
      currency: mortgage.currency,
      locale: locale,
    );

    final repaid = formatBps(mortgage.paidPrincipalBps, locale);

    return AppTableRow(
      key: Key('loanRow-$id'),
      columns: columns,
      twoLines: true,
      onTap: onTap,
      cells: [
        Row(
          children: [
            InstitutionAvatar(name: mortgage.lender),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                mortgage.label,
                key: Key('loanName-$id'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.labelLarge,
              ),
            ),
          ],
        ),
        Text(
          l10n.mortgagesTableLenderTerm(mortgage.lender, mortgage.termMonths),
          key: Key('loanLender-$id'),
          maxLines: 1,
          style: secondary,
        ),
        Text(
          formatBps(mortgage.annualRateBps, locale, digits: 2),
          key: Key('loanRate-$id'),
          maxLines: 1,
        ),
        Text(
          mortgage.insuranceMonthlyMinor > 0
              ? money(mortgage.insuranceMonthlyMinor)
              : '—',
          key: Key('loanInsurance-$id'),
          maxLines: 1,
          style: secondary,
        ),
        // 0 to principal, no mark (`00` §8); the share is printed under it.
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RepereMeter(
              key: Key('loanRepaidMeter-$id'),
              fraction: mortgage.paidPrincipalBps / 10000,
              semanticLabel: repaid,
            ),
            const SizedBox(height: AppSpacing.xsPlus),
            Text(
              l10n.mortgagesTableRepaidCaption(
                repaid,
                mortgage.remainingMonths,
              ),
              key: Key('loanRepaid-$id'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tabularNumberStyle(
                textTheme.labelSmall!,
              ).copyWith(color: colors.textTertiary),
            ),
          ],
        ),
        Text(
          money(mortgage.outstandingPrincipalMinor),
          key: Key('loanOutstanding-$id'),
          maxLines: 1,
        ),
        Text(
          mortgageMonthFormat(locale).format(mortgage.lastPaymentMonth),
          key: Key('loanEnd-$id'),
          maxLines: 1,
          style: secondary,
        ),
        Text(
          money(mortgage.totalInstalmentMinor),
          key: Key('loanInstalment-$id'),
          maxLines: 1,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
