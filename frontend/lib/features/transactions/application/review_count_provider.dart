import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/transactions_repository.dart';
import 'transactions_controller.dart';

/// How many transactions wait in the review queue: the count the sidebar shows
/// beside « Transactions » (`docs/design/00-design-system.md` §5).
///
/// Read as the `total` of the queue's first page, so it costs one small
/// request. It follows every category saved through the app
/// ([transactionEditsProvider]); imports, categorization runs and data reloads
/// invalidate it themselves, since they change the queue without an edit.
final reviewCountProvider = FutureProvider<int>((ref) async {
  ref.watch(transactionEditsProvider);
  final page = await ref
      .read(transactionsRepositoryProvider)
      .list(needsReview: true);
  return page.total;
});
