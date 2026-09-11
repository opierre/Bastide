import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/primary_button.dart';
import '../../../l10n/app_localizations.dart';
import '../../rules/presentation/rule_editor_modal.dart';
import '../application/categories_controller.dart';
import 'category_form_modal.dart';

/// The categories panel's contribution to the top bar (`docs/design/08`): one
/// primary button whose label follows the visible view — « Nouvelle catégorie »
/// or « Nouvelle règle ».
///
/// It watches [categoriesViewProvider] rather than being told which view is up,
/// because the top bar is built above the content region and cannot read state
/// the panel below it owns.
class CategoriesTopBarActions extends ConsumerWidget {
  const CategoriesTopBarActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final view = ref.watch(categoriesViewProvider);
    final isRules = view == CategoriesView.rules;

    return PrimaryButton(
      key: isRules ? const Key('addRuleButton') : const Key('addCategoryButton'),
      label: isRules ? l10n.rulesAddButton : l10n.categoriesAddButton,
      icon: Icons.add_rounded,
      onPressed: () =>
          isRules ? showRuleEditor(context) : showCategoryForm(context),
    );
  }
}
