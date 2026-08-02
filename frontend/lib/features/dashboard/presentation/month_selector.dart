import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/tokens.dart';
import '../application/dashboard_controller.dart';

/// The dashboard's top-bar contextual control: a « ‹ Mai 2026 › » pill stepping one month at a
/// time (see `docs/design/04-dashboard.md` §Top bar).
class DashboardTopBarActions extends ConsumerWidget {
  const DashboardTopBarActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(dashboardControllerProvider).value?.month;
    final locale = Localizations.localeOf(context).toString();
    final label = month == null ? '' : _capitalize(DateFormat.yMMMM(locale).format(month));
    final controller = ref.read(dashboardControllerProvider.notifier);

    return Container(
      height: AppChrome.controlPillHeight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(
            key: const Key('dashboardMonthPrev'),
            icon: Icons.chevron_left_rounded,
            onPressed: month == null ? null : () => controller.changeMonth(_shift(month, -1)),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 96),
            child: Text(
              label,
              key: const Key('dashboardMonthLabel'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          _StepButton(
            key: const Key('dashboardMonthNext'),
            icon: Icons.chevron_right_rounded,
            onPressed: month == null ? null : () => controller.changeMonth(_shift(month, 1)),
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({super.key, required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 18),
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
    );
  }
}

DateTime _shift(DateTime month, int months) => DateTime(month.year, month.month + months);

String _capitalize(String value) =>
    value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);
