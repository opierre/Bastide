import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../l10n/app_localizations.dart';
import '../../rules/application/rules_controller.dart';
import '../../rules/application/rules_filter.dart';
import '../../rules/presentation/rule_editor_modal.dart';
import '../../rules/presentation/rule_error_localizer.dart';

/// The categories panel's title: « Catégories et règles », where the sidebar
/// names the section « Catégories » (`docs/design/08`).
class CategoriesTitle extends StatelessWidget {
  const CategoriesTitle({super.key});

  @override
  Widget build(BuildContext context) =>
      TitleBarTitle(title: AppLocalizations.of(context)!.categoriesPanelTitle);
}

/// The categories panel's contribution to the title bar (`docs/design/08`):
/// secondary « Exécuter les règles » (`play`) and primary « Nouvelle règle »
/// (`plus`). A new rule targets the category the rules pane is filtered on.
class CategoriesTopBarActions extends ConsumerStatefulWidget {
  const CategoriesTopBarActions({super.key});

  @override
  ConsumerState<CategoriesTopBarActions> createState() =>
      _CategoriesTopBarActionsState();
}

class _CategoriesTopBarActionsState
    extends ConsumerState<CategoriesTopBarActions> {
  bool _isApplying = false;

  Future<void> _apply() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isApplying = true);
    try {
      final count = await ref.read(rulesControllerProvider.notifier).apply();
      if (!mounted) return;
      // Two lines, because the count alone leaves the question the second one
      // answers: the run never overwrites a category the user chose by hand,
      // and a bulk action that doesn't say so invites an undo the app can't
      // offer.
      showAppToast(
        context,
        title: l10n.rulesApplyToastTitle(count),
        message: l10n.rulesApplyToastBody,
      );
    } catch (error) {
      if (!mounted) return;
      showAppToast(
        context,
        title: l10n.rulesApplyFailed,
        message: localizeRuleError(l10n, error),
        tone: BannerTone.error,
      );
    } finally {
      if (mounted) setState(() => _isApplying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppButton(
          key: const Key('applyRulesButton'),
          label: l10n.rulesApplyButton,
          loadingLabel: l10n.rulesApplyRunning,
          icon: LucideIcons300.play,
          isLoading: _isApplying,
          onPressed: _apply,
        ),
        const SizedBox(width: AppSpacing.sm),
        PrimaryButton(
          key: const Key('addRuleButton'),
          label: l10n.rulesAddButton,
          icon: LucideIcons300.plus,
          onPressed: () => showRuleEditor(
            context,
            initialCategoryId: ref.read(rulesCategoryFilterProvider),
          ),
        ),
      ],
    );
  }
}
