import 'package:bastide/features/auth/application/auth_controller.dart';
import 'package:bastide/features/auth/domain/auth_user.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A no-network `AuthController` double for widget tests that only need a
/// fixed session state and/or to record which methods were called — without
/// touching the real API client or secure storage platform channels.
class FakeAuthController extends AuthController {
  FakeAuthController({this.initialUser});

  final AuthUser? initialUser;

  var logoutCallCount = 0;

  @override
  Future<AuthUser?> build() async => initialUser;

  @override
  Future<void> logout() async {
    logoutCallCount++;
    state = const AsyncValue.data(null);
  }
}
