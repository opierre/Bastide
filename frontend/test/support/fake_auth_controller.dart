import 'package:finstride/features/auth/application/auth_controller.dart';
import 'package:finstride/features/auth/domain/auth_user.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A no-network `AuthController` double for widget tests that only need a
/// fixed session state and/or to record which methods were called — without
/// touching the real API client or secure storage platform channels.
class FakeAuthController extends AuthController {
  FakeAuthController({this.initialUser});

  final AuthUser? initialUser;

  final loginCalls = <({String email, String password})>[];
  final registerCalls =
      <({String email, String password, String displayName, String locale, String currency})>[];
  var logoutCallCount = 0;

  @override
  Future<AuthUser?> build() async => initialUser;

  @override
  Future<void> login({required String email, required String password}) async {
    loginCalls.add((email: email, password: password));
  }

  @override
  Future<void> register({
    required String email,
    required String password,
    required String displayName,
    required String locale,
    required String currency,
  }) async {
    registerCalls.add((
      email: email,
      password: password,
      displayName: displayName,
      locale: locale,
      currency: currency,
    ));
  }

  @override
  Future<void> logout() async {
    logoutCallCount++;
    state = const AsyncValue.data(null);
  }
}
