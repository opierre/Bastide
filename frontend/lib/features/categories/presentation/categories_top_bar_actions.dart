import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/primary_button.dart';
import '../../../l10n/app_localizations.dart';
import 'category_form_modal.dart';

/// The categories panel's contribution to the top bar: the primary add action
/// (`docs/design/08` — right of the title, beside the user pill).
class CategoriesTopBarActions extends ConsumerWidget {
  const CategoriesTopBarActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return PrimaryButton(
      key: const Key('addCategoryButton'),
      label: l10n.categoriesAddButton,
      icon: Icons.add_rounded,
      onPressed: () => showCategoryForm(context),
    );
  }
}
