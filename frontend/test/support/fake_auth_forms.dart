import 'dart:async';

import 'package:bastide/features/auth/application/auth_form_controllers.dart';
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
