import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../rules/presentation/rules_view.dart';
import 'category_tree.dart';

/// The Catégories et règles panel (`docs/design/08-categories-rules.md`): a
/// flush panel of two panes, the category tree on the left and the ordered
/// rules on the right. The tree selects what the rules pane shows.
///
/// No amount or spending share appears here: this is taxonomy management, and
/// spending lives on the dashboard.
class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  static const path = '/categories';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      key: const Key('screen-categories'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          key: const Key('categoryTreePane'),
          width: AppCategoriesPanel.treeWidth,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.smPlus,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            border: Border(right: BorderSide(color: context.colors.line)),
          ),
          child: const CategoryTree(),
        ),
        const Expanded(child: RulesView()),
      ],
    );
  }
}
