import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../data/mortgages_repository.dart';
import '../domain/mortgage.dart';
import '../domain/schedule_row.dart';

/// Everything the Crédits list renders: the loans, the server-computed summary,
/// the filter they were fetched under, and the last action the server refused.
///
/// [actionError] lives inside the data rather than turning the whole
/// `AsyncValue` into an error: a refused archive says nothing about the list the
/// user is looking at.
@immutable
class MortgagesState {
  const MortgagesState({
    required this.mortgages,
    required this.summary,
    this.statusFilter,
    this.actionError,
  });

  final List<Mortgage> mortgages;
  final MortgageSummary summary;

  /// `null` is the API's default view: every loan but the archived ones.
  final MortgageStatus? statusFilter;
  final Object? actionError;

  /// The kind of the loan a trajectory end marker belongs to — the chart labels
  /// « fin prêt travaux », and the marker itself carries only an id and a label.
  MortgageKind? kindOf(String mortgageId) {
    for (final mortgage in mortgages) {
      if (mortgage.id == mortgageId) return mortgage.kind;
    }
    return null;
  }

  MortgagesState copyWith({
    List<Mortgage>? mortgages,
    MortgageSummary? summary,
    Object? actionError,
    bool clearActionError = false,
  }) => MortgagesState(
    mortgages: mortgages ?? this.mortgages,
    summary: summary ?? this.summary,
    statusFilter: statusFilter,
    actionError: clearActionError ? null : (actionError ?? this.actionError),
  );
}

/// The Crédits panel's state: the loan list and the summary, loaded together and
/// re-read together after every write.
///
/// The summary is never adjusted locally. Every figure on it — the charge, the
/// outstanding, the ratio, the trajectory — is the engine's (`PROJECT.md` §15),
/// and a client that patched it from the rows it holds would be a second
/// amortisation implementation.
class MortgagesController extends AsyncNotifier<MortgagesState> {
  MortgagesRepository get _repository => ref.read(mortgagesRepositoryProvider);

  @override
  Future<MortgagesState> build() => _load(null);

  Future<MortgagesState> _load(MortgageStatus? status) async {
    final mortgages = await _repository.list(status: status);
    final summary = await _repository.summary();
    return MortgagesState(
      mortgages: mortgages,
      summary: summary,
      statusFilter: status,
    );
  }

  Future<void> refresh() async {
    final status = state.value?.statusFilter;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _load(status));
  }

  /// Narrows the list to one status, or back to the default view.
  Future<void> setStatusFilter(MortgageStatus? status) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _load(status));
  }

  /// Declares a loan. Failures are rethrown: the form is still open and shows
  /// them inline, beside the number the user has to change.
  Future<MortgageDetail> create(LoanDraft draft) async {
    final created = await _repository.create(draft);
    await _reload();
    return created;
  }

  /// Edits a loan's declared inputs. Like [create], failures reach the form.
  Future<MortgageDetail> updateLoan(String mortgageId, LoanDraft draft) async {
    final updated = await _repository.update(mortgageId, draft);
    ref.invalidate(mortgageDetailProvider(mortgageId));
    await _reload();
    return updated;
  }

  /// Archives a loan: it leaves the list and every aggregate of the summary.
  /// Rethrown, since the confirmation that asked for it is still on screen.
  Future<void> archive(String mortgageId) async {
    await _repository.archive(mortgageId);
    ref.invalidate(mortgageDetailProvider(mortgageId));
    await _reload();
  }

  /// Brings an archived loan back to active.
  Future<void> restore(String mortgageId) async {
    try {
      await _repository.setStatus(mortgageId, MortgageStatus.active);
      ref.invalidate(mortgageDetailProvider(mortgageId));
      await _reload();
    } on ApiFailure catch (failure) {
      final current = state.value;
      if (current != null) {
        state = AsyncValue.data(current.copyWith(actionError: failure));
      }
    }
  }

  /// Declares the monthly income the ratio runs on, then re-reads the summary —
  /// the ratio, its source and `over_limit` all move with it.
  Future<void> declareIncome(int monthlyIncomeMinor) async {
    await _repository.declareIncome(monthlyIncomeMinor);
    final current = state.value;
    if (current == null) {
      await refresh();
      return;
    }
    final summary = await _repository.summary();
    state = AsyncValue.data(
      current.copyWith(summary: summary, clearActionError: true),
    );
  }

  void clearActionError() {
    final current = state.value;
    if (current == null) return;
    state = AsyncValue.data(current.copyWith(clearActionError: true));
  }

  /// Re-reads list and summary without passing through a loading state, so a
  /// save doesn't blank the panel behind the closing modal.
  Future<void> _reload() async {
    final status = state.value?.statusFilter;
    state = await AsyncValue.guard(() => _load(status));
  }
}

final mortgagesControllerProvider =
    AsyncNotifierProvider<MortgagesController, MortgagesState>(
      MortgagesController.new,
    );

/// "Today" for every date the panel reasons about — which schedule year opens,
/// which row is the current instalment. A provider so tests can pin the clock.
final mortgagesTodayProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// Which loan the panel is showing in detail, or `null` for the list.
///
/// Panel state rather than a route: the detail is a state of this panel — same
/// chrome, same top-bar controls, an iris back link (`12-credits.md` frame ②).
class SelectedMortgage extends Notifier<String?> {
  @override
  String? build() => null;

  void open(String mortgageId) => state = mortgageId;

  void close() => state = null;
}

final selectedMortgageProvider = NotifierProvider<SelectedMortgage, String?>(
  SelectedMortgage.new,
);

/// One loan with its cost totals, plus the interest still due after today.
final mortgageDetailProvider =
    FutureProvider.family<MortgageDetailView, String>((ref, mortgageId) async {
      final repository = ref.watch(mortgagesRepositoryProvider);
      final today = ref.watch(mortgagesTodayProvider)();
      final detail = await repository.detail(mortgageId);
      final interestStillDue = await repository.interestDueAfter(
        mortgageId,
        today,
      );
      return MortgageDetailView(
        detail: detail,
        interestStillDueMinor: interestStillDue,
      );
    });

/// The year the amortisation table is showing, for one loan's span of years.
///
/// Opens on the year of the current instalment; the YearSwitcher's chevrons
/// step one year and its strip jumps. Always clamped to the loan's own years —
/// there is nothing before the first instalment or after the last.
class ScheduleYearController extends Notifier<int> {
  ScheduleYearController(this.years);

  final ScheduleYears years;

  @override
  int build() => years.openingYear;

  void step(int delta) => state = years.clamp(state + delta);

  void select(int year) => state = years.clamp(year);
}

final scheduleYearControllerProvider =
    NotifierProvider.family<ScheduleYearController, int, ScheduleYears>(
      ScheduleYearController.new,
    );

/// One calendar year of one loan's schedule — the page the table draws.
final scheduleWindowProvider =
    FutureProvider.family<ScheduleYear, ({String mortgageId, int year})>((
      ref,
      window,
    ) {
      return ref
          .watch(mortgagesRepositoryProvider)
          .scheduleYear(window.mortgageId, window.year);
    });

/// The properties a loan can be linked to, for the form's property select.
final loanPropertiesProvider = FutureProvider<List<LoanProperty>>((ref) {
  return ref.watch(mortgagesRepositoryProvider).listProperties();
});
