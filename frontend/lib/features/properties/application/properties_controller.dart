import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../data/properties_repository.dart';
import '../domain/property.dart';

/// Everything the Biens view renders: the live properties, the archived ones
/// behind the foot link, whether that link is open, and the last menu action
/// the server refused.
///
/// The archived list is loaded up front so the link can state how many there
/// are before it is opened.
@immutable
class PropertiesState {
  const PropertiesState({
    required this.properties,
    required this.archived,
    this.showArchived = false,
    this.actionError,
  });

  final List<Property> properties;
  final List<Property> archived;
  final bool showArchived;
  final Object? actionError;

  PropertiesState copyWith({
    List<Property>? properties,
    List<Property>? archived,
    bool? showArchived,
    Object? actionError,
    bool clearActionError = false,
  }) => PropertiesState(
    properties: properties ?? this.properties,
    archived: archived ?? this.archived,
    showArchived: showArchived ?? this.showArchived,
    actionError: clearActionError ? null : (actionError ?? this.actionError),
  );
}

/// The declared properties: CRUD, « Nouvelle estimation », archive and
/// unarchive, each followed by a re-read of both lists.
///
/// No share is adjusted locally — the held share and the acquisition delta are
/// the server's (`PROJECT.md` §18).
class PropertiesController extends AsyncNotifier<PropertiesState> {
  PropertiesRepository get _repository =>
      ref.read(propertiesRepositoryProvider);

  @override
  Future<PropertiesState> build() => _load();

  Future<PropertiesState> _load({bool showArchived = false}) async {
    final properties = await _repository.list();
    final archived = await _repository.list(archived: true);
    return PropertiesState(
      properties: properties,
      archived: archived,
      // Nothing left to show: the link folds back up rather than staying open
      // on an empty list.
      showArchived: showArchived && archived.isNotEmpty,
    );
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_load);
  }

  /// Declares a property. Failures are rethrown: the form is still open and
  /// shows them beside the field to change.
  Future<Property> create(PropertyDraft draft) async {
    final created = await _repository.create(draft);
    await _afterWrite();
    return created;
  }

  /// Edits a property's declared inputs. Like [create], failures reach the form.
  Future<Property> updateProperty(
    String propertyId,
    PropertyDraft draft,
  ) async {
    final updated = await _repository.update(propertyId, draft);
    await _afterWrite();
    return updated;
  }

  /// « Nouvelle estimation »: a new declared value and its date. Rethrown for
  /// the modal that asked for it.
  Future<Property> revalue(
    String propertyId, {
    required int marketValueMinor,
    required DateTime valuedOn,
  }) async {
    final updated = await _repository.revalue(
      propertyId,
      marketValueMinor: marketValueMinor,
      valuedOn: valuedOn,
    );
    await _afterWrite();
    return updated;
  }

  /// Archives a property: it leaves the list and the summary's assets, and
  /// stays reachable through the archived link.
  Future<void> archive(String propertyId) =>
      _menuAction(() => _repository.archive(propertyId));

  Future<void> unarchive(String propertyId) =>
      _menuAction(() => _repository.unarchive(propertyId));

  /// Opens or folds the archived properties below the grid.
  void toggleArchived() {
    final current = state.value;
    if (current == null) return;
    state = AsyncValue.data(
      current.copyWith(
        showArchived: !current.showArchived && current.archived.isNotEmpty,
      ),
    );
  }

  void clearActionError() {
    final current = state.value;
    if (current == null) return;
    state = AsyncValue.data(current.copyWith(clearActionError: true));
  }

  /// A menu action has no form to report into, so a refusal is kept beside the
  /// grid rather than turning the whole view into an error.
  Future<void> _menuAction(Future<Object?> Function() action) async {
    try {
      await action();
      await _afterWrite();
    } on ApiFailure catch (failure) {
      final current = state.value;
      if (current != null) {
        state = AsyncValue.data(current.copyWith(actionError: failure));
      }
    }
  }

  /// Re-reads both lists without passing through a loading state, so a save
  /// doesn't blank the grid behind the closing modal.
  Future<void> _afterWrite() async {
    final showArchived = state.value?.showArchived ?? false;
    state = await AsyncValue.guard(() => _load(showArchived: showArchived));
  }
}

final propertiesControllerProvider =
    AsyncNotifierProvider<PropertiesController, PropertiesState>(
      PropertiesController.new,
    );
