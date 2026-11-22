import 'dart:async';

import 'package:bastide/features/auth/application/auth_form_controllers.dart';
import 'package:bastide/features/auth/domain/availability.dart';
import 'package:bastide/features/auth/domain/display_name.dart';
import 'package:bastide/features/auth/domain/email_address.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A no-network « Connexion » submission double: records each call and, when
/// told to, fails with [error] or stays in flight until [hold] completes.
class FakeLoginController extends LoginController {
  FakeLoginController({this.error, this.hold});

  /// When set, the submission fails with it: the seam the screen's error
  /// states are asserted through.
  final Object? error;

  /// When set, the submission stays `AsyncLoading` until it completes.
  final Completer<void>? hold;

  final calls = <({String identifier, String password})>[];

  @override
  Future<void> submit({
    required String identifier,
    required String password,
  }) async {
    calls.add((identifier: identifier, password: password));
    if (hold case final hold?) {
      state = const AsyncValue.loading();
      await hold.future;
      state = const AsyncValue.data(null);
    }
    if (error case final error?) {
      state = AsyncValue.error(error, StackTrace.current);
    }
  }
}

/// A no-network availability double that answers at once, without the
/// debounce: every well-formed value is free unless listed as taken.
class FakeRegisterAvailabilityController
    extends RegisterAvailabilityController {
  FakeRegisterAvailabilityController({
    this.takenEmails = const {},
    this.takenNames = const {},
  });

  final Set<String> takenEmails;

  /// Matched ignoring case, as the backend does.
  final Set<String> takenNames;

  @override
  void emailChanged(String email) {
    final value = email.trim();
    state = RegisterAvailability(
      email: !isPlausibleEmail(value)
          ? Availability.unknown
          : takenEmails.contains(value)
          ? Availability.taken
          : Availability.available,
      displayName: state.displayName,
    );
  }

  @override
  void displayNameChanged(String displayName) {
    final value = normalizeDisplayName(displayName).toLowerCase();
    state = RegisterAvailability(
      email: state.email,
      displayName: !isValidDisplayName(value)
          ? Availability.unknown
          : takenNames.map((name) => name.toLowerCase()).contains(value)
          ? Availability.taken
          : Availability.available,
    );
  }
}

/// A no-network « Inscription » submission double, the same seams as
/// [FakeLoginController]. [fieldEdited] stays the real one.
class FakeRegisterController extends RegisterController {
  FakeRegisterController({this.error, this.hold});

  final Object? error;
  final Completer<void>? hold;

  final calls =
      <
        ({
          String email,
          String password,
          String displayName,
          String locale,
          String currency,
        })
      >[];

  @override
  Future<void> submit({
    required String email,
    required String password,
    required String displayName,
    required String locale,
    required String currency,
  }) async {
    calls.add((
      email: email,
      password: password,
      displayName: displayName,
      locale: locale,
      currency: currency,
    ));
    if (hold case final hold?) {
      state = const AsyncValue.loading();
      await hold.future;
      state = const AsyncValue.data(null);
    }
    if (error case final error?) {
      state = AsyncValue.error(error, StackTrace.current);
    }
  }
}
