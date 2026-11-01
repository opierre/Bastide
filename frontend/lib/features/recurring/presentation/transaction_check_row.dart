import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../domain/series_preview.dart';

/// One checklist line: the gradient checkbox the rule modal draws, the date,
/// the label and the signed amount.
class TransactionCheckRow extends StatelessWidget {
  const TransactionCheckRow({
    super.key,
    required this.tickKey,
    required this.transaction,
    required this.date,
    required this.ticked,
    required this.onChanged,
    this.caption,
  });

  /// The key of the tappable line, which tests and callers tap.
  final Key tickKey;
  final PreviewTransaction transaction;
  final String date;
  final bool ticked;
  final VoidCallback? onChanged;

  /// A second line under the label, such as the account it was booked on.
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return MouseRegion(
      cursor: onChanged == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      child: GestureDetector(
        key: tickKey,
        onTap: onChanged,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm + AppSpacing.xs,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Semantics(
                checked: ticked,
                label: transaction.label,
                child: Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: ticked ? AppColors.irisGradient : null,
                    color: ticked ? null : AppColors.surfaceField,
                    borderRadius: BorderRadius.circular(AppRadii.xs + 1),
                    border: Border.all(
                      color: ticked ? Colors.transparent : AppColors.border,
                    ),
                  ),
                  child: ticked
                      ? const Icon(
                          Icons.check_rounded,
                          size: 13,
                          color: AppColors.irisInk,
                        )
                      : null,
                ),
              ),
              const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
              SizedBox(
                width: 90,
                child: Text(
                  date,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.label,
                      style: textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (caption case final caption?)
                      Text(
                        caption,
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              AmountText(
                amountMinor: transaction.amountMinor,
                currency: transaction.currency,
                style: textTheme.bodyMedium!,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
